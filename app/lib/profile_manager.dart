import 'package:flutter/foundation.dart';
import 'dart:io';

/// Gerenciador global para dados de perfil do utilizador
class ProfileManager {
  static final ProfileManager _instance = ProfileManager._internal();

  factory ProfileManager() {
    return _instance;
  }

  ProfileManager._internal() {
    profileImageNotifier = ValueNotifier<File?>(null);
  }

  late ValueNotifier<File?> profileImageNotifier;

  /// Atualiza a imagem de perfil
  void setProfileImage(File imageFile) {
    profileImageNotifier.value = imageFile;
  }

  /// Obtém a imagem de perfil
  File? getProfileImage() {
    return profileImageNotifier.value;
  }

  /// Limpa a imagem de perfil
  void clearProfileImage() {
    profileImageNotifier.value = null;
  }
}
