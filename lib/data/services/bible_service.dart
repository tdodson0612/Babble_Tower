// lib/data/services/bible_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/utils/text_normalizer.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/verse_block.dart';

class BibleService {
  // ONE verse per block — the core pedagogical unit.
  static const int blockSize = 1;

  final Map<String, dynamic> _manifestCache = {};
  final Map<String, List<Verse>> _verseCache = {};

  // ---------------------------------------------------------------------------
  // USFM markup cleanup
  //
  // The raw asset JSON has residual USFM markup baked into some verses'
  // "text" fields — most visibly \+w ...\+w* word-linking tags (used in
  // USFM source to tie a surface form to a Strong's/lexicon entry), plus
  // a stray literal "it" token that precedes Old-Testament quotation
  // spans (almost certainly a mangled \qt-style milestone attribute that
  // got flattened to plain text during conversion). Confirmed directly
  // against the real Mark asset file this session — e.g. Mark 1:2's
  // "\+w ἰδοὺ\+w* \+w ἐγὼ\+w* ..." and Mark 1:3 starting with
  // "it \+w φωνὴ\+w* ...".
  //
  // Left unstripped, this corrupted TWO separate things:
  //   1. The reader displayed the raw tags directly on screen.
  //   2. TextNormalizer.normalizeWord()'s allowed-character set includes
  //      a-zA-Z (needed elsewhere, e.g. apostrophe-adjacent forms), so
  //      stripping the backslash/plus/asterisk from a tag left the bare
  //      Latin letter "w" behind, fused onto the neighboring Greek word
  //      with no space (the tag's closing half, \+w*, sits directly
  //      against the word with no separator) — e.g. "κατασκευάσει"
  //      became "κατασκευάσειw", which no dictionary entry could ever
  //      match, hence the quiz's "(unknown word)" prompts.
  //
  // Fixed ONCE, here, at load time — every downstream consumer (reader,
  // quiz vocabulary, dictionary lookups, Word List page, Grammar lesson,
  // Hive-stored mastery) gets clean text automatically, rather than
  // patching the same bug through five separate files.
  //
  // Deliberately general — \+TAG / \+TAG* for any letters, not
  // hardcoded to \+w specifically — since USFM character-style markup
  // always follows this shape (e.g. \+nd for divine names, \+add for
  // translator-added words), and books other than Mark may carry tags
  // not yet confirmed here.
  static final RegExp _usfmTagRe = RegExp(r'\\\+[A-Za-z]+\*?');

  // The stray milestone-artifact token. Word-bounded so it can never
  // accidentally eat part of a real word — irrelevant in practice since
  // this asset is 100% Greek text and never legitimately contains the
  // Latin letters "it" as content, but bounded anyway for safety.
  static final RegExp _standaloneItRe = RegExp(r'\bit\b');

  static final RegExp _collapseSpacesRe = RegExp(r'\s+');

  /// Strips the markup described above and collapses the whitespace
  /// gaps left behind (removing a tag doesn't remove the space that sat
  /// next to it, so multiple adjacent tag removals can leave doubled
  /// spaces — same collapse-then-trim approach TextNormalizer already
  /// uses elsewhere).
  static String _stripUsfmMarkup(String raw) {
    final noTags = raw.replaceAll(_usfmTagRe, '');
    final noItMarker = noTags.replaceAll(_standaloneItRe, '');
    return noItMarker.replaceAll(_collapseSpacesRe, ' ').trim();
  }

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
  /// Every verse's text is cleaned of residual USFM markup before it
  /// leaves this method — see _stripUsfmMarkup's doc above.
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
        text:   _stripUsfmMarkup(map['text'] as String),
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
}