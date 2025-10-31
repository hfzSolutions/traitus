enum ChatRole { user, assistant, system }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.isPending = false,
    this.hasError = false,
    String? id,
  })  : createdAt = createdAt ?? DateTime.now(),
        id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final bool isPending;
  final bool hasError;
  final String id;

  ChatMessage copyWith({
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    bool? isPending,
    bool? hasError,
    String? id,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      hasError: hasError ?? this.hasError,
      id: id ?? this.id,
    );
  }

  Map<String, String> toOpenRouterMessage() {
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


