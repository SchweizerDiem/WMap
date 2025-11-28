import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_flags/country_flags.dart' as country_flags;

import '../session_manager.dart';
import '../country_names.dart';
import '../country_photo_manager.dart';

class HubPage extends StatefulWidget {
  const HubPage({super.key});

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final CountryPhotoManager _photoManager = CountryPhotoManager();
  // Track selection mode and selected indices per country code
  final Map<String, bool> _selectionMode = {};
  final Map<String, Set<int>> _selectedIndices = {};

  Future<void> _uploadForCountry(String countryCode) async {
    try {
      final List<XFile>? picked = await _imagePicker.pickMultiImage();
      if (picked != null && picked.isNotEmpty) {
        final files = picked.map((x) => File(x.path)).toList();
        _photoManager.addPhotos(countryCode, files);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${files.length} photo(s) for ${getCountryName(countryCode)}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting images: $e')),
        );
      }
    }
  }

  void _toggleSelectionMode(String countryCode, bool? value) {
    setState(() {
      _selectionMode[countryCode] = value ?? !( _selectionMode[countryCode] ?? false);
      if (!(_selectionMode[countryCode] ?? false)) {
        _selectedIndices[countryCode]?.clear();
      }
    });
  }

  void _toggleSelectIndex(String countryCode, int index) {
    final set = _selectedIndices.putIfAbsent(countryCode, () => <int>{});
    setState(() {
      if (set.contains(index)) set.remove(index); else set.add(index);
    });
  }

  Future<void> _deleteSelected(String countryCode) async {
    final selected = _selectedIndices[countryCode];
    if (selected == null || selected.isEmpty) return;
    final photos = _photoManager.getPhotos(countryCode);
    // Build list of files to remove by index
    final filesToRemove = selected.map((i) => photos[i]).toList();
    _photoManager.removePhotos(countryCode, filesToRemove);
    // clear selection
    setState(() {
      _selectedIndices[countryCode]?.clear();
      _selectionMode[countryCode] = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed ${filesToRemove.length} photo(s)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visited = SessionManager().getVisitedCountriesForCurrentUser();
    if (visited.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hub')),
        body: const Center(child: Text('No visited countries yet.')),
      );
    }

  final sorted = visited.toList()..sort((a, b) => getCountryName(a).compareTo(getCountryName(b)));

    return Scaffold(
      appBar: AppBar(title: const Text('Hub')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final code = sorted[index];
          final name = getCountryName(code);
          final notifier = _photoManager.getNotifierForCountry(code);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 32,
                        child: country_flags.CountryFlag.fromCountryCode(code),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                      // When in selection mode show delete and cancel, otherwise show upload and select
                      if (_selectionMode[code] ?? false) ...[
                        IconButton(
                          onPressed: () => _deleteSelected(code),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete selected',
                        ),
                        IconButton(
                          onPressed: () => _toggleSelectionMode(code, false),
                          icon: const Icon(Icons.close),
                          tooltip: 'Cancel selection',
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => _uploadForCountry(code),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload photos'),
                        ),
                        IconButton(
                          onPressed: () => _toggleSelectionMode(code, true),
                          icon: const Icon(Icons.check_box_outline_blank),
                          tooltip: 'Select photos',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<List<File>>(
                    valueListenable: notifier,
                    builder: (context, photos, child) {
                      if (photos.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('No photos for this country.'),
                        );
                      }

                      // Collapsible gallery: show a small horizontal strip and allow
                      // expansion to a full grid gallery using ExpansionTile.
                      return ExpansionTile(
                        title: Text('${photos.length} photo(s)'),
                        childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        children: [
                          // Horizontal thumbnails (quick preview)
                          SizedBox(
                            height: 84,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: photos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final f = photos[i];
                                final selecting = _selectionMode[code] ?? false;
                                final selectedSet = _selectedIndices[code] ?? <int>{};
                                final isSelected = selectedSet.contains(i);
                                return GestureDetector(
                                  onTap: () {
                                    if (selecting) {
                                      _toggleSelectIndex(code, i);
                                      return;
                                    }
                                    // Show full screen preview
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: InteractiveViewer(
                                          child: Image.file(f),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          f,
                                          width: 120,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (selecting)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.blue.withOpacity(0.9) : Colors.black45,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isSelected ? Icons.check : Icons.circle_outlined,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Full gallery grid when expanded
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: 1.5,
                            ),
                            itemCount: photos.length,
                            itemBuilder: (context, i) {
                              final f = photos[i];
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: InteractiveViewer(
                                        child: Image.file(f),
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    f,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
