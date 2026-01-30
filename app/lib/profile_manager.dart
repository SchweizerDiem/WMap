import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileManager {
  static final ProfileManager _instance = ProfileManager._internal();
  factory ProfileManager() => _instance;

  ProfileManager._internal() {
    profileImageNotifier = ValueNotifier<File?>(null);
  }

  late ValueNotifier<File?> profileImageNotifier;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Atualiza a imagem de perfil: Copia para pasta segura e guarda o path no Firestore
  Future<void> setProfileImage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Salvar localmente de forma permanente
      final directory = await getApplicationDocumentsDirectory();
      // Criamos um nome único baseado no UID para evitar conflitos
      final String fileName = "profile_${user.uid}${p.extension(imageFile.path)}";
      final String permanentPath = p.join(directory.path, fileName);
      
      final File savedFile = await imageFile.copy(permanentPath);

      // 2. Atualizar Notifier (UI reage aqui)
      profileImageNotifier.value = savedFile;

      // 3. Guardar o caminho no Firestore usando merge para evitar erros de "document not found"
      await _db.collection('users').doc(user.uid).set({
        'profileImagePath': permanentPath,
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint("Erro ao salvar imagem de perfil: $e");
    }
  }

  /// Carrega o caminho da imagem do Firestore e verifica se o ficheiro existe
  Future<void> loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('profileImagePath')) {
          final String path = data['profileImagePath'];
          final file = File(path);
          
          if (await file.exists()) {
            profileImageNotifier.value = file;
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar imagem de perfil: $e");
    }
  }

  /// Limpa a imagem de perfil localmente e no Firestore
  Future<void> clearProfileImage() async {
    profileImageNotifier.value = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        'profileImagePath': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }
}