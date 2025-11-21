import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traitus/models/ai_chat.dart';

/// Service for caching chat list locally to enable instant app startup
/// Similar to how Telegram/WhatsApp show cached data immediately
class ChatCacheService {
  static const String _cacheKey = 'cached_chats_list';
  static const String _cacheTimestampKey = 'cached_chats_timestamp';
  static const Duration _cacheMaxAge = Duration(hours: 24); // Cache valid for 24 hours

  /// Save chats to local cache
  static Future<void> saveChats(List<AiChat> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert chats to JSON
      final chatsJson = chats.map((chat) => chat.toJson()).toList();
      final jsonString = jsonEncode(chatsJson);
      
      // Save to cache
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('ChatCacheService: Saved ${chats.length} chats to cache');
    } catch (e) {
      debugPrint('ChatCacheService: Error saving cache: $e');
      // Non-critical, continue anyway
    }
  }

  /// Load chats from local cache
  /// Returns null if cache doesn't exist or is expired
  static Future<List<AiChat>?> loadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache exists
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString == null) {
        debugPrint('ChatCacheService: No cache found');
        return null;
      }
      
      // Check cache age
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp != null) {
        final cacheAge = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(timestamp),
        );
        if (cacheAge > _cacheMaxAge) {
          debugPrint('ChatCacheService: Cache expired (age: ${cacheAge.inHours}h)');
          // Clear expired cache
          await clearCache();
          return null;
        }
      }
      
      // Parse JSON
      final List<dynamic> chatsJson = jsonDecode(jsonString);
      final chats = chatsJson
          .map((json) => AiChat.fromJson(json as Map<String, dynamic>))
          .toList();
      
      debugPrint('ChatCacheService: Loaded ${chats.length} chats from cache');
      return chats;
    } catch (e) {
      debugPrint('ChatCacheService: Error loading cache: $e');
      // Clear corrupted cache
      await clearCache();
      return null;
    }
  }

  /// Clear the cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      debugPrint('ChatCacheService: Cache cleared');
    } catch (e) {
      debugPrint('ChatCacheService: Error clearing cache: $e');
    }
  }

  /// Check if cache exists and is valid
  static Future<bool> hasValidCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString == null) return false;
      
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return false;
      
      final cacheAge = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
      return cacheAge <= _cacheMaxAge;
    } catch (e) {
      return false;
    }
  }
}

