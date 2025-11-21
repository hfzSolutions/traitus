import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:traitus/models/chat_message.dart';
import 'package:traitus/services/openrouter_api.dart';
import 'package:traitus/services/database_service.dart';
import 'package:traitus/services/app_config_service.dart';
import 'package:traitus/services/activity_service.dart';
import 'package:traitus/providers/chats_list_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    OpenRouterApi? api, 
    String? chatId, 
    String? model,
    String? systemPrompt,
    String? responseLength, // brief, balanced, detailed
    ChatsListProvider? chatsListProvider, // Optional cache provider
  }) 
      : _api = api ?? OpenRouterApi(),
        _chatId = chatId ?? '',
        _model = model ?? _getModelFromEnv(),
        _systemPrompt = systemPrompt ?? 'You are a helpful, concise AI assistant. Use markdown for structure.',
        _responseLength = responseLength,
        _chatsListProvider = chatsListProvider,
        _messages = <ChatMessage>[
          ChatMessage(
            role: ChatRole.system,
            content: systemPrompt ?? 'You are a helpful, concise AI assistant. Use markdown for structure.',
          ),
        ] {
    _loadMessages();
  }

  static String _getModelFromEnv() {
    // Try to get from cache first
    try {
      return AppConfigService.instance.getCachedDefaultModel();
    } catch (e) {
      // Cache not available yet during app startup - use fallback
      // This is normal during initialization and will be resolved when cache loads
      debugPrint('ChatProvider: Using fallback model, cache not ready yet');
      return 'google/gemini-2.5-flash'; // Safe fallback that matches your DB default
    }
  }

  static const int _messagesPerPage = 50;

  final OpenRouterApi _api;
  final DatabaseService _dbService = DatabaseService();
  final String _chatId;
  String _model; // Uses model from chat, falls back to OPENROUTER_MODEL from env
  String _systemPrompt;
  final String? _responseLength; // brief, balanced, detailed
  final ChatsListProvider? _chatsListProvider; // For accessing message cache

  final List<ChatMessage> _messages;
  List<String> _quickReplies = [];
  DateTime? _quickRepliesGenerationStart;

  bool _isSending = false;
  bool _isStopped = false;
  bool _isLoading = false;
  bool _isLoadingOlder = false;
  bool _hasMoreMessages = true;
  bool _disposed = false;

  String get chatId => _chatId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<String> get quickReplies => List.unmodifiable(_quickReplies);
  bool get isSending => _isSending;
  bool get isLoading => _isLoading;
  bool get isLoadingOlder => _isLoadingOlder;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get hasMessages => _messages.where((m) => m.role != ChatRole.system).isNotEmpty;
  String get currentModel => _model;
  
  /// Update model and system prompt from chat
  /// This is called when chat settings are updated
  void updateFromChat({String? model, String? systemPrompt}) {
    bool changed = false;
    
    // Update model if provided, otherwise keep current or fallback to env
    if (model != null) {
      final newModel = model.isNotEmpty ? model : _getModelFromEnv();
      if (newModel != _model) {
        _model = newModel;
        changed = true;
      }
    }
    
    if (systemPrompt != null && systemPrompt != _systemPrompt) {
      _systemPrompt = systemPrompt;
      // Update system message in messages list
      final systemIndex = _messages.indexWhere((m) => m.role == ChatRole.system);
      if (systemIndex != -1) {
        _messages[systemIndex] = ChatMessage(
          role: ChatRole.system,
          content: systemPrompt,
        );
      } else {
        _messages.insert(0, ChatMessage(
          role: ChatRole.system,
          content: systemPrompt,
        ));
      }
      changed = true;
    }
    
    if (changed) {
      _safeNotifyListeners();
    }
  }
  
  /// Check if the current model supports image inputs (multimodal input)
  /// Returns false by default (safe default)
  Future<bool> getCurrentModelSupportsImageInput() async {
    // Simplified: assume image support is available if OPENROUTER_MODEL supports it
    // Most modern models support images, so default to true
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Safely notify listeners only if not disposed
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Build message list for API call, using cache or database if disposed
  Future<List<ChatMessage>> _buildMessageListForApi({ChatMessage? newUserMessage}) async {
    List<ChatMessage> messagesForApi = [];
    
    if (!_disposed) {
      // Use in-memory messages if available
      messagesForApi = List.from(_messages);
    } else {
      // If disposed, load from cache or database
      if (_chatsListProvider != null) {
        final cached = _chatsListProvider.getCachedMessages(_chatId);
        if (cached != null && cached.isNotEmpty) {
          messagesForApi = List.from(cached);
        }
      }
      
      // If no cache, load from database
      if (messagesForApi.isEmpty) {
        try {
          messagesForApi = await _dbService.fetchMessages(
            _chatId,
            limit: 100, // Get enough messages for context
            ascending: true,
          );
        } catch (e) {
          // Error loading messages
        }
      }
      
      // Ensure system message is first
      if (messagesForApi.isEmpty || messagesForApi.first.role != ChatRole.system) {
        messagesForApi.insert(0, ChatMessage(
          role: ChatRole.system,
          content: _systemPrompt,
        ));
      }
    }
    
    // Always ensure the system message uses the latest system prompt
    // This is critical when settings are updated - we need to use the latest prompt
    final systemIndex = messagesForApi.indexWhere((m) => m.role == ChatRole.system);
    if (systemIndex != -1) {
      // Update existing system message with current system prompt
      messagesForApi[systemIndex] = ChatMessage(
        role: ChatRole.system,
        content: _systemPrompt,
      );
    } else {
      // Insert system message at the beginning if it doesn't exist
      messagesForApi.insert(0, ChatMessage(
        role: ChatRole.system,
        content: _systemPrompt,
      ));
    }
    
    // Add new user message if provided
    if (newUserMessage != null) {
      messagesForApi.add(newUserMessage);
    }
    
    return messagesForApi;
  }

  Future<void> _loadMessages() async {
    if (_chatId.isEmpty || _disposed) return;

    _isLoading = true;
    _safeNotifyListeners();

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
      
      // Remove duplicates by message ID (safety check)
      final seenIds = <String>{};
      loadedMessages = loadedMessages.where((m) {
        if (seenIds.contains(m.id)) {
          return false; // Duplicate, skip it
        }
        seenIds.add(m.id);
        return true;
      }).toList();
      
      // Filter out empty pending messages (they should have been cleaned up, but handle edge cases)
      loadedMessages = loadedMessages.where((m) {
        // Remove messages that are pending with empty content
        if (m.isPending && m.content.trim().isEmpty) {
          return false;
        }
        return true;
      }).toList();
      
      _messages
        ..clear()
        ..addAll(loadedMessages);
      
      // Ensure system message is always first and uses the latest system prompt
      // This is important when settings are updated - we need to use the latest prompt
      final systemIndex = _messages.indexWhere((m) => m.role == ChatRole.system);
      if (systemIndex != -1) {
        // Update existing system message with current system prompt
        _messages[systemIndex] = ChatMessage(
          role: ChatRole.system,
          content: _systemPrompt,
        );
        // Move to first position if not already there
        if (systemIndex != 0) {
          final systemMsg = _messages.removeAt(systemIndex);
          _messages.insert(0, systemMsg);
        }
      } else {
        // Insert system message at the beginning if it doesn't exist
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
      if (!_disposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  /// Load older messages (for pagination when scrolling up)
  Future<void> loadOlderMessages() async {
    if (_chatId.isEmpty || _isLoadingOlder || !_hasMoreMessages || _disposed) return;

    _isLoadingOlder = true;
    _safeNotifyListeners();

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
      if (!_disposed) {
        _isLoadingOlder = false;
        _safeNotifyListeners();
      }
    }
  }

  Future<void> sendUserMessage(String content, {List<String>? imageUrls}) async {
    // Allow sending if there's content OR images
    // Note: imageUrls are now pre-uploaded URLs, not file paths
    if ((content.trim().isEmpty && (imageUrls == null || imageUrls.isEmpty)) || _isSending) return;

    // Note: We continue even if disposed - we want to save the message to DB

    // Images are already uploaded, so we can use the URLs directly
    final uploadedImageUrls = imageUrls ?? [];

    final userMessage = ChatMessage(
      role: ChatRole.user,
      content: content,
      imageUrls: uploadedImageUrls,
    );
    // Only update in-memory messages if not disposed (for UI)
    if (!_disposed) {
      _messages.add(userMessage);
    }
    
    // Always save user message to database (even if disposed, so realtime can pick it up)
    try {
      await _dbService.createMessage(_chatId, userMessage);
      // Add to cache if available (always, even if disposed)
      if (_chatsListProvider != null) {
        _chatsListProvider.addMessageToCache(_chatId, userMessage);
      }
      // Track user activity when sending a message
      ActivityService().updateLastActivity();
    } catch (e) {
      // Error saving user message
    }

    // Create pending message - model will be updated when we get actual model from API response
    final pendingMessage = ChatMessage(role: ChatRole.assistant, content: '', isPending: true, model: _model);
    final pendingId = pendingMessage.id;
    
    // Create pending message in database first so we can update it with images as they arrive
    try {
      await _dbService.createMessage(_chatId, pendingMessage);
    } catch (e) {
      debugPrint('Error creating pending message: $e');
      // Continue anyway - we'll save at the end
    }
    
    if (!_disposed) {
      _messages.add(pendingMessage);
    }
    _isSending = true;
    _isStopped = false;
    _safeNotifyListeners();

    try {
      String fullResponse = '';
      String? actualModelUsed; // Track the actual model used (important for openrouter/auto)
      
      // Build message list for API call (works even if disposed)
      final messagesForApi = await _buildMessageListForApi(newUserMessage: userMessage);
      
      // Calculate max_tokens based on response length preference
      final baseMaxTokens = _api.maxTokens;
      final maxTokens = OpenRouterApi.getMaxTokensForResponseLength(
        _responseLength,
        baseMaxTokens: baseMaxTokens,
      );

      // Use streaming for natural word-by-word response
      // Continue streaming even if disposed - we want to save the message to DB
      await for (final chunkData in _api.streamChatCompletion(
        messages: messagesForApi
            .where((m) => !m.isPending) // Exclude any pending messages from API call
            .map((m) => m.toOpenRouterMessage())
            .toList(),
        model: _model,
        maxTokens: maxTokens,
      )) {
        // Only break if user stopped generation, not if disposed
        // We want to continue and save the message even if user navigated away
        if (_isStopped) {
          break;
        }

        // Extract content and model from chunk
        final chunk = chunkData['content'] as String? ?? '';
        final modelFromChunk = chunkData['model'] as String?;
        
        // Capture model from first chunk that includes it
        if (actualModelUsed == null && modelFromChunk != null) {
          actualModelUsed = modelFromChunk;
        }

        // Append chunk to full response
        fullResponse += chunk;
        
        // Update the pending message with accumulated content (only if not disposed)
        if (!_disposed) {
          final pendingIndex = _messages.indexWhere((m) => m.id == pendingId && m.isPending);
          if (pendingIndex != -1) {
            _messages[pendingIndex] = ChatMessage(
              role: ChatRole.assistant,
              content: fullResponse,
              id: pendingId,
              isPending: true, // Still pending until stream completes
              model: actualModelUsed ?? _model, // Use actual model if available, fallback to env model
            );
            _safeNotifyListeners(); // Update UI with each chunk (only if not disposed)
          }
        }
      }

      if (_isStopped) {
        // User stopped generation - remove pending message
        if (!_disposed) {
          _messages.removeWhere((m) => m.id == pendingId && m.isPending);
        }
      } else if (fullResponse.isNotEmpty) {
        // Stream completed successfully - always save to database (even if disposed)
        // Use actual model from API response (important for openrouter/auto), fallback to env model
        final assistantMessage = ChatMessage(
          role: ChatRole.assistant,
          content: fullResponse,
          id: pendingId,
          isPending: false, // Mark as complete
          model: actualModelUsed ?? _model, // Store the actual model used
        );
        
        // Update in-memory messages only if not disposed
        if (!_disposed) {
          final pendingIndex = _messages.indexWhere((m) => m.id == pendingId && m.isPending);
          if (pendingIndex != -1) {
            _messages[pendingIndex] = assistantMessage;
          }
        }
        
        // Always update assistant message in database (it was created as pending, now update to final)
        // This ensures images and final content are saved
        try {
          await _dbService.updateMessage(assistantMessage);
          // Always add to cache (even if disposed) so realtime can show it in chat list
          if (_chatsListProvider != null) {
            _chatsListProvider.addMessageToCache(_chatId, assistantMessage);
            // Note: We don't call updateLastMessage here because the realtime subscription
            // will handle it automatically, including proper unread count management.
            // This prevents race conditions and ensures unread badges work correctly.
          }
          
          // Provide haptic feedback when bot finishes replying
          try {
            HapticFeedback.mediumImpact();
          } catch (e) {
            // Haptic feedback is optional, ignore errors
          }
          
          // Generate quick replies asynchronously (non-blocking)
          if (!_disposed) {
            _generateQuickReplies(assistantMessage);
          }
        } catch (e) {
          // Error saving assistant message
        }
      } else {
        // Empty response - clean up from both memory and database
        if (!_disposed) {
          _messages.removeWhere((m) => m.id == pendingId && m.isPending);
        }
        // Always delete empty pending message from database
        try {
          await _dbService.deleteMessage(pendingId);
        } catch (e) {
          // Error deleting empty pending message - not critical
        }
      }
    } catch (e) {
      // Always save error message to database (even if disposed)
      final errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('ClientException: ', '');
      final errorMsg = ChatMessage(
        role: ChatRole.assistant,
        content: errorMessage,
        hasError: true,
        id: pendingId,
        isPending: false,
        model: _model, // Use env model for errors (no API response to get actual model)
      );
      
      // Update in-memory messages only if not disposed
      if (!_disposed) {
        final pendingIndex = _messages.indexWhere((m) => m.id == pendingId && m.isPending);
        if (pendingIndex != -1) {
          _messages[pendingIndex] = errorMsg;
        }
      }
      
      // Always save error message to database
      try {
        await _dbService.createMessage(_chatId, errorMsg);
      } catch (e) {
        // Error saving error message
      }
    } finally {
      _isSending = false;
      _safeNotifyListeners();
    }
  }

  void stopGeneration() {
    if (_isSending && !_disposed) {
      _isStopped = true;
      _isSending = false;
      final pendingIndex = _messages.lastIndexWhere((m) => m.isPending);
      if (pendingIndex != -1) {
        _messages.removeAt(pendingIndex);
      }
      _safeNotifyListeners();
    }
  }

  Future<void> regenerateLastResponse() async {
    if (_isSending || _disposed) return;

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
    if (_disposed) return;
    try {
      await _dbService.deleteMessage(messageId);
      if (!_disposed) {
        _messages.removeWhere((m) => m.id == messageId);
        _safeNotifyListeners();
      }
    } catch (e) {
      // Error deleting message
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    if (_disposed) return;
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1 && _messages[index].role == ChatRole.user && !_disposed) {
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
      if (!_disposed) {
        _messages.removeRange(index + 1, _messages.length);
        _safeNotifyListeners();
        
        // Regenerate response
        await sendUserMessage(newContent);
      }
    }
  }

  /// Generate quick replies based on the last assistant message
  /// This runs asynchronously and doesn't block the UI
  Future<void> _generateQuickReplies(ChatMessage assistantMessage) async {
    if (_disposed) return;
    
    // Mark when generation started
    if (!_disposed) {
      _quickRepliesGenerationStart = DateTime.now();
      _quickReplies = []; // Clear previous replies
      _safeNotifyListeners();
    }
    
    try {
      // Build conversation history for context
      final conversationHistory = _messages
          .where((m) => m.role != ChatRole.system && !m.isPending)
          .map((m) => m.toOpenRouterMessage())
          .toList();
      
      // Generate quick replies using the API
      final generatedReplies = await _api.generateQuickReplies(
        conversationHistory: conversationHistory,
        count: 2,
      );
      
      // Update quick replies if not disposed
      if (!_disposed && generatedReplies.isNotEmpty) {
        _quickReplies = generatedReplies;
        _quickRepliesGenerationStart = null; // Clear timestamp when we have replies
        _safeNotifyListeners();
      } else if (!_disposed) {
        // If generation failed, clear quick replies (will use fallback in UI)
        _quickReplies = [];
        _quickRepliesGenerationStart = null;
        _safeNotifyListeners();
      }
    } catch (e) {
      // If generation fails, clear quick replies (will use fallback in UI)
      if (!_disposed) {
        _quickReplies = [];
        _quickRepliesGenerationStart = null;
        _safeNotifyListeners();
      }
    }
  }
  
  /// Check if we should wait for API suggestions or show defaults
  /// Returns true if we should wait (generation started recently), false if we can show defaults
  bool get shouldWaitForQuickReplies {
    if (_quickReplies.isNotEmpty) return false; // Already have replies
    if (_quickRepliesGenerationStart == null) return false; // Not generating
    
    // Wait up to 2.5 seconds for API to return
    final elapsed = DateTime.now().difference(_quickRepliesGenerationStart!);
    return elapsed.inMilliseconds < 2500;
  }

  Future<void> resetConversation() async {
    if (_disposed) return;
    _isSending = false;
    _isStopped = false;
    
    // Clear quick replies when conversation is reset
    if (!_disposed) {
      _quickReplies = [];
      _quickRepliesGenerationStart = null;
    }
    
    // Delete all messages from database
    await _dbService.deleteAllMessages(_chatId);
    
    // Clear message cache so it doesn't reload stale messages when navigating back
    if (_chatsListProvider != null) {
      _chatsListProvider.clearMessageCache(_chatId);
      // Clear the last message in chat list
      await _chatsListProvider.clearLastMessage(_chatId);
    }
    
    if (!_disposed) {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            role: ChatRole.system,
            content: _systemPrompt,
          ),
        );
      _safeNotifyListeners();
    }
  }
}
