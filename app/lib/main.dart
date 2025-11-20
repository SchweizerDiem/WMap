import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:country_flags/country_flags.dart' as country_flags;
import 'login.dart';
import 'register.dart';
import 'settings.dart';
import 'profile.dart';
import 'session_manager.dart';

// Garante que os códigos seguem o formato do mapa: iso2 lowercase
String normalizeCountryCode(String code) {
  return code.toLowerCase();
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Page',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
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
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select your nationalities'),
              content: SizedBox(
                width: double.maxFinite,
                height: 320,
                child: Column(
                  children: [
                    const Text(
                      'Choose one or more countries. Selected countries will be highlighted on the map in orange.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          itemCount: countries.length,
                          itemBuilder: (context, index) {
                            final c = countries[index];
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
                      borderRadius: BorderRadius.circular(8),
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
                                    final visited = SessionManager().getVisitedCountriesForCurrentUser();
                                    final planned = SessionManager().getPlannedCountriesForCurrentUser();
                                    final Map<String, Color> colorMap = {};
                                    
                                    // Nacionalidades em laranja
                                    for (var code in _nationalityCountries) {
                                      final c2 = normalizeCountryCode(code);
                                      colorMap[c2] = Colors.orange;
                                    }
                                    
                                    // Visitados em verde (sobrepõe laranja)
                                    for (var code in visited) {
                                      colorMap[code] = Colors.green;
                                    }
                                    // Planeados em azul (não sobrepõe visitado ou nacionalidade)
                                    for (var code in planned) {
                                      colorMap.putIfAbsent(code, () => Colors.blue);
                                    }
                                    return SimpleMap(
                                      instructions: SMapWorld.instructions,
                                      defaultColor: Colors.grey,
                                      colors: colorMap,
                                      countryBorder: const CountryBorder(
                                        color: Colors.black,
                                        width: 0.4,
                                      ),
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
          var isVisited = session.isCountryVisitedForCurrentUser(countryCode);
          var isPlanned = SessionManager().isCountryPlannedForCurrentUser(countryCode);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          session.toggleVisitedForCurrentUser(countryCode);
                          isVisited = session.isCountryVisitedForCurrentUser(countryCode);
                          isPlanned = SessionManager().isCountryPlannedForCurrentUser(countryCode);
                          setState(() {});
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (context.mounted) Navigator.of(context).pop();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isVisited ? Colors.green : null,
                          foregroundColor: isVisited ? Colors.white : null,
                        ),
                        child: Text(isVisited ? 'Visitado ✓' : 'Visitado'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          session.togglePlannedForCurrentUser(countryCode);
                          isVisited = session.isCountryVisitedForCurrentUser(countryCode);
                          isPlanned = SessionManager().isCountryPlannedForCurrentUser(countryCode);
                          setState(() {});
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (context.mounted) Navigator.of(context).pop();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPlanned ? Colors.blue : null,
                          foregroundColor: isPlanned ? Colors.white : null,
                        ),
                        child: Text(isPlanned ? 'Future Trip ✓' : 'Future Trip'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  final Map<String, String> countryNames = {
    'AF': 'Afghanistan', 'AL': 'Albania', 'DZ': 'Algeria', 'AD': 'Andorra',
    'AO': 'Angola', 'AG': 'Antigua and Barbuda', 'AR': 'Argentina', 'AM': 'Armenia',
    'AU': 'Australia', 'AT': 'Austria', 'AZ': 'Azerbaijan', 'BS': 'Bahamas',
    'BH': 'Bahrain', 'BD': 'Bangladesh', 'BB': 'Barbados', 'BY': 'Belarus',
    'BE': 'Belgium', 'BZ': 'Belize', 'BJ': 'Benin', 'BT': 'Bhutan',
    'BO': 'Bolivia', 'BA': 'Bosnia and Herzegovina', 'BW': 'Botswana', 'BR': 'Brazil',
    'BN': 'Brunei', 'BG': 'Bulgaria', 'BF': 'Burkina Faso', 'BI': 'Burundi',
    'KH': 'Cambodia', 'CM': 'Cameroon', 'CA': 'Canada', 'CV': 'Cape Verde',
    'CF': 'Central African Republic', 'TD': 'Chad', 'CL': 'Chile', 'CN': 'China',
    'CO': 'Colombia', 'KM': 'Comoros', 'CG': 'Congo', 'CR': 'Costa Rica',
    'HR': 'Croatia', 'CU': 'Cuba', 'CY': 'Cyprus', 'CZ': 'Czech Republic',
    'CD': 'Democratic Republic of the Congo', 'DK': 'Denmark', 'DJ': 'Djibouti',
    'DM': 'Dominica', 'DO': 'Dominican Republic', 'EC': 'Ecuador', 'EG': 'Egypt',
    'SV': 'El Salvador', 'GQ': 'Equatorial Guinea', 'ER': 'Eritrea', 'EE': 'Estonia',
    'ET': 'Ethiopia', 'FJ': 'Fiji', 'FI': 'Finland', 'FR': 'France',
    'GA': 'Gabon', 'GM': 'Gambia', 'GE': 'Georgia', 'DE': 'Germany',
    'GH': 'Ghana', 'GR': 'Greece', 'GD': 'Grenada', 'GT': 'Guatemala',
    'GN': 'Guinea', 'GW': 'Guinea-Bissau', 'GY': 'Guyana', 'HT': 'Haiti',
    'HN': 'Honduras', 'HU': 'Hungary', 'IS': 'Iceland', 'IN': 'India',
    'ID': 'Indonesia', 'IR': 'Iran', 'IQ': 'Iraq', 'IE': 'Ireland',
    'IM': 'Isle of Man', 'IL': 'Israel', 'IT': 'Italy', 'CI': 'Ivory Coast',
    'JM': 'Jamaica', 'JP': 'Japan', 'JO': 'Jordan', 'KZ': 'Kazakhstan',
    'KE': 'Kenya', 'KI': 'Kiribati', 'KP': 'North Korea', 'KR': 'South Korea',
    'KW': 'Kuwait', 'KG': 'Kyrgyzstan', 'LA': 'Laos', 'LV': 'Latvia',
    'LB': 'Lebanon', 'LS': 'Lesotho', 'LR': 'Liberia', 'LY': 'Libya',
    'LI': 'Liechtenstein', 'LT': 'Lithuania', 'LU': 'Luxembourg', 'MG': 'Madagascar',
    'MW': 'Malawi', 'MY': 'Malaysia', 'MV': 'Maldives', 'ML': 'Mali',
    'MT': 'Malta', 'MH': 'Marshall Islands', 'MR': 'Mauritania', 'MU': 'Mauritius',
    'MX': 'Mexico', 'FM': 'Micronesia', 'MD': 'Moldova', 'MC': 'Monaco',
    'MN': 'Mongolia', 'ME': 'Montenegro', 'MA': 'Morocco', 'MZ': 'Mozambique',
    'MM': 'Myanmar', 'NA': 'Namibia', 'NR': 'Nauru', 'NP': 'Nepal',
    'NL': 'Netherlands', 'NZ': 'New Zealand', 'NI': 'Nicaragua', 'NE': 'Niger',
    'NG': 'Nigeria', 'NO': 'Norway', 'OM': 'Oman', 'PK': 'Pakistan',
    'PW': 'Palau', 'PS': 'Palestine', 'PA': 'Panama', 'PG': 'Papua New Guinea',
    'PY': 'Paraguay', 'PE': 'Peru', 'PH': 'Philippines', 'PL': 'Poland',
    'PT': 'Portugal', 'QA': 'Qatar', 'RO': 'Romania', 'RU': 'Russia',
    'RW': 'Rwanda', 'KN': 'Saint Kitts and Nevis', 'LC': 'Saint Lucia',
    'VC': 'Saint Vincent and the Grenadines', 'WS': 'Samoa', 'SM': 'San Marino',
    'ST': 'São Tomé and Príncipe', 'SA': 'Saudi Arabia', 'SN': 'Senegal',
    'RS': 'Serbia', 'SC': 'Seychelles', 'SL': 'Sierra Leone', 'SG': 'Singapore',
    'SK': 'Slovakia', 'SI': 'Slovenia', 'SB': 'Solomon Islands', 'SO': 'Somalia',
    'ZA': 'South Africa', 'SS': 'South Sudan', 'ES': 'Spain', 'LK': 'Sri Lanka',
    'SD': 'Sudan', 'SR': 'Suriname', 'SZ': 'Eswatini', 'SE': 'Sweden',
    'CH': 'Switzerland', 'SY': 'Syria', 'TW': 'Taiwan', 'TJ': 'Tajikistan',
    'TZ': 'Tanzania', 'TH': 'Thailand', 'TL': 'Timor-Leste', 'TG': 'Togo',
    'TO': 'Tonga', 'TT': 'Trinidad and Tobago', 'TN': 'Tunisia', 'TR': 'Turkey',
    'TM': 'Turkmenistan', 'TV': 'Tuvalu', 'UG': 'Uganda', 'UA': 'Ukraine',
    'AE': 'United Arab Emirates', 'GB': 'United Kingdom', 'US': 'United States',
    'UY': 'Uruguay', 'UZ': 'Uzbekistan', 'VU': 'Vanuatu', 'VA': 'Vatican City',
    'VE': 'Venezuela', 'VN': 'Vietnam', 'YE': 'Yemen', 'ZM': 'Zambia',
    'ZW': 'Zimbabwe',
  };

  String getCountryName(String countryCode) {
    return countryNames[countryCode] ?? countryCode;
  }

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
