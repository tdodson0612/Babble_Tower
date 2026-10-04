// lib/domain/achievements/achievement.dart

/// A single achievement definition. Achievements are evaluated live
/// against real, already-tracked app data (vocabulary counts, streak
/// length, reading progress) — never a separate, parallel tracking
/// system that could drift out of sync with the actual numbers shown
/// elsewhere in the app.
class Achievement {
  final String id;
  final String category;
  final String title;
  final String description;
  final int threshold;

  /// Which visual tier this achievement renders as — purely cosmetic,
  /// escalates with threshold size within a category (see
  /// AchievementDefinitions for the actual tier assignment per entry).
  final AchievementTier tier;

  const Achievement({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.threshold,
    required this.tier,
  });
}

enum AchievementTier { bronze, silver, gold, platinum }

/// The live evaluation result for one achievement: whether it's
/// unlocked given the current stat value, and whether the person has
/// already seen it unlock (vs. just-unlocked-this-session, which
/// triggers celebration treatment).
class AchievementProgress {
  final Achievement achievement;
  final int currentValue;
  final bool unlocked;
  final bool isNewlyUnlocked;

  const AchievementProgress({
    required this.achievement,
    required this.currentValue,
    required this.unlocked,
    required this.isNewlyUnlocked,
  });

  double get progressFraction =>
      achievement.threshold == 0
          ? 1.0
          : (currentValue / achievement.threshold).clamp(0.0, 1.0);
}