import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'session_manager.dart';

class FriendsManagementPage extends StatelessWidget {
  const FriendsManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Friends'),
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.people), text: 'Friends'),
              const Tab(icon: Icon(Icons.person_add), text: 'Add'),
              Tab(
                icon: StreamBuilder<QuerySnapshot>(
                  stream: SessionManager().getIncomingRequestsStream(),
                  builder: (context, snapshot) {
                    bool hasReq = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.mail),
                        if (hasReq)
                          Positioned(
                            right: -5,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                text: 'Requests',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FriendsListTab(),    // Aba 1
            AddFriendTab(),      // Aba 2
            PendingRequestsTab(),// Aba 3
          ],
        ),
      ),
    );
  }
}

// --- ABA 1: LISTA DE AMIGOS ---
class FriendsListTab extends StatelessWidget {
  const FriendsListTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SessionManager().getFriendsListStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final friends = snapshot.data!;
        if (friends.isEmpty) return const Center(child: Text("No friends yet."));

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(friend['name'] ?? 'Unknown'),
              subtitle: Text(friend['friendCode'] ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove, color: Colors.red),
                onPressed: () => SessionManager().removeFriend(friend['id']),
              ),
            );
          },
        );
      },
    );
  }
}

// --- ABA 2: ADICIONAR (ENVIAR PEDIDO) ---
class AddFriendTab extends StatefulWidget {
  const AddFriendTab({super.key});

  @override
  State<AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<AddFriendTab> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Friend Code',
              hintText: 'WMP-123456',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final res = await SessionManager().sendFriendRequest(_controller.text);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
              _controller.clear();
            },
            child: const Text('Send Friend Request'),
          ),
        ],
      ),
    );
  }
}

// --- ABA 3: PEDIDOS PENDENTES ---
class PendingRequestsTab extends StatelessWidget {
  const PendingRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: SessionManager().getIncomingRequestsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No pending requests."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final requestId = docs[index].id;
            final fromId = data['from'];

            return ListTile(
              title: Text(data['senderName'] ?? 'Someone'),
              subtitle: const Text('wants to be your friend'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => SessionManager().acceptFriendRequest(requestId, fromId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => SessionManager().rejectFriendRequest(requestId),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}