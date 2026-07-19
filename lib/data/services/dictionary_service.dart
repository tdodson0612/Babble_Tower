// lib/data/services/dictionary_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';

/// Holds a single dictionary entry, supporting both the old flat-string
/// format and the new {gloss, definition, lemma} object format from
/// MorphGNT/Dodson.
class DictionaryEntry {
  final String gloss;
  final String definition;
  final String lemma;

  const DictionaryEntry({
    required this.gloss,
    this.definition = '',
    this.lemma = '',
  });
}

class DictionaryService {
  final Map<String, Map<String, DictionaryEntry>> _cache = {};

  /// bareGreekForm -> every distinct comma-separated meaning found
  /// across ALL dictionary keys that share that bare form (e.g.
  /// "λόγος", "λόγος,", "λόγος.", "λόγος⸃" all share the bare form
  /// "λόγος" and get merged into one entry here). Built once per
  /// pairKey, lazily, alongside [_cache]. See [otherMeaningsFor]'s doc
  /// for why this exists and why it's used additively, not as a
  /// replacement for the primary lookup.
  final Map<String, Map<String, Set<String>>> _meaningsByBareForm = {};

  static const Set<String> _availablePairs = {'en_el', 'el_en'};

  /// Same Greek-letter range the app uses everywhere else — NEVER \w.
  /// See handoff doc's "Greek regex" critical rule. Used here to find
  /// each dictionary key's "bare form" — the same core substring
  /// TextNormalizer.normalizeWord() would produce for lookup purposes,
  /// stripped of trailing punctuation/critical-apparatus marks (which
  /// is exactly why "λόγος" and "λόγος," currently resolve to
  /// DIFFERENT, inconsistently-populated gloss strings today).
  static final RegExp _greekCoreRe =
      RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036F]+');

  String _greekCore(String s) => _greekCoreRe.stringMatch(s) ?? '';

  /// Returns the short gloss for [word], or null if not found.
  Future<String?> translate(String pairKey, String word) async {
    final entry = await lookup(pairKey, word);
    return entry?.gloss;
  }

  /// Returns the full DictionaryEntry for [word], or null if not found.
  Future<DictionaryEntry?> lookup(String pairKey, String word) async {
    if (!_availablePairs.contains(pairKey)) return null;
    final dict = await _load(pairKey);
    return dict[word.toLowerCase()];
  }

  /// Bulk-translates a list of words. Returns { word → gloss } for found
  /// words.
  Future<Map<String, String>> translateAll(
    String pairKey,
    List<String> words,
  ) async {
    if (!_availablePairs.contains(pairKey) || words.isEmpty) return {};
    final dict = await _load(pairKey);
    final result = <String, String>{};
    for (final word in words) {
      final entry = dict[word.toLowerCase()];
      if (entry != null) result[word] = entry.gloss;
    }
    return result;
  }

  /// Bulk-lookup returning full DictionaryEntry objects.
  Future<Map<String, DictionaryEntry>> lookupAll(
    String pairKey,
    List<String> words,
  ) async {
    if (!_availablePairs.contains(pairKey) || words.isEmpty) return {};
    final dict = await _load(pairKey);
    final result = <String, DictionaryEntry>{};
    for (final word in words) {
      final entry = dict[word.toLowerCase()];
      if (entry != null) result[word] = entry;
    }
    return result;
  }

  /// Returns any ADDITIONAL distinct meanings for [word] beyond what's
  /// already in [primaryGloss], found among OTHER dictionary keys that
  /// share the same bare Greek core (e.g. "λόγος", "λόγος,", "λόγος.",
  /// "λόγος⸃" all share the bare form "λόγος", and several of those
  /// punctuated variants carry the richer gloss "a word, speech, divine
  /// utterance, analogy" while the bare key itself only has "word").
  ///
  /// Deliberately does NOT just return "the longest gloss" or replace
  /// [primaryGloss] — confirmed directly against real dictionary data
  /// this session that "longer" isn't always "more correct": e.g. the
  /// bare key for a specific inflected verb form often carries a
  /// short, grammatically PRECISE gloss ("was", for a 3rd-person-
  /// singular-imperfect form) while a sibling variant carries a longer
  /// but less specific citation-form gloss ("I am, exist"). Only genu-
  /// inely NEW meaning-words not already covered by [primaryGloss] are
  /// returned, as a supplementary list — this is the data source for
  /// the Word List page's "Other Possible Meanings" column, which is
  /// additive to (never a replacement for) the "Literal Translation"
  /// column's existing, already-correct primary gloss.
  Future<List<String>> otherMeaningsFor(
    String pairKey,
    String word,
    String primaryGloss,
  ) async {
    if (!_availablePairs.contains(pairKey)) return const [];
    final index = await _loadBareFormIndex(pairKey);
    final bare = _greekCore(word);
    if (bare.isEmpty) return const [];

    final allMeanings = index[bare];
    if (allMeanings == null) return const [];

    final primaryParts = primaryGloss
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .toSet();

    return allMeanings
        .where((m) => !primaryParts.contains(m.toLowerCase()))
        .toList();
  }

  bool isAvailable(String pairKey) => _availablePairs.contains(pairKey);

  void clearCache() {
    _cache.clear();
    _meaningsByBareForm.clear();
  }

  void evict(String pairKey) {
    _cache.remove(pairKey);
    _meaningsByBareForm.remove(pairKey);
  }

  Future<Map<String, DictionaryEntry>> _load(String pairKey) async {
    if (_cache.containsKey(pairKey)) return _cache[pairKey]!;

    try {
      final raw =
          await rootBundle.loadString('assets/dictionaries/$pairKey.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final dict = <String, DictionaryEntry>{};

      for (final kv in decoded.entries) {
        final key = kv.key.toLowerCase();
        final val = kv.value;

        if (val is String) {
          dict[key] = DictionaryEntry(gloss: val);
        } else if (val is Map) {
          dict[key] = DictionaryEntry(
            gloss: (val['gloss'] as String?) ?? '',
            definition: (val['definition'] as String?) ?? '',
            lemma: (val['lemma'] as String?) ?? '',
          );
        }
      }

      _cache[pairKey] = dict;
      return dict;
    } catch (_) {
      _cache[pairKey] = {};
      return {};
    }
  }

  /// Builds (once, lazily, cached per pairKey) the bare-Greek-core ->
  /// all-distinct-meanings reverse index [otherMeaningsFor] reads from.
  /// Built from the SAME cached dictionary [_load] already produces —
  /// no second asset read.
  Future<Map<String, Set<String>>> _loadBareFormIndex(
    String pairKey,
  ) async {
    if (_meaningsByBareForm.containsKey(pairKey)) {
      return _meaningsByBareForm[pairKey]!;
    }

    final dict = await _load(pairKey);
    final index = <String, Set<String>>{};

    for (final entry in dict.entries) {
      final bare = _greekCore(entry.key);
      if (bare.isEmpty) continue;
      final parts = entry.value.gloss
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      index.putIfAbsent(bare, () => <String>{}).addAll(parts);
    }

    _meaningsByBareForm[pairKey] = index;
    return index;
  }
}