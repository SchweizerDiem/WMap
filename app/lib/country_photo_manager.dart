import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CountryPhotoManager {
  static final CountryPhotoManager _instance = CountryPhotoManager._internal();
  factory CountryPhotoManager() => _instance;
  CountryPhotoManager._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, ValueNotifier<List<File>>> _notifiers = {};
  final Map<String, Map<String, ValueNotifier<List<File>>>> _folderNotifiers = {};
  final Map<String, ValueNotifier<List<String>>> _folderListNotifiers = {};
  final Map<String, ValueNotifier<String?>> _notes = {};

  // Garantir que temos um UID válido antes de qualquer operação
  String? get _uid => _auth.currentUser?.uid;

  // --- Notifiers ---
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

  // --- Lógica Principal ---

  Future<void> loadCountryData(String countryCode) async {
    if (_uid == null) return;

    try {
      final doc = await _db.collection('users').doc(_uid).collection('countries').doc(countryCode).get();
      if (!doc.exists) return;

      final data = doc.data()!;

      // 1. Nota
      _ensureNoteNotifier(countryCode).value = data['note'];

      // 2. Fotos Raiz
      final List<dynamic> rootPaths = data['rootPhotos'] ?? [];
      _ensureNotifier(countryCode).value = rootPaths.map((path) => File(path)).toList();

      // 3. Pastas
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

  Future<void> addPhotos(String countryCode, List<File> files, {String? folderName}) async {
    if (_uid == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final List<String> newPaths = [];

    for (var file in files) {
      final String extension = p.extension(file.path);
      final String name = "${countryCode}_${DateTime.now().microsecondsSinceEpoch}$extension";
      final String permanentPath = p.join(directory.path, name);
      
      await file.copy(permanentPath);
      newPaths.add(permanentPath);
    }

    final docRef = _db.collection('users').doc(_uid).collection('countries').doc(countryCode);

    if (folderName == null || folderName.isEmpty) {
      await docRef.set({'rootPhotos': FieldValue.arrayUnion(newPaths)}, SetOptions(merge: true));
    } else {
      await docRef.set({
        'folders': { folderName: FieldValue.arrayUnion(newPaths) }
      }, SetOptions(merge: true));
    }

    await loadCountryData(countryCode);
  }

  Future<void> setNote(String countryCode, String? note) async {
    if (_uid == null) return;
    final cleanNote = (note != null && note.trim().isEmpty) ? null : note;
    
    await _db.collection('users').doc(_uid).collection('countries').doc(countryCode).set({
      'note': cleanNote
    }, SetOptions(merge: true));
    
    _ensureNoteNotifier(countryCode).value = cleanNote;
  }

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
    
    // Limpeza de ficheiros locais
    for (var f in filesToRemove) {
      try { if (await f.exists()) await f.delete(); } catch (_) {}
    }

    await loadCountryData(countryCode);
  }

  // --- Getters ---
  ValueNotifier<List<File>> getNotifierForCountry(String code) => _ensureNotifier(code);
  ValueNotifier<List<File>> getFolderNotifier(String code, String folder) => _ensureFolderNotifier(code, folder);
  ValueNotifier<List<String>> getFolderListNotifier(String code) => _ensureFolderListNotifier(code);
  ValueNotifier<String?> getNoteNotifier(String code) => _ensureNoteNotifier(code);
  
  String? getNote(String code) => _ensureNoteNotifier(code).value;
  List<File> getPhotos(String code) => _ensureNotifier(code).value;
  List<File> getPhotosInFolder(String code, String folder) => _ensureFolderNotifier(code, folder).value;
}