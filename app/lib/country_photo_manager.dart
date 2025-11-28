import 'dart:io';

import 'package:flutter/foundation.dart';

/// Simple in-memory manager for photos attached to country codes.
/// Stores photos as local Files (paths returned by image_picker).
class CountryPhotoManager {
  static final CountryPhotoManager _instance = CountryPhotoManager._internal();

  factory CountryPhotoManager() => _instance;

  CountryPhotoManager._internal();

  // Map countryCode -> ValueNotifier of list of Files (root/unfoldered photos)
  final Map<String, ValueNotifier<List<File>>> _notifiers = {};
  // Map countryCode -> (folderName -> ValueNotifier of list of Files)
  final Map<String, Map<String, ValueNotifier<List<File>>>> _folderNotifiers = {};
  // Map countryCode -> ValueNotifier of folder name list to allow UI to react to folder additions/removals
  final Map<String, ValueNotifier<List<String>>> _folderListNotifiers = {};
  // Optional per-country textual notes (user-added). Use ValueNotifier to allow UI to listen.
  final Map<String, ValueNotifier<String?>> _notes = {};

  ValueNotifier<List<File>> _ensureNotifier(String countryCode) {
    return _notifiers.putIfAbsent(countryCode, () => ValueNotifier<List<File>>(<File>[]));
  }

  Map<String, ValueNotifier<List<File>>> _ensureFolderMap(String countryCode) {
    return _folderNotifiers.putIfAbsent(countryCode, () => <String, ValueNotifier<List<File>>>{});
  }

  ValueNotifier<List<File>> _ensureFolderNotifier(String countryCode, String folderName) {
    final map = _ensureFolderMap(countryCode);
    return map.putIfAbsent(folderName, () => ValueNotifier<List<File>>(<File>[]));
  }

  ValueNotifier<List<String>> _ensureFolderListNotifier(String countryCode) {
    return _folderListNotifiers.putIfAbsent(countryCode, () => ValueNotifier<List<String>>(<String>[]));
  }

  ValueNotifier<String?> _ensureNoteNotifier(String countryCode) {
    return _notes.putIfAbsent(countryCode, () => ValueNotifier<String?>(null));
  }

  /// Get current photos for a country (snapshot)
  List<File> getPhotos(String countryCode) => List.unmodifiable(_ensureNotifier(countryCode).value);

  /// Get a ValueNotifier to listen to changes for a specific country
  ValueNotifier<List<File>> getNotifierForCountry(String countryCode) => _ensureNotifier(countryCode);

  /// Get a ValueNotifier for a specific folder under a country
  ValueNotifier<List<File>> getFolderNotifier(String countryCode, String folderName) => _ensureFolderNotifier(countryCode, folderName);

  /// Get a ValueNotifier that emits the list of folder names for a country.
  ValueNotifier<List<String>> getFolderListNotifier(String countryCode) => _ensureFolderListNotifier(countryCode);

  /// Add one or more photos for a country
  void addPhotos(String countryCode, List<File> files) {
    final notifier = _ensureNotifier(countryCode);
    final newList = List<File>.from(notifier.value)..addAll(files);
    notifier.value = newList;
  }

  /// Add photos to a named folder for a country. Creates the folder if missing.
  void addPhotosToFolder(String countryCode, String folderName, List<File> files) {
    final notifier = _ensureFolderNotifier(countryCode, folderName);
    final newList = List<File>.from(notifier.value)..addAll(files);
    notifier.value = newList;
    // ensure folder appears in folder list
    final listNotifier = _ensureFolderListNotifier(countryCode);
    if (!listNotifier.value.contains(folderName)) {
      final newListNames = List<String>.from(listNotifier.value)..add(folderName);
      listNotifier.value = newListNames;
    }
  }

  /// Clear photos for a country
  void clearPhotos(String countryCode) {
    final notifier = _ensureNotifier(countryCode);
    notifier.value = <File>[];
  }

  /// Clear photos in a named folder for a country
  void clearFolder(String countryCode, String folderName) {
    final notifier = _ensureFolderNotifier(countryCode, folderName);
    notifier.value = <File>[];
  }

  /// Remove a folder entirely (delete folder entry and its notifier)
  void removeFolder(String countryCode, String folderName) {
    final map = _folderNotifiers[countryCode];
    map?.remove(folderName);
    final listNotifier = _folderListNotifiers[countryCode];
    if (listNotifier != null && listNotifier.value.contains(folderName)) {
      final newList = List<String>.from(listNotifier.value)..remove(folderName);
      listNotifier.value = newList;
    }
  }

  /// Get the current note for a country (snapshot)
  String? getNote(String countryCode) => _ensureNoteNotifier(countryCode).value;

  /// Get a ValueNotifier to listen to the textual note for a specific country
  ValueNotifier<String?> getNoteNotifier(String countryCode) => _ensureNoteNotifier(countryCode);

  /// Set or clear a textual note for a country. Pass null or empty string to clear.
  void setNote(String countryCode, String? note) {
    final notifier = _ensureNoteNotifier(countryCode);
    notifier.value = (note != null && note.isEmpty) ? null : note;
  }

  /// Remove specific photos for a country. Files are matched by path.
  void removePhotos(String countryCode, List<File> filesToRemove) {
    final notifier = _ensureNotifier(countryCode);
    final pathsToRemove = filesToRemove.map((f) => f.path).toSet();
    final newList = notifier.value.where((f) => !pathsToRemove.contains(f.path)).toList();
    notifier.value = newList;
  }

  /// Remove specific photos from a named folder for a country. Files are matched by path.
  void removePhotosFromFolder(String countryCode, String folderName, List<File> filesToRemove) {
    final notifier = _ensureFolderNotifier(countryCode, folderName);
    final pathsToRemove = filesToRemove.map((f) => f.path).toSet();
    final newList = notifier.value.where((f) => !pathsToRemove.contains(f.path)).toList();
    notifier.value = newList;
  }

  /// Get list of folder names for a country
  List<String> getFolders(String countryCode) {
    final map = _folderNotifiers[countryCode];
    if (map == null) return <String>[];
    return map.keys.toList();
  }

  /// Get photos in a folder (snapshot)
  List<File> getPhotosInFolder(String countryCode, String folderName) => List.unmodifiable(_ensureFolderNotifier(countryCode, folderName).value);
}
