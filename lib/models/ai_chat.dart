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
    );
  }
}

