import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Import necessário para renderizar ícones e ilustrações em formato SVG

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // SafeArea evita que o conteúdo fique por baixo da barra de estado ou "notch" do telemóvel
      body: SafeArea(
        child: Column(
          children: [
            // --- LOGOTIPO ---
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 30),
              child: Align(
                alignment: Alignment.topLeft,
                child: SvgPicture.asset(
                  "assets/images/logo.svg",
                  width: 70,
                ),
              ),
            ),
            const SizedBox(height: 43),
            
            // --- ILUSTRAÇÃO PRINCIPAL ---
            Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 30),
              child: Align(
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  "assets/images/nature.svg",
                  width: 300,
                ),
              ),
            ),
            
            // --- TÍTULOS (Slogan) ---
            const Text(
              "Never forget where",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const Text(
              "you've been!",
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            
            // --- SUBTÍTULO / DESCRIÇÃO ---
            const Text(
              "Your global journey, instantly recallable. \nPin it, picture it, preserve it",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            
            // --- BOTÃO DE ENTRADA (Call to Action) ---
            GestureDetector(
              onTap: () {
                // Navegação para a rota de login definida no MaterialApp
                Navigator.pushNamed(context, '/login');
              },
              child: Container(
                height: 55,
                width: 200,
                decoration: BoxDecoration(
                 color: const Color(0xffff6363), // Fundo avermelhado/coral
                 borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Spacer(flex: 2), // Empurra o texto para uma posição centralizada
                      Text(
                        "Check out",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(), // Espaço entre o texto e o ícone
                      // Ícone de seta dentro de um círculo para dar um aspeto moderno
                      CircleAvatar(
                        backgroundColor: Color(0xff6c63ff), // Círculo roxo
                        child: Icon(Icons.arrow_forward, color: Colors.white),
                      )
                    ],
                  ),
                ),
              )
            )
          ],
        ),
      ),
    );
  }
}