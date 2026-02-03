import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:country_flags/country_flags.dart' as country_flags;
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

// Pages
import './pages/welcome.dart';
import './pages/login.dart';
import './pages/register.dart';
import './pages/settings.dart';
import './pages/profile.dart';
import './pages/friends.dart';
import './pages/gallery.dart';
import 'session_manager.dart';
import 'country_names.dart';

String normalizeCountryCode(String code) {
  return code.toLowerCase();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // --- LÓGICA DE ARRANQUE (REMEMBER ME) ---
  final prefs = await SharedPreferences.getInstance();
  final bool rememberMe = prefs.getBool('remember_me') ?? false;
  final user = FirebaseAuth.instance.currentUser;

  Widget initialScreen;

  if (rememberMe && user != null) {
    // Se quer ser lembrado e está logado, atualiza dados e vai para Home
    await SessionManager().refreshUserData();
    initialScreen = const HomePage();
  } else {
    // Caso contrário, Welcome Page
    initialScreen = const WelcomePage();
  }
  // ---------------------------------------

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WMap',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: initialScreen, // Define a página inicial dinamicamente
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/settings': (context) => const SettingsPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final TransformationController _transformationController = TransformationController();
  Set<String> _nationalityCountries = <String>{};

  @override
  void initState() {
    super.initState();

    // EXECUTAR O ZOOM APÓS O MAPA ESTAR MONTADO
   WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      setState(() {
        
        _transformationController.value = Matrix4.identity()
          ..scale(4.0) 
          ..translate(-150.0, -210.0, 0.0); 
      });
    }
  });
    
    Future.delayed(Duration.zero, () async {
      final session = SessionManager();
      await session.refreshUserData();
      final user = session.getCurrentUser();
      
      if (user != null) {
        setState(() {
          _nationalityCountries = user.nationalities.toSet();
        });
        if (user.nationalities.isEmpty && mounted) {
          _showNationalityPicker();
        }
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DA API REST COUNTRIES ---
  Future<Map<String, dynamic>?> _fetchCountryData(String code) async {
    try {
      final response = await http.get(Uri.parse('https://restcountries.com/v3.1/alpha/$code'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final country = data[0];
        final List<dynamic>? capitalsList = country['capital'];
        final String capitals = capitalsList != null ? capitalsList.join(', ') : 'N/A';

        return {
          'capital': capitals,
          'population': country['population'] ?? 0,
          'region': country['region'] ?? 'N/A',
          'subregion': country['subregion'] ?? 'N/A',
          'languages': (country['languages'] as Map?)?.values.join(', ') ?? 'N/A',
          'currency': (country['currencies'] as Map?)?.values.first['name'] ?? 'N/A',
          'currencySymbol': (country['currencies'] as Map?)?.values.first['symbol'] ?? '',
        };
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    return null;
  }

  void _showCountryInfoSheet(BuildContext context, String countryCode, String countryName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 70,
                      height: 45,
                      child: countryCode.toUpperCase() == 'XK' 
                        ? Container(color: Colors.white, child: Center(child: Image.asset('assets/images/Flag_of_Kosovo.svg.webp', fit: BoxFit.cover)),):  
                      country_flags.CountryFlag.fromCountryCode(countryCode),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(countryName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(height: 30),
              FutureBuilder<Map<String, dynamic>?>(
                future: _fetchCountryData(countryCode),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(30), 
                      child: Center(child: CircularProgressIndicator())
                    );
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    return _buildDetailsGrid(snapshot.data!);
                  }
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Information temporarily unavailable."),
                  );
                },
              ),
              const SizedBox(height: 25),
              _buildActionButtons(context, countryCode),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsGrid(Map<String, dynamic> data) {
    final f = NumberFormat.compact();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _infoTile(Icons.location_city, "Capital(s)", data['capital'])),
            const SizedBox(width: 10),
            Expanded(child: _infoTile(Icons.people, "Population", f.format(data['population']))),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _infoTile(Icons.translate, "Languages", data['languages'])),
            const SizedBox(width: 10),
            Expanded(child: _infoTile(Icons.payments, "Currency", "${data['currency']} (${data['currencySymbol']})")),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _infoTile(Icons.public, "Region", data['region'])),
            const SizedBox(width: 10),
            Expanded(child: _infoTile(Icons.map, "Subregion", data['subregion'])),
          ],
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    final displayValue = value.replaceAll(', ', '\n');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(displayValue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3), softWrap: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, String code) {
    final session = SessionManager();
    final isNationality = _nationalityCountries.map((e) => e.toUpperCase()).contains(code.toUpperCase());

    if (isNationality) {
      return const Center(
        child: Text('🌍 This is your nationality!', 
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue, fontWeight: FontWeight.bold))
      );
    }

    return StatefulBuilder(builder: (context, setInternalState) {
      final bool isVisited = session.isCountryVisitedForCurrentUser(code);
      final bool isPlanned = session.isCountryPlannedForCurrentUser(code);

      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(isVisited ? Icons.check : Icons.add),
              label: Text(isVisited ? "Visited" : "Visit"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isVisited ? const Color.fromARGB(255, 31, 131, 212) : Colors.grey[200],
                foregroundColor: isVisited ? Colors.white : Colors.black,
              ),
              onPressed: () async {
                await session.toggleVisitedForCurrentUser(code);
                setInternalState(() {}); 
                setState(() {}); 
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(isPlanned ? Icons.bookmark : Icons.bookmark_border),
              label: Text(isPlanned ? "Planned" : "Plan"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPlanned ? const Color.fromARGB(255, 6, 16, 148) : Colors.grey[200],
                foregroundColor: isPlanned ? Colors.white : Colors.black,
              ),
              onPressed: () async {
                await session.togglePlannedForCurrentUser(code);
                setInternalState(() {});
                setState(() {});
              },
            ),
          ),
        ],
      );
    });
  }

  Future<void> _showNationalityPicker() async {
    final countries = countryNames.entries.map((e) => {'code': e.key, 'name': e.value}).toList();

    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final selectedSet = <String>{};
        final searchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            final query = searchController.text.toLowerCase();
            final filtered = countries.where((c) => c['name']!.toLowerCase().contains(query)).toList();

            return AlertDialog(
              title: const Text('Select your nationalities'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(hintText: 'Search...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return CheckboxListTile(
                            value: selectedSet.contains(c['code']),
                            onChanged: (val) => setState(() => val! ? selectedSet.add(c['code']!) : selectedSet.remove(c['code'])),
                            title: Text(c['name']!),
                            secondary: buildFlag(c['code']!, width: 45, height: 30),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, []), child: const Text('Skip')),
                ElevatedButton(onPressed: () => Navigator.pop(context, selectedSet.toList()), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() { _nationalityCountries = selected.toSet(); });
      await SessionManager().updateNationalities(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset("assets/images/airplane-tilt.svg", width: 40),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) => setState(() => currentPageIndex = index),
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Friends'),
          NavigationDestination(icon: Icon(Icons.image), label: 'Gallery'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      body: <Widget>[
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search countries...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : Expanded(
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      maxScale: 20.0,
                      minScale: 4.0,
                      
                      // REMOVIDO O CENTER DAQUI PARA O ZOOM FUNCIONAR
                      child: ValueListenableBuilder<int>(
                        valueListenable: SessionManager().visitedCountNotifier,
                        builder: (context, visitedCount, child) {
                          final session = SessionManager();
                          final user = session.getCurrentUser();
                          
                          final visited = user?.visitedCountries ?? {};
                          final planned = user?.plannedCountries ?? {};
                          final nationalities = user?.nationalities ?? []; 

                          final Map<String, Color> colorMap = {};

                          for (var code in planned) {
                            colorMap[normalizeCountryCode(code)] = const Color.fromARGB(255, 6, 16, 148);
                          }
                          for (var code in visited) {
                            colorMap[normalizeCountryCode(code)] = const Color.fromARGB(255, 31, 131, 212);
                          }
                          for (var code in nationalities) {
                            colorMap[normalizeCountryCode(code)] = const Color.fromARGB(255, 9, 181, 233);
                          }

                          return SimpleMap(
                            instructions: SMapWorld.instructions,
                            defaultColor: Colors.grey,
                            colors: colorMap,
                            countryBorder: const CountryBorder(color: Colors.black, width: 0.1),
                            fit: BoxFit.contain,
                            callback: (id, name, tapdetails) {
                              if (id.isNotEmpty) _showCountryInfoSheet(context, id, getCountryName(id));
                            },
                          );
                        },
                      ),
                    ),
                  ),
          ],
        ),
        const FriendsPage(),
        GalleryPage(onBackPressed: () => setState(() => currentPageIndex = 0)),
        ProfilePage(onBackPressed: () => setState(() => currentPageIndex = 0)),
        SettingsPage(onBackPressed: () => setState(() => currentPageIndex = 0)),
      ][currentPageIndex],
    );
  }

  Widget _buildSearchResults() {
    final query = _searchController.text.toLowerCase();
    final filtered = countryNames.entries.where((entry) => entry.value.toLowerCase().contains(query)).toList();

    return Expanded(
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final entry = filtered[index];
          final visited = SessionManager().getVisitedCountriesForCurrentUser().contains(entry.key);
          return ListTile(
            leading: buildFlag(entry.key),
            title: Text(entry.value),
            trailing: Icon(visited ? Icons.check_circle : Icons.circle_outlined, color: visited ? Colors.green : Colors.grey),
            onTap: () => _showCountryInfoSheet(context, entry.key, entry.value),
          );
        },
      ),
    );
  }

}