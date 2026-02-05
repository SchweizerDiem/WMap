import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:country_flags/country_flags.dart' as country_flags;
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:ui' as ui; 
import 'dart:io'; 
import 'package:flutter/rendering.dart'; 
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:home_widget/home_widget.dart'; 

// IMPORTS CORRIGIDOS (Apenas Dart, sem erro de Gradle)
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

// --- FUNÇÕES UTILITÁRIAS GLOBAIS ---
String normalizeCountryCode(String code) {
  return code.toLowerCase();
}

Widget buildFlag(String code, {double width = 40, double height = 24}) {
  final cleanCode = code.toUpperCase();
  if (cleanCode == 'XK') {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset('assets/images/Flag_of_Kosovo.svg.webp', fit: BoxFit.cover),
      ),
    );
  }
  return SizedBox(
    width: width, height: height,
    child: country_flags.CountryFlag.fromCountryCode(cleanCode),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. INICIALIZAÇÃO DA BASE DE DADOS DE TEMPO (IANA)
  tz.initializeTimeZones();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final bool rememberMe = prefs.getBool('remember_me') ?? false;
  final user = FirebaseAuth.instance.currentUser;

  Widget initialScreen;

  if (rememberMe && user != null) {
    final session = SessionManager();
    await session.refreshUserData(); 
    initialScreen = const HomePage();
  } else {
    initialScreen = const WelcomePage();
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WMap',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: initialScreen,
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
  bool _isUpdatingWidget = false;
  int currentPageIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _mapKey = GlobalKey(); 
  Set<String> _nationalityCountries = <String>{};

  @override
  void initState() {
    super.initState();

    final session = SessionManager();
    session.visitedColorNotifier.addListener(_onColorChanged);
    session.plannedColorNotifier.addListener(_onColorChanged);
    session.nationalityColorNotifier.addListener(_onColorChanged);

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
      await session.refreshUserData();
      final user = session.getCurrentUser();
      
      if (user != null) {
        setState(() {
          _nationalityCountries = user.nationalities.toSet();
        });
        if (user.nationalities.isEmpty && mounted) {
          _showNationalityPicker();
        }
        _updateWidgetMap(); 
      }
    });
  }

  @override
  void dispose() {
    final session = SessionManager();
    session.visitedColorNotifier.removeListener(_onColorChanged);
    session.plannedColorNotifier.removeListener(_onColorChanged);
    session.nationalityColorNotifier.removeListener(_onColorChanged);
    
    _transformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onColorChanged() {
    if (mounted) setState(() {});
  }

  // --- LÓGICA DO WIDGET ---
  Future<void> _updateWidgetMap() async {
    if (!mounted || currentPageIndex != 0 || _mapKey.currentContext == null) return;
    
    try {
      setState(() => _isUpdatingWidget = true);
      final originalMatrix = Matrix4.fromFloat64List(_transformationController.value.storage);
      _transformationController.value = Matrix4.identity(); 

      await Future.delayed(const Duration(milliseconds: 500)); 

      final RenderRepaintBoundary? boundary = _mapKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = '${directory.path}/map_snapshot.png';
          await File(imagePath).writeAsBytes(byteData.buffer.asUint8List());
          
          await HomeWidget.saveWidgetData<String>('map_image_path', imagePath);
          final session = SessionManager();
          final visitedCount = session.getVisitedCountriesForCurrentUser().length;
          await HomeWidget.saveWidgetData<String>('visited_count_text', 'Visited: $visitedCount/250');
          
          await HomeWidget.updateWidget(name: 'MapWidgetProvider', androidName: 'MapWidgetProvider');
        }
      }

      _transformationController.value = originalMatrix; 
      setState(() => _isUpdatingWidget = false);

    } catch (e) {
      if (mounted) setState(() => _isUpdatingWidget = false);
      debugPrint("Erro Widget Update: $e");
    }
  }

  // --- LÓGICA DE TEMPO ROBUSTA (OFFLINE) ---
  String _getCountryTime(String countryCode, List<dynamic> timezones) {
    try {
      final Map<String, String> codeToLocation = {
        'PT': 'Europe/Lisbon',
        'ES': 'Europe/Madrid',
        'GB': 'Europe/London',
        'FR': 'Europe/Paris',
        'DE': 'Europe/Berlin',
        'IT': 'Europe/Rome',
        'BR': 'America/Sao_Paulo',
        'US': 'America/New_York',
        'JP': 'Asia/Tokyo',
        'CN': 'Asia/Shanghai',
        'RU': 'Europe/Moscow',
        'AO': 'Africa/Luanda',
        'CV': 'Atlantic/Cape_Verde',
        'CH': 'Europe/Zurich',
        'BE': 'Europe/Brussels',
        'NL': 'Europe/Amsterdam',
      };

      String? locationName = codeToLocation[countryCode.toUpperCase()];
      
      if (locationName != null) {
        final location = tz.getLocation(locationName);
        final now = tz.TZDateTime.now(location);
        return DateFormat('HH:mm').format(now);
      }

      if (timezones.isNotEmpty) {
        return _calculateTimeFromOffset(timezones[0].toString());
      }
      
      return "--:--";
    } catch (e) {
      return "--:--";
    }
  }

  String _calculateTimeFromOffset(String offsetStr) {
    try {
      DateTime nowUtc = DateTime.now().toUtc();
      String cleanOffset = offsetStr.replaceAll('UTC', '').trim();
      if (cleanOffset.isEmpty) return DateFormat('HH:mm').format(nowUtc);
      
      bool isNegative = cleanOffset.startsWith('-');
      String digits = cleanOffset.replaceAll(RegExp(r'[^0-9:]'), '');
      List<String> parts = digits.split(':');
      
      int hours = int.parse(parts[0]);
      int minutes = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      Duration duration = Duration(hours: hours, minutes: minutes);
      DateTime target = isNegative ? nowUtc.subtract(duration) : nowUtc.add(duration);
      
      return DateFormat('HH:mm').format(target);
    } catch (_) {
      return "--:--";
    }
  }

  // --- LÓGICA DA API ---
  Future<Map<String, dynamic>?> _fetchCountryData(String code) async {
    try {
      final response = await http.get(Uri.parse('https://restcountries.com/v3.1/alpha/$code'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final country = data[0];

        String currencyName = (country['currencies'] as Map?)?.values.first['name'] ?? 'N/A';
        String currencySymbol = (country['currencies'] as Map?)?.values.first['symbol'] ?? '';

        if (code.toUpperCase() == 'BG') {
          currencyName = 'Euro';
          currencySymbol = '€';
        }
        
        final List<dynamic>? capitalsList = country['capital'];
        final String capitals = capitalsList != null ? capitalsList.join(', ') : 'N/A';
        final List<dynamic> timezones = country['timezones'] ?? [];

        return {
          'capital': capitals,
          'population': country['population'] ?? 0,
          'region': country['region'] ?? 'N/A',
          'subregion': country['subregion'] ?? 'N/A',
          'languages': (country['languages'] as Map?)?.values.join(', ') ?? 'N/A',
          'currency': currencyName,
          'currencySymbol': currencySymbol,
          'capitalTime': _getCountryTime(code, timezones),
        };
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    return null;
  }

  // ... (Restante do código original mantido exatamente igual: _showCountryInfoSheet, _buildDetailsGrid, etc.)
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
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 70, height: 45,
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
                    return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    return _buildDetailsGrid(snapshot.data!);
                  }
                  return const Padding(padding: EdgeInsets.all(20), child: Text("Information unavailable."));
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xff6c63ff).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xff6c63ff).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_filled, color: Color(0xff6c63ff), size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("LOCAL TIME (CAPITAL)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xff4841a8))),
                    Text(data['capitalTime'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff4841a8))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
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
      return const Center(child: Text('🌍 This is your nationality!', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue, fontWeight: FontWeight.bold)));
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
                _updateWidgetMap(); 
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
                _updateWidgetMap();
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
                width: double.maxFinite, height: 400,
                child: Column(children: [
                  TextField(controller: searchController, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Search...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)))),
                  const SizedBox(height: 10),
                  Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) {
                    final c = filtered[index];
                    return CheckboxListTile(
                      value: selectedSet.contains(c['code']),
                      onChanged: (val) => setState(() => val! ? selectedSet.add(c['code']!) : selectedSet.remove(c['code'])),
                      title: Text(c['name']!),
                      secondary: buildFlag(c['code']!, width: 45, height: 30),
                    );
                  })),
                ]),
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
      _updateWidgetMap();
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
        onDestinationSelected: (int index) {
          setState(() => currentPageIndex = index);
          if (index == 0) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) _updateWidgetMap();
            });
          }
        },
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
        Stack(
          children: [
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))
                    ),
                  ),
                ),
                _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : Expanded(
                        child: RepaintBoundary(
                          key: _mapKey,
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            maxScale: 20.0,
                            minScale: 1.0,
                            child: AnimatedBuilder( 
                              animation: Listenable.merge([
                                SessionManager().visitedCountNotifier,
                                SessionManager().visitedColorNotifier,
                                SessionManager().plannedColorNotifier,
                                SessionManager().nationalityColorNotifier,
                              ]),
                              builder: (context, child) {
                                final session = SessionManager();
                                final user = session.getCurrentUser();
                                final visited = user?.visitedCountries ?? {};
                                final planned = user?.plannedCountries ?? {};
                                final nationalities = user?.nationalities ?? []; 
                                
                                final Map<String, Color> colorMap = {};

                                for (var code in planned) {
                                  colorMap[normalizeCountryCode(code)] = session.plannedColorNotifier.value;
                                }
                                for (var code in visited) {
                                  colorMap[normalizeCountryCode(code)] = session.visitedColorNotifier.value;
                                }
                                for (var code in nationalities) {
                                  colorMap[normalizeCountryCode(code)] = session.nationalityColorNotifier.value;
                                }

                                return SimpleMap(
                                  instructions: SMapWorld.instructions,
                                  defaultColor: Colors.grey.shade400,
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
                      ),
              ],
            ),
            if (_isUpdatingWidget)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.9),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 15),
                        Text("Updating Widget Map...", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const FriendsPage(),
        GalleryPage(onBackPressed: () => setState(() => currentPageIndex = 0)),
        ProfilePage(onBackPressed: () => setState(() => currentPageIndex = 0)),
        SettingsPage(onBackPressed: () {
          setState(() => currentPageIndex = 0);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _updateWidgetMap();
          });
        }),
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