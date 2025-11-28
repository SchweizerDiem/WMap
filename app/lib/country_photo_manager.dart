import 'dart:io';

import 'package:flutter/foundation.dart';

/// Simple in-memory manager for photos attached to country codes.
/// Stores photos as local Files (paths returned by image_picker).
class CountryPhotoManager {
  static final CountryPhotoManager _instance = CountryPhotoManager._internal();

  factory CountryPhotoManager() => _instance;

  CountryPhotoManager._internal();

  // Map countryCode -> ValueNotifier of list of Files
  final Map<String, ValueNotifier<List<File>>> _notifiers = {};

  ValueNotifier<List<File>> _ensureNotifier(String countryCode) {
    return _notifiers.putIfAbsent(countryCode, () => ValueNotifier<List<File>>(<File>[]));
  }

  /// Get current photos for a country (snapshot)
  List<File> getPhotos(String countryCode) => List.unmodifiable(_ensureNotifier(countryCode).value);

  /// Get a ValueNotifier to listen to changes for a specific country
  ValueNotifier<List<File>> getNotifierForCountry(String countryCode) => _ensureNotifier(countryCode);

  /// Add one or more photos for a country
  void addPhotos(String countryCode, List<File> files) {
    final notifier = _ensureNotifier(countryCode);
    final newList = List<File>.from(notifier.value)..addAll(files);
    notifier.value = newList;
  }

  /// Clear photos for a country
  void clearPhotos(String countryCode) {
    final notifier = _ensureNotifier(countryCode);
    notifier.value = <File>[];
  }

  /// Remove specific photos for a country. Files are matched by path.
  void removePhotos(String countryCode, List<File> filesToRemove) {
    final notifier = _ensureNotifier(countryCode);
    final pathsToRemove = filesToRemove.map((f) => f.path).toSet();
    final newList = notifier.value.where((f) => !pathsToRemove.contains(f.path)).toList();
    notifier.value = newList;
  }
}
