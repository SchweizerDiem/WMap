import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// User account data model
class UserAccount {
  final String name;
  final String username;
  final String email;
  final String password;
  final Set<String> visitedCountries;
  final Set<String> plannedCountries;

  UserAccount({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    Set<String>? visitedCountries,
    Set<String>? plannedCountries,
  }) : visitedCountries = visitedCountries ?? <String>{},
       plannedCountries = plannedCountries ?? <String>{};

  UserAccount copyWith({String? name, Set<String>? visitedCountries, Set<String>? plannedCountries}) {
    return UserAccount(
      name: name ?? this.name,
      username: username,
      email: email,
      password: password,
      visitedCountries: visitedCountries ?? Set<String>.from(this.visitedCountries),
      plannedCountries: plannedCountries ?? Set<String>.from(this.plannedCountries),
    );
  }

  @override
  String toString() => 'UserAccount(name: $name, username: $username, email: $email)';
}

/// Singleton session manager to store user accounts in memory
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();

  final List<UserAccount> _accounts = [];
  UserAccount? _currentUser;
  // Notifier for the current user's visited count so UI can listen
  final ValueNotifier<int> visitedCountNotifier = ValueNotifier<int>(0);
  // Notifier for the current user's planned (future trip) count
  final ValueNotifier<int> plannedCountNotifier = ValueNotifier<int>(0);

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
    // Do not automatically set as current user here; login will set current user.
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
      // Update notifier for visited count
      visitedCountNotifier.value = _currentUser?.visitedCountries.length ?? 0;
  // Update notifier for planned count
  plannedCountNotifier.value = _currentUser?.plannedCountries.length ?? 0;
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
      _currentUser = _currentUser!.copyWith(name: newName);
      // Replace account in list as well
      for (int i = 0; i < _accounts.length; i++) {
        if (_accounts[i].email == _currentUser!.email) {
          _accounts[i] = _currentUser!;
          break;
        }
      }
    }
  }

  /// Delete the current user account
  bool deleteCurrentUser() {
    if (_currentUser != null) {
      final removed = _accounts.remove(_currentUser);
      if (removed) {
        _currentUser = null;
        visitedCountNotifier.value = 0;
        plannedCountNotifier.value = 0;
      }
      return removed;
    }
    return false;
  }

  /// Mark a country as visited for the current user
  bool markCountryVisitedForCurrentUser(String countryCode) {
    if (_currentUser == null) return false;
    final already = _currentUser!.visitedCountries.contains(countryCode);
    if (already) return false;
    // Add to visited and remove from planned if present
    final newVisited = Set<String>.from(_currentUser!.visitedCountries)..add(countryCode);
    final newPlanned = Set<String>.from(_currentUser!.plannedCountries)..remove(countryCode);
    _currentUser = _currentUser!.copyWith(visitedCountries: newVisited, plannedCountries: newPlanned);
    // update stored account
    for (int i = 0; i < _accounts.length; i++) {
      if (_accounts[i].email == _currentUser!.email) {
        _accounts[i] = _currentUser!;
        break;
      }
    }
    visitedCountNotifier.value = _currentUser!.visitedCountries.length;
    plannedCountNotifier.value = _currentUser!.plannedCountries.length;
    return true;
  }

  /// Toggle visited state for the current user. Returns true if now visited.
  bool toggleVisitedForCurrentUser(String countryCode) {
    if (_currentUser == null) return false;
    final currentSet = Set<String>.from(_currentUser!.visitedCountries);
    if (currentSet.contains(countryCode)) {
      currentSet.remove(countryCode);
      _currentUser = _currentUser!.copyWith(visitedCountries: currentSet);
      for (int i = 0; i < _accounts.length; i++) {
        if (_accounts[i].email == _currentUser!.email) {
          _accounts[i] = _currentUser!;
          break;
        }
      }
      visitedCountNotifier.value = _currentUser!.visitedCountries.length;
      plannedCountNotifier.value = _currentUser!.plannedCountries.length;
      return false;
    } else {
      currentSet.add(countryCode);
      // When marking visited, remove from planned if present
      final newPlanned = Set<String>.from(_currentUser!.plannedCountries)..remove(countryCode);
      _currentUser = _currentUser!.copyWith(visitedCountries: currentSet, plannedCountries: newPlanned);
      for (int i = 0; i < _accounts.length; i++) {
        if (_accounts[i].email == _currentUser!.email) {
          _accounts[i] = _currentUser!;
          break;
        }
      }
      visitedCountNotifier.value = _currentUser!.visitedCountries.length;
      plannedCountNotifier.value = _currentUser!.plannedCountries.length;
      return true;
    }
  }

  /// Toggle planned (future trip) state for the current user. Returns true if now planned.
  bool togglePlannedForCurrentUser(String countryCode) {
    if (_currentUser == null) return false;
    final currentSet = Set<String>.from(_currentUser!.plannedCountries);
    if (currentSet.contains(countryCode)) {
      currentSet.remove(countryCode);
      _currentUser = _currentUser!.copyWith(plannedCountries: currentSet);
      for (int i = 0; i < _accounts.length; i++) {
        if (_accounts[i].email == _currentUser!.email) {
          _accounts[i] = _currentUser!;
          break;
        }
      }
      plannedCountNotifier.value = _currentUser!.plannedCountries.length;
      return false;
    } else {
      // Do not add to planned if already visited
      if (_currentUser!.visitedCountries.contains(countryCode)) return false;
      currentSet.add(countryCode);
      _currentUser = _currentUser!.copyWith(plannedCountries: currentSet);
      for (int i = 0; i < _accounts.length; i++) {
        if (_accounts[i].email == _currentUser!.email) {
          _accounts[i] = _currentUser!;
          break;
        }
      }
      plannedCountNotifier.value = _currentUser!.plannedCountries.length;
      return true;
    }
  }

  bool isCountryVisitedForCurrentUser(String countryCode) {
    if (_currentUser == null) return false;
    return _currentUser!.visitedCountries.contains(countryCode);
  }

  bool isCountryPlannedForCurrentUser(String countryCode) {
    if (_currentUser == null) return false;
    return _currentUser!.plannedCountries.contains(countryCode);
  }

  int getVisitedCountForCurrentUser() => _currentUser?.visitedCountries.length ?? 0;

  List<String> getVisitedCountriesForCurrentUser() => List.unmodifiable(_currentUser?.visitedCountries ?? <String>[]);
  List<String> getPlannedCountriesForCurrentUser() => List.unmodifiable(_currentUser?.plannedCountries ?? <String>[]);
}
