import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:country_flags/country_flags.dart' as country_flags;

// Pages
import'./pages/welcome.dart';
import './pages/login.dart';
import './pages/register.dart';
import './pages/settings.dart';
import './pages/profile.dart';

import 'session_manager.dart';

void main() {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset("../assets/images/airplane-tilt.svg", width: 40,),
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
        // Map page - make it take most of the available space and show borders
        Container(
          //color: Colors.blue.shade50,
          color: const Color.fromARGB(255, 255, 255, 255),
          child: Column(
            children: [
              // Search bar
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
              // Search results or Give the map most of the vertical space
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
                                // Also listen to plannedCountNotifier so planned-country color updates rebuild immediately
                                return ValueListenableBuilder<int>(
                                  valueListenable: SessionManager().plannedCountNotifier,
                                  builder: (context2, plannedCount, child2) {
                                    // Build a colors map where visited countries are green and planned are blue
                                    final visited = SessionManager().getVisitedCountriesForCurrentUser();
                                    final planned = SessionManager().getPlannedCountriesForCurrentUser();
                                    final Map<String, Color> colorMap = {};
                                    for (var code in visited) {
                                      colorMap[code] = Colors.green;
                                    }
                                    for (var code in planned) {
                                      // don't override visited (visited takes precedence)
                                      colorMap.putIfAbsent(code, () => Colors.blue);
                                    }

                                    return SimpleMap(
                                      // Use the built-in world map instructions
                                      instructions: SMapWorld.instructions,

                                      // Make all countries gray
                                      defaultColor: Colors.grey,

                                      // Per-country colors (visited -> green)
                                      colors: colorMap,

                                      // Draw country borders so they are visible
                                      countryBorder: const CountryBorder(
                                        color: Colors.black,
                                        width: 0.4,
                                      ),

                                      // Fit the map to available space
                                      fit: BoxFit.contain,

                                      // Provide a simple callback to show area details when tapped
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
                  // Display the flag with appropriate size
                  SizedBox(
                    width: 60,
                    height: 40,
                    child: country_flags.CountryFlag.fromCountryCode(
                      countryCode,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Display the country name (use countryName parameter)
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
                          // Toggle visited. This will remove planned if marking visited.
                          session.toggleVisitedForCurrentUser(countryCode);
                          isVisited = session.isCountryVisitedForCurrentUser(countryCode);
                          isPlanned = SessionManager().isCountryPlannedForCurrentUser(countryCode);
                          setState(() {});
                          // Close dialog after a short delay so user sees the change
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
                          // Toggle planned (future trip). Will not add if already visited.
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

  // Map of country codes to names
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

  /// Get the full country name from its code
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
