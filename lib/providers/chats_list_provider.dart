import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traitus/models/ai_chat.dart';

class ChatsListProvider extends ChangeNotifier {
  ChatsListProvider() {
    _loadChats();
  }

  List<AiChat> _chats = [];
  bool _isLoaded = false;

  List<AiChat> get chats => List.unmodifiable(_chats);
  bool get isLoaded => _isLoaded;

  Future<void> _loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final chatsJson = prefs.getString('ai_chats');
    
    if (chatsJson != null && chatsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(chatsJson);
        _chats = decoded.map((json) => AiChat.fromJson(json)).toList();
      } catch (e) {
        // If there's an error loading, start with default
        _chats = [
          AiChat(
            name: 'AI Assistant',
            description: 'You are a helpful, friendly AI assistant. You provide clear and concise answers. Use markdown for structure when appropriate.',
            model: 'openrouter/auto',
          ),
        ];
      }
    } else {
      // First time - create default chat
      _chats = [
        AiChat(
          name: 'AI Assistant',
          description: 'You are a helpful, friendly AI assistant. You provide clear and concise answers. Use markdown for structure when appropriate.',
          model: 'openrouter/auto',
        ),
      ];
      await _saveChats();
    }
    
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    final chatsJson = jsonEncode(_chats.map((chat) => chat.toJson()).toList());
    await prefs.setString('ai_chats', chatsJson);
  }

  AiChat? getChatById(String id) {
    try {
      return _chats.firstWhere((chat) => chat.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addChat(AiChat chat) async {
    _chats.add(chat);
    await _saveChats();
    notifyListeners();
  }

  Future<void> updateChat(AiChat updatedChat) async {
    final index = _chats.indexWhere((chat) => chat.id == updatedChat.id);
    if (index != -1) {
      _chats[index] = updatedChat;
      await _saveChats();
      notifyListeners();
    }
  }

  Future<void> updateLastMessage(String chatId, String message) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(
        lastMessage: message,
        lastMessageTime: DateTime.now(),
      );
      await _saveChats();
      notifyListeners();
    }
  }

  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((chat) => chat.id == chatId);
    await _saveChats();
    notifyListeners();
  }
}

