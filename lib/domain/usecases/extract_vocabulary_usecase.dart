// lib/domain/usecases/extract_vocabulary_usecase.dart

import '../entities/verse_block.dart';
import '../entities/word_entry.dart';
import '../../data/services/vocabulary_service.dart';

/// Extracts vocabulary from a VerseBlock, compares against known words,
/// and returns a categorized result for the UI to consume.
class ExtractVocabularyUseCase {
  final VocabularyService _vocabularyService;

  const ExtractVocabularyUseCase(this._vocabularyService);

  Future<ExtractVocabularyResult> call({
    required VerseBlock block,
    required String languagePairKey,
  }) async {
    try {
      final allWords = block.words;

      // Get which words are already known
      final knownSet = await _vocabularyService.filterKnown(
        languagePairKey,
        allWords,
      );

      // Split into new vs known
      final newWords =
          allWords.where((w) => !knownSet.contains(w)).toList();
      final knownWords = allWords.where(knownSet.contains).toList();

      // Load full entries for words we already have stored
      final storedEntries = <String, WordEntry>{};
      for (final word in allWords) {
        final entry =
            await _vocabularyService.get(languagePairKey, word);
        if (entry != null) storedEntries[word] = entry;
      }

      final mastery = knownWords.length / allWords.length;

      return ExtractVocabularyResult.success(
        allWords: allWords,
        newWords: newWords,
        knownWords: knownWords.toSet(),
        storedEntries: storedEntries,
        masteryPercent: mastery,
      );
    } catch (e) {
      return ExtractVocabularyResult.failure(
        'Failed to extract vocabulary: $e',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

class ExtractVocabularyResult {
  final bool success;
  final List<String> allWords;
  final List<String> newWords;
  final Set<String> knownWords;
  final Map<String, WordEntry> storedEntries;
  final double masteryPercent;
  final String? errorMessage;

  const ExtractVocabularyResult._({
    required this.success,
    required this.allWords,
    required this.newWords,
    required this.knownWords,
    required this.storedEntries,
    required this.masteryPercent,
    this.errorMessage,
  });

  factory ExtractVocabularyResult.success({
    required List<String> allWords,
    required List<String> newWords,
    required Set<String> knownWords,
    required Map<String, WordEntry> storedEntries,
    required double masteryPercent,
  }) =>
      ExtractVocabularyResult._(
        success: true,
        allWords: allWords,
        newWords: newWords,
        knownWords: knownWords,
        storedEntries: storedEntries,
        masteryPercent: masteryPercent,
      );

  factory ExtractVocabularyResult.failure(String message) =>
      ExtractVocabularyResult._(
        success: false,
        allWords: const [],
        newWords: const [],
        knownWords: const {},
        storedEntries: const {},
        masteryPercent: 0.0,
        errorMessage: message,
      );

  bool get canProceed => masteryPercent >= 0.8;
}