import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../session_manager.dart';
import '../country_names.dart';
import '../country_photo_manager.dart';

// --- NOVO WIDGET PARA O VISUALIZADOR COM SWIPE ---
// Widget responsável por abrir a foto em ecrã inteiro, permitindo deslizar entre elas e fazer zoom.
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
  late List<File> _localPhotos;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _localPhotos = List.from(widget.photos);
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  // Função para apagar a foto que está a ser visualizada no momento
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
        // Remove a foto fisicamente através do gestor de fotos
        await widget.photoManager.removePhotos(
          widget.countryCode,
          [photoToDelete],
          folderName: widget.folderName,
        );

        setState(() {
          _localPhotos.removeAt(_currentIndex);
          // Se não sobrarem fotos, fecha o visualizador automaticamente
          if (_localPhotos.isEmpty) {
            Navigator.pop(context);
          } else {
            // Ajusta o índice caso a foto apagada seja a última da lista
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
      backgroundColor: Colors.black, // Fundo preto para destaque da imagem
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
      // PageView permite o efeito de deslizar lateralmente entre as imagens
      body: PageView.builder(
        controller: _pageController,
        itemCount: _localPhotos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          // InteractiveViewer permite fazer zoom (pinch-to-zoom) na imagem
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

// --- CLASSE GALLERY PAGE ---
// Página principal que lista os países e organiza as fotos em pastas e grelhas.
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

  // Controlam o estado de seleção múltipla para apagar várias fotos de uma vez
  final Map<String, bool> _selectionMode = {};
  final Map<String, Set<String>> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // Prepara os dados assim que o ecrã é montado
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadData());
  }

  // Carrega as fotos locais guardadas para cada país visitado ou nacionalidade
  Future<void> _preloadData() async {
    final user = SessionManager().getCurrentUser();
    final Set<String> allToLoad = {
      ...(user?.nationalities ?? []),
      ...(user?.visitedCountries ?? []),
    };
    
    for (var code in allToLoad) {
      await _photoManager.loadCountryData(code);
    }
    if (mounted) setState(() {});
  }

  // Filtra a lista de países com base no que o utilizador escreve na barra de pesquisa
  List<String> _getFilteredCountries() {
    final user = SessionManager().getCurrentUser();
    
    final Set<String> combined = {
      ...(user?.nationalities ?? []),
      ...(user?.visitedCountries ?? []),
    };

    final List<String> sorted = combined.toList()
      ..sort((a, b) => getCountryName(a).compareTo(getCountryName(b)));

    if (_searchQuery.isEmpty) return sorted;
    return sorted.where((code) => getCountryName(code).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // Lógica para adicionar fotos: pergunta se quer criar uma pasta e depois abre a galeria do telemóvel
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

      // Permite selecionar múltiplas imagens da galeria do sistema
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

  // Remove todas as fotos marcadas durante o modo de seleção
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

  // Ativa ou desativa a interface de seleção (checkboxes sobre as fotos)
  void _toggleSelectionMode(String countryCode, bool? value) {
    setState(() {
      _selectionMode[countryCode] = value ?? !( _selectionMode[countryCode] ?? false);
      if (!(_selectionMode[countryCode] ?? false)) _selectedIndices[countryCode]?.clear();
    });
  }

  // Marca ou desmarca uma foto específica para eliminação
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
          // Campo de pesquisa estilizado no topo
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
          // Lista de países filtrados
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

  // Constrói o cartão visual de cada país (Bandeira, Nome e Secção de Fotos)
  Widget _buildCountryCard(String code, String name) {
    String displayCode = code.toUpperCase();
    if (displayCode == 'KO' || displayCode == 'KOS') displayCode = 'XK';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                buildFlag(displayCode, width: 48, height: 32),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                _buildActionButtons(displayCode),
              ],
            ),
            _buildNote(displayCode),
            _buildFoldersAndPhotos(displayCode),
          ],
        ),
      ),
    );
  }

  // Alterna entre botões de ação normais (upload/nota) e botões de seleção (apagar/cancelar)
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

  // Abre diálogo para escrever uma nota/recordação sobre o país
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

  // Widget reativo que mostra a nota escrita logo abaixo do nome do país
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

  // Organiza a exibição: primeiro as pastas personalizadas, depois as fotos soltas
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

  // Cria um componente expansível para cada pasta dentro de um país
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

  // Mostra fotos que não pertencem a nenhuma pasta específica (General Photos)
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

  // Constrói a grelha de imagens propriamente dita com suporte para toque longo (seleção)
  Widget _buildPhotoGrid(String code, String folder, List<File> photos) {
    final isSelecting = _selectionMode[code] ?? false;
    return GridView.builder(
      shrinkWrap: true, // Importante para funcionar dentro de listas/ExpansionTiles
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: photos.length,
      itemBuilder: (context, i) {
        final isSelected = _selectedIndices[code]?.contains('$folder::$i') ?? false;
        return GestureDetector(
          onLongPress: () => _toggleSelectionMode(code, true), // Inicia modo seleção
          onTap: () {
            if (isSelecting) {
              _toggleSelectIndex(code, folder, i);
            } else {
              // Abre a foto em ecrã inteiro no visualizador
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewPage(
                    photos: photos, 
                    initialIndex: i, 
                    countryCode: code, 
                    folderName: folder.isEmpty ? null : folder, 
                    photoManager: _photoManager
                  ),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(photos[i], fit: BoxFit.cover),
              // Sobreposição visual (overlay) se a foto estiver selecionada
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