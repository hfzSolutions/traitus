import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/models/chat_message.dart';
import 'package:traitus/services/database_service.dart';
import 'package:traitus/services/storage_service.dart';
import 'package:traitus/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traitus/services/models_service.dart';

class ChatsListProvider extends ChangeNotifier {
  ChatsListProvider() {
    _loadChats();
  }

  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  List<AiChat> _chats = [];
  bool _isLoaded = false;
  bool _isLoading = false;
  String? _error;
  String? _activeChatId;
  RealtimeChannel? _messagesChannel;
  final Set<String> _deletingChatIds = {}; // Track chats being deleted
  
  // Message cache: stores preloaded recent messages for each chat
  // Key: chatId, Value: List of recent messages (last 50)
  final Map<String, List<ChatMessage>> _messageCache = {};
  final Map<String, int> _messageCountCache = {}; // Total message count per chat

  List<AiChat> get chats => List.unmodifiable(_chats);
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadChats() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _chats = await _dbService.fetchChats();
      // Populate unread counts concurrently
      await _refreshUnreadCounts();
      // Ensure realtime updates are active
      _ensureRealtimeSubscribed();
      
      // If no chats exist, create a default one
      if (_chats.isEmpty) {
        String? model;
        try {
          final catalog = ModelCatalogService();
          final models = await catalog.listEnabledModels();
          final basic = models.firstWhere((m) => !m.isPremium, orElse: () => models.first);
          model = basic.slug;
        } catch (_) {
          model = dotenv.env['OPENROUTER_MODEL'];
          if (model == null || model.isEmpty) {
            throw StateError('Missing OPENROUTER_MODEL. Add it to a .env file.');
          }
        }
        final defaultChat = AiChat(
          name: 'AI Assistant',
          shortDescription: 'A helpful AI assistant',
          systemPrompt: 'You are a helpful, friendly AI assistant. You provide clear and concise answers. Use markdown for structure when appropriate.',
          model: model,
        );
        await addChat(defaultChat);
      }
      
      _isLoaded = true;
      
      // Preload recent messages for all chats in the background
      // This makes chat opening instant - like WhatsApp/Telegram
      _preloadRecentMessages();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading chats: $e');
      // Start with empty list on error
      _chats = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Preload recent messages (last 50) for all chats in the background
  /// This enables instant chat opening without loading delay
  Future<void> _preloadRecentMessages() async {
    if (_chats.isEmpty) return;
    
    // Preload messages for all chats concurrently, but don't block UI
    // ignore: unawaited_futures
    Future.wait(
      _chats.map((chat) => _preloadChatMessages(chat.id)),
      eagerError: false, // Don't fail all if one fails
    ).then((_) {
      debugPrint('Finished preloading messages for ${_chats.length} chats');
    }).catchError((e) {
      debugPrint('Error during message preload: $e');
      // Non-critical, continue anyway
    });
  }

  /// Preload recent messages for a specific chat
  Future<void> _preloadChatMessages(String chatId) async {
    try {
      // Check if already cached
      if (_messageCache.containsKey(chatId)) return;
      
      // Get total count and recent messages
      final totalCount = await _dbService.getMessageCount(chatId);
      final recentMessages = await _dbService.fetchMessages(
        chatId,
        limit: 50, // Preload last 50 messages
        ascending: false,
      );
      
      // Sort chronologically (oldest to newest)
      recentMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Cache the messages
      _messageCache[chatId] = recentMessages;
      _messageCountCache[chatId] = totalCount;
    } catch (e) {
      debugPrint('Error preloading messages for chat $chatId: $e');
      // Non-critical, continue anyway
    }
  }

  /// Get cached messages for a chat (if available)
  List<ChatMessage>? getCachedMessages(String chatId) {
    return _messageCache[chatId];
  }

  /// Get cached message count for a chat (if available)
  int? getCachedMessageCount(String chatId) {
    return _messageCountCache[chatId];
  }

  /// Invalidate cache for a chat (call when new messages arrive)
  void invalidateMessageCache(String chatId) {
    _messageCache.remove(chatId);
    _messageCountCache.remove(chatId);
    // Optionally preload again in background
    // ignore: unawaited_futures
    _preloadChatMessages(chatId);
  }

  /// Add a message to the cache (for realtime updates)
  void addMessageToCache(String chatId, ChatMessage message) {
    final cached = _messageCache[chatId];
    if (cached != null) {
      // Add to end (newest messages)
      cached.add(message);
      // Keep only last 50 messages in cache
      if (cached.length > 50) {
        cached.removeRange(0, cached.length - 50);
      }
      // Update count
      final currentCount = _messageCountCache[chatId] ?? 0;
      _messageCountCache[chatId] = currentCount + 1;
    }
  }

  void setActiveChat(String? chatId) {
    _activeChatId = chatId;
  }

  /// Reload chats from database
  Future<void> refreshChats() async {
    _isLoaded = false;
    await _loadChats();
  }

  Future<void> _refreshUnreadCounts() async {
    if (_chats.isEmpty) return;
    final futures = _chats.map((chat) async {
      final count = await _dbService.getUnreadCount(
        chat.id,
        since: chat.lastReadAt ?? chat.createdAt,
      );
      return chat.copyWith(unreadCount: count);
    }).toList();

    final updated = await Future.wait(futures);
    _chats = updated;
  }

  Future<void> markChatAsRead(String chatId) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index == -1) return;
    final now = DateTime.now();
    // Optimistic local update
    _chats[index] = _chats[index].copyWith(lastReadAt: now, unreadCount: 0);
    notifyListeners();
    try {
      await _dbService.markChatRead(chatId);
    } catch (e) {
      // On failure, we won't revert; counts will be recomputed on next refresh
    }
  }

  AiChat? getChatById(String id) {
    try {
      return _chats.firstWhere((chat) => chat.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addChat(AiChat chat) async {
    try {
      final createdChat = await _dbService.createChat(chat);
      _chats.insert(0, createdChat); // Add to beginning
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding chat: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateChat(AiChat updatedChat) async {
    try {
      await _dbService.updateChat(updatedChat);
      final index = _chats.indexWhere((chat) => chat.id == updatedChat.id);
      if (index != -1) {
        _chats[index] = updatedChat;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating chat: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateLastMessage(String chatId, String message) async {
    try {
      final index = _chats.indexWhere((chat) => chat.id == chatId);
      if (index != -1) {
        final updatedChat = _chats[index].copyWith(
          lastMessage: message,
          lastMessageTime: DateTime.now(),
        );
        await _dbService.updateChat(updatedChat);
        _chats[index] = updatedChat;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating last message: $e');
      notifyListeners();
    }
  }

  /// Delete a chat and its avatar
  /// The avatar deletion is delayed to allow for undo functionality
  Future<void> deleteChat(String chatId, {bool deleteAvatarImmediately = false}) async {
    // Prevent concurrent deletions of the same chat
    if (_deletingChatIds.contains(chatId)) {
      debugPrint('Chat $chatId is already being deleted, skipping...');
      return;
    }
    
    // Prevent deletion while loading
    if (_isLoading) {
      debugPrint('Cannot delete chat while loading chats');
      return;
    }
    
    _deletingChatIds.add(chatId);
    
    try {
      // Find the chat to get its avatar URL before deletion
      final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
      
      // If chat not found, it might have already been deleted
      if (chatIndex == -1) {
        debugPrint('Chat $chatId not found in local list, may have already been deleted');
        return;
      }
      
      final chat = _chats[chatIndex];
      final avatarUrl = chat.avatarUrl;
      
      // Clear message cache for this chat immediately
      _messageCache.remove(chatId);
      _messageCountCache.remove(chatId);
      
      // Remove from local list optimistically (before database deletion)
      // This provides immediate UI feedback
      _chats.removeAt(chatIndex);
      notifyListeners();
      
      // Delete from database (this also deletes messages via cascade)
      await _dbService.deleteChat(chatId);
      
      // Delete avatar from storage if it exists
      // If not immediate, we schedule it for later (after undo window)
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        if (deleteAvatarImmediately) {
          try {
            await _storageService.deleteAvatar(avatarUrl);
            debugPrint('Avatar deleted immediately for chat: $chatId');
          } catch (storageError) {
            debugPrint('Failed to delete avatar for chat $chatId: $storageError');
          }
        } else {
          // Schedule avatar deletion after 5 seconds (undo window)
          final urlToDelete = avatarUrl; // Capture the non-null value
          Future.delayed(const Duration(seconds: 5), () async {
            try {
              await _storageService.deleteAvatar(urlToDelete);
              debugPrint('Avatar deleted (delayed) for chat: $chatId');
            } catch (storageError) {
              debugPrint('Failed to delete avatar for chat $chatId: $storageError');
            }
          });
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting chat: $e');
      
      // Reload chats to sync with database state
      // ignore: unawaited_futures
      refreshChats().catchError((refreshError) {
        debugPrint('Error refreshing chats after deletion failure: $refreshError');
      });
      
      notifyListeners();
      rethrow;
    } finally {
      _deletingChatIds.remove(chatId);
    }
  }
  
  /// Permanently delete a chat's avatar from storage
  /// Used when we know the chat won't be restored
  Future<void> permanentlyDeleteChatAvatar(String avatarUrl) async {
    try {
      await _storageService.deleteAvatar(avatarUrl);
      debugPrint('Avatar permanently deleted: $avatarUrl');
    } catch (e) {
      debugPrint('Failed to permanently delete avatar: $e');
    }
  }

  /// Toggle pin status of a chat
  Future<void> togglePin(String chatId) async {
    try {
      final index = _chats.indexWhere((chat) => chat.id == chatId);
      if (index != -1) {
        final chat = _chats[index];
        final updatedChat = chat.copyWith(isPinned: !chat.isPinned);
        await _dbService.updateChat(updatedChat);
        _chats[index] = updatedChat;
        
        // Re-sort the chats list
        _sortChats();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error toggling pin: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Reorder chats (for drag and drop)
  Future<void> reorderChats(int oldIndex, int newIndex) async {
    try {
      // Adjust newIndex if moving down
      if (newIndex > oldIndex) {
        newIndex--;
      }

      // Don't allow moving between pinned and unpinned sections
      final movingChat = _chats[oldIndex];
      final targetChat = _chats[newIndex];
      if (movingChat.isPinned != targetChat.isPinned) {
        return;
      }

      // Move the chat in the list
      final chat = _chats.removeAt(oldIndex);
      _chats.insert(newIndex, chat);

      // Update sort orders for affected chats
      final isPinnedSection = chat.isPinned;
      final chatsToUpdate = _chats
          .where((c) => c.isPinned == isPinnedSection)
          .toList();

      for (int i = 0; i < chatsToUpdate.length; i++) {
        final updatedChat = chatsToUpdate[i].copyWith(sortOrder: i);
        await _dbService.updateChat(updatedChat);
        final chatIndex = _chats.indexWhere((c) => c.id == updatedChat.id);
        if (chatIndex != -1) {
          _chats[chatIndex] = updatedChat;
        }
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error reordering chats: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Sort chats by pinned status, sort order, and created date
  void _sortChats() {
    _chats.sort((a, b) {
      // First, sort by pinned status (pinned first)
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // Then by sort order
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      // Finally by creation date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void _ensureRealtimeSubscribed() {
    // Subscribe once per provider lifetime
    if (_messagesChannel != null) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    _messagesChannel = SupabaseService.client.channel('messages-inserts')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          try {
            final record = payload.newRecord;
            if (record['user_id'] != userId) return;
            if (record['role'] != 'assistant') return;

            final chatId = record['chat_id'] as String?;
            if (chatId == null) return;

            final content = (record['content'] as String?) ?? '';
            final createdAtStr = record['created_at'] as String?;
            final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
            final messageId = record['id'] as String?;
            final model = record['model'] as String?;

            // Ignore realtime updates for chats being deleted
            if (_deletingChatIds.contains(chatId)) return;
            
            final index = _chats.indexWhere((c) => c.id == chatId);
            if (index == -1) return;

            final currentChat = _chats[index];
            
            // Create ChatMessage object for cache
            if (messageId != null) {
              final message = ChatMessage(
                id: messageId,
                role: ChatRole.assistant,
                content: content,
                createdAt: createdAt,
                model: model,
              );
              // Add to cache
              addMessageToCache(chatId, message);
            }
            
            // Update last message/time immediately
            var updated = currentChat.copyWith(
              lastMessage: content,
              lastMessageTime: createdAt,
            );

            // Unread logic based on active chat
            if (_activeChatId == chatId) {
              // If user is viewing this chat, mark read
              updated = updated.copyWith(unreadCount: 0, lastReadAt: DateTime.now());
              // Persist last_read_at best-effort (non-blocking)
              // ignore: unawaited_futures
              _dbService.markChatRead(chatId);
            } else {
              // User is not viewing this chat - increment unread count
              // Ensure we use the current unreadCount from the chat, not the updated one
              // Also ensure it's at least 1 if a new message just arrived
              final newUnreadCount = (currentChat.unreadCount + 1).clamp(1, 999);
              updated = updated.copyWith(unreadCount: newUnreadCount);
              
              // Play notification sound for new message
              _playNotificationSound();
            }

            _chats[index] = updated;
            notifyListeners();
          } catch (e) {
            debugPrint('Realtime message handling error: $e');
          }
        },
      );

    _messagesChannel!.subscribe();
  }

  /// Play notification sound and vibration when a new message arrives
  /// Only plays when user is not viewing the chat
  void _playNotificationSound() {
    debugPrint('Playing notification sound and vibration...');
    
    // Always try to vibrate - more reliable than sound
    try {
      HapticFeedback.mediumImpact();
      debugPrint('Vibration triggered successfully');
    } catch (e) {
      debugPrint('Vibration failed: $e');
    }
    
    // Also try to play sound
    try {
      // Play system alert sound (notification sound)
      // Note: On iOS, this respects silent switch and might be quiet
      SystemSound.play(SystemSoundType.alert);
      debugPrint('Notification sound played successfully (alert)');
    } catch (e) {
      debugPrint('Alert sound failed: $e, trying click sound...');
      // If alert sound is not available, try click sound as fallback
      try {
        SystemSound.play(SystemSoundType.click);
        debugPrint('Notification sound played successfully (click)');
      } catch (e2) {
        debugPrint('Could not play notification sound: $e2');
        // Silently fail - sound is not critical
      }
    }
  }
}
