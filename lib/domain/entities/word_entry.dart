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

  /// Cumulative count of wrong answers for this word, across quizzes,
  /// review sessions, and the manual "✗ Not yet" tap — every path that
  /// counts as "wrong" funnels through VocabularyService.markUnknown(),
  /// which is the single place this is incremented. Never decremented.
  /// Distinct from masteryLevel: masteryLevel can be 0 either because a
  /// word was genuinely missed repeatedly OR because it's brand new and
  /// has simply never been quizzed — timesWrong disambiguates those two
  /// cases for the "Toughest words" view.
  int timesWrong;

  WordEntry({
    required this.word,
    required this.languagePairKey,
    required this.translation,
    this.definition = '',
    this.lemma = '',
    this.known = false,
    this.masteryLevel = 0,
    this.timesWrong = 0,
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
    int? timesWrong,
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
      timesWrong: timesWrong ?? this.timesWrong,
      lastReviewed: lastReviewed ?? this.lastReviewed,
    );
  }
}