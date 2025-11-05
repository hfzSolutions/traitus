import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:traitus/models/chat_message.dart';
import 'package:traitus/services/openrouter_api.dart';
import 'package:traitus/services/database_service.dart';
import 'package:traitus/providers/chats_list_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    OpenRouterApi? api, 
    String? chatId, 
    String? model,
    String? systemPrompt,
    ChatsListProvider? chatsListProvider, // Optional cache provider
  }) 
      : _api = api ?? OpenRouterApi(),
        _chatId = chatId ?? '',
        _model = model ?? dotenv.env['OPENROUTER_MODEL'] ?? '',
        _systemPrompt = systemPrompt ?? 'You are a helpful, concise AI assistant. Use markdown for structure.',
        _chatsListProvider = chatsListProvider,
        _messages = <ChatMessage>[
          ChatMessage(
            role: ChatRole.system,
            content: systemPrompt ?? 'You are a helpful, concise AI assistant. Use markdown for structure.',
          ),
        ] {
    if (_model.isEmpty) {
      throw StateError('Missing OPENROUTER_MODEL. Add it to a .env file.');
    }
    _loadMessages();
  }

  static const int _messagesPerPage = 50;

  final OpenRouterApi _api;
  final DatabaseService _dbService = DatabaseService();
  final String _chatId;
  final String _model;
  final String _systemPrompt;
  final ChatsListProvider? _chatsListProvider; // For accessing message cache

  final List<ChatMessage> _messages;

  bool _isSending = false;
  bool _isStopped = false;
  bool _isLoading = false;
  bool _isLoadingOlder = false;
  bool _hasMoreMessages = true;

  String get chatId => _chatId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  bool get isLoading => _isLoading;
  bool get isLoadingOlder => _isLoadingOlder;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get hasMessages => _messages.where((m) => m.role != ChatRole.system).isNotEmpty;

  Future<void> _loadMessages() async {
    if (_chatId.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Try to use cached messages first (instant load!)
      List<ChatMessage> loadedMessages = [];
      int? totalCount;
      
      if (_chatsListProvider != null) {
        final cachedMessages = _chatsListProvider.getCachedMessages(_chatId);
        final cachedCount = _chatsListProvider.getCachedMessageCount(_chatId);
        
        if (cachedMessages != null && cachedCount != null) {
        // Use cached data - instant load!
        loadedMessages = List.from(cachedMessages);
          totalCount = cachedCount;
        }
      }
      
      // If no cache available, load from database
      if (loadedMessages.isEmpty) {
        totalCount = await _dbService.getMessageCount(_chatId);
        
        loadedMessages = await _dbService.fetchMessages(
          _chatId,
          limit: _messagesPerPage,
          ascending: false,
        );
        
        // Sort chronologically (oldest to newest)
        loadedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      
      _messages
        ..clear()
        ..addAll(loadedMessages);
      
      // Ensure system message is always first
      if (_messages.isEmpty || _messages.first.role != ChatRole.system) {
        _messages.insert(0, ChatMessage(
          role: ChatRole.system,
          content: _systemPrompt,
        ));
      }
      
      // Determine if there are more messages to load
      // Don't count the system message
      final nonSystemMessages = _messages.where((m) => m.role != ChatRole.system).length;
      _hasMoreMessages = nonSystemMessages < (totalCount ?? 0);
      
    } catch (e) {
      // Error loading messages
      // Keep system message on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load older messages (for pagination when scrolling up)
  Future<void> loadOlderMessages() async {
    if (_chatId.isEmpty || _isLoadingOlder || !_hasMoreMessages) return;

    _isLoadingOlder = true;
    notifyListeners();

    try {
      // Count non-system messages to determine offset
      final currentMessageCount = _messages.where((m) => m.role != ChatRole.system).length;
      
      // Fetch older messages
      final olderMessages = await _dbService.fetchMessages(
        _chatId,
        limit: _messagesPerPage,
        offset: currentMessageCount,
        ascending: true,
      );
      
      if (olderMessages.isEmpty) {
        _hasMoreMessages = false;
      } else {
        // Find the index where to insert (after system message)
        final insertIndex = _messages.indexWhere((m) => m.role != ChatRole.system);
        if (insertIndex != -1) {
          _messages.insertAll(insertIndex, olderMessages);
        } else {
          _messages.addAll(olderMessages);
        }
        
        // Check if there are more messages
        final totalCount = await _dbService.getMessageCount(_chatId);
        final newNonSystemCount = _messages.where((m) => m.role != ChatRole.system).length;
        _hasMoreMessages = newNonSystemCount < totalCount;
      }
    } catch (e) {
      // Error loading older messages
    } finally {
      _isLoadingOlder = false;
      notifyListeners();
    }
  }

  Future<void> sendUserMessage(String content) async {
    if (content.trim().isEmpty || _isSending) return;

    final userMessage = ChatMessage(role: ChatRole.user, content: content);
    _messages.add(userMessage);
    
    // Save user message to database
    try {
      await _dbService.createMessage(_chatId, userMessage);
      // Add to cache if available
      if (_chatsListProvider != null) {
        _chatsListProvider.addMessageToCache(_chatId, userMessage);
      }
    } catch (e) {
      // Error saving user message
    }

    final pendingMessage = ChatMessage(role: ChatRole.assistant, content: '', isPending: true);
    _messages.add(pendingMessage);
    final pendingId = pendingMessage.id;
    _isSending = true;
    _isStopped = false;
    notifyListeners();

    try {
      String fullResponse = '';
      
      // Use streaming for natural word-by-word response
      await for (final chunk in _api.streamChatCompletion(
        messages: _messages
            .where((m) => !m.isPending || m.id == pendingId)
            .map((m) => m.toOpenRouterMessage())
            .toList(),
        model: _model,
      )) {
        // Check if generation was stopped
        if (_isStopped) {
          break;
        }

        // Console log each chunk as it arrives from OpenRouter
        debugPrint('📦 Chunk: $chunk');

        // Append chunk to full response
        fullResponse += chunk;
        
        // Update the pending message with accumulated content
        final pendingIndex = _messages.indexWhere((m) => m.id == pendingId && m.isPending);
        if (pendingIndex != -1) {
          _messages[pendingIndex] = ChatMessage(
            role: ChatRole.assistant,
            content: fullResponse,
            id: pendingId,
            isPending: true, // Still pending until stream completes
            model: _model,
          );
          notifyListeners(); // Update UI with each chunk
        }
      }

      // Console log the bot's complete reply
      if (fullResponse.isNotEmpty) {
        debugPrint('🤖 Bot Reply (Complete): $fullResponse');
      }

      if (_isStopped) {
        // User stopped generation - remove pending message
        _messages.removeWhere((m) => m.id == pendingId && m.isPending);
      } else if (fullResponse.isNotEmpty) {
        // Stream completed successfully
        final pendingIndex = _messages.indexWhere((m) => m.id == pendingId && m.isPending);
        if (pendingIndex != -1) {
          final assistantMessage = ChatMessage(
            role: ChatRole.assistant,
            content: fullResponse,
            id: pendingId,
            isPending: false, // Mark as complete
            model: _model,
          );
          _messages[pendingIndex] = assistantMessage;
          
          // Save assistant message to database
          try {
            await _dbService.createMessage(_chatId, assistantMessage);
            // Add to cache if available
            if (_chatsListProvider != null) {
              _chatsListProvider.addMessageToCache(_chatId, assistantMessage);
            }
          } catch (e) {
            // Error saving assistant message
          }
        }
      } else {
        // Empty response - clean up
        _messages.removeWhere((m) => m.id == pendingId && m.isPending);
      }
    } catch (e) {
      final pendingIndex = _messages.indexWhere((m) => m.id == pendingId && m.isPending);
      final errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('ClientException: ', '');
      if (pendingIndex != -1) {
        final errorMsg = ChatMessage(
          role: ChatRole.assistant,
          content: errorMessage,
          hasError: true,
          id: pendingId,
          isPending: false,
          model: _model,
        );
        _messages[pendingIndex] = errorMsg;
        
        // Save error message to database
        try {
          await _dbService.createMessage(_chatId, errorMsg);
        } catch (e) {
          // Error saving error message
        }
      }
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void stopGeneration() {
    if (_isSending) {
      _isStopped = true;
      _isSending = false;
      final pendingIndex = _messages.lastIndexWhere((m) => m.isPending);
      if (pendingIndex != -1) {
        _messages.removeAt(pendingIndex);
      }
      notifyListeners();
    }
  }

  Future<void> regenerateLastResponse() async {
    if (_isSending) return;

    // Find the last assistant message
    final lastAssistantIndex = _messages.lastIndexWhere((m) => m.role == ChatRole.assistant && !m.isPending);
    if (lastAssistantIndex == -1) return;

    // Delete the last assistant message from database
    try {
      await _dbService.deleteMessage(_messages[lastAssistantIndex].id);
    } catch (e) {
      // Error deleting message from database
    }

    // Remove the last assistant message and any user message after it
    final messagesBeforeAssistant = _messages.take(lastAssistantIndex).toList();
    _messages
      ..clear()
      ..addAll(messagesBeforeAssistant);

    // Get the last user message
    final lastUserIndex = _messages.lastIndexWhere((m) => m.role == ChatRole.user);
    if (lastUserIndex != -1) {
      final lastUserMessage = _messages[lastUserIndex].content;
      // Remove the last user message temporarily
      _messages.removeAt(lastUserIndex);
      // Re-send it (which will save it again)
      await sendUserMessage(lastUserMessage);
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _dbService.deleteMessage(messageId);
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      // Error deleting message
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1 && _messages[index].role == ChatRole.user) {
      final updatedMessage = _messages[index].copyWith(content: newContent);
      _messages[index] = updatedMessage;
      
      // Update in database
      try {
        await _dbService.updateMessage(updatedMessage);
      } catch (e) {
        // Error updating message
      }
      
      // Remove all messages after this one
      final messagesToDelete = _messages.skip(index + 1).toList();
      for (final msg in messagesToDelete) {
        try {
          await _dbService.deleteMessage(msg.id);
        } catch (e) {
          // Error deleting message
        }
      }
      _messages.removeRange(index + 1, _messages.length);
      notifyListeners();
      
      // Regenerate response
      await sendUserMessage(newContent);
    }
  }

  Future<void> resetConversation() async {
    _isSending = false;
    _isStopped = false;
    
    // Delete all messages from database
    try {
      await _dbService.deleteAllMessages(_chatId);
    } catch (e) {
      // Error deleting messages
    }
    
    _messages
      ..clear()
      ..add(
        ChatMessage(
          role: ChatRole.system,
          content: _systemPrompt,
        ),
      );
    notifyListeners();
  }
}
