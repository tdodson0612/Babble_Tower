// lib/domain/entities/parsing_word.dart

import 'dart:math';

/// A single grammatical dimension a ParsingWord can be quizzed on.
/// Deliberately limited to the dimensions the handoff doc's Phase 10 spec
/// calls for: "select case (noun) or person/tense/voice/mood (verb)".
/// Number/gender/degree are decoded (available on [ParsingWord]) but not
/// quizzed — keeping the question type's scope matched to spec.
enum GrammarCategory { person, tense, voice, mood, grammaticalCase }

extension GrammarCategoryLabel on GrammarCategory {
  String get displayName {
    switch (this) {
      case GrammarCategory.person:
        return 'Person';
      case GrammarCategory.tense:
        return 'Tense';
      case GrammarCategory.voice:
        return 'Voice';
      case GrammarCategory.mood:
        return 'Mood';
      case GrammarCategory.grammaticalCase:
        return 'Case';
    }
  }
}

/// One MorphGNT-tagged word, aligned to this app's Byzantine Majority Text
/// at build time by build_morphology.py. [word] is always the BMT surface
/// form (matches verse text exactly) — [pos]/[parseCode]/[lemma] come from
/// MorphGNT. Only verses that aligned cleanly (exact word-count match)
/// ever produce these, so every ParsingWord in the app is trustworthy;
/// there is no partial/uncertain alignment state to represent here.
class ParsingWord {
  /// Byzantine Majority Text surface form — identical to the token that
  /// appears in the verse text, punctuation and accents included.
  final String word;

  /// Raw MorphGNT part-of-speech code, e.g. 'N-', 'V-', 'RA', 'C-'.
  final String pos;

  /// Raw 8-character parse code:
  /// [Person][Tense][Voice][Mood][Case][Number][Gender][Degree]
  /// '-' means "not applicable" at that position for this POS.
  final String parseCode;

  final String lemma;

  const ParsingWord({
    required this.word,
    required this.pos,
    required this.parseCode,
    required this.lemma,
  });

  factory ParsingWord.fromJson(Map<String, dynamic> json) => ParsingWord(
        word: json['word'] as String,
        pos: json['pos'] as String,
        parseCode: json['parse'] as String,
        lemma: json['lemma'] as String,
      );

  // ── Decoded single-letter codes (null when '-' / not applicable) ──────

  String? get _person => _charAt(0);
  String? get _tense => _charAt(1);
  String? get _voice => _charAt(2);
  String? get _mood => _charAt(3);
  String? get _grammaticalCase => _charAt(4);
  String? get _number => _charAt(5);
  String? get _gender => _charAt(6);
  String? get _degree => _charAt(7);

  String? _charAt(int i) {
    if (parseCode.length <= i) return null;
    final c = parseCode[i];
    return c == '-' ? null : c;
  }

  /// True for POS tags that decline for case (article, noun, adjective,
  /// pronouns) — the "select case (noun)" half of the Phase 10 spec.
  bool get isNominal =>
      const {'N-', 'A-', 'RA', 'RD', 'RI', 'RP', 'RR'}.contains(pos);

  /// True for verbs — the "person/tense/voice/mood (verb)" half of spec.
  /// Note: MorphGNT participles are POS 'V-' with a Case/Number/Gender
  /// AND Tense/Voice/Mood — they're still quizzed as verbs here (Mood
  /// will decode to "Participle"), matching the doc's verb bucket.
  bool get isVerb => pos == 'V-';

  /// Every category this word could be quizzed on, in a fixed order.
  /// Deterministic (no randomness) so QuizEngine can check eligibility
  /// ("does this word support grammarParsing at all?") without needing
  /// to commit to a specific category before actually building the
  /// question. Empty for non-quizzable POS (conjunctions, particles,
  /// prepositions, adverbs, numerals) or words with no decoded value in
  /// any quizzable slot.
  List<GrammarCategory> get availableCategories {
    if (isNominal && _grammaticalCase != null) {
      return const [GrammarCategory.grammaticalCase];
    }
    if (isVerb) {
      return [
        if (_person != null) GrammarCategory.person,
        if (_tense != null) GrammarCategory.tense,
        if (_voice != null) GrammarCategory.voice,
        if (_mood != null) GrammarCategory.mood,
      ];
    }
    return const [];
  }

  /// True if this word can be quizzed on at least one grammar category —
  /// the eligibility check QuizEngine uses before offering grammarParsing.
  bool get isQuizzable => availableCategories.isNotEmpty;

  /// Picks ONE category to actually quiz for this word appearance.
  /// Verbs quiz a randomly chosen dimension among person/tense/voice/mood
  /// (participles lack person, so that slot is naturally excluded rather
  /// than special-cased); nominals always quiz case, the only dimension
  /// in scope for them per the Phase 10 spec. Returns null only if
  /// [isQuizzable] is false — callers should check that first.
  GrammarCategory? quizCategory(Random random) {
    final available = availableCategories;
    if (available.isEmpty) return null;
    return available[random.nextInt(available.length)];
  }

  /// The correct single-letter code for [category] on this word, or null.
  String? codeFor(GrammarCategory category) {
    switch (category) {
      case GrammarCategory.person:
        return _person;
      case GrammarCategory.tense:
        return _tense;
      case GrammarCategory.voice:
        return _voice;
      case GrammarCategory.mood:
        return _mood;
      case GrammarCategory.grammaticalCase:
        return _grammaticalCase;
    }
  }

  /// Human-readable label for a given category's code, e.g.
  /// codeFor(tense) == 'A' -> 'Aorist'. Used both for the correct answer
  /// and for rendering multiple-choice distractor options.
  static String labelFor(GrammarCategory category, String code) {
    final map = _labels[category]!;
    return map[code] ?? code;
  }

  /// All possible codes for [category], in a fixed pedagogical order —
  /// used to build multiple-choice options (correct + distractors).
  static List<String> allCodesFor(GrammarCategory category) =>
      _labels[category]!.keys.toList(growable: false);

  static const Map<GrammarCategory, Map<String, String>> _labels = {
    GrammarCategory.person: {'1': '1st person', '2': '2nd person', '3': '3rd person'},
    GrammarCategory.tense: {
      'P': 'Present',
      'I': 'Imperfect',
      'F': 'Future',
      'A': 'Aorist',
      'X': 'Perfect',
      'Y': 'Pluperfect',
    },
    GrammarCategory.voice: {'A': 'Active', 'M': 'Middle', 'P': 'Passive'},
    GrammarCategory.mood: {
      'I': 'Indicative',
      'D': 'Imperative',
      'S': 'Subjunctive',
      'O': 'Optative',
      'N': 'Infinitive',
      'P': 'Participle',
    },
    GrammarCategory.grammaticalCase: {
      'N': 'Nominative',
      'G': 'Genitive',
      'D': 'Dative',
      'A': 'Accusative',
      'V': 'Vocative',
    },
  };
}