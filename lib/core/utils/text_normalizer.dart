// lib/core/utils/text_normalizer.dart

/// Unicode-aware text normalization for Koine Greek source text.
///
/// Dart's \w in RegExp only covers ASCII [a-zA-Z0-9_].
/// Greek characters (U+0370–U+03FF, U+1F00–U+1FFF extended) must be
/// listed explicitly in character classes.
class TextNormalizer {
  // Matches any character that is NOT a Greek letter, Latin letter,
  // digit, apostrophe, or whitespace — i.e. punctuation to strip.
  static final _stripPunctuation = RegExp(
    r"[^\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036Fa-zA-Z0-9'\s]",
  );

  // Collapses runs of whitespace.
  static final _collapseSpaces = RegExp(r'\s+');

  /// Lowercases, strips punctuation (preserving apostrophes),
  /// splits on whitespace, deduplicates, and returns unique words.
  static List<String> extractWords(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(_stripPunctuation, '')
        .replaceAll(_collapseSpaces, ' ')
        .trim();

    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Strips surrounding punctuation from a single tapped word for lookup.
  static String normalizeWord(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(
          RegExp(r"[^\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036Fa-zA-Z0-9']"),
          '',
        );
  }
}