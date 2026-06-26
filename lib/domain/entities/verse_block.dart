// lib/domain/entities/verse_block.dart

import 'verse.dart';

class VerseBlock {
  /// 0-based index of this block within its chapter.
  final int blockIndex;

  /// Up to 5 verses (fewer at chapter end).
  final List<Verse> verses;

  /// Normalized, deduplicated word list extracted from this block.
  final List<String> words;

  const VerseBlock({
    required this.blockIndex,
    required this.verses,
    required this.words,
  });

  /// Convenience: verse range label, e.g. "1–5".
  String get rangeLabel {
    if (verses.isEmpty) return '';
    final first = verses.first.number;
    final last = verses.last.number;
    return first == last ? '$first' : '$first–$last';
  }
}