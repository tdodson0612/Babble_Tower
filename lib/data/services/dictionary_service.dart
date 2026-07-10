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

  static const Set<String> _availablePairs = {'en_el', 'el_en'};

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

  bool isAvailable(String pairKey) => _availablePairs.contains(pairKey);

  void clearCache() => _cache.clear();

  void evict(String pairKey) => _cache.remove(pairKey);

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
}