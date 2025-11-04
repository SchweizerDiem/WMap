import 'package:flutter/foundation.dart';

// A simple global notifier for the user's display name.
// Other parts of the app can listen to this to update UI when the name changes.
final ValueNotifier<String> userNameNotifier = ValueNotifier<String>('Guest');
