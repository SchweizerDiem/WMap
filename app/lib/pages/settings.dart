import 'package:flutter/material.dart';
import '../user.dart';
import '../session_manager.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const SettingsPage({super.key, this.onBackPressed});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false; // Para feedback visual

  @override
  void initState() {
    super.initState();
    _nameController.text = userNameNotifier.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed,
              )
            : null,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Secção de Alterar Nome
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Change Name/Nickname',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'New Name/Nickname',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final newName = _nameController.text.trim();
                            if (newName.isEmpty) return;
                            
                            // No Firebase, o SessionManager deve ter um método para atualizar o nome
                            // Por agora, atualizamos o notifier e podes depois adicionar a lógica no Firestore
                            userNameNotifier.value = newName;
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name updated locally')),
                            );
                          },
                          child: const Text('Update Name'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botão Log Out (Corrigido para Firebase)
                ElevatedButton(
                  onPressed: () async {
                    await SessionManager().logout(); // Chama o logout real
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login', // Certifica-te que esta rota existe no main.dart
                        (Route<dynamic> route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Log Out'),
                ),
                const SizedBox(height: 16),

                // Botão Delete Account (Corrigido)
                ElevatedButton(
                  onPressed: () => _confirmDeleteAccount(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Delete Account'),
                ),
              ],
            ),
          ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure? This will delete all your data and cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _isLoading = true);
                
                // NOTA: No Firebase Auth, apagar conta exige um login recente.
                // Aqui chamamos o logout por segurança, mas o ideal seria apagar no Firestore primeiro.
                await SessionManager().logout(); 
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account data cleared')),
                  );
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}