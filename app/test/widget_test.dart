import 'package:flutter_test/flutter_test.dart';
import 'package:WMap/main.dart';
import 'package:WMap/pages/welcome.dart'; // Importa a WelcomePage

void main() {
  testWidgets('Verificar se a Welcome Page carrega corretamente', (WidgetTester tester) async {
    // Agora passamos o initialScreen que o MyApp exige
    await tester.pumpWidget(const MyApp(initialScreen: WelcomePage()));

    // Verifica se existe algum texto que faça parte da tua WelcomePage
    // (Ajusta 'Welcome' para um texto que realmente exista na tua WelcomePage)
    expect(find.textContaining('Welcome'), findsWidgets);
  });
}