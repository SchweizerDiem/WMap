import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Gestor responsável por sincronizar fotos locais, base de dados Firebase
/// e gerir o estado reativo da UI através de ValueNotifiers.
class CountryPhotoManager {
  // Padrão Singleton: Garante que apenas existe uma instância desta classe na app
  static final CountryPhotoManager _instance = CountryPhotoManager._internal();
  factory CountryPhotoManager() => _instance;
  CountryPhotoManager._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Mapas de Notifiers (Estado Reativo) ---
  // Guardam os estados em memória para que a UI saiba quando atualizar
  final Map<String, ValueNotifier<List<File>>> _notifiers = {}; // Fotos na raiz do país
  final Map<String, Map<String, ValueNotifier<List<File>>>> _folderNotifiers = {}; // Fotos dentro de pastas específicas
  final Map<String, ValueNotifier<List<String>>> _folderListNotifiers = {}; // Lista de nomes das pastas
  final Map<String, ValueNotifier<String?>> _notes = {}; // Notas de texto do país

  // Atalho para obter o ID do utilizador atual do Firebase
  String? get _uid => _auth.currentUser?.uid;

  // --- Métodos Internos de Gestão de Notifiers ---
  // Estes métodos garantem que se um "escritor" ou "leitor" pedir um notifier que não existe, ele é criado.

  ValueNotifier<List<File>> _ensureNotifier(String countryCode) =>
      _notifiers.putIfAbsent(countryCode, () => ValueNotifier<List<File>>([]));

  ValueNotifier<List<File>> _ensureFolderNotifier(String countryCode, String folderName) {
    final map = _folderNotifiers.putIfAbsent(countryCode, () => {});
    return map.putIfAbsent(folderName, () => ValueNotifier<List<File>>([]));
  }

  ValueNotifier<List<String>> _ensureFolderListNotifier(String countryCode) =>
      _folderListNotifiers.putIfAbsent(countryCode, () => ValueNotifier<List<String>>([]));

  ValueNotifier<String?> _ensureNoteNotifier(String countryCode) =>
      _notes.putIfAbsent(countryCode, () => ValueNotifier<String?>(null));

  // --- Lógica Principal de Dados ---

  /// Carrega os dados do Firestore para um país específico e atualiza os Notifiers.
  Future<void> loadCountryData(String countryCode) async {
    if (_uid == null) return;

    try {
      final doc = await _db.collection('users').doc(_uid).collection('countries').doc(countryCode).get();
      if (!doc.exists) return;

      final data = doc.data()!;

      // 1. Atualizar Nota
      _ensureNoteNotifier(countryCode).value = data['note'];

      // 2. Atualizar Fotos da Raiz (converte caminhos String para objetos File)
      final List<dynamic> rootPaths = data['rootPhotos'] ?? [];
      _ensureNotifier(countryCode).value = rootPaths.map((path) => File(path)).toList();

      // 3. Atualizar Pastas e os seus conteúdos
      final Map<String, dynamic> foldersData = data['folders'] ?? {};
      final folderNames = foldersData.keys.toList();
      
      foldersData.forEach((folderName, photos) {
        final List<dynamic> photoPaths = photos ?? [];
        _ensureFolderNotifier(countryCode, folderName).value = 
            photoPaths.map((path) => File(path)).toList();
      });
      
      _ensureFolderListNotifier(countryCode).value = folderNames;
    } catch (e) {
      debugPrint("Erro ao carregar dados do país $countryCode: $e");
    }
  }

  /// Adiciona fotos: copia para o armazenamento permanente do dispositivo e guarda o caminho no Firestore.
  Future<void> addPhotos(String countryCode, List<File> files, {String? folderName}) async {
    if (_uid == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final List<String> newPaths = [];

    for (var file in files) {
      // Cria um nome único baseado no timestamp para evitar conflitos de ficheiros
      final String extension = p.extension(file.path);
      final String name = "${countryCode}_${DateTime.now().microsecondsSinceEpoch}$extension";
      final String permanentPath = p.join(directory.path, name);
      
      // Copia da pasta temporária da galeria para a pasta da aplicação
      await file.copy(permanentPath);
      newPaths.add(permanentPath);
    }

    final docRef = _db.collection('users').doc(_uid).collection('countries').doc(countryCode);

    // Gravação no Firestore utilizando FieldValue.arrayUnion para não apagar fotos existentes
    if (folderName == null || folderName.isEmpty) {
      await docRef.set({'rootPhotos': FieldValue.arrayUnion(newPaths)}, SetOptions(merge: true));
    } else {
      await docRef.set({
        'folders': { folderName: FieldValue.arrayUnion(newPaths) }
      }, SetOptions(merge: true));
    }

    // Recarrega os dados para forçar a atualização da UI através dos notifiers
    await loadCountryData(countryCode);
  }

  /// Guarda ou remove a nota de texto associada a um país.
  Future<void> setNote(String countryCode, String? note) async {
    if (_uid == null) return;
    final cleanNote = (note != null && note.trim().isEmpty) ? null : note;
    
    await _db.collection('users').doc(_uid).collection('countries').doc(countryCode).set({
      'note': cleanNote
    }, SetOptions(merge: true));
    
    _ensureNoteNotifier(countryCode).value = cleanNote;
  }

  /// Remove fotos tanto da base de dados como do armazenamento físico do telemóvel.
  Future<void> removePhotos(String countryCode, List<File> filesToRemove, {String? folderName}) async {
    if (_uid == null) return;

    final pathsToRemove = filesToRemove.map((f) => f.path).toList();
    final docRef = _db.collection('users').doc(_uid).collection('countries').doc(countryCode);

    if (folderName == null || folderName.isEmpty) {
      await docRef.update({'rootPhotos': FieldValue.arrayRemove(pathsToRemove)});
    } else {
      await docRef.set({
        'folders': { folderName: FieldValue.arrayRemove(pathsToRemove) }
      }, SetOptions(merge: true));
    }
    
    // Limpeza física dos ficheiros para poupar espaço no dispositivo
    for (var f in filesToRemove) {
      try { if (await f.exists()) await f.delete(); } catch (_) {}
    }

    await loadCountryData(countryCode);
  }

  // --- Getters Reativos (Para usar em ValueListenableBuilders na UI) ---
  
  ValueNotifier<List<File>> getNotifierForCountry(String code) => _ensureNotifier(code);
  ValueNotifier<List<File>> getFolderNotifier(String code, String folder) => _ensureFolderNotifier(code, folder);
  ValueNotifier<List<String>> getFolderListNotifier(String code) => _ensureFolderListNotifier(code);
  ValueNotifier<String?> getNoteNotifier(String code) => _ensureNoteNotifier(code);
  
  // Getters de valor imediato
  String? getNote(String code) => _ensureNoteNotifier(code).value;
  List<File> getPhotos(String code) => _ensureNotifier(code).value;
  List<File> getPhotosInFolder(String code, String folder) => _ensureFolderNotifier(code, folder).value;
}