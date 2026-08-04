// lib/data/services/kjv_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/verse.dart';

/// Loads the public-domain King James Version (KJV) English text for
/// the four Gospels — project handoff doc's "See KJV translation"
/// to-do item. Unlike NIV (external link-out only, per Biblica's
/// licensing terms — see reader_screen.dart's _NivLinkButton), KJV is
/// public domain, so its text is embedded directly in the app, exactly
/// like this project's Greek text already is.
///
/// Source: aruljohn/Bible-kjv (public domain KJV JSON, one file per
/// book), converted to this project's EXISTING verse-JSON shape
/// (chapters as a map keyed by chapter number, verses as
/// {"verse": int, "text": string}) — the same schema BibleService
/// already uses for Greek text, so this service deliberately mirrors
/// BibleService's loading/caching pattern rather than inventing a
/// different one.
///
/// Deliberately a SEPARATE service from BibleService, not a
/// generalization of it — KJV is comparison/reference content, not a
/// language option in this app's core teaching flow (Babble Tower
/// teaches only Koine Greek — see supported_languages.dart's own doc,
/// "NOT a multilingual app"). Reuses the existing Verse entity
/// directly, since its shape ({number, text}) is already exactly what
/// this needs.
class KjvService {
  final Map<String, List<Verse>> _verseCache = {};

  /// Loads and returns all KJV verses for [book] + [chapter]. Returns
  /// an empty list (never throws) if the book/chapter isn't available
  /// — callers should treat that as "no KJV text for this reference",
  /// the same fail-safe posture every other optional-data path in this
  /// app already uses (Phase 10 morphology, Phase 12 word families,
  /// etc.).
  Future<List<Verse>> getVerses(String book, int chapter) async {
    final key = '$book-$chapter';
    if (_verseCache.containsKey(key)) return _verseCache[key]!;

    try {
      final bookFile = _bookFile(book);
      final raw = await rootBundle
          .loadString('assets/bible/en_kjv/$bookFile.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final chapters = data['chapters'] as Map<String, dynamic>;
      final versesRaw = chapters['$chapter'] as List<dynamic>? ?? [];

      final verses = versesRaw.map((v) {
        final map = v as Map<String, dynamic>;
        return Verse(
          number: map['verse'] as int,
          text: map['text'] as String,
        );
      }).toList();

      _verseCache[key] = verses;
      return verses;
    } catch (_) {
      _verseCache[key] = const [];
      return const [];
    }
  }

  /// Returns just the verses within [firstVerse]..[lastVerse] inclusive
  /// — the same verse-range concept reader_screen.dart's NIV link
  /// already uses for a multi-verse block, so a block's "See KJV"
  /// button shows exactly the verses it's currently displaying, not
  /// the whole chapter.
  Future<List<Verse>> getVerseRange(
    String book,
    int chapter,
    int firstVerse,
    int lastVerse,
  ) async {
    final all = await getVerses(book, chapter);
    return all
        .where((v) => v.number >= firstVerse && v.number <= lastVerse)
        .toList();
  }

  static String _bookFile(String book) {
    switch (book.toLowerCase()) {
      case 'matthew': return 'matthew';
      case 'mark':    return 'mark';
      case 'luke':    return 'luke';
      case 'john':    return 'john';
      default:        return book.toLowerCase();
    }
  }
}