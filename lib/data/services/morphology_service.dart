// lib/data/services/morphology_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/parsing_word.dart';

/// Loads grammar-parsing data produced by build_morphology.py
/// (assets/morphology/*.json). Mirrors BibleService's file-naming and
/// caching pattern deliberately, since morphology files are generated
/// 1:1 against the same book files.
///
/// Only verses that aligned cleanly against the Byzantine Majority Text
/// at build time exist in these files — see build_morphology.py's header
/// comment. [wordsForVerse] returning an empty list means "no grammar
/// parsing available for this verse" (either untagged or misaligned),
/// NOT an error — callers (QuizEngine via VerseQuizScreen) must treat
/// that as "grammarParsing simply isn't eligible here", the same way
/// verseFillInBlank is excluded when a word isn't in the verse text.
class MorphologyService {
  final Map<String, Map<String, dynamic>> _bookCache = {};

  /// Returns parsing data for every word in [book]/[chapter]/[verseNumber],
  /// in verse order. Empty list if this verse wasn't tagged or didn't
  /// align — always safe to call, never throws.
  Future<List<ParsingWord>> wordsForVerse(
    String book,
    int chapter,
    int verseNumber,
  ) async {
    final data = await _loadBook(book);
    if (data == null) return const [];

    final chapters = data['chapters'] as Map<String, dynamic>?;
    final verses = chapters?[chapter.toString()] as Map<String, dynamic>?;
    final words = verses?[verseNumber.toString()] as List<dynamic>?;
    if (words == null) return const [];

    return words
        .map((w) => ParsingWord.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  /// True if [book]/[chapter]/[verseNumber] has grammar-parsing data
  /// available at all — lets callers decide whether to even attempt
  /// building a GrammarParsingQuestion before doing the lookup work.
  Future<bool> hasDataForVerse(
    String book,
    int chapter,
    int verseNumber,
  ) async {
    final words = await wordsForVerse(book, chapter, verseNumber);
    return words.isNotEmpty;
  }

  Future<Map<String, dynamic>?> _loadBook(String book) async {
    final file = _bookFile(book);
    if (_bookCache.containsKey(file)) return _bookCache[file];
    try {
      final raw =
          await rootBundle.loadString('assets/morphology/$file.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      _bookCache[file] = data;
      return data;
    } catch (_) {
      // Missing file (e.g. build_morphology.py hasn't been run yet, or
      // this book has zero aligned verses) — treat as "no data", not
      // an error. Cache the miss too so we don't retry every call.
      _bookCache[file] = const {};
      return null;
    }
  }

  /// Identical mapping to BibleService._bookFile — kept as its own copy
  /// rather than a shared import, since the two services are independent
  /// and this avoids coupling asset lookups across unrelated services.
  static String _bookFile(String book) {
    switch (book.toLowerCase()) {
      case 'matthew':
        return 'matthew';
      case 'mark':
        return 'mark';
      case 'luke':
        return 'luke';
      case 'john':
        return 'ioannis';
      default:
        return book.toLowerCase();
    }
  }
}