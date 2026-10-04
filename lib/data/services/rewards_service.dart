// lib/data/services/rewards_service.dart

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

/// The result of one _rollReward_ call — what to actually show the
/// person as feedback for a single correct answer.
class RewardResult {
  final int baseXp;
  final int bonusXp;
  final bool isLucky;

  /// Non-null only on the (rarer) roll that also triggers a mystery
  /// box reveal — either a newly-unlocked theme id, or null if every
  /// theme was already unlocked (in which case [jackpotXp] is set
  /// instead, so the reward never "runs dry" once cosmetics are all
  /// collected).
  final String? unlockedThemeId;
  final int? jackpotXp;

  const RewardResult({
    required this.baseXp,
    required this.bonusXp,
    required this.isLucky,
    this.unlockedThemeId,
    this.jackpotXp,
  });

  int get totalXp => baseXp + bonusXp + (jackpotXp ?? 0);
  bool get isMysteryBox => unlockedThemeId != null || jackpotXp != null;
}

/// Variable-reward system: XP with a randomized "lucky bonus" on some
/// correct answers, plus an occasional mystery-box reveal that unlocks
/// a cosmetic color theme (see AppColors.unlockableThemes). All state
/// lives in its OWN independent SharedPreferences key namespace
/// ('rewards_*') — deliberately not touching prefs_service.dart, so
/// this file can be dropped in without needing changes to a file
/// that's already been modified locally for the streak feature.
///
/// Deliberately NOT a gambling-style mechanic: every "roll" still
/// guarantees the base XP; the randomness only ever ADDS on top,
/// never withholds or takes away. Nothing here uses real-money stakes,
/// loss framing, or artificial scarcity — it's simple positive-surprise
/// variability, the same category of mechanic as a game giving bonus
/// points for a good move, not a slot machine.
class RewardsService {
  static const _kTotalXp = 'rewards_total_xp';
  static const _kUnlockedThemes = 'rewards_unlocked_themes';
  static const _kActiveTheme = 'rewards_active_theme';

  static const int _baseXpPerCorrect = 10;
  static const double _luckyChance = 0.20; // 1 in 5 correct answers
  static const double _mysteryBoxChance = 0.06; // ~1 in 17 correct answers

  final Random _random;

  RewardsService({Random? random}) : _random = random ?? Random();

  Future<int> get totalXp async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kTotalXp) ?? 0;
  }

  Future<Set<String>> get unlockedThemeIds async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kUnlockedThemes) ?? const []).toSet();
  }

  Future<String?> get activeThemeId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveTheme);
  }

  /// Sets which unlocked theme is currently applied app-wide, or null
  /// to fall back to the normal light/dark mode. Does nothing if
  /// [themeId] isn't actually unlocked yet — call unlockedThemeIds
  /// first if you need to validate before offering a picker.
  Future<void> setActiveTheme(String? themeId) async {
    final prefs = await SharedPreferences.getInstance();
    if (themeId == null) {
      await prefs.remove(_kActiveTheme);
      return;
    }
    final unlocked = await unlockedThemeIds;
    if (!unlocked.contains(themeId)) return;
    await prefs.setString(_kActiveTheme, themeId);
  }

  /// Call this once per correct answer. Always awards at least
  /// [_baseXpPerCorrect] — the randomness only ever adds on top, never
  /// reduces or withholds the guaranteed base reward (see class doc
  /// for why that distinction matters).
  Future<RewardResult> rollForCorrectAnswer() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTotal = prefs.getInt(_kTotalXp) ?? 0;

    final isLucky = _random.nextDouble() < _luckyChance;
    final bonusXp = isLucky ? 5 + _random.nextInt(16) : 0; // +5..+20

    String? unlockedThemeId;
    int? jackpotXp;
    if (_random.nextDouble() < _mysteryBoxChance) {
      final unlocked = (prefs.getStringList(_kUnlockedThemes) ?? const []).toSet();
      final locked = AppColors.unlockableThemes.keys
          .where((id) => !unlocked.contains(id))
          .toList();
      if (locked.isNotEmpty) {
        unlockedThemeId = locked[_random.nextInt(locked.length)];
        await prefs.setStringList(
          _kUnlockedThemes,
          {...unlocked, unlockedThemeId}.toList(),
        );
      } else {
        // Everything already unlocked — keep the mystery box exciting
        // by turning it into a bigger XP jackpot instead of doing
        // nothing.
        jackpotXp = 40 + _random.nextInt(41); // +40..+80
      }
    }

    final result = RewardResult(
      baseXp: _baseXpPerCorrect,
      bonusXp: bonusXp,
      isLucky: isLucky,
      unlockedThemeId: unlockedThemeId,
      jackpotXp: jackpotXp,
    );

    await prefs.setInt(_kTotalXp, currentTotal + result.totalXp);
    return result;
  }
}