import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import '../session_manager.dart';
import '../country_names.dart';

class FriendProfilePage extends StatelessWidget {
  final Map<String, dynamic> friendData;

  const FriendProfilePage({super.key, required this.friendData});

  // Função para garantir que os códigos dos países fiquem em minúsculas para o pacote do mapa
  String normalize(String code) => code.toLowerCase();

  @override
  Widget build(BuildContext context) {
    // 1. Extração de dados básicos: recupera as informações do mapa de dados do amigo
    final String friendId = friendData['id'] ?? '';
    final String name = friendData['name'] ?? 'Friend';
    final Set<String> visited = Set<String>.from(friendData['visitedCountries'] ?? []);
    final Set<String> planned = Set<String>.from(friendData['plannedCountries'] ?? []);
    final List<String> nationalities = List<String>.from(friendData['nationalities'] ?? []);
    
    // 2. Cálculos consolidados: define estatísticas de exploração (Nacionalidades + Visitados)
    const int totalCountries = 250;
    final Set<String> allVisited = {...nationalities, ...visited};
    final int totalVisitedCount = allVisited.length;
    final double percentValue = (totalVisitedCount / totalCountries).clamp(0.0, 1.0);

    // 3. Mapeamento de cores para o Mapa: define a lógica visual de preenchimento do mapa mundial
    final Map<String, Color> colorMap = {};

    // Define a cor para países Planeados (Base)
    for (var code in planned) {
      colorMap[normalize(code)] = const Color.fromARGB(255, 6, 16, 148);
    }
    // Define a cor para países Visitados (Sobrepõe os planeados)
    for (var code in visited) {
      colorMap[normalize(code)] = const Color.fromARGB(255, 31, 131, 212);
    }
    // Define a cor para as Nacionalidades (Prioridade visual máxima)
    for (var code in nationalities) {
      colorMap[normalize(code)] = const Color.fromARGB(255, 9, 181, 233);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$name's Profile"),
        actions: [
          // Botão para remover o amigo da lista
          IconButton(
            icon: const Icon(Icons.person_remove, color: Colors.redAccent),
            onPressed: () => _showRemoveDialog(context, friendId, name),
            tooltip: 'Remove Friend',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- CABEÇALHO (Exibe Nome e Bandeiras das nacionalidades lado a lado) ---
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  if (nationalities.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: nationalities.map((code) {
                        String displayCode = code.toUpperCase();
                        if (displayCode == 'KO' || displayCode == 'KOS') displayCode = 'XK';
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: buildFlag(displayCode, width: 26, height: 18),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
                        
            const SizedBox(height: 24),

            // --- MAPA ESTÁTICO (Representação visual das viagens do amigo com zoom) ---
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  maxScale: 5.0,
                  child: SimpleMap(
                    instructions: SMapWorld.instructions,
                    defaultColor: Colors.grey[300]!,
                    colors: colorMap,
                    countryBorder: const CountryBorder(color: Colors.black, width: 0.1),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            const Divider(height: 48),

            // --- CARD: COUNTRIES VISITED (Lista expansível com os países já visitados) ---
            Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: const Text('Countries Visited', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('$totalVisitedCount / $totalCountries'),
                children: [
                  if (allVisited.isEmpty)
                    const ListTile(title: Text("No countries visited yet."))
                  else
                    Column(
                      children: allVisited.map((code) {
                        String displayCode = code.toUpperCase();
                        if (displayCode == 'KO' || displayCode == 'KOS') displayCode = 'XK';

                        return ListTile(
                          leading: buildFlag(displayCode, width: 32, height: 22),
                          title: Text(getCountryName(displayCode)),
                          subtitle: Text(displayCode),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- CARD: WORLD EXPLORATION (Barra de progresso percentual do mundo explorado) ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'World Exploration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: percentValue,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(percentValue * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- CARD: FUTURE TRIPS (Lista expansível com os países que o amigo planeia visitar) ---
            Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: const Text('Future Trips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('${planned.length} countries planned'),
                children: [
                  if (planned.isEmpty)
                    const ListTile(title: Text("No planned trips."))
                  else
                    Column(
                      children: planned.map((code) {
                        String displayCode = code.toUpperCase();
                        if (displayCode == 'KO' || displayCode == 'KOS') displayCode = 'XK';

                        return ListTile(
                          leading: buildFlag(displayCode, width: 32, height: 22),
                          title: Text(getCountryName(displayCode)),
                          subtitle: Text(displayCode),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Diálogo de confirmação para remover o amigo
  void _showRemoveDialog(BuildContext context, String friendId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Are you sure you want to remove $name from your friends?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await SessionManager().removeFriend(friendId);
              if (context.mounted) {
                Navigator.pop(context); 
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name removed.')),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}