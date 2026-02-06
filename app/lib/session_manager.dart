import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; 
import 'package:home_widget/home_widget.dart';
import 'dart:math';

/// Modelo de dados para representar o perfil e progresso do utilizador
class UserAccount {
  final String name;
  final String email;
  final String friendCode; // Código único para amizades
  final Set<String> visitedCountries; // Conjunto de códigos ISO de países visitados
  final Set<String> plannedCountries; // Países que o utilizador planeia visitar
  final List<String> friends; // IDs dos amigos
  final List<String> nationalities; // Países de origem do utilizador
  final Color colorVisited; // Cor personalizada para países visitados no mapa
  final Color colorPlanned; // Cor personalizada para países planeados
  final Color colorNationality; // Cor para o país de nacionalidade

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
  // Padrão Singleton: garante que apenas existe uma instância do SessionManager em toda a app
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserAccount? _currentUser; // Armazena os dados do utilizador logado em memória

  // --- NOTIFIERS ---
  // ValueNotifiers permitem que a UI se atualize automaticamente quando os valores mudam
  final ValueNotifier<int> visitedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> plannedCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> userNameNotifier = ValueNotifier<String>('Guest');
  
  final ValueNotifier<Color> visitedColorNotifier = ValueNotifier<Color>(const Color(0xFF1F83D4));
  final ValueNotifier<Color> plannedColorNotifier = ValueNotifier<Color>(const Color(0xFF061094));
  final ValueNotifier<Color> nationalityColorNotifier = ValueNotifier<Color>(const Color(0xFF09B5E9));

  UserAccount? getCurrentUser() => _currentUser;

  // --- FUNÇÕES DE CONVERSÃO ---

  // Converte a cor do Flutter para String Hex (ex: #FF00FF), necessário para salvar no DB e ler no Android
  String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  // Converte a String Hex guardada no Firestore de volta para um objeto Color do Flutter
  Color _hexToColor(String hex) {
    try {
      String cleanHex = hex.replaceFirst('#', '');
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return Colors.blue; // Cor padrão caso haja erro
    }
  }

  // Gera um código aleatório (ex: WMP-123456) para o utilizador partilhar com amigos
  String _generateFriendCode() {
    final random = Random();
    int code = random.nextInt(900000) + 100000;
    return "WMP-$code";
  }

  // --- AUTH (AUTENTICAÇÃO) ---

  // Regista um novo utilizador no Firebase Auth e cria o seu perfil inicial no Firestore
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

  // Realiza o login e carrega os dados do utilizador
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

  // Procura os dados do utilizador no Firestore e atualiza todos os Notifiers da UI
  Future<void> refreshUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Converte as cores vindas do banco de dados
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

      // Atualiza os Notifiers para disparar rebuilds nos widgets que os escutam
      visitedCountNotifier.value = _currentUser!.visitedCountries.length;
      plannedCountNotifier.value = _currentUser!.plannedCountries.length;
      userNameNotifier.value = _currentUser!.name;
      
      visitedColorNotifier.value = vColor;
      plannedColorNotifier.value = pColor;
      nationalityColorNotifier.value = nColor;
    }
  }

  // --- ATUALIZAÇÃO DE CORES ---

  // Muda as cores do mapa no DB e sincroniza com o HomeWidget (Android)
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
      // Notifica o Android para atualizar o desenho do widget no homescreen
      await HomeWidget.updateWidget(name: 'MapWidgetProvider', androidName: 'MapWidgetProvider');
    } catch (e) {
      debugPrint("Erro ao atualizar cores no Firebase: $e");
    }
  }

  // --- SOCIAL / AMIGOS ---

  // Cria um pedido de amizade no Firestore para outro utilizador
  Future<String> sendFriendRequest(String code) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null || _currentUser == null) return "Erro de sessão";
      final cleanCode = code.toUpperCase().trim();
      
      // Procura o utilizador pelo código
      final query = await _db.collection('users').where('friendCode', isEqualTo: cleanCode).get();
      if (query.docs.isEmpty) return "User not found.";
      
      final targetId = query.docs.first.id;
      if (targetId == currentUserId) return "You can't add yourself.";
      if (_currentUser!.friends.contains(targetId)) return "Already friends.";

      // Regista o pedido na coleção friend_requests
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

  // Aceita o pedido e adiciona o ID à lista de amigos de ambos os utilizadores
  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    try {
      final currentUserId = _auth.currentUser!.uid;
      await _db.collection('users').doc(currentUserId).update({'friends': FieldValue.arrayUnion([fromUserId])});
      await _db.collection('users').doc(fromUserId).update({'friends': FieldValue.arrayUnion([currentUserId])});
      await _db.collection('friend_requests').doc(requestId).delete();
      await refreshUserData();
    } catch (e) { debugPrint("Error accepting friend: $e"); }
  }

  // Elimina o documento do pedido de amizade
  Future<void> rejectFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).delete();
  }

  // Stream para ouvir novos pedidos de amizade em tempo real
  Stream<QuerySnapshot> getIncomingRequestsStream() {
    final currentUserId = _auth.currentUser?.uid;
    return _db.collection('friend_requests').where('to', isEqualTo: currentUserId).where('status', isEqualTo: 'pending').snapshots();
  }

  // Stream para obter os dados (nome, foto, etc) da lista de amigos
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

  // Marca um país como visitado (e remove-o da lista de planeados se lá estiver)
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

  // Marca um país como planeado (apenas se ainda não foi visitado)
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

  // Métodos auxiliares de consulta de estado
  bool isCountryVisitedForCurrentUser(String code) => _currentUser?.visitedCountries.contains(code.toUpperCase()) ?? false;
  bool isCountryPlannedForCurrentUser(String code) => _currentUser?.plannedCountries.contains(code.toUpperCase()) ?? false;
  List<String> getVisitedCountriesForCurrentUser() => _currentUser?.visitedCountries.toList() ?? [];
  List<String> getFriendsForCurrentUser() => _currentUser?.friends ?? [];

  // Atualiza as nacionalidades do utilizador
  Future<void> updateNationalities(List<String> codes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'nationalities': codes});
    await refreshUserData(); 
  }

  // Repõe as cores originais da aplicação
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

  // Remove um amigo da lista (em ambos os perfis)
  Future<void> removeFriend(String friendId) async {
    if (_currentUser == null) return;
    final currentUserId = _auth.currentUser!.uid;
    await _db.collection('users').doc(currentUserId).update({'friends': FieldValue.arrayRemove([friendId])});
    await _db.collection('users').doc(friendId).update({'friends': FieldValue.arrayRemove([currentUserId])});
    await refreshUserData(); 
  }
}