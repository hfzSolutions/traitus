import 'package:flutter/foundation.dart';
import 'package:traitus/services/supabase_service.dart';
import 'package:traitus/app_initializer.dart';

/// Service to track user activity for re-engagement purposes
class ActivityService {
  static final ActivityService _instance = ActivityService._internal();
  factory ActivityService() => _instance;
  ActivityService._internal();

  /// Check if Supabase is initialized and ready to use
  bool _isSupabaseReady() {
    // First check if AppInitializer says it's initialized
    if (!AppInitializer.isInitialized) {
      return false;
    }
    
    try {
      // Try to access Supabase - if it throws, it's not initialized
      final _ = SupabaseService.client;
      return true;
    } catch (e) {
      // Supabase not initialized yet
      return false;
    }
  }

  /// Update the last app activity timestamp for the current user
  /// This should be called when:
  /// - App comes to foreground
  /// - User sends a message
  /// - User performs any significant interaction
  Future<void> updateLastActivity() async {
    try {
      // Check if Supabase is initialized before using it
      if (!_isSupabaseReady()) {
        debugPrint('ActivityService: Supabase not initialized yet, skipping activity update');
        return;
      }

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('ActivityService: No user logged in, skipping activity update');
        return;
      }

      final now = DateTime.now().toIso8601String();
      await SupabaseService.client
          .from('user_profiles')
          .update({'last_app_activity': now})
          .eq('id', userId);

      debugPrint('ActivityService: Updated last_app_activity for user $userId');
    } catch (e) {
      debugPrint('ActivityService: Error updating last activity: $e');
      // Don't throw - activity tracking should not break the app
    }
  }

  /// Get the number of days since the user's last activity
  /// Returns null if user is not logged in or activity data is not available
  Future<int?> getDaysSinceLastActivity() async {
    try {
      // Check if Supabase is initialized before using it
      if (!_isSupabaseReady()) {
        return null;
      }

      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await SupabaseService.client
          .from('user_profiles')
          .select('last_app_activity')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      final lastActivityStr = response['last_app_activity'] as String?;
      if (lastActivityStr == null) return null;

      final lastActivity = DateTime.parse(lastActivityStr);
      final now = DateTime.now();
      final difference = now.difference(lastActivity);

      return difference.inDays;
    } catch (e) {
      debugPrint('ActivityService: Error getting days since last activity: $e');
      return null;
    }
  }

  /// Check if user has been inactive for a specified number of days
  Future<bool> isInactiveForDays(int days) async {
    final daysSince = await getDaysSinceLastActivity();
    if (daysSince == null) return false;
    return daysSince >= days;
  }
}

