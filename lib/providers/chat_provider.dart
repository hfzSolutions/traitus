import 'package:flutter/foundation.dart';
import 'package:traitus/models/chat_message.dart';
import 'package:traitus/services/openrouter_api.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    OpenRouterApi? api, 
    String? chatId, 
    String? model,
    String? systemPrompt,
  }) 
      : _api = api ?? OpenRouterApi(),
        _chatId = chatId ?? '',
        _model = model ?? 'openrouter/auto',
        _systemPrompt = systemPrompt ?? 'You are a helpful, concise AI assistant. Use markdown for structure.',
        _messages = <ChatMessage>[
          ChatMessage(
            role: ChatRole.system,
            content: systemPrompt ?? 'You are a helpful, concise AI assistant. Use markdown for structure.',
          ),
        ];

  final OpenRouterApi _api;
  final String _chatId;
  final String _model;
  final String _systemPrompt;

  final List<ChatMessage> _messages;

  bool _isSending = false;
  bool _isStopped = false;

  String get chatId => _chatId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  bool get hasMessages => _messages.where((m) => m.role != ChatRole.system).isNotEmpty;

  Future<void> sendUserMessage(String content) async {
    if (content.trim().isEmpty || _isSending) return;

    final userMessage = ChatMessage(role: ChatRole.user, content: content);
    _messages.add(userMessage);
    final pendingMessage = ChatMessage(role: ChatRole.assistant, content: '', isPending: true);
    _messages.add(pendingMessage);
    final pendingId = pendingMessage.id;
    _isSending = true;
    _isStopped = false;
    notifyListeners();

    try {
      final response = await _api.createChatCompletion(
        messages: _messages
            .where((m) => !m.isPending || m.id == pendingId)
            .map((m) => m.toOpenRouterMessage())
            .toList(),
        model: _model,
      );

      if (!_isStopped) {
        final pendingIndex = _messages.indexWhere((m) => m.id == pendingId && m.isPending);
        if (pendingIndex != -1) {
          _messages[pendingIndex] = ChatMessage(
            role: ChatRole.assistant,
            content: response,
            id: pendingId,
            isPending: false,
          );
        }
      } else {
        // Clean up pending message if stopped
        _messages.removeWhere((m) => m.id == pendingId && m.isPending);
      }
    } catch (e) {
      final pendingIndex = _messages.indexWhere((m) => m.id == pendingId && m.isPending);
      final errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('ClientException: ', '');
      if (pendingIndex != -1) {
        _messages[pendingIndex] = ChatMessage(
          role: ChatRole.assistant,
          content: errorMessage,
          hasError: true,
          id: pendingId,
          isPending: false,
        );
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

    // Remove the last assistant message and any user message after it
    // Actually, we want to keep conversation context, just regenerate the last AI response
    final messagesBeforeAssistant = _messages.take(lastAssistantIndex).toList();
    _messages
      ..clear()
      ..addAll(messagesBeforeAssistant);

    // Get the last user message
    final lastUserIndex = _messages.lastIndexWhere((m) => m.role == ChatRole.user);
    if (lastUserIndex != -1) {
      final lastUserMessage = _messages[lastUserIndex].content;
      await sendUserMessage(lastUserMessage);
    }
  }

  void deleteMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  void editMessage(String messageId, String newContent) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1 && _messages[index].role == ChatRole.user) {
      _messages[index] = _messages[index].copyWith(content: newContent);
      // Remove all messages after this one
      _messages.removeRange(index + 1, _messages.length);
      notifyListeners();
      // Regenerate response
      sendUserMessage(newContent);
    }
  }

  void resetConversation() {
    _isSending = false;
    _isStopped = false;
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


