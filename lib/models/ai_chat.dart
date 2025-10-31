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

  AiChat({
    String? id,
    required this.name,
    required this.description,
    required this.model,
    this.lastMessage,
    this.lastMessageTime,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  AiChat copyWith({
    String? name,
    String? description,
    String? model,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return AiChat(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      model: model ?? this.model,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'model': model,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AiChat.fromJson(Map<String, dynamic> json) {
    return AiChat(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      model: json['model'] as String,
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

