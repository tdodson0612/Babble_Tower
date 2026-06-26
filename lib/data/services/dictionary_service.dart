// lib/data/services/dictionary_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/constants/supported_languages.dart';

/// A dictionary entry — either a plain gloss or the richer format
/// produced by the MorphGNT + Dodson build pipeline.
class DictionaryEntry {
  /// Short English gloss (e.g. "I say, speak").
  final String gloss;

  /// Longer definition (e.g. "I say, speak; I tell, command; I call, name.").
  /// Equal to [gloss] for legacy plain-string entries.
  final String definition;

  /// The lemma / dictionary headword (e.g. "λέγω").
  /// Empty string for legacy plain-string entries.
  final String lemma;

  const DictionaryEntry({
    required this.gloss,
    required this.definition,
    required this.lemma,
  });

  /// Build from the new {gloss, definition, lemma} object format.
  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      gloss:      (map['gloss']      as String? ?? '').trim(),
      definition: (map['definition'] as String? ?? '').trim(),
      lemma:      (map['lemma']      as String? ?? '').trim(),
    );
  }

  /// Build from the legacy plain-string format.
  factory DictionaryEntry.fromString(String value) {
    return DictionaryEntry(
      gloss:      value.trim(),
      definition: value.trim(),
      lemma:      '',
    );
  }
}

/// Loads and caches the bundled offline dictionary JSON files.
///
/// Babble Tower teaches a single fixed pair: English speakers reading
/// Koine Greek. Dictionary files live at:
///   assets/dictionaries/{pairKey}.json
///
/// The el_en.json file now contains a mix of:
///   - Old entries: { "word": "plain english string" }
///   - New entries: { "word": {"gloss": "...", "definition": "...", "lemma": "..."} }
///
/// This service transparently handles both formats.
class DictionaryService {
  // Cache: pairKey → { word → DictionaryEntry }
  final Map<String, Map<String, DictionaryEntry>> _cache = {};

  static const Set<String> _availablePairs = {
    'en_el',
    'el_en',
  };

  /// Returns the [DictionaryEntry] for [word] in [pairKey], or null if not found.
  Future<DictionaryEntry?> lookup(String pairKey, String word) async {
    if (!_availablePairs.contains(pairKey)) return null;
    final dict = await _load(pairKey);
    return dict[word.toLowerCase()];
  }

  /// Convenience: returns just the gloss string (backwards-compatible).
  Future<String?> translate(String pairKey, String word) async {
    final entry = await lookup(pairKey, word);
    return entry?.gloss;
  }

  /// Bulk-looks up a list of words for [pairKey].
  /// Returns a map of { word → DictionaryEntry } for words found.
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

  /// Convenience: bulk-translate returning { word → gloss string }.
  Future<Map<String, String>> translateAll(
    String pairKey,
    List<String> words,
  ) async {
    final entries = await lookupAll(pairKey, words);
    return entries.map((k, v) => MapEntry(k, v.gloss));
  }

  bool isAvailable(String pairKey) => _availablePairs.contains(pairKey);

  void clearCache() => _cache.clear();
  void evict(String pairKey) => _cache.remove(pairKey);

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<Map<String, DictionaryEntry>> _load(String pairKey) async {
    if (_cache.containsKey(pairKey)) return _cache[pairKey]!;

    try {
      final raw = await rootBundle
          .loadString('assets/dictionaries/$pairKey.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;

      final dict = <String, DictionaryEntry>{};
      for (final kv in decoded.entries) {
        final key = kv.key.toLowerCase();
        final val = kv.value;
        if (val is String) {
          dict[key] = DictionaryEntry.fromString(val);
        } else if (val is Map<String, dynamic>) {
          dict[key] = DictionaryEntry.fromMap(val);
        }
        // Ignore unexpected types silently.
      }

      _cache[pairKey] = dict;
      return dict;
    } catch (e) {
      _cache[pairKey] = {};
      return {};
    }
  }
}
