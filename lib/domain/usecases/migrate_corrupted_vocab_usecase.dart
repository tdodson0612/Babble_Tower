// lib/domain/usecases/migrate_corrupted_vocab_usecase.dart

import '../../data/services/vocabulary_service.dart';
import '../entities/word_entry.dart';

/// Summary returned after running [MigrateCorruptedVocabUseCase.run],
/// for a confirmation message in the Settings UI.
class VocabMigrationResult {
  /// Total vocabulary entries scanned for this pairKey.
  final int totalScanned;

  /// Corrupted entries (real word + fused trailing "w") successfully
  /// merged back into their correct key.
  final int wordsFixed;

  /// Pure-garbage entries (e.g. "w", "it") deleted outright — no real
  /// word to recover from these.
  final int garbageDeleted;

  /// Entries that contained a Latin letter but didn't match the one
  /// recognized corruption shape — left untouched rather than guessed
  /// at, and worth a manual look if this is ever non-zero.
  final int skippedUnrecognized;

  const VocabMigrationResult({
    required this.totalScanned,
    required this.wordsFixed,
    required this.garbageDeleted,
    required this.skippedUnrecognized,
  });

  int get totalChanged => wordsFixed + garbageDeleted;
  bool get hadAnyCorruption => totalChanged > 0 || skippedUnrecognized > 0;
}

/// One-time cleanup for vocabulary entries corrupted by the USFM
/// word-linking markup bug (see bible_service.dart's _stripUsfmMarkup
/// doc for the full root-cause explanation). Before that fix shipped,
/// TextNormalizer's a-zA-Z allowance let residual \+w/\+w* tag remnants
/// survive into stored Hive keys — either as pure-garbage single-token
/// entries ("w" from the opening tag, "it" from the stray milestone
/// marker) or as a real word with a Latin "w" fused onto its end (from
/// the closing tag, which sits directly against the word with no
/// space) — e.g. "κατασκευάσει" got stored as "κατασκευάσειw".
///
/// Detection is unambiguous and safe: this app's real vocabulary words
/// are always pure Greek script — the shared punctuation-stripping
/// regex (TextNormalizer / DictionaryService / this file) never lets a
/// Latin letter into a legitimate stored word. So ANY stored word
/// containing a Latin letter is guaranteed to be a bug artifact, never
/// a false positive on real data.
///
/// Deliberately a manual, explicit action (see settings_screen.dart's
/// "Clean Up Corrupted Vocabulary" tile) rather than an automatic
/// silent migration on next launch — this mutates and deletes real
/// Hive data, so it follows the same confirm-before-destructive-action
/// pattern the project already uses for Restore.
class MigrateCorruptedVocabUseCase {
  MigrateCorruptedVocabUseCase({VocabularyService? service})
      : _service = service ?? VocabularyService();

  final VocabularyService _service;

  // Same Greek-letter range used everywhere else in the app.
  static final RegExp _hasGreekRe =
      RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036F]');
  static final RegExp _hasLatinLetterRe = RegExp(r'[A-Za-z]');
  static final RegExp _trailingLatinWRe = RegExp(r'w+$');

  Future<VocabMigrationResult> run(String pairKey) async {
    final all = await _service.getAll(pairKey);
    final byWord = {for (final e in all) e.word: e};

    final toDeleteKeys = <String>{};
    // clean word -> merged entry so far. Seeded lazily below with
    // whatever real clean entry already exists, then folded together
    // with each corrupted variant found.
    final pending = <String, WordEntry>{};

    var garbageDeleted = 0;
    var wordsFixed = 0;
    var skippedUnrecognized = 0;

    for (final entry in all) {
      if (!_hasLatinLetterRe.hasMatch(entry.word)) continue; // already clean

      if (!_hasGreekRe.hasMatch(entry.word)) {
        // Entirely non-Greek — pure garbage artifact ("w", "it", etc.),
        // nothing real to recover.
        toDeleteKeys.add(entry.word);
        garbageDeleted++;
        continue;
      }

      if (!_trailingLatinWRe.hasMatch(entry.word)) {
        // Has Latin letters but not in the one recognized shape
        // (trailing "w" fused onto a real Greek word) — leave alone
        // rather than guessing at unfamiliar corruption.
        skippedUnrecognized++;
        continue;
      }

      final cleanWord = entry.word.replaceAll(_trailingLatinWRe, '');
      if (cleanWord.isEmpty) {
        // Somehow all-"w" with no Greek core despite the earlier Greek
        // check — treat as garbage rather than writing an empty key.
        toDeleteKeys.add(entry.word);
        garbageDeleted++;
        continue;
      }

      final base = pending[cleanWord] ?? byWord[cleanWord];
      pending[cleanWord] = _mergeEntries(cleanWord, pairKey, base, entry);
      toDeleteKeys.add(entry.word);
      wordsFixed++;
    }

    // Save merged/recovered entries first, then delete the old
    // corrupted keys — safe in either order since a corrupted key
    // (contains a Latin letter) can never collide with a clean key
    // (never contains one).
    if (pending.isNotEmpty) {
      await _service.saveAll(pending.values.toList());
    }
    for (final key in toDeleteKeys) {
      await _service.delete(pairKey, key);
    }

    return VocabMigrationResult(
      totalScanned: all.length,
      wordsFixed: wordsFixed,
      garbageDeleted: garbageDeleted,
      skippedUnrecognized: skippedUnrecognized,
    );
  }

  /// Combines a corrupted entry's stats with whatever's already stored
  /// under the clean key (if anything). Conservative merge — never
  /// throws away progress:
  ///   - known:        OR (known under either key counts as known)
  ///   - masteryLevel:  MAX (never regress progress)
  ///   - timesWrong:    SUM (both are real wrong-answer counts for the
  ///                    same underlying word, split across two keys by
  ///                    the bug)
  ///   - lastReviewed:  most recent of the two
  ///   - translation:   prefer the clean entry's (looked up under the
  ///                    correct dictionary key) unless it's empty
  WordEntry _mergeEntries(
    String cleanWord,
    String pairKey,
    WordEntry? existingClean,
    WordEntry corrupted,
  ) {
    if (existingClean == null) {
      // No existing clean entry — recreate this one under the correct
      // key, stats untouched.
      return WordEntry(
        word: cleanWord,
        languagePairKey: pairKey,
        translation: corrupted.translation,
        definition: corrupted.definition,
        lemma: corrupted.lemma,
        known: corrupted.known,
        masteryLevel: corrupted.masteryLevel,
        timesWrong: corrupted.timesWrong,
        lastReviewed: corrupted.lastReviewed,
      );
    }

    return existingClean.copyWith(
      translation: existingClean.translation.isNotEmpty
          ? existingClean.translation
          : corrupted.translation,
      known: existingClean.known || corrupted.known,
      masteryLevel: existingClean.masteryLevel > corrupted.masteryLevel
          ? existingClean.masteryLevel
          : corrupted.masteryLevel,
      timesWrong: existingClean.timesWrong + corrupted.timesWrong,
      lastReviewed: existingClean.lastReviewed.isAfter(corrupted.lastReviewed)
          ? existingClean.lastReviewed
          : corrupted.lastReviewed,
    );
  }
}