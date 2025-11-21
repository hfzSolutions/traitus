import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseClient get client => Supabase.instance.client;

  SupabaseService._();

  static Future<SupabaseService> getInstance() async {
    if (_instance == null) {
      await _initialize();
      _instance = SupabaseService._();
    }
    return _instance!;
  }

  // Get the current instance (must be called after getInstance)
  static SupabaseService get instance {
    if (_instance == null) {
      throw Exception('SupabaseService not initialized. Call getInstance() first.');
    }
    return _instance!;
  }

  static Future<void> _initialize() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Supabase credentials not found in .env file');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  // Auth helpers
  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => client.auth.currentUser?.id;
  bool get isAuthenticated => client.auth.currentUser != null;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Sign up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Sign in
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  // Resend verification email
  Future<void> resendVerificationEmail(String email) async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.hafiz.traitus://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }
}

