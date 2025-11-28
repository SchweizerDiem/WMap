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
  // selected indices store strings in the form 'folderName::index' where folderName is empty for root
  final Map<String, bool> _selectionMode = {};
  final Map<String, Set<String>> _selectedIndices = {};

  Future<void> _uploadForCountry(String countryCode) async {
    try {
      // Ask whether to create a folder
      final createFolder = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Create folder?'),
            content: const Text('Do you wish to create a folder for these photos?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
            ],
          );
        },
      );

      if (createFolder == true) {
        // Ask for folder name
        final folderNameController = TextEditingController();
        final folderName = await showDialog<String?>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Folder name'),
              content: TextField(
                controller: folderNameController,
                decoration: const InputDecoration(hintText: 'Enter folder name'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(folderNameController.text.trim()), child: const Text('Create')),
              ],
            );
          },
        );
        if (folderName == null || folderName.isEmpty) {
          // user cancelled or provided empty name -> abort
          return;
        }

        final List<XFile>? picked = await _imagePicker.pickMultiImage();
        if (picked != null && picked.isNotEmpty) {
          final files = picked.map((x) => File(x.path)).toList();
          _photoManager.addPhotosToFolder(countryCode, folderName, files);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added ${files.length} photo(s) to "$folderName" for ${getCountryName(countryCode)}')),
            );
          }
        }
      } else {
        // No folder: behave as before
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

  void _toggleSelectIndex(String countryCode, String folderName, int index) {
    final set = _selectedIndices.putIfAbsent(countryCode, () => <String>{});
    final key = '$folderName::$index';
    setState(() {
      if (set.contains(key)) set.remove(key); else set.add(key);
    });
  }

  Future<void> _deleteSelected(String countryCode) async {
    final selected = _selectedIndices[countryCode];
    if (selected == null || selected.isEmpty) return;

    // Group selections by folder
    final Map<String, List<int>> byFolder = {};
    for (final s in selected) {
      final parts = s.split('::');
      final folder = parts[0];
      final idx = int.tryParse(parts.length > 1 ? parts[1] : '') ?? -1;
      if (idx < 0) continue;
      byFolder.putIfAbsent(folder, () => <int>[]).add(idx);
    }

    int totalRemoved = 0;
    // Remove from folders
    for (final entry in byFolder.entries) {
      final folder = entry.key;
      final indices = entry.value..sort((a,b)=>b.compareTo(a)); // remove by descending index
      if (folder.isEmpty) {
        // root
        final photos = _photoManager.getPhotos(countryCode);
        final filesToRemove = indices.map((i) => photos[i]).toList();
        _photoManager.removePhotos(countryCode, filesToRemove);
        totalRemoved += filesToRemove.length;
      } else {
        final photos = _photoManager.getPhotosInFolder(countryCode, folder);
        final filesToRemove = indices.map((i) => photos[i]).toList();
        _photoManager.removePhotosFromFolder(countryCode, folder, filesToRemove);
        totalRemoved += filesToRemove.length;
      }
    }

    // clear selection
    setState(() {
      _selectedIndices[countryCode]?.clear();
      _selectionMode[countryCode] = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $totalRemoved photo(s)')));
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
                        // Edit-note button (pencil) — opens a dialog to add/edit a note for this country
                        IconButton(
                          onPressed: () async {
                            final currentNote = _photoManager.getNote(code) ?? '';
                            final controller = TextEditingController(text: currentNote);
                            final result = await showDialog<String?>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Add note'),
                                  content: TextField(
                                    controller: controller,
                                    maxLines: 4,
                                    decoration: const InputDecoration(hintText: 'Write a short note about this country...'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(null),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                );
                              },
                            );
                            // Save note if user pressed Save (result may be empty string to clear)
                            if (result != null) {
                              _photoManager.setNote(code, result.isEmpty ? null : result);
                            }
                          },
                          icon: const Icon(Icons.edit),
                          tooltip: 'Add note',
                        ),
                        // Only show the 'Select photos' button when there are photos for this country
                        ValueListenableBuilder<List<File>>(
                          valueListenable: notifier,
                          builder: (context, photos, child) {
                            if (photos.isEmpty) return const SizedBox.shrink();
                            return IconButton(
                              onPressed: () => _toggleSelectionMode(code, true),
                              icon: const Icon(Icons.check_box_outline_blank),
                              tooltip: 'Select photos',
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Show note (if present) under the flag/name and above the photos
                  ValueListenableBuilder<String?>(
                    valueListenable: _photoManager.getNoteNotifier(code),
                    builder: (context, note, child) {
                      if (note == null || note.trim().isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          note,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                      );
                    },
                  ),

                  // Show any named folders first
                  // Folder list is listenable so UI updates when folders are added
                  ValueListenableBuilder<List<String>>(
                    valueListenable: _photoManager.getFolderListNotifier(code),
                    builder: (context, folders, child) {
                      return Column(
                        children: [
                          for (final folder in folders)
                            ValueListenableBuilder<List<File>>(
                              valueListenable: _photoManager.getFolderNotifier(code, folder),
                              builder: (context, photos, child) {
                                if (photos.isEmpty) return const SizedBox.shrink();
                                return ExpansionTile(
                                  title: Text('$folder — ${photos.length} photo(s)'),
                                  childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  children: [
                                    SizedBox(
                                      height: 84,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: photos.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                                        itemBuilder: (context, i) {
                                          final f = photos[i];
                                          final selecting = _selectionMode[code] ?? false;
                                          final selectedSet = _selectedIndices[code] ?? <String>{};
                                          final isSelected = selectedSet.contains('$folder::$i');
                                          return GestureDetector(
                                            onTap: () {
                                              if (selecting) {
                                                _toggleSelectIndex(code, folder, i);
                                                return;
                                              }
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

                          // Root (unnamed) photos
                          ValueListenableBuilder<List<File>>(
                            valueListenable: notifier,
                            builder: (context, photos, child) {
                              if (photos.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text('No photos for this country.'),
                                );
                              }

                              return ExpansionTile(
                                title: Text('${photos.length} photo(s)'),
                                childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                children: [
                                  SizedBox(
                                    height: 84,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: photos.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemBuilder: (context, i) {
                                        final f = photos[i];
                                        final selecting = _selectionMode[code] ?? false;
                                        final selectedSet = _selectedIndices[code] ?? <String>{};
                                        final isSelected = selectedSet.contains('::$i');
                                        return GestureDetector(
                                          onTap: () {
                                            if (selecting) {
                                              _toggleSelectIndex(code, '', i);
                                              return;
                                            }
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
