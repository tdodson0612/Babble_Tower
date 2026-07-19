// lib/domain/usecases/spaced_repetition_usecase.dart

import '../entities/word_entry.dart';

/// Decides which vocabulary words are "due" for spaced-repetition review,
/// based on WordEntry's existing masteryLevel (0-5) and lastReviewed
/// fields — both already correctly maintained by
/// VocabularyService.markKnown/markUnknown (confirmed directly against
/// that file: +1/-1 to masteryLevel per answer, clamped 0-5,
/// lastReviewed bumped to now on every call). No new persistence is
/// needed for scheduling — this usecase is purely the "which of these
/// already-tracked words should come up for review right now" question.
///
/// Pure — no file I/O, no Hive, no platform channels — same reasoning
/// as ExportVocabularyUseCase and QuizEngine staying I/O-free.
class SpacedRepetitionUseCase {
  const SpacedRepetitionUseCase();

  /// Days until a word at a given masteryLevel comes up for review again.
  /// Increasing with mastery — the classic spaced-repetition shape.
  /// Index 5 (fully mastered, WordEntry.isMastered) still gets a
  /// 60-day "maintenance" check-in rather than never coming up again —
  /// catching slow forgetting of things you "know" is the actual point
  /// of spaced repetition, not just drilling weak words.
  static const List<int> _intervalDays = [1, 3, 7, 14, 30, 60];

  /// Returns every entry from [allWords] that's due for review right now
  /// (now >= lastReviewed + interval[masteryLevel]), ordered most-overdue
  /// first. Deliberately NOT filtered by WordEntry.known — "known" and
  /// "due for spaced-repetition review" are different concepts; even a
  /// known/mastered word benefits from the occasional check-in.
  List<WordEntry> dueWords(List<WordEntry> allWords, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();

    final due = allWords.where((e) => _isDue(e, effectiveNow)).toList();

    due.sort((a, b) {
      final aOverdueBy = effectiveNow.difference(_dueDate(a));
      final bOverdueBy = effectiveNow.difference(_dueDate(b));
      return bOverdueBy.compareTo(aOverdueBy); // most overdue first
    });

    return due;
  }

  /// Convenience for a badge/count display — avoids callers needing to
  /// build and discard the full sorted list just to show a number.
  int dueCount(List<WordEntry> allWords, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    return allWords.where((e) => _isDue(e, effectiveNow)).length;
  }

  bool _isDue(WordEntry entry, DateTime now) =>
      !now.isBefore(_dueDate(entry));

  DateTime _dueDate(WordEntry entry) {
    final level = entry.masteryLevel.clamp(0, _intervalDays.length - 1);
    return entry.lastReviewed.add(Duration(days: _intervalDays[level]));
  }
}