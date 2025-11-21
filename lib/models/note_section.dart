import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class NoteSection {
  final String id;
  final String noteId;
  final String content;
  final DateTime createdAt;

  NoteSection({
    String? id,
    required this.noteId,
    required this.content,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note_id': noteId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory NoteSection.fromJson(Map<String, dynamic> json) {
    return NoteSection(
      id: json['id'] as String,
      noteId: json['note_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  NoteSection copyWith({
    String? id,
    String? noteId,
    String? content,
    DateTime? createdAt,
  }) {
    return NoteSection(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

