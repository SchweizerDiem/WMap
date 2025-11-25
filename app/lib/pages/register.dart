import 'package:flutter/material.dart';
import '../user.dart';
import '../session_manager.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // ValueNotifier to track password changes in real-time
  late final ValueNotifier<String> _passwordNotifier;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _passwordNotifier = ValueNotifier<String>('');
    _passwordController.addListener(() {
      _passwordNotifier.value = _passwordController.text;
    });
  }

  // Validate email format: must contain @ and a domain extension like .com
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Validate password: minimum 12 chars, uppercase, lowercase, special chars, and numbers
  bool _isValidPassword(String password) {
    if (password.length < 12) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false; // uppercase
    if (!RegExp(r'[a-z]').hasMatch(password)) return false; // lowercase
    if (!RegExp(r'[0-9]').hasMatch(password)) return false; // number
    // Check for special characters: !@#$%^&*()_+-=[]{}; etc
    final specialCharRegex = RegExp(r'[!@#$%^&*()_+\-=\[\]{};:`~<>?/\\|.,]');
    if (!specialCharRegex.hasMatch(password)) return false;
    return true;
  }

  void _register() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() {
        errorMessage = 'Please fill in all fields';
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        errorMessage = 'Invalid email format. Email must contain @ and a domain (e.g., .com)';
      });
      return;
    }

    if (!_isValidPassword(password)) {
      setState(() {
        errorMessage = 'Password must have at least 12 characters, uppercase, lowercase, numbers, and special characters';
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        errorMessage = 'Passwords do not match';
      });
      return;
    }

    // Try to register the account in the session
    final sessionManager = SessionManager();
    // usamos o mesmo valor para name e username (Name/Username)
    if (!sessionManager.registerAccount(name, name, email, password)) {
      setState(() {
        errorMessage = 'Email or username already registered';
      });
      return;
    }

    // Log the user in and navigate to home.
    if (sessionManager.login(email, password)) {
      final user = sessionManager.getCurrentUser();
      if (user != null) {
        userNameNotifier.value = user.name;
      }
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // deixa o Scaffold transparente para o gradient do container aparecer
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // mesmas cores usadas na página de login
              Color.fromARGB(255, 17, 236, 72),
              Color.fromARGB(255, 67, 100, 233),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Create an account',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name/Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  // Password Requirements Widget
                  PasswordRequirementsWidget(
                    passwordNotifier: _passwordNotifier,
                    isValidPassword: _isValidPassword,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 18),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B62FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Sign In'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para exibir requisitos de password em tempo real
class PasswordRequirementsWidget extends StatelessWidget {
  final ValueNotifier<String> passwordNotifier;
  final bool Function(String) isValidPassword;

  const PasswordRequirementsWidget({
    super.key,
    required this.passwordNotifier,
    required this.isValidPassword,
  });

  bool _hasMinLength(String password) => password.length >= 12;
  bool _hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);
  bool _hasLowercase(String password) => RegExp(r'[a-z]').hasMatch(password);
  bool _hasNumber(String password) => RegExp(r'[0-9]').hasMatch(password);
  bool _hasSpecialChar(String password) =>
      RegExp(r'[!@#$%^&*()_+\-=\[\]{};:`~<>?/\\|.,]').hasMatch(password);

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
              const Text(
                'Password Requirements:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              _RequirementRow(
                label: 'At least 12 characters',
                isMet: _hasMinLength(password),
              ),
              _RequirementRow(
                label: 'Uppercase letter (A-Z)',
                isMet: _hasUppercase(password),
              ),
              _RequirementRow(
                label: 'Lowercase letter (a-z)',
                isMet: _hasLowercase(password),
              ),
              _RequirementRow(
                label: 'Number (0-9)',
                isMet: _hasNumber(password),
              ),
              _RequirementRow(
                label: 'Special character (!@#\$%...)',
                isMet: _hasSpecialChar(password),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget para cada linha de requisito
class _RequirementRow extends StatelessWidget {
  final String label;
  final bool isMet;

  const _RequirementRow({
    required this.label,
    required this.isMet,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
