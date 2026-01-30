import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';

/// Modelo de dados da conta (simplificado para o Firebase)
class UserAccount {
  final String name;
  final String email;
  final Set<String> visitedCountries;
  final Set<String> plannedCountries;

  UserAccount({
    required this.name,
    required this.email,
    Set<String>? visitedCountries,
    Set<String>? plannedCountries,
  }) : visitedCountries = visitedCountries ?? <String>{},
       plannedCountries = plannedCountries ?? <String>{};

  UserAccount copyWith({String? name, Set<String>? visitedCountries, Set<String>? plannedCountries}) {
    return UserAccount(
      name: name ?? this.name,
      email: email,
      visitedCountries: visitedCountries ?? Set<String>.from(this.visitedCountries),
      plannedCountries: plannedCountries ?? Set<String>.from(this.plannedCountries),
    );
  }
}

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserAccount? _currentUser;

  // Notifiers para a UI (Ecrã de Perfil/Home)
  final ValueNotifier<int> visitedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> plannedCountNotifier = ValueNotifier<int>(0);

  UserAccount? getCurrentUser() => _currentUser;

  /// Regista uma conta no Firebase Auth e cria o perfil no Firestore
  Future<bool> registerAccount(String name, String email, String password) async {
    try {
      // 1. Criar utilizador no Firebase Auth
      UserCredential res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        // 2. Criar documento inicial no Firestore
        await _db.collection('users').doc(res.user!.uid).set({
          'name': name,
          'email': email,
          'visitedCountries': [],
          'plannedCountries': [],
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Erro no registo: $e");
      return false;
    }
  }

  /// Autentica o utilizador e carrega os seus dados da Cloud
  Future<bool> login(String email, String password) async {
    try {
      UserCredential res = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await refreshUserData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Erro no login: $e");
      return false;
    }
  }

  /// Sincroniza os dados do Firestore com o estado local da App
  Future<void> refreshUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      
      _currentUser = UserAccount(
        name: data['name'] ?? 'User',
        email: data['email'] ?? '',
        visitedCountries: Set<String>.from(data['visitedCountries'] ?? []),
        plannedCountries: Set<String>.from(data['plannedCountries'] ?? []),
      );

      // Atualiza notifiers globais
      visitedCountNotifier.value = _currentUser!.visitedCountries.length;
      plannedCountNotifier.value = _currentUser!.plannedCountries.length;
      userNameNotifier.value = _currentUser!.name;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    visitedCountNotifier.value = 0;
    plannedCountNotifier.value = 0;
    userNameNotifier.value = 'Guest';
  }

  // --- Lógica de Toggle (Mapa) ---

  Future<void> toggleVisitedForCurrentUser(String countryCode) async {
    if (_currentUser == null) return;
    final String code = countryCode.toUpperCase();
    final userDoc = _db.collection('users').doc(_auth.currentUser!.uid);

    if (_currentUser!.visitedCountries.contains(code)) {
      // Remover de visitados
      await userDoc.update({
        'visitedCountries': FieldValue.arrayRemove([code])
      });
    } else {
      // Adicionar a visitados e garantir que sai dos planeados
      await userDoc.update({
        'visitedCountries': FieldValue.arrayUnion([code]),
        'plannedCountries': FieldValue.arrayRemove([code])
      });
    }
    await refreshUserData();
  }

  Future<void> togglePlannedForCurrentUser(String countryCode) async {
    if (_currentUser == null) return;
    final String code = countryCode.toUpperCase();
    
    // Se já visitou, não faz sentido planear
    if (_currentUser!.visitedCountries.contains(code)) return;

    final userDoc = _db.collection('users').doc(_auth.currentUser!.uid);

    if (_currentUser!.plannedCountries.contains(code)) {
      await userDoc.update({
        'plannedCountries': FieldValue.arrayRemove([code])
      });
    } else {
      await userDoc.update({
        'plannedCountries': FieldValue.arrayUnion([code])
      });
    }
    await refreshUserData();
  }

  // --- Getters ---
  bool isCountryVisitedForCurrentUser(String code) => _currentUser?.visitedCountries.contains(code.toUpperCase()) ?? false;
  bool isCountryPlannedForCurrentUser(String code) => _currentUser?.plannedCountries.contains(code.toUpperCase()) ?? false;
  List<String> getVisitedCountriesForCurrentUser() => _currentUser?.visitedCountries.toList() ?? [];
}