// lib/data/services/prefs_service.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences.
/// All keys are prefixed to avoid collisions.
class PrefsService {
  PrefsService._();

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Keys ──────────────────────────────────────────────────────────────────
  static const _kNativeCode     = 'native_code';
  static const _kTargetCode     = 'target_code';
  static const _kOnboardingDone = 'onboarding_done';
  static const _kAlphabetDone   = 'alphabet_done';

  // Streak keys (Phase 9 — streak tracking)
  static const _kStreakLastDate = 'streak_last_date';  // ISO date e.g. "2026-07-01"
  static const _kStreakCount    = 'streak_count';
  static const _kStreakLongest  = 'streak_longest';

  static String _posBook(String pair)     => 'pos_${pair}_book';
  static String _posChapter(String pair)  => 'pos_${pair}_chapter';
  static String _posBlock(String pair)    => 'pos_${pair}_block';
  static String _posHighest(String pair)  => 'pos_${pair}_highest';
  static String _unlockedKey(String pair) => 'unlocked_$pair';

  // ─── Language codes ────────────────────────────────────────────────────────
  static String? get nativeCode => _prefs.getString(_kNativeCode);
  static String? get targetCode => _prefs.getString(_kTargetCode);

  static Future<void> setNativeCode(String code) =>
      _prefs.setString(_kNativeCode, code);

  static Future<void> setTargetCode(String code) =>
      _prefs.setString(_kTargetCode, code);

  // ─── Onboarding / alphabet flags ───────────────────────────────────────────
  static bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;
  static bool get alphabetDone   => _prefs.getBool(_kAlphabetDone)   ?? false;

  static Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(_kOnboardingDone, value);

  static Future<void> setAlphabetDone(bool value) =>
      _prefs.setBool(_kAlphabetDone, value);

  // ─── Reading position ──────────────────────────────────────────────────────
  static String? lastBook({required String pairKey}) =>
      _prefs.getString(_posBook(pairKey));

  static int? lastChapter({required String pairKey}) =>
      _prefs.getInt(_posChapter(pairKey));

  static int? lastBlock({required String pairKey}) =>
      _prefs.getInt(_posBlock(pairKey));

  static int highestBlock({required String pairKey}) =>
      _prefs.getInt(_posHighest(pairKey)) ?? 0;

  static Future<void> savePosition({
    required String pairKey,
    required String book,
    required int chapter,
    required int block,
  }) async {
    await _prefs.setString(_posBook(pairKey), book);
    await _prefs.setInt(_posChapter(pairKey), chapter);
    await _prefs.setInt(_posBlock(pairKey), block);
    final current = highestBlock(pairKey: pairKey);
    if (block > current) {
      await _prefs.setInt(_posHighest(pairKey), block);
    }
  }

  // ─── Block unlock tracking ─────────────────────────────────────────────────
  static String _blockKey(String book, int chapter, int block) =>
      '$book:$chapter:$block';

  static bool isBlockUnlocked({
    required String pairKey,
    required String book,
    required int chapter,
    required int block,
  }) {
    if (block == 0) return true;
    final raw  = _prefs.getString(_unlockedKey(pairKey)) ?? '';
    final keys = raw.isEmpty ? <String>[] : raw.split(',');
    return keys.contains(_blockKey(book, chapter, block));
  }

  static Future<void> unlockBlock({
    required String pairKey,
    required String book,
    required int chapter,
    required int block,
  }) async {
    final key  = _blockKey(book, chapter, block);
    final raw  = _prefs.getString(_unlockedKey(pairKey)) ?? '';
    final keys = raw.isEmpty ? <String>{} : raw.split(',').toSet();
    if (!keys.contains(key)) {
      keys.add(key);
      await _prefs.setString(_unlockedKey(pairKey), keys.join(','));
    }
  }

  // ─── Streak tracking ───────────────────────────────────────────────────────
  //
  // Rules:
  //   - Call recordSession() once per day when any quiz is completed.
  //   - If last session was yesterday → increment streak.
  //   - If last session was today → no change (already counted).
  //   - If last session was 2+ days ago → reset to 1.
  //   - Longest streak is updated whenever current exceeds it.

  static int get currentStreak  => _prefs.getInt(_kStreakCount)   ?? 0;
  static int get longestStreak  => _prefs.getInt(_kStreakLongest) ?? 0;
  static String? get _lastDateStr => _prefs.getString(_kStreakLastDate);

  /// Records a session for today and updates the streak.
  /// Safe to call multiple times per day — only the first call counts.
  static Future<void> recordSession() async {
    final today     = _dateOnly(DateTime.now());
    final todayStr  = _formatDate(today);
    final lastStr   = _lastDateStr;

    // Already recorded today — no change.
    if (lastStr == todayStr) return;

    int newStreak;

    if (lastStr == null) {
      // First ever session.
      newStreak = 1;
    } else {
      final last = _parseDate(lastStr);
      final diff = today.difference(last).inDays;
      if (diff == 1) {
        // Consecutive day — extend streak.
        newStreak = currentStreak + 1;
      } else {
        // Gap of 2+ days — reset.
        newStreak = 1;
      }
    }

    await _prefs.setString(_kStreakLastDate, todayStr);
    await _prefs.setInt(_kStreakCount, newStreak);

    if (newStreak > longestStreak) {
      await _prefs.setInt(_kStreakLongest, newStreak);
    }
  }

  /// Resets streak data. Used when clearing all progress.
  static Future<void> resetStreak() async {
    await _prefs.remove(_kStreakLastDate);
    await _prefs.remove(_kStreakCount);
    await _prefs.remove(_kStreakLongest);
  }

  // ─── Date helpers ──────────────────────────────────────────────────────────

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  static DateTime _parseDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return DateTime(1970);
    return DateTime(
      int.tryParse(parts[0]) ?? 1970,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  // ─── Reset ─────────────────────────────────────────────────────────────────
  static Future<void> resetProgress(String pairKey) async {
    await _prefs.remove(_posBook(pairKey));
    await _prefs.remove(_posChapter(pairKey));
    await _prefs.remove(_posBlock(pairKey));
    await _prefs.remove(_posHighest(pairKey));
    await _prefs.remove(_unlockedKey(pairKey));
  }

  static Future<void> clearAll() => _prefs.clear();

  // ─── Raw access for SettingsNotifier ───────────────────────────────────────
  static Future<void> rawSetBool(String key, bool value) =>
      _prefs.setBool(key, value);

  static Future<void> rawSetDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  static bool?   rawGetBool(String key)   => _prefs.getBool(key);
  static double? rawGetDouble(String key) => _prefs.getDouble(key);
}