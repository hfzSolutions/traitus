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
  bool _isInitializing = true; // Track initial profile load
  String? _error;

  AuthProvider(this._supabaseService) {
    _user = _supabaseService.currentUser;
    _listenToAuthChanges();
    if (_user != null) {
      _loadUserProfile();
    } else {
      _isInitializing = false; // No user, no need to load profile
    }
  }

  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing; // Expose initializing state
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
    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      _isInitializing = false; // Always set to false when done
      notifyListeners();
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

  Future<void> completeOnboarding({
    required String displayName,
    DateTime? dateOfBirth,
    String? preferredLanguage,
    String? avatarUrl,
    String? experienceLevel,
    String? useContext,
    required List<String> preferences,
    required List<String> selectedChatIds,
    List<Map<String, dynamic>>? selectedChatDefinitions,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _databaseService.completeOnboarding(
        displayName: displayName,
        dateOfBirth: dateOfBirth,
        preferredLanguage: preferredLanguage,
        avatarUrl: avatarUrl,
        experienceLevel: experienceLevel,
        useContext: useContext,
        preferences: preferences,
        selectedChatIds: selectedChatIds,
        selectedChatDefinitions: selectedChatDefinitions,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get needsOnboarding {
    return _user != null && 
           (_userProfile == null || !_userProfile!.onboardingCompleted);
  }

  /// Mark onboarding as not completed so the app routes to onboarding again
  Future<void> redoOnboarding() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _databaseService.resetOnboarding();
      await _loadUserProfile();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
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

