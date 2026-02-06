import 'package:flutter/material.dart';
import '../user.dart';
import '../session_manager.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controladores para capturar os dados inseridos nos campos de texto
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // Notifier para detetar mudanças na password e atualizar os requisitos em tempo real
  late final ValueNotifier<String> _passwordNotifier;

  bool _isLoading = false;             // Estado de carregamento do botão
  bool _obscurePassword = true;        // Ocultar/Mostrar password principal
  bool _obscureConfirmPassword = true; // Ocultar/Mostrar confirmação
  String? errorMessage;                // Armazena mensagens de erro de validação

  @override
  void initState() {
    super.initState();
    _passwordNotifier = ValueNotifier<String>('');
    // Listener que avisa o ValueNotifier sempre que o texto da password muda
    _passwordController.addListener(() {
      _passwordNotifier.value = _passwordController.text;
    });
  }

  // Validação de formato de Email usando Expressões Regulares (Regex)
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Validação robusta de Password (Segurança Máxima)
  bool _isValidPassword(String password) {
    if (password.length < 12) return false; // Mínimo 12 caracteres
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false; // Letra Grande
    if (!RegExp(r'[a-z]').hasMatch(password)) return false; // Letra Pequena
    if (!RegExp(r'[0-9]').hasMatch(password)) return false; // Número
    final specialCharRegex = RegExp(r'[!@#$%^&*()_+\-=\[\]{};:`~<>?/\\|.,]');
    if (!specialCharRegex.hasMatch(password)) return false; // Caracter Especial
    return true;
  }

  /// Lógica de Registo
  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // 1. Verificação de campos vazios
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => errorMessage = 'Please fill in all fields');
      return;
    }
    // 2. Verificação de formato de Email
    if (!_isValidEmail(email)) {
      setState(() => errorMessage = 'Invalid email format.');
      return;
    }
    // 3. Verificação de requisitos de segurança da password
    if (!_isValidPassword(password)) {
      setState(() => errorMessage = 'Password does not meet requirements');
      return;
    }
    // 4. Verificação se as passwords coincidem
    if (password != confirm) {
      setState(() => errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      final sessionManager = SessionManager();
      // Tenta criar a conta no sistema (ex: Firebase ou Backend)
      bool success = await sessionManager.registerAccount(name, email, password);

      if (success) {
        // Se criar com sucesso, faz login automático
        await sessionManager.login(email, password);
        await sessionManager.refreshUserData();
        
        if (mounted) {
          // Atualiza o nome global na aplicação e vai para a Home
          userNameNotifier.value = sessionManager.getCurrentUser()?.name ?? name;
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() => errorMessage = 'Registration failed. Email might be in use.');
      }
    } catch (e) {
      setState(() => errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff6c63ff), Color(0xff4841a8)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Create Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xff4841a8))),
                  const SizedBox(height: 8),
                  const Text("Join our community today", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 25),
                  
                  // Campo Nome
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name/Username',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Email
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // WIDGET DE REQUISITOS (Reativo ao que o utilizador escreve)
                  PasswordRequirementsWidget(
                    passwordNotifier: _passwordNotifier,
                    isValidPassword: _isValidPassword,
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Confirmar Password
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],

                  const SizedBox(height: 25),
                  
                  // Botão de Registo
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6c63ff),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('REGISTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Voltar para o Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text("Sign In", style: TextStyle(color: Color(0xff6c63ff), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET AUXILIAR: PasswordRequirementsWidget ---
// Mostra uma lista de requisitos que mudam de cor (Vermelho para Verde) conforme são cumpridos
class PasswordRequirementsWidget extends StatelessWidget {
  final ValueNotifier<String> passwordNotifier;
  final bool Function(String) isValidPassword;

  const PasswordRequirementsWidget({super.key, required this.passwordNotifier, required this.isValidPassword});

  // Funções internas para verificar cada regra individualmente para a UI
  bool _hasMinLength(String password) => password.length >= 12;
  bool _hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);
  bool _hasLowercase(String password) => RegExp(r'[a-z]').hasMatch(password);
  bool _hasNumber(String password) => RegExp(r'[0-9]').hasMatch(password);
  bool _hasSpecialChar(String password) => RegExp(r'[!@#$%^&*()_+\-=\[\]{};:`~<>?/\\|.,]').hasMatch(password);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: passwordNotifier,
      builder: (context, password, child) {
        return Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Password Requirements:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              _RequirementRow(label: 'At least 12 characters', isMet: _hasMinLength(password)),
              _RequirementRow(label: 'Uppercase letter (A-Z)', isMet: _hasUppercase(password)),
              _RequirementRow(label: 'Lowercase letter (a-z)', isMet: _hasLowercase(password)),
              _RequirementRow(label: 'Number (0-9)', isMet: _hasNumber(password)),
              _RequirementRow(label: 'Special character (!@#\$%...)', isMet: _hasSpecialChar(password)),
            ],
          ),
        );
      },
    );
  }
}

// Linha individual de requisito com ícone de Check ou Erro
class _RequirementRow extends StatelessWidget {
  final String label;
  final bool isMet;

  const _RequirementRow({required this.label, required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(isMet ? Icons.check_circle : Icons.cancel, color: isMet ? Colors.green : Colors.red, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: isMet ? Colors.green : Colors.red)),
        ],
      ),
    );
  }
}