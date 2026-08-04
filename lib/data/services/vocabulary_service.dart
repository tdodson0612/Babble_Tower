// lib/data/services/vocabulary_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/word_entry.dart';

/// Persists and retrieves WordEntry objects using Hive.
///
/// Box name schema: "vocab_{pairKey}"  e.g. "vocab_en_es"
/// Each entry is stored with the word as key.

class VocabularyService {
  static const String _boxPrefix = 'vocab_';

  /// Opens (or returns cached) Hive box for the given language pair.
  Future<Box> _box(String pairKey) async {
    final name = '$_boxPrefix$pairKey';
    if (Hive.isBoxOpen(name)) return Hive.box(name);
    return Hive.openBox(name);
  }

  /// Returns all stored WordEntry objects for [pairKey].
  Future<List<WordEntry>> getAll(String pairKey) async {
    final box = await _box(pairKey);
    return box.values
        .map((raw) => _fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  /// Returns a single WordEntry by [word] for [pairKey], or null.
  Future<WordEntry?> get(String pairKey, String word) async {
    final box = await _box(pairKey);
    final raw = box.get(word);
    if (raw == null) return null;
    return _fromMap(Map<String, dynamic>.from(raw as Map));
  }

  /// Saves or updates a WordEntry.
  Future<void> save(WordEntry entry) async {
    final box = await _box(entry.languagePairKey);
    await box.put(entry.word, _toMap(entry));
  }

  /// Saves a batch of entries efficiently.
  Future<void> saveAll(List<WordEntry> entries) async {
    if (entries.isEmpty) return;
    final box = await _box(entries.first.languagePairKey);
    final map = {for (final e in entries) e.word: _toMap(e)};
    await box.putAll(map);
  }

  /// Removes a single stored entry outright. Used by
  /// MigrateCorruptedVocabUseCase to delete USFM-corrupted keys once
  /// their real content (if any) has been recovered under the correct
  /// key — not used anywhere in normal quiz/review flow, which only
  /// ever adds or updates entries.
  Future<void> delete(String pairKey, String word) async {
    final box = await _box(pairKey);
    await box.delete(word);
  }

  /// Marks a word as known and bumps mastery by 1 (max 5).
  /// Clamp raised from 3 → 5 to match isMastered threshold in
  /// word_entry.dart (masteryLevel >= 5). See project handoff doc,
  /// Mastery System section.
  Future<WordEntry> markKnown(String pairKey, String word) async {
    final existing = await get(pairKey, word);
    final updated = (existing ?? _blank(pairKey, word)).copyWith(
      known: true,
      masteryLevel: ((existing?.masteryLevel ?? 0) + 1).clamp(0, 5),
      lastReviewed: DateTime.now(),
    );
    await save(updated);
    return updated;
  }

  /// Marks a word as not known and decrements mastery by 1 (min 0).
  /// Also bumps timesWrong by 1 — this is the ONE place in the app that
  /// does so, since every "wrong" signal (verse quiz misses, review
  /// session misses, and the manual "✗ Not yet" tap) already funnels
  /// through here via VocabularyNotifier.markUnknown(). See
  /// WordEntry.timesWrong's doc for why this is tracked separately from
  /// masteryLevel.
  Future<WordEntry> markUnknown(String pairKey, String word) async {
    final existing = await get(pairKey, word);
    final updated = (existing ?? _blank(pairKey, word)).copyWith(
      known: false,
      masteryLevel: ((existing?.masteryLevel ?? 1) - 1).clamp(0, 5),
      timesWrong: (existing?.timesWrong ?? 0) + 1,
      lastReviewed: DateTime.now(),
    );
    await save(updated);
    return updated;
  }

  /// Returns only the words from [words] that exist and are known.
  Future<Set<String>> filterKnown(String pairKey, List<String> words) async {
    final box = await _box(pairKey);
    return words.where((w) {
      final raw = box.get(w);
      if (raw == null) return false;
      return (raw as Map)['known'] == true;
    }).toSet();
  }

  /// Returns mastery percentage for [words] in [pairKey].
  Future<double> masteryPercent(
      String pairKey, List<String> words) async {
    if (words.isEmpty) return 0.0;
    final box = await _box(pairKey);
    int known = 0;
    for (final w in words) {
      final raw = box.get(w);
      if (raw != null && (raw as Map)['known'] == true) known++;
    }
    return known / words.length;
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toMap(WordEntry e) => {
        'word': e.word,
        'languagePairKey': e.languagePairKey,
        'translation': e.translation,
        'known': e.known,
        'masteryLevel': e.masteryLevel,
        'timesWrong': e.timesWrong,
        'lastReviewed': e.lastReviewed.toIso8601String(),
      };

  WordEntry _fromMap(Map<String, dynamic> m) => WordEntry(
        word: m['word'] as String,
        languagePairKey: m['languagePairKey'] as String,
        translation: m['translation'] as String? ?? '',
        known: m['known'] as bool? ?? false,
        masteryLevel: m['masteryLevel'] as int? ?? 0,
        timesWrong: m['timesWrong'] as int? ?? 0,
        lastReviewed:
            DateTime.tryParse(m['lastReviewed'] as String? ?? '') ??
                DateTime.now(),
      );

  WordEntry _blank(String pairKey, String word) => WordEntry(
        word: word,
        languagePairKey: pairKey,
        translation: '',
        lastReviewed: DateTime.now(),
      );
}