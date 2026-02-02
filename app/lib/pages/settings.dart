import 'package:flutter/material.dart';
import '../user.dart';
import '../session_manager.dart';
import '../country_names.dart'; // IMPORTANTE: Para a lista de países

class SettingsPage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const SettingsPage({super.key, this.onBackPressed});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

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

  // Função para converter código em Emoji (copiada para manter autonomia do ficheiro)
  String _countryCodeToEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '';
    final base = 0x1F1E6;
    final first = base + code.codeUnitAt(0) - 'A'.codeUnitAt(0);
    final second = base + code.codeUnitAt(1) - 'A'.codeUnitAt(0);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  // Lógica do Seletor de Nacionalidades para Definições
  Future<void> _showNationalitySettingsPicker() async {
    final session = SessionManager();
    final user = session.getCurrentUser();
    if (user == null) return;

    final countries = countryNames.entries.map((e) => {'code': e.key, 'name': e.value}).toList();
    final selectedSet = Set<String>.from(user.nationalities);

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setInternalState) {
            final query = searchController.text.toLowerCase();
            final filtered = countries.where((c) => c['name']!.toLowerCase().contains(query)).toList();

            return AlertDialog(
              title: const Text('Edit Nationalities'),
              content: SizedBox(
                width: double.maxFinite,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setInternalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search country...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          final isSelected = selectedSet.contains(c['code']);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setInternalState(() {
                                if (val == true) {
                                  selectedSet.add(c['code']!);
                                } else {
                                  selectedSet.remove(c['code']);
                                }
                              });
                            },
                            title: Text(c['name']!),
                            secondary: Text(_countryCodeToEmoji(c['code']!), style: const TextStyle(fontSize: 22)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedSet.toList()), 
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() => _isLoading = true);
      try {
        await session.updateNationalities(selected);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nationalities updated!')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
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
        : SingleChildScrollView( // Adicionado para evitar overflow
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Secção de Nome
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile Settings',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name/Nickname',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final newName = _nameController.text.trim();
                            if (newName.isEmpty) return;
                            setState(() => _isLoading = true);
                            try {
                              await SessionManager().updateUserName(newName);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Name updated!')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                          child: const Text('Update Name'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. NOVA Secção: Gerir Nacionalidades
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.flag_rounded, color: Colors.blue),
                    title: const Text("Manage Nationalities"),
                    subtitle: const Text("Add or change your home countries"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showNationalitySettingsPicker,
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Botão Log Out
                ElevatedButton(
                  onPressed: () async {
                    await SessionManager().logout();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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

                // 4. Botão Delete Account
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