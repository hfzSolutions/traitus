import 'package:flutter/foundation.dart';
import 'package:traitus/config/default_ai_config.dart';
import 'package:traitus/models/ai_chat.dart';
import 'package:traitus/models/chat_message.dart';
import 'package:traitus/models/note.dart';
import 'package:traitus/models/user_profile.dart';
import 'package:traitus/services/supabase_service.dart';

class DatabaseService {
  final _client = SupabaseService.client;

  // ========== CHATS ==========

  /// Fetch all chats for the current user
  /// Chats are ordered by: pinned status (pinned first), then sort_order (ascending), then created_at (descending)
  Future<List<AiChat>> fetchChats() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('chats')
        .select()
        .eq('user_id', userId)
        .order('is_pinned', ascending: false)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);

    return (response as List).map((json) => AiChat.fromJson(json)).toList();
  }

  /// Count unread assistant messages for a chat since last_read_at
  Future<int> getUnreadCount(String chatId, {DateTime? since}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final threshold = since;

    var query = _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .eq('user_id', userId)
        .eq('role', 'assistant');

    if (threshold != null) {
      query = query.gt('created_at', threshold.toIso8601String());
    }

    final response = await query;
    return (response as List).length;
  }

  /// Mark chat as read now by updating last_read_at
  Future<void> markChatRead(String chatId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('chats')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('id', chatId)
        .eq('user_id', userId);
  }

  /// Create a new chat
  Future<AiChat> createChat(AiChat chat) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final chatData = {
      ...chat.toJson(),
      'user_id': userId,
    };

    final response = await _client
        .from('chats')
        .insert(chatData)
        .select()
        .single();

    return AiChat.fromJson(response);
  }

  /// Update an existing chat
  Future<void> updateChat(AiChat chat) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('chats')
        .update(chat.toJson())
        .eq('id', chat.id)
        .eq('user_id', userId);
  }

  /// Delete a chat
  Future<void> deleteChat(String chatId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // First delete all messages in this chat
    await _client
        .from('messages')
        .delete()
        .eq('chat_id', chatId)
        .eq('user_id', userId);

    // Then delete the chat
    await _client
        .from('chats')
        .delete()
        .eq('id', chatId)
        .eq('user_id', userId);
  }

  // ========== MESSAGES ==========

  /// Fetch all messages for a specific chat
  /// 
  /// [limit] - Number of messages to fetch (default: null = fetch all)
  /// [offset] - Number of messages to skip (default: 0)
  /// [ascending] - Order by created_at ascending (true) or descending (false)
  Future<List<ChatMessage>> fetchMessages(
    String chatId, {
    int? limit,
    int offset = 0,
    bool ascending = true,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    var query = _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .eq('user_id', userId)
        .order('created_at', ascending: ascending);

    if (limit != null) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;

    return (response as List).map((json) => _chatMessageFromJson(json)).toList();
  }

  /// Get the total count of messages in a chat
  Future<int> getMessageCount(String chatId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .eq('user_id', userId);

    return (response as List).length;
  }

  /// Create a new message
  Future<ChatMessage> createMessage(String chatId, ChatMessage message) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final messageData = {
      'id': message.id,
      'chat_id': chatId,
      'user_id': userId,
      'role': message.role.name,
      'content': message.content,
      'created_at': message.createdAt.toIso8601String(),
      'is_pending': message.isPending,
      'has_error': message.hasError,
      if (message.model != null) 'model': message.model,
    };

    final response = await _client
        .from('messages')
        .insert(messageData)
        .select()
        .single();

    return _chatMessageFromJson(response);
  }

  /// Update a message
  Future<void> updateMessage(ChatMessage message) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('messages')
        .update({
          'content': message.content,
          'is_pending': message.isPending,
          'has_error': message.hasError,
          if (message.model != null) 'model': message.model,
        })
        .eq('id', message.id)
        .eq('user_id', userId);
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('messages')
        .delete()
        .eq('id', messageId)
        .eq('user_id', userId);
  }

  /// Delete all messages in a chat
  Future<void> deleteAllMessages(String chatId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('messages')
        .delete()
        .eq('chat_id', chatId)
        .eq('user_id', userId);
  }

  // ========== NOTES ==========

  /// Fetch all notes for the current user
  Future<List<Note>> fetchNotes() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Note.fromJson(json)).toList();
  }

  /// Create a new note
  Future<Note> createNote(Note note) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final noteData = {
      ...note.toJson(),
      'user_id': userId,
    };

    final response = await _client
        .from('notes')
        .insert(noteData)
        .select()
        .single();

    return Note.fromJson(response);
  }

  /// Update a note
  Future<void> updateNote(Note note) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('notes')
        .update({
          'title': note.title,
          'content': note.content,
        })
        .eq('id', note.id)
        .eq('user_id', userId);
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', userId);
  }

  // ========== USER PROFILES ==========

  /// Fetch user profile for the current user
  Future<UserProfile?> fetchUserProfile() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Create or update user profile
  Future<UserProfile> upsertUserProfile(UserProfile profile) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final profileData = {
      'id': userId,
      'avatar_url': profile.avatarUrl,
      'display_name': profile.displayName,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('user_profiles')
        .upsert(profileData)
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  /// Update user avatar URL
  Future<void> updateUserAvatar(String avatarUrl) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('user_profiles')
        .upsert({
          'id': userId,
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
  }

  /// Complete onboarding for user
  Future<UserProfile> completeOnboarding({
    required String displayName,
    DateTime? dateOfBirth,
    String? preferredLanguage,
    String? avatarUrl,
    String? experienceLevel,
    String? useContext,
    required List<String> preferences,
    required List<String> selectedChatIds,
    List<Map<String, dynamic>>? selectedChatDefinitions,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Update user profile with onboarding completion
    final profileData = {
      'id': userId,
      'display_name': displayName,
      if (dateOfBirth != null) 
        'date_of_birth': dateOfBirth.toIso8601String().split('T')[0], // Date only
      if (preferredLanguage != null) 
        'preferred_language': preferredLanguage,
      if (avatarUrl != null) 
        'avatar_url': avatarUrl,
      if (experienceLevel != null && experienceLevel.isNotEmpty)
        'experience_level': experienceLevel,
      if (useContext != null && useContext.isNotEmpty)
        'use_context': useContext,
      'onboarding_completed': true,
      'preferences': preferences,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('user_profiles')
        .upsert(profileData)
        .select()
        .single();

    final profile = UserProfile.fromJson(response);

    // Create selected AI chats
    try {
      if (selectedChatDefinitions != null && selectedChatDefinitions.isNotEmpty) {
        await _createChatsFromDefinitions(selectedChatDefinitions);
      } else if (selectedChatIds.isNotEmpty) {
        await _createSelectedChats(selectedChatIds);
      }
    } catch (e) {
      // Proceed even if chat creation fails, profile is already saved
    }

    return profile;
  }

  /// Reset onboarding state so user can redo onboarding
  Future<void> resetOnboarding() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('user_profiles')
        .upsert({
          'id': userId,
          'onboarding_completed': false,
          'preferences': [],
          'updated_at': DateTime.now().toIso8601String(),
        });
  }

  /// Create selected AI chats from onboarding
  Future<void> _createSelectedChats(List<String> selectedChatIds) async {
    for (var chatId in selectedChatIds) {
      final config = DefaultAIConfig.getChatConfig(chatId);
      if (config != null) {
        try {
          await createChat(AiChat(
            name: config['name'] as String,
            shortDescription: config['shortDescription'] as String? ?? config['description'] as String? ?? '',
            systemPrompt: config['systemPrompt'] as String? ?? config['description'] as String? ?? 'You are a helpful AI assistant.',
            model: config['model'] as String,
            avatarUrl: config['avatar'] as String,
          ));
        } catch (e) {
          debugPrint('Error creating chat $chatId: $e');
          // Continue even if one chat fails
        }
      }
    }
  }

  /// Create chats directly from dynamic definitions suggested during onboarding
  Future<void> _createChatsFromDefinitions(List<Map<String, dynamic>> chatDefs) async {
    for (final def in chatDefs) {
      try {
        final preference = (def['preference'] ?? '').toString();
        final model = (def['model'] ?? '').toString().isNotEmpty
            ? (def['model'] as String)
            : DefaultAIConfig.getModel(preference);
        
        final description = (def['description'] ?? '') as String;
        final shortDescription = (def['shortDescription'] ?? description).toString();
        final systemPrompt = (def['systemPrompt'] ?? description).toString();

        await createChat(AiChat(
          name: (def['name'] ?? 'Assistant') as String,
          shortDescription: shortDescription.isNotEmpty ? shortDescription : 'A helpful AI assistant',
          systemPrompt: systemPrompt.isNotEmpty ? systemPrompt : 'You are a helpful AI assistant.',
          model: model,
          // Do not submit emoji or any provided avatar for suggested assistants
          // We'll leave avatarUrl null to avoid storing emojis as URLs
          avatarUrl: null,
        ));
      } catch (e) {
        // Continue even if one chat fails
      }
    }
  }

  // ========== HELPERS ==========

  ChatMessage _chatMessageFromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: ChatRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => ChatRole.user,
      ),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPending: json['is_pending'] as bool? ?? false,
      hasError: json['has_error'] as bool? ?? false,
      model: json['model'] as String?,
    );
  }
}

