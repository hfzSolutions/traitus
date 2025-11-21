import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traitus/models/user_profile.dart';
import 'package:traitus/services/database_service.dart';
import 'package:traitus/services/supabase_service.dart';
import 'package:traitus/services/notification_service.dart';
import 'package:traitus/services/chat_cache_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final DatabaseService _databaseService = DatabaseService();
  User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  bool _isEmailSignInLoading = false;
  bool _isGoogleSignInLoading = false;
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
  bool get isEmailSignInLoading => _isEmailSignInLoading;
  bool get isGoogleSignInLoading => _isGoogleSignInLoading;
  bool get isInitializing => _isInitializing; // Expose initializing state
  String? get error => _error;

  void _listenToAuthChanges() {
    _supabaseService.authStateChanges.listen((AuthState state) {
      _user = state.session?.user;
      if (_user != null) {
        _loadUserProfile();
        // Link OneSignal to user ID for targeted notifications
        NotificationService.setExternalUserId(_user!.id);
      } else {
        _userProfile = null;
        // Clear OneSignal external user ID on logout
        NotificationService.clearExternalUserId();
        // Clear chat cache on logout
        ChatCacheService.clearCache();
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      _userProfile = await _databaseService.fetchUserProfile();
      
      // Fallback: If profile doesn't exist, try to create it
      // This handles cases where the database trigger failed
      if (_userProfile == null && _user != null) {
        debugPrint('User profile missing, creating fallback profile...');
        await _databaseService.ensureUserProfileExists();
        _userProfile = await _databaseService.fetchUserProfile();
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
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
    String? username,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );
      
      // If signup successful and user is authenticated, ensure profile exists
      if (response.user != null) {
        _user = response.user;
        
        // Give the database trigger a moment to create the profile
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Ensure profile exists (fallback if trigger failed)
        try {
          await _databaseService.ensureUserProfileExists();
          await _loadUserProfile();
        } catch (profileError) {
          debugPrint('Error ensuring profile exists: $profileError');
          // Continue even if profile creation fails
        }
        
        // Sign out after ensuring profile exists
        // This forces users to verify email and sign in explicitly
        await _supabaseService.signOut();
        _user = null;
        _userProfile = null;
      }
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
    _isEmailSignInLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );
      _user = response.user;
      // Link OneSignal to user ID for targeted notifications
      await NotificationService.setExternalUserId(_user!.id);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isEmailSignInLoading = false;
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
      // Clear OneSignal external user ID on logout
      await NotificationService.clearExternalUserId();
      // Clear chat cache on logout
      await ChatCacheService.clearCache();
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
    if (_user == null) {
      return false;
    }
    if (_isInitializing) {
      return false;
    }
    if (_userProfile == null) {
      return true;
    }
    return !_userProfile!.onboardingCompleted;
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

  Future<void> resendVerificationEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.resendVerificationEmail(email);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isGoogleSignInLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.signInWithGoogle();
      // Note: The actual authentication happens via OAuth callback
      // The auth state will be updated via _listenToAuthChanges
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isGoogleSignInLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Delete the user's account permanently
  Future<void> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Call the delete-account edge function
      await _supabaseService.deleteAccount();
      
      // Clear local state
      _user = null;
      _userProfile = null;
      
      // Clear OneSignal external user ID
      await NotificationService.clearExternalUserId();
      // Clear chat cache on account deletion
      await ChatCacheService.clearCache();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

