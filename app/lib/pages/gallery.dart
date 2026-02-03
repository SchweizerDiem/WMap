import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_flags/country_flags.dart' as country_flags;

import '../session_manager.dart';
import '../country_names.dart';
import '../country_photo_manager.dart';

// --- NOVO WIDGET PARA O VISUALIZADOR COM SWIPE ---
class PhotoViewPage extends StatefulWidget {
  final List<File> photos;
  final int initialIndex;
  final String countryCode;
  final String? folderName;
  final CountryPhotoManager photoManager;

  const PhotoViewPage({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.countryCode,
    this.folderName,
    required this.photoManager,
  });

  @override
  State<PhotoViewPage> createState() => _PhotoViewPageState();
}

class _PhotoViewPageState extends State<PhotoViewPage> {
  late PageController _pageController;
  late int _currentIndex;
  late List<File> _localPhotos; // Cópia local para atualizar a UI ao apagar

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _localPhotos = List.from(widget.photos);
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  Future<void> _deleteCurrentPhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final photoToDelete = _localPhotos[_currentIndex];
      
      try {
        await widget.photoManager.removePhotos(
          widget.countryCode,
          [photoToDelete],
          folderName: widget.folderName,
        );

        setState(() {
          _localPhotos.removeAt(_currentIndex);
          // Se não houver mais fotos, fecha o visualizador
          if (_localPhotos.isEmpty) {
            Navigator.pop(context);
          } else {
            // Ajusta o índice se apagarmos a última foto
            if (_currentIndex >= _localPhotos.length) {
              _currentIndex = _localPhotos.length - 1;
            }
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_currentIndex + 1} / ${_localPhotos.length}', 
                   style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteCurrentPhoto,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _localPhotos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.file(_localPhotos[index], fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

// --- CLASSE GALLERY PAGE ATUALIZADA ---
class GalleryPage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const GalleryPage({super.key, this.onBackPressed});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final CountryPhotoManager _photoManager = CountryPhotoManager();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final Map<String, bool> _selectionMode = {};
  final Map<String, Set<String>> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadData());
  }

  Future<void> _preloadData() async {
    final visited = SessionManager().getVisitedCountriesForCurrentUser();
    for (var code in visited) {
      await _photoManager.loadCountryData(code);
    }
    if (mounted) setState(() {});
  }

  List<String> _getFilteredCountries() {
    final visited = SessionManager().getVisitedCountriesForCurrentUser();
    final sorted = visited.toList()..sort((a, b) => getCountryName(a).compareTo(getCountryName(b)));
    if (_searchQuery.isEmpty) return sorted;
    return sorted.where((code) => getCountryName(code).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ... (As funções _uploadForCountry e _deleteSelected mantêm-se iguais à versão anterior)
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
        await _photoManager.addPhotos(countryCode, files, folderName: folderName);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${files.length} photo(s)')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteSelected(String countryCode) async {
    final selectedKeys = _selectedIndices[countryCode];
    if (selectedKeys == null || selectedKeys.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text('Are you sure you want to delete ${selectedKeys.length} photo(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final Map<String, List<File>> byFolder = {};
    for (final key in selectedKeys) {
      final parts = key.split('::');
      final folder = parts[0];
      final idx = int.parse(parts[1]);
      final photos = folder.isEmpty 
          ? _photoManager.getPhotos(countryCode) 
          : _photoManager.getPhotosInFolder(countryCode, folder);
      if (idx < photos.length) byFolder.putIfAbsent(folder, () => []).add(photos[idx]);
    }

    try {
      for (final entry in byFolder.entries) {
        await _photoManager.removePhotos(countryCode, entry.value, folderName: entry.key.isEmpty ? null : entry.key);
      }
      setState(() {
        _selectedIndices[countryCode]?.clear();
        _selectionMode[countryCode] = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
    }
  }

  void _toggleSelectionMode(String countryCode, bool? value) {
    setState(() {
      _selectionMode[countryCode] = value ?? !( _selectionMode[countryCode] ?? false);
      if (!(_selectionMode[countryCode] ?? false)) _selectedIndices[countryCode]?.clear();
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
    final filteredCountries = _getFilteredCountries();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        leading: widget.onBackPressed != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBackPressed)
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search country...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ""); }) 
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredCountries.length,
              itemBuilder: (context, index) {
                final code = filteredCountries[index];
                return _buildCountryCard(code, getCountryName(code));
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS DE CONSTRUÇÃO DE UI ---

  Widget _buildCountryCard(String code, String name) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 48, height: 32, child: country_flags.CountryFlag.fromCountryCode(code)),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                _buildActionButtons(code),
              ],
            ),
            _buildNote(code),
            _buildFoldersAndPhotos(code),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String code) {
    if (_selectionMode[code] ?? false) {
      return Row(
        children: [
          IconButton(onPressed: () => _deleteSelected(code), icon: const Icon(Icons.delete, color: Colors.red)),
          IconButton(onPressed: () => _toggleSelectionMode(code, false), icon: const Icon(Icons.close)),
        ],
      );
    }
    return Row(
      children: [
        IconButton(onPressed: () => _uploadForCountry(code), icon: const Icon(Icons.add_a_photo, color: Color(0xff6c63ff))),
        IconButton(onPressed: () => _showNoteDialog(code), icon: const Icon(Icons.edit_note)),
      ],
    );
  }

  Future<void> _showNoteDialog(String code) async {
    final controller = TextEditingController(text: _photoManager.getNote(code) ?? '');
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
  }

  Widget _buildNote(String code) {
    return ValueListenableBuilder<String?>(
      valueListenable: _photoManager.getNoteNotifier(code),
      builder: (context, note, _) {
        if (note == null || note.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(note, style: const TextStyle(fontStyle: FontStyle.italic)),
        );
      },
    );
  }

  Widget _buildFoldersAndPhotos(String code) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: _photoManager.getFolderListNotifier(code),
      builder: (context, folders, _) {
        return Column(
          children: [
            for (final folder in folders) _buildFolderTile(code, folder),
            _buildRootPhotos(code),
          ],
        );
      },
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
          onLongPress: () => _toggleSelectionMode(code, true),
          onTap: () {
            if (isSelecting) {
              _toggleSelectIndex(code, folder, i);
            } else {
              // --- ABRIR O NOVO VISUALIZADOR COM SWIPE ---
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewPage(photos: photos, initialIndex: i, countryCode: code, folderName: folder.isEmpty ? null : folder, photoManager: _photoManager),
                ),
              );
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}