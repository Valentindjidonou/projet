import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Gère l'état de connexion de l'utilisateur. Toute l'app écoute ce
/// provider pour savoir si elle doit afficher l'écran de connexion
/// ou l'écran principal des notes.
class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (username.trim().isEmpty || password.isEmpty) {
      _errorMessage = "Veuillez renseigner votre nom d'utilisateur et votre mot de passe.";
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final user = await DatabaseHelper.instance.authenticate(username.trim(), password);
      _isLoading = false;
      if (user == null) {
        _errorMessage = "Nom d'utilisateur ou mot de passe incorrect.";
        notifyListeners();
        return false;
      }
      _currentUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Une erreur est survenue lors de la connexion. Veuillez réessayer.";
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String password, String confirmPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (username.trim().length < 3) {
      _errorMessage = "Le nom d'utilisateur doit contenir au moins 3 caractères.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      _errorMessage = "Le mot de passe doit contenir au moins 6 caractères.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
    if (password != confirmPassword) {
      _errorMessage = "Les mots de passe ne correspondent pas.";
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final existing = await DatabaseHelper.instance.getUserByUsername(username.trim());
      if (existing != null) {
        _errorMessage = "Ce nom d'utilisateur est déjà utilisé.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final user = await DatabaseHelper.instance.createUser(username.trim(), password);
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Impossible de créer le compte. Veuillez réessayer.";
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
