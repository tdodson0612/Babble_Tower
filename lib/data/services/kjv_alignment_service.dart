// lib/data/services/kjv_alignment_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';

/// Loads assets/alignment/kjv_word_alignment.json and provides
/// per-occurrence KJV word alignment: for a given verse, the list of
/// KJV English word(s) that correspond to EACH Greek word position in
/// that verse (as opposed to DictionaryService, which gives ONE gloss
/// shared across every occurrence of a word regardless of context).
///
/// Data provenance -- built from a public-domain scholarly source
/// (KJV text tagged word-by-word with Strong's numbers, itself built
/// from Strong's Concordance, 1890), NOT invented or guessed by any
/// automated process. See build_kjv_alignment_v2.py (project root)
/// for the full generation pipeline and its honestly-stated
/// limitations.
///
/// COVERAGE: roughly 78% of Greek word occurrences across all four
/// Gospels have a real match; the remainder are left as "" (empty
/// string) rather than guessed at -- most commonly articles/particles
/// that KJV doesn't render as a separate English word, or genuine
/// textual variants between this app's Greek edition and the
/// alignment source's edition. A caller should treat "" or a missing
/// entry as "no second gloss for this word", never as an error.
///
/// Indexing: each verse's list is in the SAME word order as this
/// app's own Greek tokenization (strip USFM markup, then
/// verse.text.split(' ') -- see BibleService._stripUsfmMarkup and
/// verse_block_view.dart's tokenization). A caller must tokenize the
/// verse the same way to get a matching word index; this service does
/// not re-tokenize anything itself, it only returns the pre-built list.
class KjvAlignmentService {
  static const _assetPath = 'assets/alignment/kjv_word_alignment.json';

  // book (as it appears at call sites, e.g. bibleState.selectedBook --
  // "Matthew"/"Mark"/"Luke"/"John", case-insensitive) -> the asset's
  // own book key. Same English/Greek-name resolution pattern already
  // used independently in bible_service.dart, morphology_service.dart,
  // and kjv_service.dart's respective _bookFile() methods -- kept as
  // its own small mapping here rather than introduced as a new shared
  // utility, consistent with this project's existing (if duplicated)
  // convention for this exact kind of lookup.
  static String _assetBookKey(String book) {
    switch (book.toLowerCase()) {
      case 'matthew':
      case 'ματθαῖος':
        return 'matthew';
      case 'mark':
      case 'μάρκος':
        return 'mark';
      case 'luke':
      case 'λουκᾶς':
        return 'luke';
      case 'john':
      case 'ἰωάννης':
        return 'ioannis';
      default:
        return book.toLowerCase();
    }
  }

  Map<String, dynamic>? _data;
  bool _loadFailed = false;

  Future<void> _ensureLoaded() async {
    if (_data != null || _loadFailed) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      _data = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Missing/corrupt asset should never crash the reader -- this
      // is a supplementary second gloss, not core functionality.
      _loadFailed = true;
    }
  }

  /// Returns the per-word KJV alignment list for [book]/[chapter]/
  /// [verse], or null if unavailable (asset failed to load, or this
  /// specific verse has no entry). An empty string at a given index
  /// means "no match for that word" -- not the same as the whole list
  /// being null.
  Future<List<String>?> forVerse(
    String book,
    String chapter,
    int verse,
  ) async {
    await _ensureLoaded();
    if (_data == null) return null;

    final bookKey = _assetBookKey(book);
    final bookData = _data![bookKey] as Map<String, dynamic>?;
    if (bookData == null) return null;

    final chapterData = bookData[chapter] as Map<String, dynamic>?;
    if (chapterData == null) return null;

    final verseList = chapterData[verse.toString()] as List<dynamic>?;
    if (verseList == null) return null;

    return verseList.map((e) => e as String).toList();
  }

  /// Convenience for a single word position -- returns '' (not null)
  /// if the verse/word can't be resolved, so callers can render
  /// unconditionally without a null check at every use site.
  Future<String> forWord(
    String book,
    String chapter,
    int verse,
    int wordIndex,
  ) async {
    final list = await forVerse(book, chapter, verse);
    if (list == null || wordIndex < 0 || wordIndex >= list.length) return '';
    return list[wordIndex];
  }
}