import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/services/database_service.dart';
import 'package:traitus/services/storage_service.dart';

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
      
      // If no chats exist, create a default one
      if (_chats.isEmpty) {
        final model = dotenv.env['OPENROUTER_MODEL'];
        if (model == null || model.isEmpty) {
          throw StateError('Missing OPENROUTER_MODEL. Add it to a .env file.');
        }
        final defaultChat = AiChat(
          name: 'AI Assistant',
          description: 'You are a helpful, friendly AI assistant. You provide clear and concise answers. Use markdown for structure when appropriate.',
          model: model,
        );
        await addChat(defaultChat);
      }
      
      _isLoaded = true;
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

  /// Reload chats from database
  Future<void> refreshChats() async {
    _isLoaded = false;
    await _loadChats();
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
    try {
      // Find the chat to get its avatar URL before deletion
      final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
      String? avatarUrl;
      
      if (chatIndex != -1) {
        avatarUrl = _chats[chatIndex].avatarUrl;
      }
      
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
      
      // Remove from local list
      _chats.removeWhere((chat) => chat.id == chatId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting chat: $e');
      notifyListeners();
      rethrow;
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
}
