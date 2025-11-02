class UserProfile {
  final String id;
  final String? avatarUrl;
  final String? displayName;
  final DateTime? dateOfBirth;
  final String? preferredLanguage;
  final bool onboardingCompleted;
  final List<String> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.avatarUrl,
    this.displayName,
    this.dateOfBirth,
    this.preferredLanguage,
    this.onboardingCompleted = false,
    this.preferences = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create UserProfile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      avatarUrl: json['avatar_url'] as String?,
      displayName: json['display_name'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      preferredLanguage: json['preferred_language'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      preferences: json['preferences'] != null
          ? List<String>.from(json['preferences'] as List)
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert UserProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatar_url': avatarUrl,
      'display_name': displayName,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'preferred_language': preferredLanguage,
      'onboarding_completed': onboardingCompleted,
      'preferences': preferences,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? avatarUrl,
    String? displayName,
    DateTime? dateOfBirth,
    String? preferredLanguage,
    bool? onboardingCompleted,
    List<String>? preferences,
  }) {
    return UserProfile(
      id: id,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

