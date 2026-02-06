import 'package:flutter/foundation.dart';

// Este é um Notificador Global (ValueNotifier).
// Ele guarda uma String e avisa automaticamente todos os widgets que o estão a "ouvir" 
// sempre que o nome do utilizador muda (por exemplo, de 'Guest' para o nome real após o login).
final ValueNotifier<String> userNameNotifier = ValueNotifier<String>('Guest');