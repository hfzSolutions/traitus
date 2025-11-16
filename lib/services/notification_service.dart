import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:app_settings/app_settings.dart';
import 'package:traitus/ui/widgets/haptic_modal.dart';

/// Service to manage OneSignal push notifications
class NotificationService {
  static bool _initialized = false;
  
  /// Callback function to handle navigation when a notification is clicked
  /// Set this from your app to handle deep linking to chats
  static Function(String chatId)? onNotificationChatTap;

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
      final permissionGranted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('NotificationService: Permission granted: $permissionGranted');

      // Get and log user ID for verification
      try {
        // Wait a bit for subscription to complete
        await Future.delayed(const Duration(seconds: 1));
        final userId = OneSignal.User.pushSubscription.id;
        debugPrint('NotificationService: OneSignal User ID: $userId');
        
        // Log subscription status
        final isSubscribed = OneSignal.User.pushSubscription.optedIn;
        final status = isSubscribed == true ? "Subscribed" : "Not subscribed";
        debugPrint('NotificationService: Subscription status: $status');
      } catch (e) {
        debugPrint('NotificationService: Could not get user ID yet: $e');
      }

      // Set up notification click handlers for deep linking
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('NotificationService: Notification clicked');
        debugPrint('Title: ${event.notification.title}');
        debugPrint('Body: ${event.notification.body}');
        debugPrint('Data: ${event.notification.additionalData}');
        
        // Handle deep linking to chat if chat_id is present
        final additionalData = event.notification.additionalData;
        if (additionalData != null) {
          final type = additionalData['type'] as String?;
          final chatId = additionalData['chat_id'] as String?;
          
          if (type == 're_engagement' && chatId != null) {
            debugPrint('NotificationService: Opening chat $chatId from re-engagement notification');
            // Call the navigation callback if set
            if (onNotificationChatTap != null) {
              onNotificationChatTap!(chatId);
            } else {
              debugPrint('NotificationService: Warning - onNotificationChatTap callback not set. Cannot navigate to chat.');
            }
          }
        }
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
      debugPrint('NotificationService: ✅ Ready to receive notifications!');
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

  /// Show a dialog to enable notifications in settings
  /// Uses common practice wording that matches popular apps
  static Future<void> showEnableNotificationsDialog(BuildContext context) async {
    final theme = Theme.of(context);
    
    await HapticModal.showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.notifications_off_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Notifications Disabled'),
        content: const Text(
          'To receive notifications, please enable them in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show a dialog to enable microphone permission in settings
  /// Uses common practice wording that matches popular apps
  static Future<void> showEnableMicrophoneDialog(BuildContext context) async {
    final theme = Theme.of(context);
    
    await HapticModal.showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.mic_off_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Microphone Access Disabled'),
        content: const Text(
          'To use voice input, please enable microphone access in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show a dialog to enable camera permission in settings
  /// Uses common practice wording that matches popular apps
  static Future<void> showEnableCameraDialog(BuildContext context) async {
    final theme = Theme.of(context);
    
    await HapticModal.showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.camera_alt_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Camera Access Disabled'),
        content: const Text(
          'To take photos, please enable camera access in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show a dialog to enable photo library permission in settings
  /// Uses common practice wording that matches popular apps
  static Future<void> showEnablePhotoLibraryDialog(BuildContext context) async {
    final theme = Theme.of(context);
    
    await HapticModal.showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.photo_library_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Photo Library Access Disabled'),
        content: const Text(
          'To select photos, please enable photo library access in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

