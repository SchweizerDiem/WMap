import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:country_flags/country_flags.dart' as country_flags;
import 'package:firebase_core/firebase_core.dart';

// Pages
import './pages/welcome.dart';
import './pages/login.dart';
import './pages/register.dart';
import './pages/settings.dart';
import './pages/profile.dart';
import './pages/friends.dart';
import './pages/hub.dart';

import 'session_manager.dart';
import 'country_names.dart';

// Garante que os códigos seguem o formato do mapa: iso2 lowercase
String normalizeCountryCode(String code) {
  return code.toLowerCase();
}

void main() async{
  WidgetsFlutterBinding.ensureInitialized();  
  try{
    await Firebase.initializeApp();
    debugPrint("Firebase initialized successfully");
  } catch(e){
    debugPrint("Firebase already initialized: $e");
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await SessionManager().refreshUserData();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Welcome Page',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WelcomePage(),
      // Register the home route so the login page can navigate here
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
  Set<String> _nationalityCountries = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final selectedCodes = (args?['selectedCountriesCodes'] as List<dynamic>?)
            ?.cast<String>()
            .toList() ?? [];
        
        debugPrint('Nationality countries received: $selectedCodes');
        
        if (mounted) {
          setState(() {
            _nationalityCountries = selectedCodes.toSet();
            debugPrint('_nationalityCountries set to: $_nationalityCountries');
          });
          
          if (selectedCodes.isEmpty) {
            _showNationalityPicker();
          }
        }
      } catch (e) {
        debugPrint('Error reading nationality arguments: $e');
      }
    });
  }

  String _countryCodeToEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '';
    final base = 0x1F1E6;
    final first = base + code.codeUnitAt(0) - 'A'.codeUnitAt(0);
    final second = base + code.codeUnitAt(1) - 'A'.codeUnitAt(0);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  Future<void> _showNationalityPicker() async {
    final countries = <Map<String, String>>[
      {'code': 'AF', 'name': 'Afghanistan'},
      {'code': 'AL', 'name': 'Albania'},
      {'code': 'DZ', 'name': 'Algeria'},
      {'code': 'AD', 'name': 'Andorra'},
      {'code': 'AO', 'name': 'Angola'},
      {'code': 'AG', 'name': 'Antigua and Barbuda'},
      {'code': 'AR', 'name': 'Argentina'},
      {'code': 'AM', 'name': 'Armenia'},
      {'code': 'AU', 'name': 'Australia'},
      {'code': 'AT', 'name': 'Austria'},
      {'code': 'AZ', 'name': 'Azerbaijan'},
      {'code': 'BS', 'name': 'Bahamas'},
      {'code': 'BH', 'name': 'Bahrain'},
      {'code': 'BD', 'name': 'Bangladesh'},
      {'code': 'BB', 'name': 'Barbados'},
      {'code': 'BY', 'name': 'Belarus'},
      {'code': 'BE', 'name': 'Belgium'},
      {'code': 'BZ', 'name': 'Belize'},
      {'code': 'BJ', 'name': 'Benin'},
      {'code': 'BT', 'name': 'Bhutan'},
      {'code': 'BO', 'name': 'Bolivia'},
      {'code': 'BA', 'name': 'Bosnia and Herzegovina'},
      {'code': 'BW', 'name': 'Botswana'},
      {'code': 'BR', 'name': 'Brazil'},
      {'code': 'BN', 'name': 'Brunei'},
      {'code': 'BG', 'name': 'Bulgaria'},
      {'code': 'BF', 'name': 'Burkina Faso'},
      {'code': 'BI', 'name': 'Burundi'},
      {'code': 'KH', 'name': 'Cambodia'},
      {'code': 'CM', 'name': 'Cameroon'},
      {'code': 'CA', 'name': 'Canada'},
      {'code': 'CV', 'name': 'Cape Verde'},
      {'code': 'CF', 'name': 'Central African Republic'},
      {'code': 'TD', 'name': 'Chad'},
      {'code': 'CL', 'name': 'Chile'},
      {'code': 'CN', 'name': 'China'},
      {'code': 'CO', 'name': 'Colombia'},
      {'code': 'KM', 'name': 'Comoros'},
      {'code': 'CG', 'name': 'Congo'},
      {'code': 'CR', 'name': 'Costa Rica'},
      {'code': 'HR', 'name': 'Croatia'},
      {'code': 'CU', 'name': 'Cuba'},
      {'code': 'CY', 'name': 'Cyprus'},
      {'code': 'CZ', 'name': 'Czech Republic'},
      {'code': 'CD', 'name': 'Democratic Republic of the Congo'},
      {'code': 'DK', 'name': 'Denmark'},
      {'code': 'DJ', 'name': 'Djibouti'},
      {'code': 'DM', 'name': 'Dominica'},
      {'code': 'DO', 'name': 'Dominican Republic'},
      {'code': 'EC', 'name': 'Ecuador'},
      {'code': 'EG', 'name': 'Egypt'},
      {'code': 'SV', 'name': 'El Salvador'},
      {'code': 'GQ', 'name': 'Equatorial Guinea'},
      {'code': 'ER', 'name': 'Eritrea'},
      {'code': 'EE', 'name': 'Estonia'},
      {'code': 'ET', 'name': 'Ethiopia'},
      {'code': 'FJ', 'name': 'Fiji'},
      {'code': 'FI', 'name': 'Finland'},
      {'code': 'FR', 'name': 'France'},
      {'code': 'GA', 'name': 'Gabon'},
      {'code': 'GM', 'name': 'Gambia'},
      {'code': 'GE', 'name': 'Georgia'},
      {'code': 'DE', 'name': 'Germany'},
      {'code': 'GH', 'name': 'Ghana'},
      {'code': 'GR', 'name': 'Greece'},
      {'code': 'GD', 'name': 'Grenada'},
      {'code': 'GT', 'name': 'Guatemala'},
      {'code': 'GN', 'name': 'Guinea'},
      {'code': 'GW', 'name': 'Guinea-Bissau'},
      {'code': 'GY', 'name': 'Guyana'},
      {'code': 'HT', 'name': 'Haiti'},
      {'code': 'HN', 'name': 'Honduras'},
      {'code': 'HU', 'name': 'Hungary'},
      {'code': 'IS', 'name': 'Iceland'},
      {'code': 'IN', 'name': 'India'},
      {'code': 'ID', 'name': 'Indonesia'},
      {'code': 'IR', 'name': 'Iran'},
      {'code': 'IQ', 'name': 'Iraq'},
      {'code': 'IE', 'name': 'Ireland'},
      {'code': 'IM', 'name': 'Isle of Man'},
      {'code': 'IL', 'name': 'Israel'},
      {'code': 'IT', 'name': 'Italy'},
      {'code': 'CI', 'name': 'Ivory Coast'},
      {'code': 'JM', 'name': 'Jamaica'},
      {'code': 'JP', 'name': 'Japan'},
      {'code': 'JO', 'name': 'Jordan'},
      {'code': 'KZ', 'name': 'Kazakhstan'},
      {'code': 'KE', 'name': 'Kenya'},
      {'code': 'KI', 'name': 'Kiribati'},
      {'code': 'KP', 'name': 'North Korea'},
      {'code': 'KR', 'name': 'South Korea'},
      {'code': 'KW', 'name': 'Kuwait'},
      {'code': 'KG', 'name': 'Kyrgyzstan'},
      {'code': 'LA', 'name': 'Laos'},
      {'code': 'LV', 'name': 'Latvia'},
      {'code': 'LB', 'name': 'Lebanon'},
      {'code': 'LS', 'name': 'Lesotho'},
      {'code': 'LR', 'name': 'Liberia'},
      {'code': 'LY', 'name': 'Libya'},
      {'code': 'LI', 'name': 'Liechtenstein'},
      {'code': 'LT', 'name': 'Lithuania'},
      {'code': 'LU', 'name': 'Luxembourg'},
      {'code': 'MG', 'name': 'Madagascar'},
      {'code': 'MW', 'name': 'Malawi'},
      {'code': 'MY', 'name': 'Malaysia'},
      {'code': 'MV', 'name': 'Maldives'},
      {'code': 'ML', 'name': 'Mali'},
      {'code': 'MT', 'name': 'Malta'},
      {'code': 'MH', 'name': 'Marshall Islands'},
      {'code': 'MR', 'name': 'Mauritania'},
      {'code': 'MU', 'name': 'Mauritius'},
      {'code': 'MX', 'name': 'Mexico'},
      {'code': 'FM', 'name': 'Micronesia'},
      {'code': 'MD', 'name': 'Moldova'},
      {'code': 'MC', 'name': 'Monaco'},
      {'code': 'MN', 'name': 'Mongolia'},
      {'code': 'ME', 'name': 'Montenegro'},
      {'code': 'MA', 'name': 'Morocco'},
      {'code': 'MZ', 'name': 'Mozambique'},
      {'code': 'MM', 'name': 'Myanmar'},
      {'code': 'NA', 'name': 'Namibia'},
      {'code': 'NR', 'name': 'Nauru'},
      {'code': 'NP', 'name': 'Nepal'},
      {'code': 'NL', 'name': 'Netherlands'},
      {'code': 'NZ', 'name': 'New Zealand'},
      {'code': 'NI', 'name': 'Nicaragua'},
      {'code': 'NE', 'name': 'Niger'},
      {'code': 'NG', 'name': 'Nigeria'},
      {'code': 'NO', 'name': 'Norway'},
      {'code': 'OM', 'name': 'Oman'},
      {'code': 'PK', 'name': 'Pakistan'},
      {'code': 'PW', 'name': 'Palau'},
      {'code': 'PS', 'name': 'Palestine'},
      {'code': 'PA', 'name': 'Panama'},
      {'code': 'PG', 'name': 'Papua New Guinea'},
      {'code': 'PY', 'name': 'Paraguay'},
      {'code': 'PE', 'name': 'Peru'},
      {'code': 'PH', 'name': 'Philippines'},
      {'code': 'PL', 'name': 'Poland'},
      {'code': 'PT', 'name': 'Portugal'},
      {'code': 'QA', 'name': 'Qatar'},
      {'code': 'RO', 'name': 'Romania'},
      {'code': 'RU', 'name': 'Russia'},
      {'code': 'RW', 'name': 'Rwanda'},
      {'code': 'KN', 'name': 'Saint Kitts and Nevis'},
      {'code': 'LC', 'name': 'Saint Lucia'},
      {'code': 'VC', 'name': 'Saint Vincent and the Grenadines'},
      {'code': 'WS', 'name': 'Samoa'},
      {'code': 'SM', 'name': 'San Marino'},
      {'code': 'ST', 'name': 'São Tomé and Príncipe'},
      {'code': 'SA', 'name': 'Saudi Arabia'},
      {'code': 'SN', 'name': 'Senegal'},
      {'code': 'RS', 'name': 'Serbia'},
      {'code': 'SC', 'name': 'Seychelles'},
      {'code': 'SL', 'name': 'Sierra Leone'},
      {'code': 'SG', 'name': 'Singapore'},
      {'code': 'SK', 'name': 'Slovakia'},
      {'code': 'SI', 'name': 'Slovenia'},
      {'code': 'SB', 'name': 'Solomon Islands'},
      {'code': 'SO', 'name': 'Somalia'},
      {'code': 'ZA', 'name': 'South Africa'},
      {'code': 'SS', 'name': 'South Sudan'},
      {'code': 'ES', 'name': 'Spain'},
      {'code': 'LK', 'name': 'Sri Lanka'},
      {'code': 'SD', 'name': 'Sudan'},
      {'code': 'SR', 'name': 'Suriname'},
      {'code': 'SZ', 'name': 'Eswatini'},
      {'code': 'SE', 'name': 'Sweden'},
      {'code': 'CH', 'name': 'Switzerland'},
      {'code': 'SY', 'name': 'Syria'},
      {'code': 'TW', 'name': 'Taiwan'},
      {'code': 'TJ', 'name': 'Tajikistan'},
      {'code': 'TZ', 'name': 'Tanzania'},
      {'code': 'TH', 'name': 'Thailand'},
      {'code': 'TL', 'name': 'Timor-Leste'},
      {'code': 'TG', 'name': 'Togo'},
      {'code': 'TO', 'name': 'Tonga'},
      {'code': 'TT', 'name': 'Trinidad and Tobago'},
      {'code': 'TN', 'name': 'Tunisia'},
      {'code': 'TR', 'name': 'Turkey'},
      {'code': 'TM', 'name': 'Turkmenistan'},
      {'code': 'TV', 'name': 'Tuvalu'},
      {'code': 'UG', 'name': 'Uganda'},
      {'code': 'UA', 'name': 'Ukraine'},
      {'code': 'AE', 'name': 'United Arab Emirates'},
      {'code': 'GB', 'name': 'United Kingdom'},
      {'code': 'US', 'name': 'United States'},
      {'code': 'UY', 'name': 'Uruguay'},
      {'code': 'UZ', 'name': 'Uzbekistan'},
      {'code': 'VU', 'name': 'Vanuatu'},
      {'code': 'VA', 'name': 'Vatican City'},
      {'code': 'VE', 'name': 'Venezuela'},
      {'code': 'VN', 'name': 'Vietnam'},
      {'code': 'YE', 'name': 'Yemen'},
      {'code': 'ZM', 'name': 'Zambia'},
      {'code': 'ZW', 'name': 'Zimbabwe'},
    ];

    final selected = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final selectedSet = <String>{};
        final searchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            // Filter countries based on search query
            final query = searchController.text.toLowerCase();
            final filtered = countries.where((c) {
              final name = c['name']!.toLowerCase();
              return name.contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('Select your nationalities'),
              content: SizedBox(
                width: double.maxFinite,
                height: 380,
                child: Column(
                  children: [
                    const Text(
                      'Choose one or more countries. Selected countries will be highlighted on the map.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search countries...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    searchController.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No countries found for "${searchController.text}"',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final c = filtered[index];
                                  final code = c['code']!;
                                  final name = c['name']!;
                                  final flag = _countryCodeToEmoji(code);
                                  return CheckboxListTile(
                                    value: selectedSet.contains(code),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          selectedSet.add(code);
                                        } else {
                                          selectedSet.remove(code);
                                        }
                                      });
                                    },
                                    secondary: Text(
                                      flag,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    title: Text(name),
                                    controlAffinity: ListTileControlAffinity.leading,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(<String>[]);
                  },
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(selectedSet.toList());
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _nationalityCountries = selected.toSet();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset("../assets/images/airplane-tilt.svg", width: 40),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Hub',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: <Widget>[
        Container(
          color: const Color.fromARGB(255, 255, 255, 255),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Search countries...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              _searchController.text.isNotEmpty
                  ? _buildSearchResults()
                  : Expanded(
                      child: InteractiveViewer(
                        maxScale: 20.0,
                        child: Center(
                          child: SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: ValueListenableBuilder<int>(
                              valueListenable: SessionManager().visitedCountNotifier,
                              builder: (context, visitedCount, child) {
                                return ValueListenableBuilder<int>(
                                  valueListenable: SessionManager().plannedCountNotifier,
                                  builder: (context2, plannedCount, child2) {
                                    final session = SessionManager();
                                    // MUDANÇA AQUI: Garantir que as listas são extraídas corretamente do UserAccount
                                    final visited = session.getCurrentUser()?.visitedCountries ?? {};
                                    final planned = session.getCurrentUser()?.plannedCountries ?? {};
                                    
                                    final Map<String, Color> colorMap = {};
                                    
                                    // Nacionalidades em azul claro
                                    for (var code in _nationalityCountries) {
                                      colorMap[normalizeCountryCode(code)] = const Color.fromARGB(255, 9, 181, 233);
                                    }
                                    
                                    // Visitados em azul médio (sobrepõe nacionalidade)
                                    for (var code in visited) {
                                      colorMap[normalizeCountryCode(code)] = const Color.fromARGB(255, 31, 131, 212);
                                    }
                                    
                                    // Planeados em azul escuro (apenas se não for visitado)
                                    for (var code in planned) {
                                      final c2 = normalizeCountryCode(code);
                                      colorMap.putIfAbsent(c2, () => const Color.fromARGB(255, 6, 16, 148));
                                    }

                                    return SimpleMap(
                                      instructions: SMapWorld.instructions,
                                      defaultColor: Colors.grey,
                                      colors: colorMap,
                                      countryBorder: const CountryBorder(color: Colors.black, width: 0.4),
                                      fit: BoxFit.contain,
                                      callback: (id, name, tapdetails) {
                                        _showCountryInfoDialog(context, id, getCountryName(id));
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        // Friends page (placeholder)
        const FriendsPage(),

        // Hub page (placeholder)
        const HubPage(),

        // Profile page
        ProfilePage(
          onBackPressed: () {
            setState(() {
              currentPageIndex = 0;
            });
          },
        ),

        // Settings page
        Center(
          child: SettingsPage(
            onBackPressed: () {
              setState(() {
                currentPageIndex = 0;
              });
            },
          ),
        ),
      ][currentPageIndex],
    );
  }

  void _showCountryInfoDialog(BuildContext context, String countryCode, String countryName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final session = SessionManager();
        return StatefulBuilder(builder: (context, setState) {
          final isVisited = session.isCountryVisitedForCurrentUser(countryCode);
          final isPlanned = SessionManager().isCountryPlannedForCurrentUser(countryCode);
          // Check whether this country was selected as the user's nationality (normalize to uppercase for safety)
          final isNationality = _nationalityCountries.map((e) => e.toUpperCase()).contains(countryCode.toUpperCase());

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 40,
                        child: country_flags.CountryFlag.fromCountryCode(countryCode),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        countryName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // If the user indicated this country as their nationality, display a friendly message instead
                      if (isNationality) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Oh it seems like you are from this country',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ] else ...[
                        // Row apenas com os botões "Visited" e "Future Trip"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Botão 'Visited'
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async{
                                  await session.toggleVisitedForCurrentUser(countryCode);
                                  setState(() {});
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (context.mounted) Navigator.of(context).pop();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isVisited ? const Color.fromARGB(255, 31, 131, 212): null,
                                  foregroundColor: isVisited ? Colors.white : null,
                                  padding: const EdgeInsets.symmetric(horizontal: 4), 
                                ),
                                child: Text(isVisited ? 'Visited ✓' : 'Visited'),
                              ),
                            ),
                            const SizedBox(width: 8), 
                            // Botão 'Future Trip'
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async{
                                  await session.togglePlannedForCurrentUser(countryCode);
                                  setState(() {});
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (context.mounted) Navigator.of(context).pop();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPlanned ? const Color.fromARGB(255, 6, 16, 148) : null,
                                  foregroundColor: isPlanned ? Colors.white : null,
                                  padding: const EdgeInsets.symmetric(horizontal: 4), 
                                ),
                                child: Text(isPlanned ? 'Future Trip ✓' : 'Future Trip'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // countryNames and getCountryName are provided by lib/country_names.dart

  Widget _buildSearchResults() {
    final query = _searchController.text.toLowerCase();
    final filtered = countryNames.entries
        .where((entry) => entry.value.toLowerCase().contains(query))
        .toList();

    return Expanded(
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final entry = filtered[index];
          final code = entry.key;
          final name = entry.value;
          final visited = SessionManager().getVisitedCountriesForCurrentUser().contains(code);

          return ListTile(
            leading: SizedBox(
              width: 40,
              height: 25,
              child: country_flags.CountryFlag.fromCountryCode(code),
            ),
            title: Text(name),
            trailing: visited
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.circle_outlined, color: Colors.grey),
            onTap: () {
              _showCountryInfoDialog(context, code, name);
            },
          );
        },
      ),
    );
  }
}
