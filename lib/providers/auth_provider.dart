import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traitus/models/user_profile.dart';
import 'package:traitus/services/database_service.dart';
import 'package:traitus/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final DatabaseService _databaseService = DatabaseService();
  User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._supabaseService) {
    _user = _supabaseService.currentUser;
    _listenToAuthChanges();
    if (_user != null) {
      _loadUserProfile();
    }
  }

  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _listenToAuthChanges() {
    _supabaseService.authStateChanges.listen((AuthState state) {
      _user = state.session?.user;
      if (_user != null) {
        _loadUserProfile();
      } else {
        _userProfile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      _userProfile = await _databaseService.fetchUserProfile();
      notifyListeners();
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> refreshUserProfile() async {
    await _loadUserProfile();
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.signUp(
        email: email,
        password: password,
      );
      
      // Important: Sign out immediately after signup
      // This forces users to verify email and sign in explicitly
      await _supabaseService.signOut();
      _user = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );
      _user = response.user;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.signOut();
      _user = null;
      _userProfile = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserAvatar(String avatarUrl) async {
    try {
      await _databaseService.updateUserAvatar(avatarUrl);
      await _loadUserProfile();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.resetPassword(email);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

