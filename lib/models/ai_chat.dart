import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class AiChat {
  final String id;
  final String name;
  final String description;
  final String model;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final DateTime createdAt;
  final bool isPinned;
  final int sortOrder;
  final String? avatarUrl;
  
  // Response style preferences
  final String responseTone;        // friendly, professional, casual, formal, enthusiastic
  final String responseLength;      // brief, balanced, detailed
  final String writingStyle;        // simple, technical, creative, analytical
  final bool useEmojis;

  AiChat({
    String? id,
    required this.name,
    required this.description,
    required this.model,
    this.lastMessage,
    this.lastMessageTime,
    DateTime? createdAt,
    this.isPinned = false,
    this.sortOrder = 0,
    this.avatarUrl,
    this.responseTone = 'friendly',
    this.responseLength = 'balanced',
    this.writingStyle = 'simple',
    this.useEmojis = false,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  AiChat copyWith({
    String? name,
    String? description,
    String? model,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isPinned,
    int? sortOrder,
    String? avatarUrl,
    String? responseTone,
    String? responseLength,
    String? writingStyle,
    bool? useEmojis,
  }) {
    return AiChat(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      model: model ?? this.model,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      createdAt: createdAt,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      responseTone: responseTone ?? this.responseTone,
      responseLength: responseLength ?? this.responseLength,
      writingStyle: writingStyle ?? this.writingStyle,
      useEmojis: useEmojis ?? this.useEmojis,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'model': model,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_pinned': isPinned,
      'sort_order': sortOrder,
      'avatar_url': avatarUrl,
      'response_tone': responseTone,
      'response_length': responseLength,
      'writing_style': writingStyle,
      'use_emojis': useEmojis,
    };
  }

  factory AiChat.fromJson(Map<String, dynamic> json) {
    return AiChat(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      model: json['model'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPinned: json['is_pinned'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      responseTone: json['response_tone'] as String? ?? 'friendly',
      responseLength: json['response_length'] as String? ?? 'balanced',
      writingStyle: json['writing_style'] as String? ?? 'simple',
      useEmojis: json['use_emojis'] as bool? ?? false,
    );
  }
  
  /// Get enhanced system prompt with response style preferences
  String getEnhancedSystemPrompt() {
    final buffer = StringBuffer(description);
    buffer.write('\n\nResponse Style Guidelines:');
    
    // Add tone guidance
    switch (responseTone) {
      case 'professional':
        buffer.write('\n- Maintain a professional and formal tone');
        break;
      case 'friendly':
        buffer.write('\n- Use a warm, friendly, and approachable tone');
        break;
      case 'casual':
        buffer.write('\n- Keep the conversation casual and relaxed');
        break;
      case 'formal':
        buffer.write('\n- Use formal language and maintain appropriate distance');
        break;
      case 'enthusiastic':
        buffer.write('\n- Be enthusiastic and energetic in responses');
        break;
    }
    
    // Add length guidance
    switch (responseLength) {
      case 'brief':
        buffer.write('\n- Keep responses concise and to the point');
        break;
      case 'balanced':
        buffer.write('\n- Provide balanced responses with appropriate detail');
        break;
      case 'detailed':
        buffer.write('\n- Provide comprehensive and detailed explanations');
        break;
    }
    
    // Add writing style guidance
    switch (writingStyle) {
      case 'simple':
        buffer.write('\n- Use simple, easy-to-understand language');
        break;
      case 'technical':
        buffer.write('\n- Use technical terminology where appropriate');
        break;
      case 'creative':
        buffer.write('\n- Use creative and engaging language');
        break;
      case 'analytical':
        buffer.write('\n- Use analytical and structured explanations');
        break;
    }
    
    // Add emoji guidance
    if (useEmojis) {
      buffer.write('\n- Feel free to use emojis to enhance communication 😊');
    } else {
      buffer.write('\n- Avoid using emojis in responses');
    }
    
    return buffer.toString();
  }
}

