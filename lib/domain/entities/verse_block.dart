// lib/domain/entities/verse_block.dart

import 'verse.dart';

class VerseBlock {
  /// 0-based index of this block within its chapter.
  final int blockIndex;

  /// The verse(s) in this block. Currently always exactly one verse per
  /// block (BibleService.buildBlocks uses blockSize=1) — the verse-lock
  /// quiz gate in reader_screen.dart operates per individual verse.
  final List<Verse> verses;

  /// Normalized, deduplicated word list extracted from this block.
  final List<String> words;

  const VerseBlock({
    required this.blockIndex,
    required this.verses,
    required this.words,
  });

  /// Convenience: verse range label, e.g. "1" (or "1–5" if a future
  /// blockSize change groups multiple verses again).
  String get rangeLabel {
    if (verses.isEmpty) return '';
    final first = verses.first.number;
    final last = verses.last.number;
    return first == last ? '$first' : '$first–$last';
  }
}