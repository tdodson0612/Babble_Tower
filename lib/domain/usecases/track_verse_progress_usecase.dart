// lib/domain/usecases/track_verse_progress_usecase.dart

import '../../data/models/verse_progress_model.dart';
import '../../data/services/hive_service.dart';

/// Records and retrieves per-verse quiz progress (Phase 6).
///
/// This is intentionally a SEPARATE use case from TrackProgressUseCase,
/// not an extension of it. TrackProgressUseCase owns coarse block-unlock
/// state (Set<String> of unlocked block keys) used for the verse-lock
/// navigation gate — that contract is load-bearing for reader_screen.dart
/// and is not touched here. This use case owns the finer-grained data
/// Phase 9's dashboard needs (known words, accuracy, retry count) in its
/// own Hive box, keyed per language pair via
/// HiveService.verseProgressBoxName.
class TrackVerseProgressUseCase {
  const TrackVerseProgressUseCase();

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Returns saved progress for a single verse, or a fresh model if this
  /// verse has never been attempted.
  Future<VerseProgressModel> load({
    required String pairKey,
    required String book,
    required int chapter,
    required int verseNumber,
  }) async {
    final verseKey = VerseProgressModel.buildKey(book, chapter, verseNumber);
    try {
      final box =
          await HiveService.openBox(HiveService.verseProgressBoxName(pairKey));
      final raw = box.get(verseKey);
      if (raw == null) return VerseProgressModel.fresh(verseKey);
      return VerseProgressModel.fromMap(raw as Map);
    } catch (_) {
      return VerseProgressModel.fresh(verseKey);
    }
  }

  /// Returns saved progress for every verse ever attempted in [pairKey].
  /// Used by Phase 9's dashboard to aggregate totals without loading one
  /// verse at a time.
  Future<List<VerseProgressModel>> loadAll(String pairKey) async {
    try {
      final box =
          await HiveService.openBox(HiveService.verseProgressBoxName(pairKey));
      return box.values
          .map((raw) => VerseProgressModel.fromMap(raw as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Record attempt
  // ---------------------------------------------------------------------------

  /// Records a single quiz attempt for one verse. Call this once per quiz
  /// completion (pass OR fail) — retryCount increments on every call,
  /// cumulative forever, never reset. [completed] is sticky: once a verse
  /// passes, later failed retries do not un-complete it.
  Future<VerseProgressModel> recordAttempt({
    required String pairKey,
    required String book,
    required int chapter,
    required int verseNumber,
    required Set<String> knownWords,
    required int totalWords,
    required bool passed,
    required double accuracy,
  }) async {
    final current = await load(
      pairKey: pairKey,
      book: book,
      chapter: chapter,
      verseNumber: verseNumber,
    );

    final updated = current.recordAttempt(
      knownWords: knownWords,
      totalWords: totalWords,
      passed: passed,
      accuracy: accuracy,
    );

    await _persist(pairKey, updated);
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clears all per-verse progress for [pairKey]. Mirrors
  /// TrackProgressUseCase.reset's box-delete pattern, but operates on the
  /// separate verse-progress box only — does not touch
  /// reading_progress or any vocabulary box.
  Future<void> reset(String pairKey) async {
    await HiveService.clearBox(HiveService.verseProgressBoxName(pairKey));
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _persist(String pairKey, VerseProgressModel model) async {
    final box =
        await HiveService.openBox(HiveService.verseProgressBoxName(pairKey));
    await box.put(model.verseKey, model.toMap());
  }
}