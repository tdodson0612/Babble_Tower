// lib/domain/entities/word_entry.dart

class WordEntry {
  final String word;
  final String languagePairKey;

  /// Short gloss (e.g. "word, message") — shown during quiz.
  String translation;

  /// Longer definition from Dodson lexicon (optional).
  String definition;

  /// The dictionary lemma this form was resolved from (optional).
  String lemma;

  bool known;
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

  // masteryLevel ranges 0–5 (see Mastery System in the project handoff doc).
  // Level 5 is the top of the scale and is treated as fully mastered:
  // lower quiz frequency, lower spaced-repetition priority.
  bool get isMastered => masteryLevel >= 5;

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