import 'package:flutter/foundation.dart';

// Notificador global para o nome de exibição do utilizador.
// Atualizado automaticamente após o login/registo via Firebase.
final ValueNotifier<String> userNameNotifier = ValueNotifier<String>('Guest');