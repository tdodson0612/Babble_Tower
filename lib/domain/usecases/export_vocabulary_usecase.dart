// lib/domain/usecases/export_vocabulary_usecase.dart

import '../entities/word_entry.dart';

/// Builds CSV content from the user's vocabulary. Pure — no file I/O,
/// no platform channels — so it's independently testable, same reasoning
/// as QuizEngine staying UI/Hive-free. Actual file writing + sharing
/// lives in ExportService (data layer), which calls this first.
class ExportVocabularyUseCase {
  const ExportVocabularyUseCase();

  static const _header =
      'Greek Word,Translation,Definition,Lemma,Known,Mastery Level,Last Reviewed';

  /// One row per WordEntry, in the order given — callers typically pass
  /// entries sorted however the vocabulary screen is currently sorted,
  /// so the export matches what the user was just looking at.
  String buildCsv(List<WordEntry> entries) {
    final buffer = StringBuffer()..writeln(_header);
    for (final e in entries) {
      buffer.writeln([
        _escape(e.word),
        _escape(e.translation),
        _escape(e.definition),
        _escape(e.lemma),
        e.known ? 'Yes' : 'No',
        e.masteryLevel.toString(),
        e.lastReviewed.toIso8601String(),
      ].join(','));
    }
    return buffer.toString();
  }

  /// Standard CSV quoting: wrap in quotes and double up any embedded
  /// quotes whenever a field contains a comma, quote, or newline.
  /// Greek text itself never needs escaping — only English glosses
  /// occasionally contain commas (e.g. "love, affection").
  String _escape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}