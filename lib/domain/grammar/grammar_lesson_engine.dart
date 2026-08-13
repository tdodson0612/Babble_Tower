// lib/domain/grammar/grammar_lesson_engine.dart

import 'dart:math';
import '../entities/parsing_word.dart';

/// Plain-English explanation for one specific value of one grammatical
/// category (e.g. GrammarCategory.tense's 'A' = Aorist). Keyed by
/// (category, code) rather than code alone, since single-letter MorphGNT
/// codes COLLIDE across categories — e.g. 'A' means Aorist for tense,
/// Active for voice, and Accusative for case; 'P' means Present for
/// tense, Passive for voice, and Participle for mood. See
/// [grammarExplanations]'s nested-map shape below.
///
/// Deliberately does NOT duplicate ParsingWord.labelFor's grammatical
/// term ("Aorist", "Passive"...) as a stored field — that's already the
/// canonical label in parsing_word.dart; callers needing it call
/// ParsingWord.labelFor(category, code) directly, so there is exactly
/// one place that string lives.
class GrammarValueExplanation {
  final GrammarCategory category;
  final String code;
  final String question;
  final String plainEnglish;
  final String exampleGloss;

  const GrammarValueExplanation({
    required this.category,
    required this.code,
    required this.question,
    required this.plainEnglish,
    required this.exampleGloss,
  });
}

/// All quizzable values for all five GrammarCategory dimensions, in each
/// category's fixed pedagogical order. `const`, so every reference to
/// e.g. grammarExplanations[GrammarCategory.tense]!['A'] is the SAME
/// instance everywhere — GrammarLessonEngine relies on that for
/// reference-equality option matching (see _buildQuizQueue), the same
/// pattern AlphabetQuizEngine uses for LetterEntry.
///
/// Case explanations extend the original Cases-lesson master prompt
/// directly. Person/tense/voice/mood explanations were authored this
/// session in the same "concept before terminology" style, since no
/// equivalent spec was provided for conjugation — flagged here rather
/// than silently presented as if handed down verbatim.
const Map<GrammarCategory, Map<String, GrammarValueExplanation>>
    grammarExplanations = {
  GrammarCategory.grammaticalCase: {
    'N': GrammarValueExplanation(
      category: GrammarCategory.grammaticalCase,
      code: 'N',
      question: 'Who or what is doing the action?',
      plainEnglish: 'The subject',
      exampleGloss: 'This word is the one doing something in the sentence.',
    ),
    'A': GrammarValueExplanation(
      category: GrammarCategory.grammaticalCase,
      code: 'A',
      question: 'Who or what is receiving the action?',
      plainEnglish: 'The direct object',
      exampleGloss: 'This word is receiving the action — nothing about its '
          'meaning changed, only its job did.',
    ),
    'G': GrammarValueExplanation(
      category: GrammarCategory.grammaticalCase,
      code: 'G',
      question: 'Whose is it, or what does it belong to?',
      plainEnglish: 'Belongs to someone',
      exampleGloss: 'This ending shows belonging or possession — "of ___".',
    ),
    'D': GrammarValueExplanation(
      category: GrammarCategory.grammaticalCase,
      code: 'D',
      question: 'To whom, or for whom?',
      plainEnglish: 'To or for someone',
      exampleGloss: 'Greek often uses this ending where English would use '
          '"to", "for", "by", "with", or "in".',
    ),
    'V': GrammarValueExplanation(
      category: GrammarCategory.grammaticalCase,
      code: 'V',
      question: 'Who is being spoken to?',
      plainEnglish: 'Being spoken to',
      exampleGloss: 'The speaker is talking directly to this — common in '
          'dialogue throughout the Gospels.',
    ),
  },
  GrammarCategory.person: {
    '1': GrammarValueExplanation(
      category: GrammarCategory.person,
      code: '1',
      question: 'Who is speaking?',
      plainEnglish: '"I" or "we" — the speaker',
      exampleGloss: 'This ending shows the SPEAKER is doing the action.',
    ),
    '2': GrammarValueExplanation(
      category: GrammarCategory.person,
      code: '2',
      question: 'Who is being spoken to?',
      plainEnglish: '"You" — the listener',
      exampleGloss: 'This ending shows the person being spoken TO is doing '
          'the action.',
    ),
    '3': GrammarValueExplanation(
      category: GrammarCategory.person,
      code: '3',
      question: 'Who is being spoken about?',
      plainEnglish: '"He", "she", "it", or "they"',
      exampleGloss: 'This ending shows someone other than the speaker or '
          'listener is doing the action.',
    ),
  },
  GrammarCategory.tense: {
    'P': GrammarValueExplanation(
      category: GrammarCategory.tense,
      code: 'P',
      question: 'Is it happening right now, or again and again?',
      plainEnglish: 'Happening now, or ongoing/repeated',
      exampleGloss: 'The action is in progress or keeps happening.',
    ),
    'I': GrammarValueExplanation(
      category: GrammarCategory.tense,
      code: 'I',
      question: 'Was it happening, again and again, in the past?',
      plainEnglish: 'Was ongoing in the past',
      exampleGloss:
          'Like English "was doing" — an ongoing or repeated past action.',
    ),
    'F': GrammarValueExplanation(
      category: GrammarCategory.tense,
      code: 'F',
      question: 'Will it happen?',
      plainEnglish: "Hasn't happened yet — it will",
      exampleGloss: 'The action is going to happen.',
    ),
    'A': GrammarValueExplanation(
      category: GrammarCategory.tense,
      code: 'A',
      question: 'Did it simply happen, as one complete action?',
      plainEnglish: 'A simple, complete action',
      exampleGloss: "Greek's most common way to say something just "
          'happened, without saying how long it took.',
    ),
    'X': GrammarValueExplanation(
      category: GrammarCategory.tense,
      code: 'X',
      question: 'Did it already happen, with the result still true now?',
      plainEnglish: 'Completed, with a lasting result',
      exampleGloss:
          'Something happened, and its effect is still true right now.',
    ),
    'Y': GrammarValueExplanation(
      category: GrammarCategory.tense,
      code: 'Y',
      question: 'Had it already happened, before another past moment?',
      plainEnglish: 'Had already happened',
      exampleGloss: 'Rare in the Gospels — like English "had already done".',
    ),
  },
  GrammarCategory.voice: {
    'A': GrammarValueExplanation(
      category: GrammarCategory.voice,
      code: 'A',
      question: 'Is the subject doing the action?',
      plainEnglish: 'The subject does it',
      exampleGloss: '"He loves" — the subject is the one acting.',
    ),
    'M': GrammarValueExplanation(
      category: GrammarCategory.voice,
      code: 'M',
      question: 'Is the subject acting on or for itself?',
      plainEnglish: 'The subject acts for/on itself',
      exampleGloss:
          'No exact English equivalent — often like "he washes himself".',
    ),
    'P': GrammarValueExplanation(
      category: GrammarCategory.voice,
      code: 'P',
      question: 'Is the subject receiving the action?',
      plainEnglish: 'The subject has it done TO them',
      exampleGloss: '"He is loved" — the subject receives the action '
          'instead of doing it.',
    ),
  },
  GrammarCategory.mood: {
    'I': GrammarValueExplanation(
      category: GrammarCategory.mood,
      code: 'I',
      question: 'Is this stating a plain fact?',
      plainEnglish: 'A plain statement of fact',
      exampleGloss:
          'The most common mood — simply saying something is true.',
    ),
    'D': GrammarValueExplanation(
      category: GrammarCategory.mood,
      code: 'D',
      question: 'Is this a command?',
      plainEnglish: 'A command or instruction',
      exampleGloss: '"Go!" or "Believe!"',
    ),
    'S': GrammarValueExplanation(
      category: GrammarCategory.mood,
      code: 'S',
      question: 'Is this possible or hoped-for, rather than certain?',
      plainEnglish: 'Possible, hoped-for, or uncertain',
      exampleGloss: 'Often follows "that" or "in order that" — "that he '
          'may believe".',
    ),
    'O': GrammarValueExplanation(
      category: GrammarCategory.mood,
      code: 'O',
      question: 'Is this a wish?',
      plainEnglish: 'A wish, often a strong one',
      exampleGloss:
          'Rare in the New Testament — e.g. Paul\'s "May it never be!"',
    ),
    'N': GrammarValueExplanation(
      category: GrammarCategory.mood,
      code: 'N',
      question: 'Is this the plain "to ___" form?',
      plainEnglish: 'The "to do" form of the verb',
      exampleGloss: '"To believe", "to go" — not tied to any person.',
    ),
    'P': GrammarValueExplanation(
      category: GrammarCategory.mood,
      code: 'P',
      question: 'Is this being used like a describing word?',
      plainEnglish: 'A verb acting like an adjective',
      exampleGloss:
          '"Believing", "having gone" — describes a noun using a verb.',
    ),
  },
};

/// One word occurrence paired with every grammar category due for it
/// on this session. A single verb can be due on several categories at
/// once (person AND tense AND voice AND mood might all be due
/// independently) — this groups them under one item so the lesson
/// teaches one actual word occurrence per page, rather than spawning
/// separate pages for each category of the same word.
class DueGrammarItem {
  final ParsingWord word;
  final List<GrammarCategory> dueCategories;
  const DueGrammarItem({
    required this.word,
    required this.dueCategories,
  });
}

/// One teach card — one actual word occurrence, with all its due grammar
/// properties grouped on the same page. [comparisonWord] is set only
/// when another due item shares this word's lemma in one of the same
/// categories but carries a DIFFERENT code — the "θεός vs θεόν" moment,
/// generalized to any category. Null is the common case.
class GrammarTeachCard {
  final ParsingWord word;
  final List<GrammarValueExplanation> explanations;
  final ParsingWord? comparisonWord;

  const GrammarTeachCard({
    required this.word,
    required this.explanations,
    this.comparisonWord,
  });
}

/// One "what's going on with this word?" multiple-choice question.
/// [options] are always drawn from the SAME category as the correct
/// answer (never mixing e.g. a Tense option into a Case question) —
/// see _buildQuizQueue. Option count varies by category: up to 4 for
/// categories with 4+ possible values (case, tense, mood), only 3 for
/// voice and person (their total possible-value count is smaller).
class GrammarQuizQuestion {
  final ParsingWord word;
  final GrammarValueExplanation correctExplanation;
  final List<GrammarValueExplanation> options;
  final int correctIndex;

  const GrammarQuizQuestion({
    required this.word,
    required this.correctExplanation,
    required this.options,
    required this.correctIndex,
  });
}

/// Drives one Grammar-lesson session covering ALL FIVE GrammarCategory
/// dimensions — case, person, tense, voice, mood — via one unified
/// teach-phase/quiz-phase mechanic. Generalizes what was originally a
/// Cases-only pilot (see project handoff doc's Grammar cluster, items 3
/// and 4): "same mechanic as Cases, applied to the rest of
/// GrammarCategory." Replaces the retired CasesLessonEngine.
///
/// IMPORTANT — due-filtering happens OUTSIDE this engine, in
/// reader_screen.dart's _startQuiz via
/// TrackGrammarLessonProgressUseCase. Every item passed into [dueItems]
/// is assumed to need teaching this session; this class has no concept
/// of "already taught this week" — that's a persistence concern, kept
/// out of this pure domain class.
///
/// Deliberately a sibling to AlphabetQuizEngine, not built on QuizEngine
/// — a grammar-teaching moment isn't a vocabulary word with a
/// translation, same reasoning as before this generalization.
///
/// Pure — no file I/O, no Hive, no Flutter widget imports.
class GrammarLessonEngine {
  GrammarLessonEngine({required List<DueGrammarItem> dueItems, Random? random})
      : _random = random ?? Random() {
    _cards = _buildTeachCards(dueItems);
  }

  final Random _random;
  late final List<GrammarTeachCard> _cards;

  int _teachIndex = 0;
  bool _inQuizPhase = false;
  List<GrammarQuizQuestion> _quizQueue = [];
  int _quizPosition = 0;
  int _quizCorrect = 0;

  // ── Teach phase ──────────────────────────────────────────────────────

  int get cardCount => _cards.length;
  bool get isTeachPhase => !_inQuizPhase;
  bool get isQuizPhase => _inQuizPhase;
  GrammarTeachCard get currentCard => _cards[_teachIndex];
  int get teachIndex => _teachIndex;
  bool get isLastCard => _teachIndex == _cards.length - 1;

  /// Moves to the next teach card, or — after the last one — builds and
  /// starts the quiz phase.
  void advanceTeach() {
    if (_teachIndex < _cards.length - 1) {
      _teachIndex++;
    } else {
      _quizQueue = _buildQuizQueue(_cards);
      _quizPosition = 0;
      _quizCorrect = 0;
      _inQuizPhase = true;
    }
  }

  // ── Quiz phase ───────────────────────────────────────────────────────

  int get quizTotal => _quizQueue.length;
  int get quizPosition => _quizPosition;
  int get quizCorrect => _quizCorrect;
  bool get isQuizComplete => _quizPosition >= _quizQueue.length;
  GrammarQuizQuestion? get currentQuestion =>
      isQuizComplete ? null : _quizQueue[_quizPosition];

  void submitQuizAnswer(int selectedIndex) {
    final q = _quizQueue[_quizPosition];
    if (selectedIndex == q.correctIndex) _quizCorrect++;
    _quizPosition++;
  }

  /// Every distinct (category, code) pair this session actually taught,
  /// as combined "categoryName:code" strings (see [grammarKey]) — the
  /// screen persists these once the session finishes, via
  /// TrackGrammarLessonProgressUseCase.recordTaught, resetting the
  /// weekly clock for exactly these values.
  Set<String> get taughtKeys => _cards
      .expand((c) => c.explanations)
      .map((e) => grammarKey(e.category, e.code))
      .toSet();

  // ── Construction ─────────────────────────────────────────────────────

  List<GrammarTeachCard> _buildTeachCards(List<DueGrammarItem> dueItems) {
    final cards = <GrammarTeachCard>[];
    for (final item in dueItems) {
      final explanations = <GrammarValueExplanation>[];
      for (final category in item.dueCategories) {
        final code = item.word.codeFor(category);
        if (code == null) continue;

        final categoryMap = grammarExplanations[category];
        if (categoryMap == null) continue;

        final explanation = categoryMap[code];
        if (explanation == null) continue;

        explanations.add(explanation);
      }

      if (explanations.isEmpty) continue;

      // Same-lemma comparison: search across all due items for a
      // different occurrence of the same lemma in any of the same
      // categories but with a different code.
      ParsingWord? comparison;
      outer:
      for (final other in dueItems) {
        if (identical(other.word, item.word)) continue;
        if (other.word.lemma.isEmpty || other.word.lemma != item.word.lemma) {
          continue;
        }
        for (final cat in item.dueCategories) {
          if (!other.dueCategories.contains(cat)) continue;
          final itemCode = item.word.codeFor(cat);
          final otherCode = other.word.codeFor(cat);
          if (itemCode != null && otherCode != null && itemCode != otherCode) {
            comparison = other.word;
            break outer;
          }
        }
      }

      cards.add(GrammarTeachCard(
        word: item.word,
        explanations: explanations,
        comparisonWord: comparison,
      ));
    }
    return cards;
  }

  List<GrammarQuizQuestion> _buildQuizQueue(List<GrammarTeachCard> cards) {
    final questions = <GrammarQuizQuestion>[];
    for (final card in cards) {
      for (final explanation in card.explanations) {
        final categoryValues =
            grammarExplanations[explanation.category]!.values;
        final pool =
            categoryValues.where((e) => e.code != explanation.code).toList()
              ..shuffle(_random);
        final take = pool.length < 3 ? pool.length : 3;
        final options = [explanation, ...pool.take(take)]
          ..shuffle(_random);
        final correctIndex = options.indexOf(explanation);
        questions.add(GrammarQuizQuestion(
          word: card.word,
          correctExplanation: explanation,
          options: options,
          correctIndex: correctIndex,
        ));
      }
    }
    questions.shuffle(_random);
    return questions;
  }
}

/// Combined key used both for persistence
/// (TrackGrammarLessonProgressUseCase) and for [GrammarLessonEngine
/// .taughtKeys] above — kept as one shared function so the two never
/// drift apart on format.
String grammarKey(GrammarCategory category, String code) =>
    '${category.name}:$code';