import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../session_manager.dart';
import '../country_names.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onBackPressed; // Callback para atualizar o mapa ao retornar
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
    // Inicializa o campo de texto com o nome atual do utilizador na sessão
    _nameController.text = SessionManager().getCurrentUser()?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Converte código ISO de país (ex: PT) para o respetivo Emoji de bandeira
  String _countryCodeToEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '';
    final base = 0x1F1E6;
    final first = base + code.codeUnitAt(0) - 'A'.codeUnitAt(0);
    final second = base + code.codeUnitAt(1) - 'A'.codeUnitAt(0);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  /// Exibe um diálogo interativo para selecionar múltiplas nacionalidades
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
        return StatefulBuilder( // Permite atualizar o estado interno do diálogo (pesquisa e checks)
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
                      onChanged: (_) => setInternalState(() {}), // Recalcula a lista filtrada
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
        // Notifica o componente pai para atualizar cores de nacionalidade no mapa
        if (widget.onBackPressed != null) widget.onBackPressed!();
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
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Secção de Edição do Nome de Perfil
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

                // Lista de opções de configuração
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.flag_rounded, color: Colors.blue),
                        title: const Text("Manage Nationalities"),
                        subtitle: const Text("Add or change your home countries"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showNationalitySettingsPicker,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.palette_outlined, color: Colors.purple),
                        title: const Text("Map Colors"),
                        subtitle: const Text("Customize map marker colors"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MapCustomizationPage(onSave: widget.onBackPressed)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Botão de Logout
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

                // Botão crítico: Eliminação de conta
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

  /// Diálogo de confirmação para evitar eliminação acidental de dados
  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text('Are you sure? This will delete all your data and cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _isLoading = true);
                await SessionManager().logout(); 
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account data cleared')));
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

// --- PÁGINA DE PERSONALIZAÇÃO DE CORES DO MAPA ---

class MapCustomizationPage extends StatefulWidget {
  final VoidCallback? onSave;
  const MapCustomizationPage({super.key, this.onSave});

  @override
  State<MapCustomizationPage> createState() => _MapCustomizationPageState();
}

class _MapCustomizationPageState extends State<MapCustomizationPage> {
  // Estados temporários para as cores antes de persistir no SessionManager
  late Color tempVisited;
  late Color tempPlanned;
  late Color tempNationality;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    tempVisited = session.visitedColorNotifier.value;
    tempPlanned = session.plannedColorNotifier.value;
    tempNationality = session.nationalityColorNotifier.value;
  }

  /// Abre o ColorPicker do pacote externo para selecionar uma nova cor
  void _pickColor(String type, Color currentColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick color for $type'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                if (type == 'Visited') tempVisited = color;
                if (type == 'Planned') tempPlanned = color;
                if (type == 'Nationality') tempNationality = color;
                _hasChanges = true;
              });
            },
            enableAlpha: false, // Cores sólidas funcionam melhor no mapa
            labelTypes: const [],
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map Colors")),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _tempColorTile("Visited Countries", tempVisited, () => _pickColor('Visited', tempVisited)),
                _tempColorTile("Planned Trips", tempPlanned, () => _pickColor('Planned', tempPlanned)),
                _tempColorTile("Your Nationalities", tempNationality, () => _pickColor('Nationality', tempNationality)),
                const SizedBox(height: 20),
                // Botão para reverter para o esquema original do app
                OutlinedButton.icon(
                  onPressed: () => _confirmReset(),
                  icon: const Icon(Icons.restore, color: Colors.grey),
                  label: const Text("Reset to Default Colors", style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
          // Botão que efetivamente guarda as alterações na sessão
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: _hasChanges ? () async {
                final session = SessionManager();
                await session.updateMapColors(
                  visited: tempVisited,
                  planned: tempPlanned,
                  nationality: tempNationality,
                );
                
                if (mounted && widget.onSave != null) {
                  widget.onSave!(); // Atualiza o widget do Mapa
                  Navigator.pop(context); // Regressa às Settings
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              child: const Text("SAVE & UPDATE WIDGET", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// Construtor de itens da lista de cores com preview circular
  Widget _tempColorTile(String title, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Container(
          width: 35, height: 35,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
        ),
        onTap: onTap,
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Colors?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await SessionManager().resetMapColors();
              if (mounted && widget.onSave != null) {
                widget.onSave!();
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text("Reset", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}