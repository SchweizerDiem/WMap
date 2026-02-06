import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Necessário para persistir a preferência de login
import '../session_manager.dart';
import '../user.dart';
import '../profile_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para capturar o texto dos campos de input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Variáveis de estado para controlar a UI
  bool _isLoading = false;       // Controla o spinner de carregamento no botão
  bool _obscurePassword = true;  // Alterna a visibilidade da palavra-passe
  bool _rememberMe = false;      // Estado da checkbox "Lembrar-me"
  String? errorMessage;          // Armazena mensagens de erro para o utilizador

  /// Lógica principal de autenticação
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validação básica local antes de chamar o servidor/Firebase
    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);
    errorMessage = null;

    final sessionManager = SessionManager();
    // Tenta efetuar o login através do SessionManager
    final success = await sessionManager.login(email, password);

    if (mounted) {
      if (success) {
        // --- LÓGICA DO REMEMBER ME ---
        // Se o login for bem-sucedido, guarda a preferência do utilizador localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', _rememberMe);
        
        // Atualiza os dados globais da sessão (Nome no Notifier e Imagem de Perfil)
        final user = sessionManager.getCurrentUser();
        if (user != null) {
          userNameNotifier.value = user.name;
          await ProfileManager().loadProfileImage();
        }
        
        setState(() => _isLoading = false);
        // Navega para a Home e remove a página de login da pilha (pushReplacement)
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Caso o login falhe, mostra erro e para o carregamento
        setState(() {
          _isLoading = false;
          errorMessage = 'Invalid email or password';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fundo com gradiente cobrindo todo o ecrã
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
            padding: const EdgeInsets.symmetric(horizontal: 30),
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
                  const Text(
                    "Welcome Back",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xff4841a8)),
                  ),
                  const SizedBox(height: 8),
                  const Text("Log in to your account", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  
                  // Campo de Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de Password com botão para mostrar/esconder
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  
                  const SizedBox(height: 10),

                  // Secção do "Remember Me"
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: const Color(0xff6c63ff),
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Remember me",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                  
                  // Exibição condicional da mensagem de erro
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],

                  const SizedBox(height: 20),
                  
                  // Botão de Login (Muda para loading se _isLoading for true)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff6c63ff),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text('LOGIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Link para navegar para o Registo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/register'),
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(color: Color(0xff6c63ff), fontWeight: FontWeight.bold),
                        ),
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