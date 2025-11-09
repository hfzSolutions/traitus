import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_storage;
import 'package:traitus/services/supabase_service.dart';

class StorageService {
  static const String _chatAvatarsBucket = 'chat-avatars';
  static const String _userAvatarsBucket = 'user-avatars';
  static const String _chatImagesBucket = 'chat-images';
  final _client = SupabaseService.client;

  /// Upload an avatar image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadAvatar(String filePath, String chatId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final file = File(filePath);
    final fileExt = filePath.split('.').last;
    final fileName = '$userId/$chatId.$fileExt';

    try {
      // Upload the file
      await _client.storage.from(_chatAvatarsBucket).upload(
            fileName,
            file,
            fileOptions: const supabase_storage.FileOptions(
              cacheControl: '3600',
              upsert: true, // Replace if exists
            ),
          );

      // Get the public URL with cache-busting timestamp
      final publicUrl = _client.storage.from(_chatAvatarsBucket).getPublicUrl(fileName);
      
      // Add timestamp to bust cache when image is updated
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urlWithTimestamp = '$publicUrl?t=$timestamp';

      return urlWithTimestamp;
    } catch (e) {
      throw Exception('Failed to upload avatar: $e');
    }
  }

  /// Delete an avatar from storage
  Future<void> deleteAvatar(String avatarUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(avatarUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the bucket name and file path
      int bucketIndex = pathSegments.indexOf(_chatAvatarsBucket);
      String bucketName = _chatAvatarsBucket;
      
      if (bucketIndex == -1) {
        bucketIndex = pathSegments.indexOf(_userAvatarsBucket);
        bucketName = _userAvatarsBucket;
      }
      
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        throw Exception('Invalid avatar URL');
      }
      
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      
      await _client.storage.from(bucketName).remove([filePath]);
    } catch (e) {
      // Silently fail - the file might already be deleted
      debugPrint('Failed to delete avatar: $e');
    }
  }

  /// Update avatar - deletes old one and uploads new one
  Future<String> updateAvatar(
    String filePath,
    String chatId,
    String? oldAvatarUrl,
  ) async {
    // Delete old avatar if exists
    if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
      await deleteAvatar(oldAvatarUrl);
    }

    // Upload new avatar
    return await uploadAvatar(filePath, chatId);
  }

  /// Upload a user profile picture to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadUserAvatar(String filePath) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final file = File(filePath);
    final fileExt = filePath.split('.').last;
    final fileName = '$userId/profile.$fileExt';

    try {
      // Upload the file
      await _client.storage.from(_userAvatarsBucket).upload(
            fileName,
            file,
            fileOptions: const supabase_storage.FileOptions(
              cacheControl: '3600',
              upsert: true, // Replace if exists
            ),
          );

      // Get the public URL with cache-busting timestamp
      final publicUrl = _client.storage.from(_userAvatarsBucket).getPublicUrl(fileName);
      
      // Add timestamp to bust cache when image is updated
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urlWithTimestamp = '$publicUrl?t=$timestamp';

      return urlWithTimestamp;
    } catch (e) {
      throw Exception('Failed to upload user avatar: $e');
    }
  }

  /// Update user profile picture - deletes old one and uploads new one
  Future<String> updateUserAvatar(
    String filePath,
    String? oldAvatarUrl,
  ) async {
    // Delete old avatar if exists
    if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
      await deleteAvatar(oldAvatarUrl);
    }

    // Upload new avatar
    return await uploadUserAvatar(filePath);
  }

  /// Upload a chat image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadChatImage(String filePath, String messageId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final file = File(filePath);
    final fileExt = filePath.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$userId/$messageId-$timestamp.$fileExt';

    try {
      // Upload the file
      await _client.storage.from(_chatImagesBucket).upload(
            fileName,
            file,
            fileOptions: const supabase_storage.FileOptions(
              cacheControl: '3600',
              upsert: false, // Don't replace - each image should be unique
            ),
          );

      // Get the public URL
      final publicUrl = _client.storage.from(_chatImagesBucket).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload chat image: $e');
    }
  }

  /// Delete a chat image from storage
  Future<void> deleteChatImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the bucket name and file path
      final bucketIndex = pathSegments.indexOf(_chatImagesBucket);
      
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        throw Exception('Invalid image URL');
      }
      
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      
      await _client.storage.from(_chatImagesBucket).remove([filePath]);
    } catch (e) {
      // Silently fail - the file might already be deleted
      debugPrint('Failed to delete chat image: $e');
    }
  }
}

