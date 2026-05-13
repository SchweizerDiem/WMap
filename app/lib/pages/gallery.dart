import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../session_manager.dart';
import '../country_names.dart';
import '../country_photo_manager.dart';

// --- VISUALIZADOR DE FOTOS (FULL SCREEN + SWIPE + DELETE) ---
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
  late List<File>
  _localPhotos; // Lista local para permitir atualizar a UI ao apagar

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _localPhotos = List.from(widget.photos); // Inicialização crucial
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  Future<void> _deleteCurrentPhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
        await widget.photoManager.removePhotos(widget.countryCode, [
          photoToDelete,
        ], folderName: widget.folderName);

        setState(() {
          _localPhotos.removeAt(_currentIndex);
          if (_localPhotos.isEmpty) {
            Navigator.pop(context);
          } else {
            if (_currentIndex >= _localPhotos.length) {
              _currentIndex = _localPhotos.length - 1;
            }
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        title: Text(
          '${_currentIndex + 1} / ${_localPhotos.length}',
          style: const TextStyle(color: Colors.white),
        ),
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
            child: Hero(
              tag: _localPhotos[index].path,
              child: Center(
                child: Image.file(_localPhotos[index], fit: BoxFit.contain),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- PÁGINA DE CONTEÚDO DA PASTA ---
class FolderPhotosPage extends StatefulWidget {
  final String countryCode;
  final String folderName;

  const FolderPhotosPage({
    super.key,
    required this.countryCode,
    required this.folderName,
  });

  @override
  State<FolderPhotosPage> createState() => _FolderPhotosPageState();
}

class _FolderPhotosPageState extends State<FolderPhotosPage> {
  final CountryPhotoManager photoManager = CountryPhotoManager();
  final ImagePicker _picker = ImagePicker();

  bool isSelectionMode = false;
  Set<File> selectedPhotos = {};

  void _toggleSelection(File file) {
    setState(() {
      if (selectedPhotos.contains(file)) {
        selectedPhotos.remove(file);
        if (selectedPhotos.isEmpty) isSelectionMode = false;
      } else {
        selectedPhotos.add(file);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${selectedPhotos.length} photos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await photoManager.removePhotos(
        widget.countryCode,
        selectedPhotos.toList(),
        folderName: widget.folderName,
      );
      setState(() {
        isSelectionMode = false;
        selectedPhotos.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelectionMode
              ? "${selectedPhotos.length} selected"
              : widget.folderName,
        ),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteSelected,
            )
          else
            IconButton(
              icon: const Icon(Icons.add_a_photo),
              onPressed: () async {
                final List<XFile> pickedFiles = await _picker.pickMultiImage();
                if (pickedFiles.isNotEmpty) {
                  List<File> files = pickedFiles
                      .map((x) => File(x.path))
                      .toList();
                  await photoManager.addPhotos(
                    widget.countryCode,
                    files,
                    folderName: widget.folderName,
                  );
                }
              },
            ),
        ],
      ),
      body: ValueListenableBuilder<List<File>>(
        valueListenable: photoManager.getFolderNotifier(
          widget.countryCode,
          widget.folderName,
        ),
        builder: (context, photos, _) {
          if (photos.isEmpty) return const Center(child: Text("Empty Folder."));

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final isSelected = selectedPhotos.contains(photo);

              return GestureDetector(
                onLongPress: () {
                  setState(() {
                    isSelectionMode = true;
                    _toggleSelection(photo);
                  });
                },
                onTap: () {
                  if (isSelectionMode) {
                    _toggleSelection(photo);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhotoViewPage(
                          photos: photos,
                          initialIndex: index,
                          countryCode: widget.countryCode,
                          folderName: widget.folderName,
                          photoManager: photoManager,
                        ),
                      ),
                    );
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: photo.path,
                      child: Image.file(photo, fit: BoxFit.cover),
                    ),
                    if (isSelected)
                      Container(
                        color: Colors.black45,
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- PÁGINA PRINCIPAL DA GALERIA ---
class GalleryPage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const GalleryPage({super.key, this.onBackPressed});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final CountryPhotoManager _photoManager = CountryPhotoManager();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadData());
  }

  Future<void> _preloadData() async {
    final user = SessionManager().getCurrentUser();
    final Set<String> allToLoad = {
      ...(user?.nationalities ?? []),
      ...(user?.visitedCountries.keys ?? []),
    };
    for (var code in allToLoad) {
      await _photoManager.loadCountryData(code);
    }
    if (mounted) setState(() {});
  }

  List<String> _getFilteredCountries() {
    final user = SessionManager().getCurrentUser();
    final Set<String> combined = {
      ...(user?.nationalities ?? []),
      ...(user?.visitedCountries.keys ?? []),
    };
    final List<String> sorted = combined.toList()
      ..sort((a, b) => getCountryName(a).compareTo(getCountryName(b)));

    if (_searchQuery.isEmpty) return sorted;
    return sorted
        .where(
          (code) => getCountryName(
            code,
          ).toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCountries = _getFilteredCountries();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed,
              )
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
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredCountries.length,
              itemBuilder: (context, index) =>
                  _buildCountryCard(filteredCountries[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryCard(String code) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: buildFlag(code, width: 50, height: 35),
        ),
        title: Text(
          getCountryName(code),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: ValueListenableBuilder<List<String>>(
          valueListenable: _photoManager.getFolderListNotifier(code),
          builder: (context, folders, _) => Text(
            "${folders.length} folder/s",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        children: [
          ValueListenableBuilder<List<String>>(
            valueListenable: _photoManager.getFolderListNotifier(code),
            builder: (context, folders, _) {
              if (folders.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No folder created."),
                );
              }
              return Column(
                children: folders
                    .map(
                      (folder) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        leading: const Icon(
                          Icons.folder_open,
                          size: 20,
                          color: Colors.orangeAccent,
                        ),
                        title: Text(
                          folder,
                          style: const TextStyle(fontSize: 15),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FolderPhotosPage(
                              countryCode: code,
                              folderName: folder,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
