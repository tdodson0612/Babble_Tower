// lib/domain/usecases/track_grammar_lesson_progress_usecase.dart

import '../../data/models/grammar_lesson_progress_model.dart';
import '../../data/services/hive_service.dart';

/// Records and retrieves per-grammar-value "last taught" timestamps for
/// the Grammar lesson (project handoff doc's Grammar cluster, items 3
/// and 4 — originally case-only, now generalized to all five
/// GrammarCategory dimensions). A separate use case from
/// TrackParsingProgressUseCase — different data, different Hive box,
/// different question being answered — see GrammarLessonProgressModel's
/// doc. Replaces the retired TrackCaseLessonProgressUseCase.
class TrackGrammarLessonProgressUseCase {
  const TrackGrammarLessonProgressUseCase();

  static const _key = 'aggregate';

  /// Box name constructed directly here (same "{feature}_{pairKey}"
  /// convention as parsingProgressBoxName) rather than adding a new
  /// named helper to HiveService.
  static String _boxName(String pairKey) =>
      'grammar_lesson_progress_$pairKey';

  Future<GrammarLessonProgressModel> load(String pairKey) async {
    try {
      final box = await HiveService.openBox(_boxName(pairKey));
      final raw = box.get(_key);
      if (raw == null) return GrammarLessonProgressModel.fresh();
      return GrammarLessonProgressModel.fromMap(raw as Map);
    } catch (_) {
      return GrammarLessonProgressModel.fresh();
    }
  }

  /// Given every "categoryName:code" key present in the current verse
  /// (see grammarKey() in grammar_lesson_engine.dart), returns only the
  /// ones that are due (never taught, or 7+ days since last taught).
  Future<List<String>> dueKeys(
    String pairKey,
    Iterable<String> keysInVerse,
  ) async {
    final progress = await load(pairKey);
    final now = DateTime.now();
    return keysInVerse.where((k) => progress.isDue(k, now)).toList();
  }

  /// Call once, when a Grammar-lesson session completes, with every key
  /// it actually taught — resets the weekly clock for exactly those
  /// values, and no others.
  Future<void> recordTaught(String pairKey, Iterable<String> keys) async {
    if (keys.isEmpty) return;
    final current = await load(pairKey);
    final updated = current.recordTaught(keys, DateTime.now());
    final box = await HiveService.openBox(_boxName(pairKey));
    await box.put(_key, updated.toMap());
  }

  /// Clears all grammar-lesson-taught timestamps for [pairKey]. Mirrors
  /// TrackParsingProgressUseCase.reset's pattern.
  Future<void> reset(String pairKey) async {
    await HiveService.clearBox(_boxName(pairKey));
  }
}