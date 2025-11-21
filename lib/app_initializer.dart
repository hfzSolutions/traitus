import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:traitus/services/app_config_service.dart';
import 'package:traitus/services/notification_service.dart';
import 'package:traitus/services/supabase_service.dart';

/// Handles heavy, synchronous startup work before the main UI appears.
/// By centralizing initialization we can kick it off before runApp while
/// still showing a Flutter-rendered splash right away.
class AppInitializer {
  AppInitializer._();

  static Future<void>? _initialization;

  /// Starts initialization once and reuses the same future for hot restarts.
  static Future<void> initialize() {
    _initialization ??= _runInitialization();
    return _initialization!;
  }

  static Future<void> _runInitialization() async {
    await dotenv.load(fileName: '.env');
    await SupabaseService.getInstance();

    // Run remaining non-critical work in parallel so we unblock the UI asap.
    await Future.wait([
      _initializeAppConfig(),
      NotificationService.initialize(),
    ]);
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

