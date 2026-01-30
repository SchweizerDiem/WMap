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
  
  final Map<String, bool> _selectionMode = {};
  final Map<String, Set<String>> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // Carregar dados iniciais de todos os países visitados
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadData());
  }

  Future<void> _preloadData() async {
    final visited = SessionManager().getVisitedCountriesForCurrentUser();
    for (var code in visited) {
      // IMPORTANTE: loadCountryData agora deve ser async para ler do Firestore
      await _photoManager.loadCountryData(code);
    }
    if (mounted) setState(() {});
  }

  Future<void> _uploadForCountry(String countryCode) async {
    try {
      final createFolder = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create folder?'),
          content: const Text('Do you wish to create a folder for these photos?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      );

      if (!mounted || createFolder == null) return;

      String? folderName;
      if (createFolder) {
        final controller = TextEditingController();
        folderName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Folder name'),
            content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Enter name')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
            ],
          ),
        );
        if (folderName == null || folderName.isEmpty) return;
      }

      final List<XFile>? picked = await _imagePicker.pickMultiImage();
      if (picked != null && picked.isNotEmpty) {
        final files = picked.map((x) => File(x.path)).toList();
        
        // ADICIONADO AWAIT AQUI
        await _photoManager.addPhotos(countryCode, files, folderName: folderName);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${files.length} photo(s)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteSelected(String countryCode) async {
    final selected = _selectedIndices[countryCode];
    if (selected == null || selected.isEmpty) return;

    // Mostrar carregamento simples ou desativar botões
    setState(() => _selectionMode[countryCode] = false); 

    final Map<String, List<File>> byFolder = {};
    for (final s in selected) {
      final parts = s.split('::');
      final folder = parts[0];
      final idx = int.parse(parts[1]);
      final photos = folder.isEmpty 
          ? _photoManager.getPhotos(countryCode) 
          : _photoManager.getPhotosInFolder(countryCode, folder);
      byFolder.putIfAbsent(folder, () => []).add(photos[idx]);
    }

    try {
      for (final entry in byFolder.entries) {
        // MUDADO: Agora espera a remoção no Firestore
        await _photoManager.removePhotos(
          countryCode, 
          entry.value, 
          folderName: entry.key.isEmpty ? null : entry.key
        );
      }
      _selectedIndices[countryCode]?.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
    }
    
    if (mounted) setState(() {});
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

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 48, height: 32, child: country_flags.CountryFlag.fromCountryCode(code)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      
                      if (_selectionMode[code] ?? false) ...[
                        IconButton(onPressed: () => _deleteSelected(code), icon: const Icon(Icons.delete, color: Colors.red)),
                        IconButton(onPressed: () => _toggleSelectionMode(code, false), icon: const Icon(Icons.close)),
                      ] else ...[
                        IconButton(
                          onPressed: () => _uploadForCountry(code), 
                          icon: const Icon(Icons.add_a_photo, color: Color(0xff6c63ff))
                        ),
                        IconButton(
                          onPressed: () async {
                            final currentNote = _photoManager.getNote(code) ?? '';
                            final controller = TextEditingController(text: currentNote);
                            final result = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Country Note'),
                                content: TextField(controller: controller, maxLines: 3),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
                                ],
                              ),
                            );
                            if (result != null) await _photoManager.setNote(code, result);
                          },
                          icon: const Icon(Icons.edit_note),
                        ),
                      ],
                    ],
                  ),
                  
                  // LISTENER DE NOTAS
                  ValueListenableBuilder<String?>(
                    valueListenable: _photoManager.getNoteNotifier(code),
                    builder: (context, note, _) {
                      if (note == null || note.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(note, style: const TextStyle(fontStyle: FontStyle.italic)),
                      );
                    },
                  ),

                  // LISTENER DE FOLDERS E FOTOS
                  ValueListenableBuilder<List<String>>(
                    valueListenable: _photoManager.getFolderListNotifier(code),
                    builder: (context, folders, _) {
                      return Column(
                        children: [
                          for (final folder in folders) _buildFolderTile(code, folder),
                          _buildRootPhotos(code),
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

  Widget _buildFolderTile(String code, String folder) {
    return ValueListenableBuilder<List<File>>(
      valueListenable: _photoManager.getFolderNotifier(code, folder),
      builder: (context, photos, _) {
        if (photos.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(
          leading: const Icon(Icons.folder, color: Colors.orange),
          title: Text(folder),
          children: [_buildPhotoGrid(code, folder, photos)],
        );
      },
    );
  }

  Widget _buildRootPhotos(String code) {
    return ValueListenableBuilder<List<File>>(
      valueListenable: _photoManager.getNotifierForCountry(code),
      builder: (context, photos, _) {
        if (photos.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(
          title: const Text('General Photos'),
          children: [_buildPhotoGrid(code, '', photos)],
        );
      },
    );
  }

  Widget _buildPhotoGrid(String code, String folder, List<File> photos) {
    final isSelecting = _selectionMode[code] ?? false;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: photos.length,
      itemBuilder: (context, i) {
        final isSelected = _selectedIndices[code]?.contains('$folder::$i') ?? false;
        return GestureDetector(
          onTap: () {
            if (isSelecting) {
              _toggleSelectIndex(code, folder, i);
            } else {
              // Zoom da imagem
              showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(photos[i]))));
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(photos[i], fit: BoxFit.cover),
              if (isSelecting)
                Container(
                  color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                  child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}