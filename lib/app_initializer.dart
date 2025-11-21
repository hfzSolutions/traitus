import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:traitus/services/app_config_service.dart';
import 'package:traitus/services/notification_service.dart';
import 'package:traitus/services/supabase_service.dart';

/// Handles heavy, synchronous startup work before the main UI appears.
/// By centralizing initialization we can kick it off before runApp while
/// still showing a Flutter-rendered splash right away.
/// 
/// Now optimized to be non-blocking: shows UI immediately and loads in background.
class AppInitializer {
  AppInitializer._();

  static Future<void>? _initialization;
  static bool _isInitialized = false;

  /// Starts initialization - waits for critical parts, then continues in background
  /// Critical initialization (env + Supabase) must complete before UI shows
  /// Non-critical initialization continues in background
  static Future<void> initialize() async {
    // Critical initialization - must complete before UI shows
    // This is fast (just loading env and initializing Supabase)
    try {
      await dotenv.load(fileName: '.env');
      await SupabaseService.getInstance();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Critical initialization error: $e');
      // Still allow app to start - will fail gracefully later
      _isInitialized = true; // Set to true anyway to prevent infinite waiting
    }

    // Start background initialization (non-blocking)
    // Don't await - let it run in background while UI shows
    _initialization ??= _runBackgroundInitialization();
  }

  /// Check if critical initialization is done (env + Supabase)
  static bool get isInitialized => _isInitialized;

  /// Background initialization - runs after UI is shown
  static Future<void> _runBackgroundInitialization() async {
    try {
      // Run remaining non-critical work in parallel
      await Future.wait([
        _initializeAppConfig(),
        NotificationService.initialize(),
      ]);
      debugPrint('AppInitializer: Background initialization complete');
    } catch (e) {
      debugPrint('AppInitializer: Background initialization error: $e');
      // Non-critical, app continues
    }
  }

  static Future<void> _initializeAppConfig() async {
    try {
      await AppConfigService.instance.initialize();
    } catch (e, stackTrace) {
      debugPrint('Warning: Failed to initialize app config: $e');
      debugPrint('$stackTrace');
      // Allow the app to continue; model usage will surface failures later.
    }
  }
}

