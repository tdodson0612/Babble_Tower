// lib/presentation/providers/vocabulary_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/supported_languages.dart';
import '../../data/services/vocabulary_service.dart';
import '../../data/services/dictionary_service.dart';
import '../../domain/entities/word_entry.dart';
import 'language_provider.dart';
import 'bible_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class VocabularyState {
  /// All WordEntry objects loaded for the current block.
  final Map<String, WordEntry> entries;

  /// Words from the current block that are new (not yet in Hive).
  final List<String> newWords;

  /// Words from the current block that are already known.
  final Set<String> knownWords;

  /// Mastery percentage for current block's words (0.0 – 1.0).
  final double blockMastery;

  final bool isLoading;
  final String? error;

  const VocabularyState({
    this.entries = const {},
    this.newWords = const [],
    this.knownWords = const {},
    this.blockMastery = 0.0,
    this.isLoading = false,
    this.error,
  });

  /// True when block mastery meets the 80% progression threshold.
  bool get canProceed => blockMastery >= 0.8;

  VocabularyState copyWith({
    Map<String, WordEntry>? entries,
    List<String>? newWords,
    Set<String>? knownWords,
    double? blockMastery,
    bool? isLoading,
    Object? error = _keep,
  }) =>
      VocabularyState(
        entries: entries ?? this.entries,
        newWords: newWords ?? this.newWords,
        knownWords: knownWords ?? this.knownWords,
        blockMastery: blockMastery ?? this.blockMastery,
        isLoading: isLoading ?? this.isLoading,
        error: error == _keep ? this.error : error as String?,
      );
}

const Object _keep = Object();

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class VocabularyNotifier extends StateNotifier<VocabularyState> {
  VocabularyNotifier(this._service, this._dictionary, this._ref)
      : super(const VocabularyState());

  final VocabularyService _service;
  final DictionaryService _dictionary;
  final Ref _ref;

  String get _pairKey => _ref.read(languageProvider).pairKey;

  // ---------------------------------------------------------------------------
  // loadForBlock
  //
  // Called whenever the reader moves to a new block. Guarantees every word
  // ends up in state.entries with a non-empty translation.
  //
  // Strategy:
  //   1. Load everything already stored in Hive for this pair.
  //   2. Identify words that need translation:
  //        a. Brand-new words (not in Hive at all), AND
  //        b. Words in Hive but with an empty translation (stale bad data).
  //   3. Bulk-lookup those words using el_en (Greek → English).
  //      Now returns DictionaryEntry objects with gloss + definition + lemma.
  //   4. For stale entries, patch and persist the fix to Hive.
  //   5. Emit a block-scoped entries map.
  // ---------------------------------------------------------------------------
  Future<void> loadForBlock(List<String> blockWords) async {
    if (blockWords.isEmpty) {
      state = const VocabularyState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final pairKey = _pairKey;

      // Step 1 — load all stored entries.
      final allStored = await _service.getAll(pairKey);
      final storedMap = <String, WordEntry>{
        for (final e in allStored) e.word: e
      };

      // Step 2 — find words needing translation.
      final needsTranslation = blockWords.where((w) {
        final stored = storedMap[w];
        return stored == null || stored.translation.isEmpty;
      }).toList();

      // Step 3 — bulk-lookup using Greek → English direction.
      if (needsTranslation.isNotEmpty) {
        final dictEntries = await _dictionary.lookupAll(
          AppLanguage.readingDictionaryKey, // 'el_en' — never pairKey here
          needsTranslation,
        );

        for (final word in needsTranslation) {
          final dictEntry = dictEntries[word];
          final gloss      = dictEntry?.gloss ?? '';
          final definition = dictEntry?.definition ?? '';
          final lemma      = dictEntry?.lemma ?? '';
          final existing   = storedMap[word];

          if (existing == null) {
            // Brand-new: create in-memory entry (Hive write deferred).
            storedMap[word] = WordEntry(
              word:            word,
              languagePairKey: pairKey,
              translation:     gloss,
              definition:      definition,
              lemma:           lemma,
              known:           false,
              masteryLevel:    0,
              lastReviewed:    DateTime.now(),
            );
          } else {
            // Step 4 — stale entry: patch and persist.
            final patched = existing.copyWith(
              translation: gloss,
              definition:  definition,
              lemma:       lemma,
            );
            storedMap[word] = patched;
            if (gloss.isNotEmpty) {
              await _service.save(patched);
            }
          }
        }
      }

      // Step 5 — block-scoped entries map.
      final blockEntries = <String, WordEntry>{
        for (final w in blockWords)
          if (storedMap.containsKey(w)) w: storedMap[w]!,
      };

      final knownWords = blockWords
          .where((w) => storedMap[w]?.known == true)
          .toSet();
      final mastery = blockWords.isEmpty
          ? 0.0
          : knownWords.length / blockWords.length;

      state = state.copyWith(
        entries:      blockEntries,
        newWords:     blockWords
            .where((w) => !(allStored.any((e) => e.word == w)))
            .toList(),
        knownWords:   knownWords,
        blockMastery: mastery,
        isLoading:    false,
        error:        null,
      );
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: '$e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // markKnown / markUnknown
  // ---------------------------------------------------------------------------

  Future<void> markKnown(String word) async {
    await _markWord(word, known: true);
  }

  Future<void> markUnknown(String word) async {
    await _markWord(word, known: false);
  }

  Future<void> _markWord(String word, {required bool known}) async {
    final pairKey            = _pairKey;
    final existing           = state.entries[word];
    final existingTranslation = existing?.translation ?? '';
    final existingDefinition  = existing?.definition  ?? '';
    final existingLemma       = existing?.lemma       ?? '';

    final updated = known
        ? await _service.markKnown(pairKey, word)
        : await _service.markUnknown(pairKey, word);

    // Re-apply in-memory fields if the service round-trip lost them.
    final withFields = updated.copyWith(
      translation: updated.translation.isEmpty ? existingTranslation : null,
      definition:  updated.definition.isEmpty  ? existingDefinition  : null,
      lemma:       updated.lemma.isEmpty       ? existingLemma       : null,
    );

    // Persist if translation was missing from Hive.
    if (existingTranslation.isNotEmpty && updated.translation.isEmpty) {
      await _service.save(withFields);
    }

    final newEntries = Map<String, WordEntry>.from(state.entries)
      ..[word] = withFields;

    final newKnown = known
        ? {...state.knownWords, word}
        : ({...state.knownWords}..remove(word));

    final blockWords =
        _ref.read(bibleProvider).currentBlock?.words ?? [];
    final mastery = blockWords.isEmpty
        ? 0.0
        : newKnown.length / blockWords.length;

    state = state.copyWith(
      entries:      newEntries,
      knownWords:   newKnown,
      blockMastery: mastery,
    );
  }

  // ---------------------------------------------------------------------------
  // setTranslation — manual override.
  // ---------------------------------------------------------------------------

  Future<void> setTranslation(String word, String translation) async {
    final pairKey = _pairKey;
    final existing = state.entries[word];
    final updated = (existing ??
            WordEntry(
              word:            word,
              languagePairKey: pairKey,
              translation:     translation,
              lastReviewed:    DateTime.now(),
            ))
        .copyWith(translation: translation);

    await _service.save(updated);

    final newEntries = Map<String, WordEntry>.from(state.entries)
      ..[word] = updated;
    state = state.copyWith(entries: newEntries);
  }

  void clearForLanguageChange() {
    _dictionary.clearCache();
    state = const VocabularyState();
  }

  WordEntry? entryFor(String word) => state.entries[word];
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final vocabularyServiceProvider =
    Provider<VocabularyService>((_) => VocabularyService());

final dictionaryServiceProvider =
    Provider<DictionaryService>((_) => DictionaryService());

final vocabularyProvider =
    StateNotifierProvider<VocabularyNotifier, VocabularyState>((ref) {
  return VocabularyNotifier(
    ref.read(vocabularyServiceProvider),
    ref.read(dictionaryServiceProvider),
    ref,
  );
});
