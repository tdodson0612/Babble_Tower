// lib/domain/usecases/track_parsing_progress_usecase.dart

import '../../data/models/parsing_progress_model.dart';
import '../../data/services/hive_service.dart';

/// Records and retrieves grammar-parsing accuracy by category (Phase 10).
/// A SEPARATE use case from TrackVerseProgressUseCase, same reasoning as
/// that class's own doc comment: different data, different Hive box,
/// different question the dashboard is answering. Does not touch
/// reading_progress or verse_progress boxes.
class TrackParsingProgressUseCase {
  const TrackParsingProgressUseCase();

  static const _key = 'aggregate';

  /// Returns saved parsing-accuracy stats for [pairKey], or a fresh
  /// (empty) model if grammar parsing has never been attempted.
  Future<ParsingProgressModel> load(String pairKey) async {
    try {
      final box = await HiveService.openBox(
          HiveService.parsingProgressBoxName(pairKey));
      final raw = box.get(_key);
      if (raw == null) return ParsingProgressModel.fresh();
      return ParsingProgressModel.fromMap(raw as Map);
    } catch (_) {
      return ParsingProgressModel.fresh();
    }
  }

  /// Records one answered grammar-parsing question. Call this once per
  /// GrammarParsingQuestion answer — mirrors how mastery updates fire
  /// once per vocabulary question in verse_quiz_screen.dart.
  Future<ParsingProgressModel> recordAnswer({
    required String pairKey,
    required String categoryName,
    required bool correct,
  }) async {
    final current = await load(pairKey);
    final updated = current.recordAnswer(categoryName, correct);
    final box = await HiveService.openBox(
        HiveService.parsingProgressBoxName(pairKey));
    await box.put(_key, updated.toMap());
    return updated;
  }

  /// Clears all parsing-accuracy stats for [pairKey]. Mirrors
  /// TrackVerseProgressUseCase.reset's pattern.
  Future<void> reset(String pairKey) async {
    await HiveService.clearBox(HiveService.parsingProgressBoxName(pairKey));
  }
}