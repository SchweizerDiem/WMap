import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; 
import 'package:home_widget/home_widget.dart';
import 'dart:math';

class UserAccount {
  final String name;
  final String email;
  final String friendCode;
  final Set<String> visitedCountries;
  final Set<String> plannedCountries;
  final List<String> friends;
  final List<String> nationalities;
  final Color colorVisited;
  final Color colorPlanned;
  final Color colorNationality;

  UserAccount({
    required this.name,
    required this.email,
    required this.friendCode,
    required this.visitedCountries,
    required this.plannedCountries,
    required this.friends,
    this.nationalities = const [],
    this.colorVisited = const Color(0xFF1F83D4),
    this.colorPlanned = const Color(0xFF061094),
    this.colorNationality = const Color(0xFF09B5E9),
  });   
}

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserAccount? _currentUser;

  // --- NOTIFIERS ---
  final ValueNotifier<int> visitedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> plannedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> userNameNotifier = ValueNotifier<String>('Guest');
  
  final ValueNotifier<Color> visitedColorNotifier = ValueNotifier<Color>(const Color(0xFF1F83D4));
  final ValueNotifier<Color> plannedColorNotifier = ValueNotifier<Color>(const Color(0xFF061094));
  final ValueNotifier<Color> nationalityColorNotifier = ValueNotifier<Color>(const Color(0xFF09B5E9));

  UserAccount? getCurrentUser() => _currentUser;

  // --- FUNÇÕES DE CONVERSÃO ---

  // Converte Cor para String Hexadecimal com '#' (Para o HomeWidget/Android)
  String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  // Helper para converter String Hex para Cor (Vinda do Firestore)
  Color _hexToColor(String hex) {
    try {
      // Remove o '#' se existir para evitar erros no parse
      String cleanHex = hex.replaceFirst('#', '');
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return Colors.blue; // Cor de fallback
    }
  }

  String _generateFriendCode() {
    final random = Random();
    int code = random.nextInt(900000) + 100000;
    return "WMP-$code";
  }

  // --- AUTH ---

  Future<bool> registerAccount(String name, String email, String password) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        // Usamos colorToHex para manter consistência no DB
        await _db.collection('users').doc(res.user!.uid).set({
          'name': name,
          'email': email,
          'friendCode': _generateFriendCode(),
          'visitedCountries': [],
          'plannedCountries': [],
          'friends': [],
          'nationalities': [],
          'colorVisited': colorToHex(const Color(0xFF1F83D4)),
          'colorPlanned': colorToHex(const Color(0xFF061094)),
          'colorNationality': colorToHex(const Color(0xFF09B5E9)),
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

    DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      
      final Color vColor = data['colorVisited'] != null ? _hexToColor(data['colorVisited']) : const Color(0xFF1F83D4);
      final Color pColor = data['colorPlanned'] != null ? _hexToColor(data['colorPlanned']) : const Color(0xFF061094);
      final Color nColor = data['colorNationality'] != null ? _hexToColor(data['colorNationality']) : const Color(0xFF09B5E9);

      _currentUser = UserAccount(
        name: data['name'] ?? 'User',
        email: data['email'] ?? '',
        friendCode: data['friendCode'] ?? 'N/A',
        visitedCountries: Set<String>.from(data['visitedCountries'] ?? []),
        plannedCountries: Set<String>.from(data['plannedCountries'] ?? []),
        friends: List<String>.from(data['friends'] ?? []),
        nationalities: List<String>.from(data['nationalities'] ?? []),
        colorVisited: vColor,
        colorPlanned: pColor,
        colorNationality: nColor,
      );

      visitedCountNotifier.value = _currentUser!.visitedCountries.length;
      plannedCountNotifier.value = _currentUser!.plannedCountries.length;
      userNameNotifier.value = _currentUser!.name;
      
      visitedColorNotifier.value = vColor;
      plannedColorNotifier.value = pColor;
      nationalityColorNotifier.value = nColor;
      
      debugPrint("User data refreshed (including colors)");
    }
  }

  // --- ATUALIZAÇÃO DE CORES ---

  Future<void> updateMapColors({Color? visited, Color? planned, Color? nationality}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final Map<String, dynamic> updates = {};

    if (visited != null) {
      String hex = colorToHex(visited);
      updates['colorVisited'] = hex;
      visitedColorNotifier.value = visited;
      await HomeWidget.saveWidgetData<String>('color_visited_hex', hex);
    }

    if (planned != null) {
      String hex = colorToHex(planned);
      updates['colorPlanned'] = hex;
      plannedColorNotifier.value = planned;
      await HomeWidget.saveWidgetData<String>('color_planned_hex', hex);
    }

    if (nationality != null) {
      String hex = colorToHex(nationality);
      updates['colorNationality'] = hex;
      nationalityColorNotifier.value = nationality;
      await HomeWidget.saveWidgetData<String>('color_nat_hex', hex);
    }

    try {
      await _db.collection('users').doc(uid).update(updates);
      // Notifica o sistema Android que o Widget precisa de ser redesenhado com as novas cores
      await HomeWidget.updateWidget(name: 'MapWidgetProvider', androidName: 'MapWidgetProvider');
    } catch (e) {
      debugPrint("Erro ao atualizar cores no Firebase: $e");
    }
  }

  // --- SOCIAL / AMIGOS ---

  Future<String> sendFriendRequest(String code) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null || _currentUser == null) return "Erro de sessão";
      final cleanCode = code.toUpperCase().trim();
      final query = await _db.collection('users').where('friendCode', isEqualTo: cleanCode).get();
      if (query.docs.isEmpty) return "User not found.";
      final targetId = query.docs.first.id;
      if (targetId == currentUserId) return "You can't add yourself.";
      if (_currentUser!.friends.contains(targetId)) return "Already friends.";
      await _db.collection('friend_requests').doc("${currentUserId}_$targetId").set({
        'from': currentUserId,
        'to': targetId,
        'senderName': _currentUser!.name,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      return "Request sent!";
    } catch (e) { return "Error: $e"; }
  }

  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      await _db.collection('users').doc(currentUserId).update({'friends': FieldValue.arrayUnion([fromUserId])});
      await _db.collection('users').doc(fromUserId).update({'friends': FieldValue.arrayUnion([currentUserId])});
      await _db.collection('friend_requests').doc(requestId).delete();
      await refreshUserData();
    } catch (e) { debugPrint("Error accepting friend: $e"); }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).delete();
  }

  Stream<QuerySnapshot> getIncomingRequestsStream() {
    final currentUserId = _auth.currentUser?.uid;
    return _db.collection('friend_requests').where('to', isEqualTo: currentUserId).where('status', isEqualTo: 'pending').snapshots();
  }

  Stream<List<Map<String, dynamic>>> getFriendsListStream() {
    if (_currentUser == null || _currentUser!.friends.isEmpty) return Stream.value([]);
    return _db.collection('users').where(FieldPath.documentId, whereIn: _currentUser!.friends).snapshots().map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // --- GESTÃO DE CONTA ---

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    visitedCountNotifier.value = 0;
    plannedCountNotifier.value = 0;
    userNameNotifier.value = 'Guest';
  }

  Future<void> updateUserName(String newName) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      await _db.collection('users').doc(uid).update({'name': newName});
      await refreshUserData();
    } catch (e) { rethrow; }
  }

  // --- LÓGICA DO MAPA ---

  Future<void> toggleVisitedForCurrentUser(String countryCode) async {
    if (_currentUser == null) return;
    final String code = countryCode.toUpperCase();
    final userDoc = _db.collection('users').doc(_auth.currentUser!.uid);
    if (_currentUser!.visitedCountries.contains(code)) {
      await userDoc.update({'visitedCountries': FieldValue.arrayRemove([code])});
    } else {
      await userDoc.update({'visitedCountries': FieldValue.arrayUnion([code]), 'plannedCountries': FieldValue.arrayRemove([code])});
    }
    await refreshUserData();
  }

  Future<void> togglePlannedForCurrentUser(String countryCode) async {
    if (_currentUser == null) return;
    final String code = countryCode.toUpperCase();
    if (_currentUser!.visitedCountries.contains(code)) return;
    final userDoc = _db.collection('users').doc(_auth.currentUser!.uid);
    if (_currentUser!.plannedCountries.contains(code)) {
      await userDoc.update({'plannedCountries': FieldValue.arrayRemove([code])});
    } else {
      await userDoc.update({'plannedCountries': FieldValue.arrayUnion([code])});
    }
    await refreshUserData();
  }

  bool isCountryVisitedForCurrentUser(String code) => _currentUser?.visitedCountries.contains(code.toUpperCase()) ?? false;
  bool isCountryPlannedForCurrentUser(String code) => _currentUser?.plannedCountries.contains(code.toUpperCase()) ?? false;
  List<String> getVisitedCountriesForCurrentUser() => _currentUser?.visitedCountries.toList() ?? [];
  List<String> getFriendsForCurrentUser() => _currentUser?.friends ?? [];

  Future<void> updateNationalities(List<String> codes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'nationalities': codes});
    await refreshUserData(); 
  }

  Future<void> resetMapColors() async {
    const Color defaultVisited = Color(0xFF1F83D4);
    const Color defaultPlanned = Color(0xFF061094);
    const Color defaultNationality = Color(0xFF09B5E9);

    await updateMapColors(
      visited: defaultVisited,
      planned: defaultPlanned,
      nationality: defaultNationality,
    );
  }

  Future<void> removeFriend(String friendId) async {
    if (_currentUser == null) return;
    final currentUserId = _auth.currentUser!.uid;
    await _db.collection('users').doc(currentUserId).update({'friends': FieldValue.arrayRemove([friendId])});
    await _db.collection('users').doc(friendId).update({'friends': FieldValue.arrayRemove([currentUserId])});
    await refreshUserData(); 
  }
}