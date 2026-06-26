// lib/data/services/bible_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/verse_block.dart';
import '../../core/utils/text_normalizer.dart';

/// Loads Bible text from bundled JSON assets.
///
/// Expected asset structure:
///   assets/bible/{languageCode}/{filename}.json
///
/// Each JSON file is structured as:
/// {
///   "book": "John",
///   "chapters": {
///     "1": [{"verse": 1, "text": "..."}, ...]
///   }
/// }
class BibleService {
  // Each verse is its own learning unit.
  static const int blockSize = 1;

  /// Maps display book names (as they appear in manifest.json) to their
  /// asset filenames (no extension). Required because "John" maps to
  /// the file "ioannis.json" — the Greek transliteration used for the
  /// Gospel of John, to avoid colliding with the apostle John elsewhere.
  static const Map<String, String> _filenameOverrides = {
    'John': 'ioannis',
  };

  /// Converts a book display name to its asset filename.
  static String _toFilename(String book) {
    if (_filenameOverrides.containsKey(book)) {
      return _filenameOverrides[book]!;
    }
    return book
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w]'), '');
  }

  /// Returns list of available book names for [languageCode].
  Future<List<String>> getAvailableBooks(String languageCode) async {
    try {
      final raw = await rootBundle
          .loadString('assets/bible/$languageCode/manifest.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final books = decoded['books'] as List<dynamic>;
      return books
          .map((b) => (b as Map<String, dynamic>)['name'] as String)
          .toList();
    } catch (e) {
      return _fallbackBooks;
    }
  }

  /// Returns number of chapters in [book] for [languageCode].
  Future<int> getChapterCount(String languageCode, String book) async {
    try {
      final data = await _loadBook(languageCode, book);
      final chapters = data['chapters'] as Map<String, dynamic>;
      return chapters.length;
    } catch (_) {
      return 0;
    }
  }

  /// Loads all verses for [chapter] in [book] for [languageCode].
  Future<List<Verse>> getVerses(
    String languageCode,
    String book,
    int chapter,
  ) async {
    final data = await _loadBook(languageCode, book);
    final chapters = data['chapters'] as Map<String, dynamic>;
    final chapterData = chapters['$chapter'];
    if (chapterData == null) return [];

    final verseList = chapterData as List<dynamic>;
    return verseList
        .map((v) {
          final entry = v as Map<String, dynamic>;
          return Verse(
            number: entry['verse'] as int,
            text:   entry['text'] as String,
          );
        })
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }

  /// Splits [verses] into blocks of [blockSize] (= 1 verse each).
  List<VerseBlock> buildBlocks(List<Verse> verses) {
    final blocks = <VerseBlock>[];
    for (var i = 0; i < verses.length; i += blockSize) {
      final end   = (i + blockSize).clamp(0, verses.length);
      final chunk = verses.sublist(i, end);
      final combinedText = chunk.map((v) => v.text).join(' ');
      blocks.add(VerseBlock(
        blockIndex: blocks.length,
        verses:     chunk,
        words:      TextNormalizer.extractWords(combinedText),
      ));
    }
    return blocks;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _loadBook(
      String languageCode, String book) async {
    final filename  = _toFilename(book);
    final assetPath = 'assets/bible/$languageCode/$filename.json';
    final raw       = await rootBundle.loadString(assetPath);
    return json.decode(raw) as Map<String, dynamic>;
  }

  static const List<String> _fallbackBooks = [
    'Matthew',
    'Mark',
    'Luke',
    'John',
  ];
}
