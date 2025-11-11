/// User account data model
class UserAccount {
  final String name;
  final String username;
  final String email;
  final String password;

  UserAccount({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
  });

  @override
  String toString() => 'UserAccount(name: $name, username: $username, email: $email)';
}

/// Singleton session manager to store user accounts in memory
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();

  final List<UserAccount> _accounts = [];
  UserAccount? _currentUser;

  SessionManager._internal();

  factory SessionManager() {
    return _instance;
  }

  /// Register a new account and save it to the session
  bool registerAccount(String name, String username, String email, String password) {
    // Check if email or username already exists
    if (_accounts.any((account) => account.email == email)) {
      return false; // Email already registered
    }
    if (_accounts.any((account) => account.username == username)) {
      return false; // Username already taken
    }

    // Add new account
    final newAccount = UserAccount(
      name: name,
      username: username,
      email: email,
      password: password,
    );
    _accounts.add(newAccount);
    return true;
  }

  /// Validate login credentials
  bool login(String emailOrUsername, String password) {
    try {
      final account = _accounts.firstWhere(
        (account) =>
            (account.email == emailOrUsername || account.username == emailOrUsername) &&
            account.password == password,
      );
      _currentUser = account;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Logout the current user
  void logout() {
    _currentUser = null;
  }

  /// Get the current logged-in user
  UserAccount? getCurrentUser() => _currentUser;

  /// Get all registered accounts (for debugging)
  List<UserAccount> getAllAccounts() => List.unmodifiable(_accounts);

  /// Update user name in the current session
  void updateCurrentUserName(String newName) {
    if (_currentUser != null) {
      _currentUser = UserAccount(
        name: newName,
        username: _currentUser!.username,
        email: _currentUser!.email,
        password: _currentUser!.password,
      );
    }
  }

  /// Delete the current user account
  bool deleteCurrentUser() {
    if (_currentUser != null) {
      final removed = _accounts.remove(_currentUser);
      if (removed) {
        _currentUser = null;
      }
      return removed;
    }
    return false;
  }
}
