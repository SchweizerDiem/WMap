import 'package:WMap/main.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../session_manager.dart';
import '../friends_management_page.dart';
import 'friend_profile.dart'; 

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  // Instância do gestor de sessão para aceder aos dados do utilizador e streams
  final _sessionManager = SessionManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Friends'),
        // Botão de retorno personalizado para garantir que voltamos à HomePage limpando a pilha de navegação
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()), 
              (route) => false,
            );
          },
        ),
        actions: [
          // StreamBuilder que escuta pedidos de amizade pendentes para mostrar a notificação (badge)
          StreamBuilder<QuerySnapshot>(
            stream: _sessionManager.getIncomingRequestsStream(),
            builder: (context, snapshot) {
              bool hasRequests = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.group_add),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FriendsManagementPage()),
                      );
                    },
                  ),
                  // Ponto vermelho indicativo de novos pedidos recebidos
                  if (hasRequests)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      // StreamBuilder que reconstrói a lista de amigos automaticamente sempre que há alterações no Firestore
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _sessionManager.getFriendsListStream(),
        builder: (context, snapshot) {
          // Mostra um indicador de progresso enquanto os dados estão a ser carregados
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final friends = snapshot.data ?? [];

          // Layout exibido quando o utilizador ainda não tem amigos adicionados
          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No friends added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FriendsManagementPage()),
                      );
                    },
                    child: const Text('Add your first friend'),
                  ),
                ],
              ),
            );
          }

          // Construtor de lista eficiente para exibir os cards de cada amigo
          return ListView.builder(
            itemCount: friends.length,
            padding: const EdgeInsets.all(12.0),
            itemBuilder: (context, index) {
              final friend = friends[index];
              final String name = friend['name'] ?? 'User';
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  // Avatar com a inicial do nome do amigo
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Exibe o código de amizade único por baixo do nome
                  subtitle: Text(friend['friendCode'] ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  // Ao clicar, navega para o perfil detalhado do amigo selecionado
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FriendProfilePage(friendData: friend),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}