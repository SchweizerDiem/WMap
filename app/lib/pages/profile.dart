import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
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
    _profileManager.loadProfileImage();

    // --- CORREÇÃO AQUI: Sincronizar o userNameNotifier com o nome real do utilizador ---
    final currentUser = SessionManager().getCurrentUser();
    if (currentUser != null && currentUser.name.isNotEmpty) {
      userNameNotifier.value = currentUser.name;
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
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
        leading: widget.onBackPressed != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBackPressed)
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- CABEÇALHO CENTRADO ---
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: ValueListenableBuilder<File?>(
                      valueListenable: _profileManager.profileImageNotifier,
                      builder: (context, profileImage, child) {
                        return CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: profileImage != null ? FileImage(profileImage) : null,
                          child: profileImage == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Exibe o nome do userNameNotifier (agora sincronizado no initState)
                          ValueListenableBuilder<String>(
                            valueListenable: userNameNotifier,
                            builder: (context, name, child) => Text(
                              name.isEmpty ? 'Guest' : name,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(builder: (context) {
                            final user = SessionManager().getCurrentUser();
                            final nationalities = user?.nationalities ?? [];
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: nationalities.map((code) {
                                String displayCode = code.toUpperCase();
                                if (displayCode == 'KO' || displayCode == 'KOS') displayCode = 'XK';
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: buildFlag(displayCode, width: 22, height: 16),
                                );
                              }).toList(),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // FRIEND CODE
                      Builder(builder: (context) {
                        final code = SessionManager().getCurrentUser()?.friendCode ?? '---';
                        return InkWell(
                          onTap: () {
                            if (code != '---') {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Friend code $code copied!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  code,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.copy, size: 14, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 40),

            // --- PAÍSES VISITADOS ---
            ValueListenableBuilder<int>(
              valueListenable: SessionManager().visitedCountNotifier,
              builder: (context, count, _) {
                final user = SessionManager().getCurrentUser();
                final Set<String> allVisited = {
                  ...(user?.nationalities ?? []),
                  ...(user?.visitedCountries ?? []),
                };
                
                final int totalVisitedCount = allVisited.length;
                final double percentValue = (totalVisitedCount / 250).clamp(0.0, 1.0);

                return Column(
                  children: [
                    Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: const Text('Countries Visited', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text('$totalVisitedCount / 250'),
                        children: [
                          if (allVisited.isEmpty)
                            const ListTile(title: Text('No countries visited yet.'))
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
                    // --- PERCENTAGEM ---
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text('World Exploration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // --- FUTURE TRIPS ---
            ValueListenableBuilder<int>(
              valueListenable: SessionManager().plannedCountNotifier,
              builder: (context, count, _) {
                final user = SessionManager().getCurrentUser();
                final codes = user?.plannedCountries.toList() ?? [];

                return Card(
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    title: const Text('Future Trips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text('$count countries planned'),
                    children: [
                      if (codes.isEmpty)
                        const ListTile(title: Text('No planned countries.'))
                      else
                        Column(
                          children: codes.map((code) {
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}