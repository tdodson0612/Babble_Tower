// lib/data/models/user_profile_model.dart

/// Hive-persisted user profile.
///
/// Babble Tower now teaches a single fixed language pair (English
/// speakers reading Koine Greek), so language codes are no longer
/// part of the user's choices — only onboarding/alphabet completion
/// state is tracked here.
class UserProfileModel {
  final bool hasCompletedAlphabet;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfileModel({
    this.hasCompletedAlphabet = false,
    this.hasCompletedOnboarding = false,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfileModel copyWith({
    bool? hasCompletedAlphabet,
    bool? hasCompletedOnboarding,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      hasCompletedAlphabet:
          hasCompletedAlphabet ?? this.hasCompletedAlphabet,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'hasCompletedAlphabet': hasCompletedAlphabet,
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserProfileModel.fromMap(Map<dynamic, dynamic> m) =>
      UserProfileModel(
        hasCompletedAlphabet:
            m['hasCompletedAlphabet'] as bool? ?? false,
        hasCompletedOnboarding:
            m['hasCompletedOnboarding'] as bool? ?? false,
        createdAt: DateTime.tryParse(
              m['createdAt'] as String? ?? '',
            ) ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(
              m['updatedAt'] as String? ?? '',
            ) ??
            DateTime.now(),
      );

  /// Creates a brand-new profile for first launch.
  factory UserProfileModel.fresh() {
    final now = DateTime.now();
    return UserProfileModel(
      createdAt: now,
      updatedAt: now,
    );
  }
}