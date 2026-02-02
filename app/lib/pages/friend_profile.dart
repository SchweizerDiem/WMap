import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:country_flags/country_flags.dart' as country_flags;
import '../session_manager.dart';
import '../country_names.dart';

class FriendProfilePage extends StatelessWidget {
  final Map<String, dynamic> friendData;

  const FriendProfilePage({super.key, required this.friendData});

  String normalize(String code) => code.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final String friendId = friendData['id'] ?? '';
    final String name = friendData['name'] ?? 'Friend';
    final Set<String> visited = Set<String>.from(friendData['visitedCountries'] ?? []);
    final Set<String> planned = Set<String>.from(friendData['plannedCountries'] ?? []);
    
    const int totalCountries = 250;
    final percent = (visited.length / totalCountries * 100);

    final Map<String, Color> colorMap = {};
    for (var code in visited) {
      colorMap[normalize(code)] = const Color.fromARGB(255, 31, 131, 212);
    }
    for (var code in planned) {
      colorMap.putIfAbsent(normalize(code), () => const Color.fromARGB(255, 6, 16, 148));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$name's Profile"),
        actions: [
          // Botão para remover amigo
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Nome do Amigo
            Text(
              name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 2. Mapa Estático Centrado
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

            const SizedBox(height: 24),

            // 3. Card de Países Visitados (Igual ao Profile)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const Text(
                      'Countries Visited',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${visited.length} / $totalCountries',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    ExpansionTile(
                      title: const Text('Show visited countries'),
                      children: visited.isEmpty 
                        ? [const Padding(padding: EdgeInsets.all(12), child: Text("No countries visited yet."))]
                        : visited.map((code) => ListTile(
                            leading: SizedBox(
                              width: 40,
                              height: 24,
                              child: country_flags.CountryFlag.fromCountryCode(code),
                            ),
                            title: Text(getCountryName(code)),
                            subtitle: Text(code.toUpperCase()),
                          )).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Card de Percentagem (Igual ao Profile)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const Text(
                      'Percentage of World Visited',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: (percent / 100).clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedValue, child) {
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: animatedValue,
                                minHeight: 16,
                                color: Theme.of(context).primaryColor,
                                backgroundColor: Colors.grey[200],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(animatedValue * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 5. Card de Viagens Futuras (Igual ao Profile)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const Text(
                      'Future Trips',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${planned.length}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    ExpansionTile(
                      title: const Text('Show planned countries'),
                      children: planned.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(12), child: Text("No planned trips."))]
                        : planned.map((code) => ListTile(
                            leading: SizedBox(
                              width: 40,
                              height: 24,
                              child: country_flags.CountryFlag.fromCountryCode(code),
                            ),
                            title: Text(getCountryName(code)),
                            subtitle: Text(code.toUpperCase()),
                          )).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                Navigator.pop(context); // Fecha o dialog
                Navigator.pop(context); // Volta para a lista de amigos
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