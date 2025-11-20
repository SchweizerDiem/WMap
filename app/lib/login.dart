import 'package:flutter/material.dart';
import 'session_manager.dart';
import 'user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? errorMessage;

  void _login() {
    final emailOrUsername = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (emailOrUsername.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter username/email and password';
      });
      return;
    }

    // Try to login with session data
    final sessionManager = SessionManager();
    if (sessionManager.login(emailOrUsername, password)) {
      // Get the logged-in user and update the global notifier
      final user = sessionManager.getCurrentUser();
      if (user != null) {
        userNameNotifier.value = user.name;
      }
      // Navigate to home
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        errorMessage = 'Invalid username/email or password';
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
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
              // tom de verde até azul; ajuste os hex se preferir outros tons
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to WMap',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: Color(0xFF1C1C1C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign In to continue',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.normal,
                      fontSize: 18,
                      color: Color(0xFF1C1C1C),
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 26),
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
                    height: 49,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B62FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Center(
                    child: Text(
                      'Forgot Password?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF87879D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF87879D),
                      ),
                      child: const Text(
                        "Don't have an account? Sign Up",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF87879D),
                        ),
                      ),
                    ),
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
