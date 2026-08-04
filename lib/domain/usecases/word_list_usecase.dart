// lib/domain/usecases/word_list_usecase.dart

import '../../core/constants/supported_languages.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/services/dictionary_service.dart';
import '../../data/services/pronunciation_service.dart';

/// One row of the Word List page's 4-column table, for a single unique
/// word appearing in the block about to be read.
class WordListRow {
  /// The Greek word as it appears in the source text — trailing
  /// punctuation stripped, original case/accents preserved (e.g. "Ἐν",
  /// "Λόγος"). Display text, not a lookup key.
  final String greek;

  /// The existing syllabified Koine phonetic spelling (e.g. "lo-gos"),
  /// from PronunciationService.getPair(...).koineGreek. Display-only —
  /// no audio. See project handoff doc's Pronunciation System section:
  /// Koine-specific TTS was tried and explicitly rejected for this
  /// project; only the display spelling survives.
  final String pronunciation;

  /// "Literal Translation" — DictionaryService's existing, unmodified
  /// primary gloss for this word. Empty string if not found.
  final String translation;

  /// "Other Possible Meanings" — additive-only, from
  /// DictionaryService.otherMeaningsFor(). Never replaces [translation].
  final List<String> otherMeanings;

  const WordListRow({
    required this.greek,
    required this.pronunciation,
    required this.translation,
    required this.otherMeanings,
  });
}

/// Builds the Word List page's rows for a block of verse text, shown
/// before the reader displays that block's verse content for the first
/// time (forward-progress path only). See reader_screen.dart and the
/// project handoff doc's "Word List Page" section.
class WordListUseCase {
  const WordListUseCase();

  // Same Greek-letter range used everywhere else in the app — NEVER \w.
  static final RegExp _greekCoreRe =
      RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036F]+');

  // ignore: prefer_const_constructors
  static final _dictionary = DictionaryService();
  // ignore: prefer_const_constructors
  static final _pronunciation = PronunciationService();

  /// [verseText] must be the SAME combined string reader_screen.dart
  /// already builds for the quiz and "Listen to this verse" button —
  /// block.verses.map((v) => v.text).join(' '). Do not recompute it
  /// differently here; for a multi-verse block this naturally covers
  /// every verse's words, deduped, in one pass.
  Future<List<WordListRow>> build(String verseText) async {
    final tokens = verseText.split(' ').where((t) => t.isNotEmpty).toList();

    // Dedupe by the same normalized form dictionary/vocab lookups use —
    // "no repeats" per spec — keeping first-seen display casing, in
    // order of first appearance.
    final seen = <String>{};
    final uniqueDisplayTokens = <String>[];
    for (final token in tokens) {
      final normalized = TextNormalizer.normalizeWord(token);
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) continue;
      uniqueDisplayTokens.add(token);
    }

    final rows = <WordListRow>[];
    for (final rawToken in uniqueDisplayTokens) {
      final greekCore = _greekCoreRe.stringMatch(rawToken) ?? rawToken;
      final normalized = TextNormalizer.normalizeWord(rawToken);

      final entry = await _dictionary.lookup(
        AppLanguage.readingDictionaryKey, // 'el_en' — never pairKey here
        normalized,
      );
      final translation = entry?.gloss ?? '';

      final otherMeanings = translation.isNotEmpty
          ? await _dictionary.otherMeaningsFor(
              AppLanguage.readingDictionaryKey,
              normalized,
              translation,
            )
          : const <String>[];

      final pronunciation = _pronunciation.getPair(rawToken).koineGreek;

      rows.add(WordListRow(
        greek: greekCore,
        pronunciation: pronunciation,
        translation: translation,
        otherMeanings: otherMeanings,
      ));
    }

    return rows;
  }
}