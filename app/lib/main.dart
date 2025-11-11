import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'login.dart';
import 'register.dart';
import 'settings.dart';
import 'profile.dart';

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
      // Register the home route so the login page can navigate here
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: SvgPicture.asset("../assets/images/airplane-tilt.svg", width: 40,)),
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
              // Give the map most of the vertical space
              Expanded(
                child: InteractiveViewer(
                  maxScale: 20.0,
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: SimpleMap(
                        // Use the built-in world map instructions
                        instructions: SMapWorld.instructions,

                        // Make all countries gray
                        defaultColor: Colors.grey,

                        // Draw country borders so they are visible
                        countryBorder: const CountryBorder(
                          color: Colors.black,
                          width: 0.8,
                        ),

                        // Fit the map to available space
                        fit: BoxFit.contain,

                        // Provide a simple callback to show area details when tapped
                        callback: (id, name, tapdetails) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Tapped: $name ($id)')),
                          );
                          // Keep print for quick debugging (non-fatal analyzer info)
                          print('Tapped country: $id - $name');
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
        const ProfilePage(),
        // Settings page
        const Center(
           child: SettingsPage(),
        ),
      ][currentPageIndex],
    );
  }
}
