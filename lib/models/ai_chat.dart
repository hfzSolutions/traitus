import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class AiChat {
  final String id;
  final String name;
  final String shortDescription;  // User-facing description shown under AI name
  final String systemPrompt;       // AI prompt (not shown to users)
  final String? model; // Optional for backward compatibility, but always uses OPENROUTER_MODEL from env
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final DateTime createdAt;
  final bool isPinned;
  final int sortOrder;
  final String? avatarUrl;
  final DateTime? lastReadAt;      // When user last viewed this chat
  final int unreadCount;           // Computed locally, not stored in DB
  
  // Response style preferences
  final String responseTone;        // friendly, professional, casual, formal, enthusiastic
  final String responseLength;      // brief, balanced, detailed
  final String writingStyle;        // simple, technical, creative, analytical
  final bool useEmojis;

  AiChat({
    String? id,
    required this.name,
    required this.shortDescription,
    required this.systemPrompt,
    this.model, // Optional - will use OPENROUTER_MODEL from env if not provided
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
    this.lastReadAt,
    this.unreadCount = 0,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  AiChat copyWith({
    String? name,
    String? shortDescription,
    String? systemPrompt,
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
    DateTime? lastReadAt,
    int? unreadCount,
  }) {
    return AiChat(
      id: id,
      name: name ?? this.name,
      shortDescription: shortDescription ?? this.shortDescription,
      systemPrompt: systemPrompt ?? this.systemPrompt,
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
      lastReadAt: lastReadAt ?? this.lastReadAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'short_description': shortDescription,
      'system_prompt': systemPrompt,
      if (model != null) 'model': model, // Only include if not null
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_pinned': isPinned,
      'sort_order': sortOrder,
      'avatar_url': avatarUrl,
      'last_read_at': lastReadAt?.toIso8601String(),
      'response_tone': responseTone,
      'response_length': responseLength,
      'writing_style': writingStyle,
      'use_emojis': useEmojis,
    };
  }

  factory AiChat.fromJson(Map<String, dynamic> json) {
    // Backward compatibility: if system_prompt doesn't exist, use description as systemPrompt
    // and short_description (or description) as shortDescription
    final systemPrompt = json['system_prompt'] as String?;
    final shortDesc = json['short_description'] as String?;
    final oldDescription = json['description'] as String?;
    
    return AiChat(
      id: json['id'] as String,
      name: json['name'] as String,
      shortDescription: shortDesc ?? oldDescription ?? '',
      systemPrompt: systemPrompt ?? oldDescription ?? 'You are a helpful AI assistant.',
      model: json['model'] as String?, // Optional for backward compatibility
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPinned: json['is_pinned'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String)
          : null,
      responseTone: json['response_tone'] as String? ?? 'friendly',
      responseLength: json['response_length'] as String? ?? 'balanced',
      writingStyle: json['writing_style'] as String? ?? 'simple',
      useEmojis: json['use_emojis'] as bool? ?? false,
    );
  }
  
  /// Get enhanced system prompt with response style preferences
  String getEnhancedSystemPrompt() {
    final buffer = StringBuffer(systemPrompt);
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
    
    // Add length guidance with explicit token limit awareness
    switch (responseLength) {
      case 'brief':
        buffer.write('\n- Keep responses concise and to the point (aim for 2-4 sentences, maximum 300 words)');
        buffer.write('\n- Prioritize the most important information first');
        buffer.write('\n- If you reach the response limit, ensure your last sentence is complete and meaningful');
        break;
      case 'balanced':
        buffer.write('\n- Provide balanced responses with appropriate detail (aim for 4-8 sentences)');
        buffer.write('\n- If you reach the response limit, ensure your last sentence is complete and meaningful');
        break;
      case 'detailed':
        buffer.write('\n- Provide comprehensive and detailed explanations');
        buffer.write('\n- If you reach the response limit, ensure your last sentence is complete and meaningful');
        break;
    }
    
    // Add general instruction about completing thoughts
    buffer.write('\n- Always complete your thoughts within the response limit - do not cut off mid-sentence');
    buffer.write('\n- If approaching the limit, conclude with a complete sentence rather than starting a new point');
    
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

