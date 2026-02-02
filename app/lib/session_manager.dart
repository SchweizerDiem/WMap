import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'user.dart';
import 'post.dart';

class UserAccount {
  final String name;
  final String email;
  final String friendCode;
  final Set<String> visitedCountries;
  final Set<String> plannedCountries;
  final List<String> friends;

  UserAccount({
    required this.name,
    required this.email,
    required this.friendCode,
    Set<String>? visitedCountries,
    Set<String>? plannedCountries,
    List<String>? friends,
  }) : visitedCountries = visitedCountries ?? <String>{},
       plannedCountries = plannedCountries ?? <String>{},
       friends = friends ?? <String>[];
}

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserAccount? _currentUser;
  final ValueNotifier<int> visitedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> plannedCountNotifier = ValueNotifier<int>(0);

  UserAccount? getCurrentUser() => _currentUser;

  // --- Funções Auxiliares ---

  String _generateFriendCode() {
    final random = Random();
    int code = random.nextInt(900000) + 100000;
    return "WMP-$code";
  }

  // --- Auth ---

  Future<bool> registerAccount(String name, String email, String password) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        await _db.collection('users').doc(res.user!.uid).set({
          'name': name,
          'email': email,
          'friendCode': _generateFriendCode(),
          'visitedCountries': [],
          'plannedCountries': [],
          'friends': [],
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Erro no registo: $e");
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
  try {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    
    // FORÇAR O CARREGAMENTO DOS DADOS DO FIRESTORE
    await refreshUserData(); 
    
    return true;
  } catch (e) {
    debugPrint("Login error: $e");
    return false;
  }
}

  Future<void> refreshUserData() async {
  final user = _auth.currentUser;
  if (user == null) return;

  // Forçamos a leitura fresca do Firestore
  DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
  
  if (doc.exists) {
    final data = doc.data() as Map<String, dynamic>;
    
    // 1. Atualizamos o objeto local
    _currentUser = UserAccount(
      name: data['name'] ?? 'User',
      email: data['email'] ?? '',
      friendCode: data['friendCode'] ?? 'N/A',
      visitedCountries: Set<String>.from(data['visitedCountries'] ?? []),
      plannedCountries: Set<String>.from(data['plannedCountries'] ?? []),
      friends: List<String>.from(data['friends'] ?? []),
    );

    // 2. Notificamos os Notifiers para a UI reagir
    visitedCountNotifier.value = _currentUser!.visitedCountries.length;
    plannedCountNotifier.value = _currentUser!.plannedCountries.length;
    
    // IMPORTANTE: Isto garante que o nome no topo do perfil e noutras páginas muda
    userNameNotifier.value = _currentUser!.name; 
    
    debugPrint("User data refreshed: Name is now ${_currentUser!.name}");
  }
}

  // --- NOVO SISTEMA DE AMIGOS (PEDIDOS) ---

  /// Envia um pedido de amizade usando o código
  Future<String> sendFriendRequest(String code) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null || _currentUser == null) return "Erro de sessão";

      final cleanCode = code.toUpperCase().trim();

      // 1. Procurar o utilizador pelo código
      final query = await _db.collection('users').where('friendCode', isEqualTo: cleanCode).get();
      if (query.docs.isEmpty) return "User not found.";

      final targetId = query.docs.first.id;
      if (targetId == currentUserId) return "You can't add yourself.";
      if (_currentUser!.friends.contains(targetId)) return "Already friends.";

      // 2. Criar pedido pendente
      // Usamos um ID fixo para evitar pedidos duplicados entre as mesmas duas pessoas
      await _db.collection('friend_requests').doc("${currentUserId}_$targetId").set({
        'from': currentUserId,
        'to': targetId,
        'senderName': _currentUser!.name,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return "Request sent!";
    } catch (e) {
      return "Error: $e";
    }
  }

  /// Aceita um pedido de amizade e cria a ligação mútua
  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;

      // 1. Adicionar aos amigos de ambos
      await _db.collection('users').doc(currentUserId).update({
        'friends': FieldValue.arrayUnion([fromUserId])
      });
      await _db.collection('users').doc(fromUserId).update({
        'friends': FieldValue.arrayUnion([currentUserId])
      });

      // 2. Apagar o pedido
      await _db.collection('friend_requests').doc(requestId).delete();

      await refreshUserData();
    } catch (e) {
      debugPrint("Error accepting friend: $e");
    }
  }

  /// Rejeita/Apaga um pedido de amizade
  Future<void> rejectFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).delete();
  }

  /// Stream para ouvir pedidos de amizade que TU recebeste
  Stream<QuerySnapshot> getIncomingRequestsStream() {
    final currentUserId = _auth.currentUser?.uid;
    return _db.collection('friend_requests')
        .where('to', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Stream para obter os detalhes dos teus amigos (nomes, fotos, etc)
  Stream<List<Map<String, dynamic>>> getFriendsListStream() {
    if (_currentUser == null || _currentUser!.friends.isEmpty) {
      return Stream.value([]);
    }

    return _db.collection('users')
        .where(FieldPath.documentId, whereIn: _currentUser!.friends)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data()
        }).toList());
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

  // --- Friends and Posts Methods ---
  
  /// Get all friends of the current user
  List<String> getFriendsForCurrentUser() => _currentUser?.friends ?? [];

  /// Add a friend to the current user
  Future<void> addFriend(String friendId) async {
    if (_currentUser == null) return;
    final currentUserId = _auth.currentUser!.uid;
    
    // Add friend to current user's list
    await _db.collection('users').doc(currentUserId).update({
      'friends': FieldValue.arrayUnion([friendId])
    });
    
    // Add current user to friend's list
    await _db.collection('users').doc(friendId).update({
      'friends': FieldValue.arrayUnion([currentUserId])
    });
    
    await refreshUserData();
  }

  /// Remove a friend
  Future<void> removeFriend(String friendId) async {
    if (_currentUser == null) return;
    final currentUserId = _auth.currentUser!.uid;
    
    // 1. Remove de ambos os lados no Firestore
    await _db.collection('users').doc(currentUserId).update({
      'friends': FieldValue.arrayRemove([friendId])
    });
    await _db.collection('users').doc(friendId).update({
      'friends': FieldValue.arrayRemove([currentUserId])
    });
    
    // 2. IMPORTANTE: Forçar a atualização dos dados locais
    await refreshUserData(); 
  }

  /// Create a new post
  Future<void> createPost(String country, {String? description, String? imageUrl}) async {
    if (_currentUser == null) return;
    final userId = _auth.currentUser!.uid;
    
    await _db.collection('posts').add({
      'userId': userId,
      'userName': _currentUser!.name,
      'country': country,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.now(),
    });
  }

  /// Get posts from friends
  Stream<List<Post>> getFriendsPosts() {
    if (_currentUser == null) {
      return Stream.value([]);
    }

    final friendIds = _currentUser!.friends;
    if (friendIds.isEmpty) {
      return Stream.value([]);
    }

    return _db
        .collection('posts')
        .where('userId', whereIn: friendIds)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }

  /// Get all posts from a specific user
  Stream<List<Post>> getUserPosts(String userId) {
    return _db
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());
  }

  /// Delete a post (only if it's the current user's post)
  Future<void> deletePost(String postId) async {
    if (_currentUser == null) return;
    
    try {
      await _db.collection('posts').doc(postId).delete();
    } catch (e) {
      debugPrint("Error deleting post: $e");
    }
  }

  Future<void> updateUserName(String newName) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint("Erro: UID do utilizador é nulo.");
        return;
      }

      // 1. Tenta atualizar no Firestore
      // Certifica-se de que a coleção se chama 'users' (minúsculo)
      await _db.collection('users').doc(uid).update({
        'name': newName,
      });

      debugPrint("Firestore atualizado com sucesso para: $newName");

      // 2. Só depois de confirmar o sucesso no Firebase é que atualizamos a App
      await refreshUserData();
      
    } catch (e) {
      debugPrint("Erro detalhado ao atualizar nome no Firestore: $e");
      // Lança a exceção para que a UI (SettingsPage) possa mostrar o erro
      rethrow;
    }
  }
}

