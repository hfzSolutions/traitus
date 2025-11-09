import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum ChatRole { user, assistant, system }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.isPending = false,
    this.hasError = false,
    this.model,
    String? id,
    List<String>? imageUrls,
  })  : createdAt = createdAt ?? DateTime.now(),
        id = id ?? _uuid.v4(),
        imageUrls = imageUrls ?? [];

  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final bool isPending;
  final bool hasError;
  final String? model;
  final String id;
  final List<String> imageUrls; // User-uploaded images (URLs)

  ChatMessage copyWith({
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    bool? isPending,
    bool? hasError,
    String? model,
    String? id,
    List<String>? imageUrls,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      hasError: hasError ?? this.hasError,
      model: model ?? this.model,
      id: id ?? this.id,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  Map<String, dynamic> toOpenRouterMessage() {
    // For multimodal messages, we need to use content array
    if (imageUrls.isNotEmpty && role == ChatRole.user) {
      final contentArray = <Map<String, dynamic>>[];
      
      // Add text first (OpenRouter recommends text before images)
      if (content.trim().isNotEmpty) {
        contentArray.add({
          'type': 'text',
          'text': content,
        });
      }
      
      // Add images
      for (final imageUrl in imageUrls) {
        contentArray.add({
          'type': 'image_url',
          'image_url': {
            'url': imageUrl,
          },
        });
      }
      
      return {
        'role': 'user',
        'content': contentArray,
      };
    }
    
    // For non-multimodal messages, use simple string content
    return {
      'role': switch (role) {
        ChatRole.user => 'user',
        ChatRole.assistant => 'assistant',
        ChatRole.system => 'system',
      },
      'content': content,
    };
  }
}


