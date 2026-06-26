// lib/domain/entities/word_entry.dart

class WordEntry {
  /// The word in the target language (L2).
  final String word;

  /// Composite key identifying the language pair, e.g. "en_el".
  final String languagePairKey;

  /// Short translation / gloss in the user's native language (L1).
  String translation;

  /// Longer definition (may equal [translation] for legacy entries).
  String definition;

  /// The lemma / dictionary headword (empty for legacy entries).
  String lemma;

  /// Whether the user has marked this word as known.
  bool known;

  /// Mastery level 0–3:
  ///   0 = unseen
  ///   1 = seen / marked
  ///   2 = recalled in test
  ///   3 = mastered (recalled across sessions)
  int masteryLevel;

  DateTime lastReviewed;

  WordEntry({
    required this.word,
    required this.languagePairKey,
    required this.translation,
    this.definition = '',
    this.lemma = '',
    this.known = false,
    this.masteryLevel = 0,
    required this.lastReviewed,
  });

  /// Returns true if this word should be considered mastered.
  bool get isMastered => masteryLevel >= 3;

  /// The best available definition — long if present, else short gloss.
  String get bestDefinition =>
      definition.isNotEmpty ? definition : translation;

  WordEntry copyWith({
    String? translation,
    String? definition,
    String? lemma,
    bool? known,
    int? masteryLevel,
    DateTime? lastReviewed,
  }) {
    return WordEntry(
      word: word,
      languagePairKey: languagePairKey,
      translation: translation ?? this.translation,
      definition: definition ?? this.definition,
      lemma: lemma ?? this.lemma,
      known: known ?? this.known,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      lastReviewed: lastReviewed ?? this.lastReviewed,
    );
  }
}
