import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart' as country_flags;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../user.dart';
import '../session_manager.dart';
import '../profile_manager.dart';
import '../country_names.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const ProfilePage({super.key, this.onBackPressed});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _imagePicker = ImagePicker();
  late ProfileManager _profileManager;

  @override
  void initState() {
    super.initState();
    _profileManager = ProfileManager();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        _profileManager.setProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            // Profile photo button with camera overlay
            GestureDetector(
              onTap: _pickImageFromGallery,
              child: ValueListenableBuilder<File?>(
                valueListenable: _profileManager.profileImageNotifier,
                builder: (context, profileImage, child) {
                  if (profileImage != null) {
                    return Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: FileImage(profileImage),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Stack(
                    children: [
                      const CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey,
                        child: Icon(
                          Icons.person,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Name (listens to userNameNotifier)
            ValueListenableBuilder<String>(
              valueListenable: userNameNotifier,
              builder: (context, name, child) {
                return Text(
                  name.isEmpty ? 'Guest' : name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // Stats with real visited count
            ValueListenableBuilder<int>(
              valueListenable: SessionManager().visitedCountNotifier,
              builder: (context, visitedCount, child) {
                const int totalCountries = 250;
                final percent = (visitedCount / totalCountries * 100);
                return Column(
                  children: [
                    // Large summary card for countries visited
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                'Countries Visited',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                '$visitedCount / $totalCountries',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Dropdown / expansion to show visited country list
                            ExpansionTile(
                              title: const Text('Show visited countries'),
                              children: [
                                Builder(builder: (context) {
                                  final codes = SessionManager().getVisitedCountriesForCurrentUser();
                                  if (codes.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text('No countries visited yet.'),
                                    );
                                  }
                                  return Column(
                                    children: codes.toList().map((code) {
                                      final name = getCountryName(code);
                                      return ListTile(
                                        leading: SizedBox(
                                          width: 40,
                                          height: 24,
                                          child: country_flags.CountryFlag.fromCountryCode(code),
                                        ),
                                        title: Text(name),
                                        subtitle: Text(code.toUpperCase()),
                                      );
                                    }).toList(),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Label for the percentage (numeric percentage is shown inside the bar)
                    Row(
                      children: const [
                        Text('Percentage of the world visited:'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Animated visual progress bar corresponding to percent (0.0 - 1.0)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: (percent / 100).clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedValue, child) {
                        // Determine a readable text color depending on primary color luminance
                        final primary = Theme.of(context).colorScheme.primary;
                        final displayedPercent = (animatedValue * 100).clamp(0.0, 100.0);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: double.infinity,
                                child: LinearProgressIndicator(
                                  value: animatedValue,
                                  minHeight: 16,
                                  color: primary,
                                  backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Animated percentage label centered below the bar
                            Text(
                              '${displayedPercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Large summary card for planned (to-visit) countries (same style as visited)
            ValueListenableBuilder<int>(
              valueListenable: SessionManager().plannedCountNotifier,
              builder: (context, plannedCount, child) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Future Trips',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                        ),
                                const SizedBox(height: 12),
                                // Center the planned count and show only the number
                                Center(
                                  child: Text(
                                    '$plannedCount',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          title: const Text('Show planned countries'),
                          children: [
                            Builder(builder: (context) {
                              final codes = SessionManager().getPlannedCountriesForCurrentUser();
                              if (codes.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Text('No planned (future) countries.'),
                                );
                              }
                              return Column(
                                children: codes.toList().map((code) {
                                  final name = getCountryName(code);
                                  return ListTile(
                                    leading: SizedBox(
                                      width: 40,
                                      height: 24,
                                      child: country_flags.CountryFlag.fromCountryCode(code),
                                    ),
                                    title: Text(name),
                                    subtitle: Text(code.toUpperCase()),
                                  );
                                }).toList(),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Use shared countryNames/getCountryName from ../country_names.dart

  // Planned countries are shown inline in the card above via ExpansionTile.
}
