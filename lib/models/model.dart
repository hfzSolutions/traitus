class Model {
  final String id;
  final String name;
  final String modelId; // OpenRouter model ID (e.g., "openai/gpt-4o-mini")
  final String provider; // Always 'openrouter'
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Model({
    required this.id,
    required this.name,
    required this.modelId,
    this.provider = 'openrouter',
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model_id': modelId,
      'provider': provider,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      id: json['id'] as String,
      name: json['name'] as String,
      modelId: json['model_id'] as String,
      provider: json['provider'] as String? ?? 'openrouter',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Model copyWith({
    String? id,
    String? name,
    String? modelId,
    String? provider,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Model(
      id: id ?? this.id,
      name: name ?? this.name,
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

