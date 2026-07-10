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
  // Called whenever the reader moves to a new block. Guarantees that every
  // word in [blockWords] ends up in state.entries with a non-empty English
  // translation, regardless of what is (or isn't) already in Hive.
  //
  // Strategy:
  //   1. Load everything already stored in Hive for this pair.
  //   2. Identify words that need translation:
  //        a. Brand-new words (not in Hive at all), AND
  //        b. Words in Hive but with an empty translation (stale bad data
  //           written before the dictionary-direction bug was fixed).
  //   3. Bulk-translate those words using the reading-direction dictionary
  //      (el_en — Greek → English). Never use pairKey (en_el) for lookups;
  //      that key is only the Hive storage namespace.
  //   4. For stale entries, patch translation in-memory AND persist the fix
  //      to Hive so future sessions don't repeat the lookup.
  //   5. Emit a state whose entries map contains ONLY the current block's
  //      words (not the entire Hive contents), so the UI has a clean slice.
  // ---------------------------------------------------------------------------
  Future<void> loadForBlock(List<String> blockWords) async {
    if (blockWords.isEmpty) {
      state = const VocabularyState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final pairKey = _pairKey;

      // Step 1 — load all stored entries, keyed by word.
      final allStored = await _service.getAll(pairKey);
      final storedMap = <String, WordEntry>{for (final e in allStored) e.word: e};

      // Step 2 — find words needing translation.
      final needsTranslation = blockWords.where((w) {
        final stored = storedMap[w];
        // Brand-new word, or stale entry with blank translation.
        return stored == null || stored.translation.isEmpty;
      }).toList();

      // Step 3 — bulk translate using Greek → English direction.
      if (needsTranslation.isNotEmpty) {
        final entries = await _dictionary.lookupAll(
          AppLanguage.readingDictionaryKey, // 'el_en' — never pairKey here
          needsTranslation,
        );

        for (final word in needsTranslation) {
          final dictEntry = entries[word];

          // IMPORTANT: `gloss` is the translation shown in the UI. For flat
          // JSON dictionary entries, `definition` is always '' (empty
          // string, not null), so a `definition ?? gloss` fallback chain
          // NEVER falls through to gloss and silently produces ''. Use
          // gloss directly. See CRITICAL BUGS #2 in the project handoff doc.
          final translation = dictEntry?.gloss ?? '';
          final definition  = dictEntry?.definition ?? '';
          final lemma       = dictEntry?.lemma ?? '';
          final existing = storedMap[word];

          if (existing == null) {
            storedMap[word] = WordEntry(
              word: word,
              languagePairKey: pairKey,
              translation: translation,
              definition: definition,
              lemma: lemma,
              known: false,
              masteryLevel: 0,
              lastReviewed: DateTime.now(),
            );
          } else {
            // Step 4 — stale entry: patch translation and persist fix.
            final patched = existing.copyWith(
              translation: translation,
              definition: definition,
              lemma: lemma,
            );
            storedMap[word] = patched;
            if (translation.isNotEmpty) {
              await _service.save(patched);
            }
          }
        }
      }

      // Step 5 — build a block-scoped entries map (only current words).
      final blockEntries = <String, WordEntry>{
        for (final w in blockWords)
          if (storedMap.containsKey(w)) w: storedMap[w]!,
      };

      // Derive known set and mastery from the block slice.
      final knownWords = blockWords
          .where((w) => storedMap[w]?.known == true)
          .toSet();
      final mastery = blockWords.isEmpty
          ? 0.0
          : knownWords.length / blockWords.length;

      state = state.copyWith(
        entries: blockEntries,
        newWords: blockWords
            .where((w) => !(allStored.any((e) => e.word == w)))
            .toList(),
        knownWords: knownWords,
        blockMastery: mastery,
        isLoading: false,
        error: null,
      );
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: '$e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // markKnown / markUnknown
  //
  // Persists to Hive via the service. Preserves any in-memory translation so
  // it is never lost on the round-trip through the service layer.
  // ---------------------------------------------------------------------------

  Future<void> markKnown(String word) async {
    await _markWord(word, known: true);
  }

  Future<void> markUnknown(String word) async {
    await _markWord(word, known: false);
  }

  Future<void> _markWord(String word, {required bool known}) async {
    final pairKey = _pairKey;
    final existingTranslation = state.entries[word]?.translation ?? '';

    final updated = known
        ? await _service.markKnown(pairKey, word)
        : await _service.markUnknown(pairKey, word);

    // Re-apply in-memory translation if the service lost it.
    final withTranslation =
        existingTranslation.isNotEmpty && updated.translation.isEmpty
            ? updated.copyWith(translation: existingTranslation)
            : updated;

    // Persist the translation if the service entry was missing it.
    if (existingTranslation.isNotEmpty && updated.translation.isEmpty) {
      await _service.save(withTranslation);
    }

    final newEntries = Map<String, WordEntry>.from(state.entries)
      ..[word] = withTranslation;

    final newKnown = known
        ? {...state.knownWords, word}
        : ({...state.knownWords}..remove(word));

    final blockWords = _ref.read(bibleProvider).currentBlock?.words ?? [];
    final mastery = blockWords.isEmpty
        ? 0.0
        : newKnown.length / blockWords.length;

    state = state.copyWith(
      entries: newEntries,
      knownWords: newKnown,
      blockMastery: mastery,
    );
  }

  // ---------------------------------------------------------------------------
  // setTranslation — manual override, persists immediately.
  // ---------------------------------------------------------------------------

  Future<void> setTranslation(String word, String translation) async {
    final pairKey = _pairKey;
    final existing = state.entries[word];
    final updated = (existing ??
            WordEntry(
              word: word,
              languagePairKey: pairKey,
              translation: translation,
              lastReviewed: DateTime.now(),
            ))
        .copyWith(translation: translation);

    await _service.save(updated);

    final newEntries = Map<String, WordEntry>.from(state.entries)
      ..[word] = updated;
    state = state.copyWith(entries: newEntries);
  }

  // ---------------------------------------------------------------------------
  // clearForLanguageChange — not currently reachable (fixed language pair)
  // but kept for safety.
  // ---------------------------------------------------------------------------

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