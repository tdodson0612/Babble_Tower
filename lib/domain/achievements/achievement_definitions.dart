// lib/domain/achievements/achievement_definitions.dart

import 'achievement.dart';

/// Fixed list of every achievement in the app. Four categories, each
/// with an escalating threshold ladder — a common, proven game-design
/// pattern (bronze/silver/gold/platinum tiers within a category) that
/// gives both quick early wins and long-term goals.
///
/// All thresholds are checked against REAL data already tracked
/// elsewhere in the app (see AchievementService) — never invented or
/// duplicated tracking.
class AchievementDefinitions {
  static const List<Achievement> all = [
    // ── Vocabulary: total distinct words encountered/known ──────────
    Achievement(
      id: 'vocab_10',
      category: 'Vocabulary',
      title: 'First Words',
      description: 'Learn 10 Greek words',
      threshold: 10,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'vocab_50',
      category: 'Vocabulary',
      title: 'Building Blocks',
      description: 'Learn 50 Greek words',
      threshold: 50,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'vocab_100',
      category: 'Vocabulary',
      title: 'Growing Vocabulary',
      description: 'Learn 100 Greek words',
      threshold: 100,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'vocab_250',
      category: 'Vocabulary',
      title: 'Word Collector',
      description: 'Learn 250 Greek words',
      threshold: 250,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'vocab_500',
      category: 'Vocabulary',
      title: 'Lexicon Master',
      description: 'Learn 500 Greek words',
      threshold: 500,
      tier: AchievementTier.platinum,
    ),

    // ── Mastery: words fully mastered (WordEntry.isMastered) ────────
    Achievement(
      id: 'mastery_10',
      category: 'Mastery',
      title: 'Getting Fluent',
      description: 'Fully master 10 words',
      threshold: 10,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'mastery_50',
      category: 'Mastery',
      title: 'Confident Reader',
      description: 'Fully master 50 words',
      threshold: 50,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'mastery_100',
      category: 'Mastery',
      title: 'Greek Scholar',
      description: 'Fully master 100 words',
      threshold: 100,
      tier: AchievementTier.gold,
    ),

    // ── Streak: consecutive days studied (PrefsService.currentStreak) ─
    Achievement(
      id: 'streak_3',
      category: 'Streak',
      title: 'Warming Up',
      description: 'Study 3 days in a row',
      threshold: 3,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'streak_7',
      category: 'Streak',
      title: 'One Week Strong',
      description: 'Study 7 days in a row',
      threshold: 7,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'streak_30',
      category: 'Streak',
      title: 'Habit Formed',
      description: 'Study 30 days in a row',
      threshold: 30,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'streak_100',
      category: 'Streak',
      title: 'Unstoppable',
      description: 'Study 100 days in a row',
      threshold: 100,
      tier: AchievementTier.platinum,
    ),

    // ── Reading: blocks of Scripture unlocked (ReadingProgressModel) ─
    Achievement(
      id: 'reading_10',
      category: 'Reading',
      title: 'First Steps',
      description: 'Read 10 passages',
      threshold: 10,
      tier: AchievementTier.bronze,
    ),
    Achievement(
      id: 'reading_50',
      category: 'Reading',
      title: 'Steady Reader',
      description: 'Read 50 passages',
      threshold: 50,
      tier: AchievementTier.silver,
    ),
    Achievement(
      id: 'reading_100',
      category: 'Reading',
      title: 'Devoted Reader',
      description: 'Read 100 passages',
      threshold: 100,
      tier: AchievementTier.gold,
    ),
    Achievement(
      id: 'reading_250',
      category: 'Reading',
      title: 'Gospel Journey',
      description: 'Read 250 passages',
      threshold: 250,
      tier: AchievementTier.platinum,
    ),
  ];
}