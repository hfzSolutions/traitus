import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Service to manage OneSignal push notifications
class NotificationService {
  static bool _initialized = false;

  /// Initialize OneSignal with app ID from environment
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('NotificationService: Already initialized');
      return;
    }

    try {
      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      
      if (appId == null || appId.isEmpty) {
        debugPrint('NotificationService: ONESIGNAL_APP_ID not found in .env');
        return;
      }

      debugPrint('NotificationService: Initializing OneSignal...');

      // Initialize OneSignal
      OneSignal.initialize(appId);

      // Request notification permission
      // This will show the native permission dialog on iOS
      OneSignal.Notifications.requestPermission(true);

      // Optional: Set up notification click handlers
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('NotificationService: Notification clicked');
        debugPrint('Data: ${event.notification.additionalData}');
        
        // TODO: Handle notification click (e.g., navigate to specific chat)
        // You can access notification data like:
        // - event.notification.title
        // - event.notification.body
        // - event.notification.additionalData (custom data)
      });

      // Optional: Set up notification received handler (when app is in foreground)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('NotificationService: Notification received in foreground');
        debugPrint('Title: ${event.notification.title}');
        debugPrint('Body: ${event.notification.body}');
        
        // You can prevent the notification from displaying:
        // event.preventDefault();
        
        // Or modify it before displaying:
        // event.notification.display();
      });

      _initialized = true;
      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Error initializing: $e');
    }
  }

  /// Get the current OneSignal user ID (for targeting specific users)
  static Future<String?> getUserId() async {
    try {
      final userId = OneSignal.User.pushSubscription.id;
      debugPrint('NotificationService: User ID: $userId');
      return userId;
    } catch (e) {
      debugPrint('NotificationService: Error getting user ID: $e');
      return null;
    }
  }

  /// Set external user ID (e.g., your Supabase user ID)
  /// This allows you to send notifications to specific users by their ID
  static Future<void> setExternalUserId(String userId) async {
    try {
      OneSignal.login(userId);
      debugPrint('NotificationService: Set external user ID: $userId');
    } catch (e) {
      debugPrint('NotificationService: Error setting external user ID: $e');
    }
  }

  /// Clear external user ID on logout
  static Future<void> clearExternalUserId() async {
    try {
      OneSignal.logout();
      debugPrint('NotificationService: Cleared external user ID');
    } catch (e) {
      debugPrint('NotificationService: Error clearing external user ID: $e');
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      final permission = await OneSignal.Notifications.permission;
      return permission;
    } catch (e) {
      debugPrint('NotificationService: Error checking permission: $e');
      return false;
    }
  }

  /// Prompt user for notification permission
  static Future<bool> requestPermission() async {
    try {
      final accepted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('NotificationService: Permission accepted: $accepted');
      return accepted;
    } catch (e) {
      debugPrint('NotificationService: Error requesting permission: $e');
      return false;
    }
  }

  /// Add tags for user segmentation (optional)
  /// Example: sendTag('user_type', 'premium')
  static Future<void> sendTag(String key, String value) async {
    try {
      OneSignal.User.addTagWithKey(key, value);
      debugPrint('NotificationService: Added tag: $key = $value');
    } catch (e) {
      debugPrint('NotificationService: Error adding tag: $e');
    }
  }

  /// Remove a tag
  static Future<void> removeTag(String key) async {
    try {
      OneSignal.User.removeTag(key);
      debugPrint('NotificationService: Removed tag: $key');
    } catch (e) {
      debugPrint('NotificationService: Error removing tag: $e');
    }
  }
}

