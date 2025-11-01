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
      print('Error fetching user profile: $e');
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

