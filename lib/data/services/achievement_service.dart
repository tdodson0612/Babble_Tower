// lib/data/services/achievement_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/supported_languages.dart';
import '../../domain/achievements/achievement.dart';
import '../../domain/achievements/achievement_definitions.dart';
import '../../domain/usecases/track_progress_usecase.dart';
import 'vocabulary_service.dart';
import 'prefs_service.dart';

/// Evaluates every Achievement against REAL, already-tracked app data
/// — vocabulary counts and mastery from VocabularyService, streak
/// length from PrefsService, and reading progress from
/// TrackProgressUseCase. Never a parallel/duplicate tracking system
/// that could drift out of sync with the numbers shown elsewhere in
/// the app (Vocabulary screen, Progress Dashboard, Home streak
/// banner).
///
/// Deliberately does NOT touch PrefsService's own storage — uses its
/// own independent SharedPreferences key namespace
/// ('achievement_seen_<id>') for "has this been seen/celebrated yet"
/// state, so this file can be dropped in without needing any changes
/// to prefs_service.dart.
class AchievementService {
  static const _seenKeyPrefix = 'achievement_seen_';

  final VocabularyService _vocabularyService;
  final TrackProgressUseCase _progressUseCase;

  AchievementService({
    VocabularyService? vocabularyService,
    TrackProgressUseCase? progressUseCase,
  })  : _vocabularyService = vocabularyService ?? VocabularyService(),
        _progressUseCase = progressUseCase ?? const TrackProgressUseCase();

  /// Evaluates every achievement's current progress. Call this
  /// whenever the Achievements screen opens, or after any action that
  /// could plausibly unlock something (finishing a quiz, a reading
  /// block, etc.) if you want immediate celebration rather than
  /// waiting for the next screen visit.
  Future<List<AchievementProgress>> evaluateAll() async {
    final prefs = await SharedPreferences.getInstance();

    final entries = await _vocabularyService.getAll(AppLanguage.pairKey);
    final wordsKnown = entries.where((e) => e.known).length;
    final wordsMastered = entries.where((e) => e.isMastered).length;

    final streak = PrefsService.currentStreak;

    final progress = await _progressUseCase.load(AppLanguage.pairKey);
    final blocksRead = progress.unlockedBlocks.length;

    final results = <AchievementProgress>[];
    for (final achievement in AchievementDefinitions.all) {
      final currentValue = _valueFor(
        achievement,
        wordsKnown: wordsKnown,
        wordsMastered: wordsMastered,
        streak: streak,
        blocksRead: blocksRead,
      );
      final unlocked = currentValue >= achievement.threshold;
      final alreadySeen =
          prefs.getBool('$_seenKeyPrefix${achievement.id}') ?? false;

      results.add(AchievementProgress(
        achievement: achievement,
        currentValue: currentValue,
        unlocked: unlocked,
        isNewlyUnlocked: unlocked && !alreadySeen,
      ));
    }
    return results;
  }

  int _valueFor(
    Achievement achievement, {
    required int wordsKnown,
    required int wordsMastered,
    required int streak,
    required int blocksRead,
  }) {
    switch (achievement.category) {
      case 'Vocabulary':
        return wordsKnown;
      case 'Mastery':
        return wordsMastered;
      case 'Streak':
        return streak;
      case 'Reading':
        return blocksRead;
      default:
        return 0;
    }
  }

  /// Marks an achievement as seen so it stops showing "NEW" /
  /// celebration treatment on future visits. Call this once the
  /// person has actually viewed/acknowledged a newly-unlocked
  /// achievement (e.g. when its celebration animation finishes, or
  /// when they open the Achievements screen and see it).
  Future<void> markSeen(String achievementId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenKeyPrefix$achievementId', true);
  }

  /// Convenience for a quick unread-count badge elsewhere in the app
  /// (e.g. a small number on a Home screen entry point into
  /// Achievements) without needing the full evaluated list.
  Future<int> countNewlyUnlocked() async {
    final all = await evaluateAll();
    return all.where((a) => a.isNewlyUnlocked).length;
  }
}