// lib/data/services/bible_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/constants/supported_languages.dart';
import '../../core/utils/text_normalizer.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/verse_block.dart';

class BibleService {
  // ONE verse per block — the core pedagogical unit.
  static const int blockSize = 1;

  final Map<String, dynamic> _manifestCache = {};
  final Map<String, List<Verse>> _verseCache = {};

  // ---------------------------------------------------------------------------
  // Public API (used by bible_provider and load_chapter_usecase)
  // ---------------------------------------------------------------------------

  /// Returns the list of available books for [languageCode] (e.g. 'el').
  /// Handles both flat-string ["Matthew", ...] and object
  /// [{"name": "Matthew", "file": "...", "chapters": 28}, ...] manifests.
  Future<List<String>> getAvailableBooks(String languageCode) async {
    final manifest = await _loadManifest(languageCode);
    final books = manifest['books'];
    if (books is List) {
      return books.map((b) {
        if (b is String) return b;
        if (b is Map)    return (b['name'] as String?) ?? '';
        return '';
      }).where((s) => s.isNotEmpty).toList();
    }
    return ['Matthew', 'Mark', 'Luke', 'John'];
  }

  /// Returns the number of chapters in [book] for [languageCode].
  Future<int> getChapterCount(String languageCode, String book) async {
    try {
      final bookFile = _bookFile(book);
      final raw = await rootBundle
          .loadString('assets/bible/$languageCode/$bookFile.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final chapters = data['chapters'] as Map<String, dynamic>;
      return chapters.length;
    } catch (_) {
      return 0;
    }
  }

  /// Loads and returns all verses for [book] + [chapter] in [languageCode].
  Future<List<Verse>> getVerses(
    String languageCode,
    String book,
    int chapter,
  ) async {
    final key = '$languageCode-$book-$chapter';
    if (_verseCache.containsKey(key)) return _verseCache[key]!;

    final bookFile = _bookFile(book);
    final raw = await rootBundle
        .loadString('assets/bible/$languageCode/$bookFile.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final chapters = data['chapters'] as Map<String, dynamic>;
    final versesRaw = chapters['$chapter'] as List<dynamic>? ?? [];

    final verses = versesRaw.map((v) {
      final map = v as Map<String, dynamic>;
      return Verse(
        number: map['verse'] as int,
        text:   map['text']  as String,
      );
    }).toList();

    _verseCache[key] = verses;
    return verses;
  }

  /// Splits [verses] into blocks of [blockSize] (1 verse each).
  List<VerseBlock> buildBlocks(List<Verse> verses) {
    final blocks = <VerseBlock>[];
    for (var i = 0; i < verses.length; i += blockSize) {
      final end   = (i + blockSize).clamp(0, verses.length);
      final slice = verses.sublist(i, end);
      final combinedText = slice.map((v) => v.text).join(' ');
      final words = TextNormalizer.extractWords(combinedText);
      blocks.add(VerseBlock(
        blockIndex: i ~/ blockSize,
        verses:     slice,
        words:      words,
      ));
    }
    return blocks;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _loadManifest(String languageCode) async {
    if (_manifestCache.containsKey(languageCode)) {
      return _manifestCache[languageCode]!;
    }
    try {
      final raw = await rootBundle
          .loadString('assets/bible/$languageCode/manifest.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      _manifestCache[languageCode] = data;
      return data;
    } catch (_) {
      return {};
    }
  }

  static String _bookFile(String book) {
    switch (book.toLowerCase()) {
      case 'matthew': return 'matthew';
      case 'mark':    return 'mark';
      case 'luke':    return 'luke';
      case 'john':    return 'ioannis';
      default:        return book.toLowerCase();
    }
  }
}