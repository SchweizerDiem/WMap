import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // Alias para manipular caminhos de ficheiros
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Classe responsável pela gestão da imagem de perfil do utilizador.
/// Implementa o padrão Singleton para manter a sincronia em toda a app.
class ProfileManager {
  static final ProfileManager _instance = ProfileManager._internal();
  factory ProfileManager() => _instance;

  ProfileManager._internal() {
    // Inicializa o notifier que a UI vai observar para mostrar a foto de perfil
    profileImageNotifier = ValueNotifier<File?>(null);
  }

  late ValueNotifier<File?> profileImageNotifier;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Atualiza a imagem de perfil: Copia o ficheiro para uma pasta segura 
  /// e guarda o caminho (path) no Firestore.
  Future<void> setProfileImage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Guardar o ficheiro localmente de forma permanente
      // O path_provider ajuda a encontrar a pasta de documentos da app
      final directory = await getApplicationDocumentsDirectory();
      
      // Criamos um nome único baseado no UID do utilizador para que, 
      // ao trocar de conta no mesmo telemóvel, as fotos não se misturem.
      final String fileName = "profile_${user.uid}${p.extension(imageFile.path)}";
      final String permanentPath = p.join(directory.path, fileName);
      
      // Copia a imagem da pasta temporária (ex: galeria/câmara) para a pasta da app
      final File savedFile = await imageFile.copy(permanentPath);

      // 2. Atualizar o Notifier
      // Qualquer widget que use ValueListenableBuilder(valueListenable: profileImageNotifier)
      // irá atualizar-se instantaneamente aqui.
      profileImageNotifier.value = savedFile;

      // 3. Persistir o caminho no Firestore
      // Usamos SetOptions(merge: true) para garantir que não sobrescrevemos outros dados do utilizador.
      await _db.collection('users').doc(user.uid).set({
        'profileImagePath': permanentPath,
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint("Erro ao salvar imagem de perfil: $e");
    }
  }

  /// Carrega o caminho da imagem guardado no Firestore e valida a existência do ficheiro.
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
          
          // Verifica se o ficheiro ainda existe no disco antes de atualizar a UI
          if (await file.exists()) {
            profileImageNotifier.value = file;
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar imagem de perfil: $e");
    }
  }

  /// Remove a imagem de perfil tanto da UI (notifier) como da base de dados.
  Future<void> clearProfileImage() async {
    profileImageNotifier.value = null; // Remove da interface
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // Remove o campo 'profileImagePath' do documento do utilizador no Firestore
      await _db.collection('users').doc(user.uid).set({
        'profileImagePath': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }
}