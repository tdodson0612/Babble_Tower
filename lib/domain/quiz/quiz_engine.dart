// lib/domain/quiz/quiz_engine.dart

import 'dart:math';
import '../entities/parsing_word.dart';
import 'quiz_models.dart';
import 'quiz_question.dart';
import 'question_types/greek_to_english_mc.dart';
import 'question_types/english_to_greek_mc.dart';
import 'question_types/spell_the_word.dart';
import 'question_types/unscramble.dart';
import 'question_types/matching_pairs.dart';
import 'question_types/verse_fill_in_blank.dart';
import 'question_types/tap_word_in_context.dart';
import 'question_types/word_order_challenge.dart';
import 'question_types/grammar_parsing.dart';
import 'question_types/listening_recognition.dart';

/// Callback the engine uses to report a mastery change for a word, so the
/// screen layer can persist it via VocabularyNotifier.markKnown/markUnknown.
/// The engine itself never touches Hive, Riverpod, or any provider — it is
/// pure domain logic, which keeps it independently testable.
typedef MasteryUpdateCallback = void Function(String word, bool correct);

/// Phase 10 — reports a grammar-parsing answer separately from vocab
/// mastery, so the screen can persist it via TrackParsingProgressUseCase.
/// Kept as its own callback rather than overloading [MasteryUpdateCallback]
/// because the two track genuinely different skills (knowing a word vs.
/// recognizing its grammatical form) in separate Hive boxes — see
/// parsing_progress_model.dart's doc comment.
typedef GrammarAnswerCallback = void Function(
    String categoryName, bool correct);

/// Drives a single verse quiz session end-to-end.
///
/// Responsibilities (and ONLY these — see Phase 4 in the handoff doc,
/// "Core engine only handles: question selection, score tracking, mastery
/// updates, rule enforcement"):
///   - Building the question queue from the verse's vocabulary.
///   - Selecting which question type to use for each word.
///   - Weighting low-mastery words to appear more frequently.
///   - Re-asking incorrect answers near the end of the same quiz.
///   - Tracking score, XP, and streak.
///   - Reporting mastery changes via [onMasteryUpdate].
///
/// It does NOT know how any individual question type renders itself —
/// that is entirely encapsulated inside each QuizQuestion implementation.
class QuizEngine {
  QuizEngine({
    required List<QuizWord> words,
    required String verseText,
    required MasteryUpdateCallback onMasteryUpdate,
    List<ParsingWord> morphology = const [],
    GrammarAnswerCallback? onGrammarAnswered,
    Random? random,
  })  : _allWords = words,
        _verseText = verseText,
        _onMasteryUpdate = onMasteryUpdate,
        _onGrammarAnswered = onGrammarAnswered,
        _morphologyByWord = {for (final m in morphology) m.word: m},
        _random = random ?? Random() {
    _buildQueue();
  }

  final List<QuizWord> _allWords;
  final String _verseText;
  final MasteryUpdateCallback _onMasteryUpdate;
  final GrammarAnswerCallback? _onGrammarAnswered;
  final Random _random;

  /// Phase 10 — surface form -> parsing data, built once from whatever
  /// morphology data the screen loaded for this verse. Empty map (the
  /// default) means grammarParsing is simply never eligible — every
  /// existing call site that doesn't pass [morphology] behaves exactly
  /// as before this change.
  final Map<String, ParsingWord> _morphologyByWord;

  /// The full ordered queue of (word, type) pairs to ask this session.
  /// Built once at construction; re-asks are appended dynamically as
  /// incorrect answers come in, per the "re-ask near end" rule.
  final List<_QueueItem> _queue = [];

  int _position = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _xpEarned = 0;
  final List<QuizAnswerRecord> _history = [];
  final Set<String> _wordsNeedingReask = {};

  // ── Public surface ─────────────────────────────────────────────────────

  /// True once every queued question (including re-asks) has been answered.
  bool get isComplete => _position >= _queue.length;

  int get totalAsked => _history.length;
  int get correctCount => _correctCount;
  int get currentStreak => _streak;
  int get xpEarned => _xpEarned;

  /// 0-based progress for a progress bar: answered / total-known-so-far.
  /// Total grows if re-asks are appended, so this is intentionally an
  /// estimate rather than a fixed denominator.
  double get progressEstimate =>
      _queue.isEmpty ? 0 : _position / _queue.length;

  /// Builds and returns the next question to present, or null if the quiz
  /// is already complete. Call [submitAnswer] after the question's
  /// `onAnswered` fires before calling this again.
  QuizQuestion? nextQuestion() {
    if (isComplete) return null;
    final item = _queue[_position];
    return _buildQuestion(item);
  }

  /// Must be called once per question, immediately after the question
  /// widget reports an answer. Advances the queue, updates score/streak/XP,
  /// schedules a re-ask if incorrect, and reports the mastery change.
  void submitAnswer(QuizQuestion question, bool correct) {
    final word = question.targetWord;

    _history.add(QuizAnswerRecord(
      word: word,
      type: question.type,
      correct: correct,
    ));

    if (correct) {
      _correctCount++;
      _streak++;
      _bestStreak = max(_bestStreak, _streak);
      _xpEarned += QuizScoring.xpForCorrectAnswer(_streak);
    } else {
      _streak = 0;
      // Schedule a re-ask near the end, but only once per word per
      // session — repeated misses on the same word don't keep stacking
      // duplicate re-asks.
      if (!_wordsNeedingReask.contains(word.word)) {
        _wordsNeedingReask.add(word.word);
        _queue.add(_QueueItem(word: word, type: _pickReaskType(word)));
      }
    }

    _onMasteryUpdate(word.word, correct);

    // Phase 10 — grammarParsing answers additionally report to grammar
    // accuracy tracking. This is purely additive: vocab mastery above
    // still fires for every question type exactly as before, including
    // grammarParsing (the underlying word is still being reinforced).
    //
    // Captured to a local first — nullable instance fields don't reliably
    // promote across a null check the way local variables do (depends on
    // SDK field-promotion support), so `_onGrammarAnswered(...)` directly
    // after the null check can trip "unconditionally invoked" even though
    // the check is right there.
    final onGrammarAnswered = _onGrammarAnswered;
    if (question.type == QuizQuestionType.grammarParsing &&
        question is GrammarParsingQuestion &&
        onGrammarAnswered != null) {
      onGrammarAnswered(question.category.name, correct);
    }

    _position++;
  }

  /// Builds the final result summary. Call only once [isComplete] is true.
  QuizResult buildResult() {
    final missed = <String, QuizWord>{};
    for (final record in _history) {
      if (!record.correct) {
        missed[record.word.word] = record.word;
      } else {
        // A later correct re-ask removes the word from "missed" — the
        // doc's spec is about words still wrong at quiz end, not words
        // that were ever wrong during the session.
        missed.remove(record.word.word);
      }
    }

    return QuizResult(
      totalAsked: _history.length,
      totalCorrect: _correctCount,
      xpEarned: _xpEarned,
      bestStreak: _bestStreak,
      missedWords: missed.values.toList(),
    );
  }

  // ── Queue construction ────────────────────────────────────────────────

  /// quizLength = (vocab words × 2) + re-asked incorrect answers.
  /// Re-asks are appended dynamically in [submitAnswer], so this only
  /// builds the base 2x pass here.
  void _buildQueue() {
    final weighted = _weightedWordOrder();

    // First pass and second pass both drawn from the same weighted order,
    // reshuffled independently so the two appearances of a word don't
    // land back-to-back by coincidence more than chance allows.
    final firstPass = List<QuizWord>.from(weighted)..shuffle(_random);
    final secondPass = List<QuizWord>.from(weighted)..shuffle(_random);

    for (final w in firstPass) {
      _queue.add(_QueueItem(word: w, type: _pickTypeFor(w)));
    }
    for (final w in secondPass) {
      _queue.add(_QueueItem(word: w, type: _pickTypeFor(w)));
    }

    // Final shuffle so the two passes interleave rather than appearing
    // as two visible halves — "questions randomly mixed across types,
    // no predictable patterns".
    _queue.shuffle(_random);
  }

  /// Builds a word list where low-mastery words (0–2) appear more often
  /// than higher-mastery words, per the weighted-selection requirement.
  /// This list is the basis for BOTH passes of quizLength, so the
  /// weighting compounds across the full quiz rather than just once.
  List<QuizWord> _weightedWordOrder() {
    final result = <QuizWord>[];
    for (final w in _allWords) {
      final weight = _weightForMastery(w.masteryLevel);
      for (var i = 0; i < weight; i++) {
        result.add(w);
      }
    }
    return result;
  }

  int _weightForMastery(int masteryLevel) {
    if (masteryLevel <= 2) return 3;
    if (masteryLevel <= 4) return 2;
    return 1; // mastered (5) — lowest frequency, never zero so it still
    // satisfies "every word appears at least once per quiz".
  }

  // ── Question type selection ──────────────────────────────────────────

  /// Picks a question type for a normal (first/second pass) appearance.
  /// Excludes types that can't function for this word (e.g. fill-in-blank
  /// and tap-in-context need the word to actually appear in verse text;
  /// grammarParsing needs aligned morphology data for this specific word).
  QuizQuestionType _pickTypeFor(QuizWord word) {
    final eligible = _eligibleTypes(word);
    return eligible[_random.nextInt(eligible.length)];
  }

  /// Re-asks deliberately favor simpler, more diagnostic types
  /// (multiple choice) over construction-heavy types (word order,
  /// unscramble), since the goal is confirming recall, not re-testing
  /// production skills the user already struggled with once.
  QuizQuestionType _pickReaskType(QuizWord word) {
    final simple = [
      QuizQuestionType.greekToEnglishMc,
      QuizQuestionType.englishToGreekMc,
    ];
    return simple[_random.nextInt(simple.length)];
  }

  List<QuizQuestionType> _eligibleTypes(QuizWord word) {
    final inVerse = _verseText.contains(word.word);
    final parsingWord = _morphologyByWord[word.word];
    final hasGrammarData = parsingWord != null && parsingWord.isQuizzable;
    return [
      QuizQuestionType.greekToEnglishMc,
      QuizQuestionType.englishToGreekMc,
      QuizQuestionType.spellTheWord,
      QuizQuestionType.unscramble,
      QuizQuestionType.matchingPairs,
      if (inVerse) QuizQuestionType.verseFillInBlank,
      if (inVerse) QuizQuestionType.tapWordInContext,
      QuizQuestionType.wordOrderChallenge,
      if (hasGrammarData) QuizQuestionType.grammarParsing,
      QuizQuestionType.listeningRecognition, // Phase 7 complete — TTS wired
    ];
  }

  // ── Question construction ─────────────────────────────────────────────

  /// Translates a queue item into a concrete, ready-to-render QuizQuestion.
  /// This is the ONLY place the engine needs to know about concrete
  /// question classes — adding an 11th type means adding one case here
  /// and one entry in QuizQuestionType, nothing else in this file changes.
  QuizQuestion _buildQuestion(_QueueItem item) {
    final distractorPool = _allWords.where((w) => w.word != item.word.word).toList();

    switch (item.type) {
      case QuizQuestionType.greekToEnglishMc:
        return GreekToEnglishMcQuestion(
          target: item.word,
          distractorPool: distractorPool,
          random: _random,
        );
      case QuizQuestionType.englishToGreekMc:
        return EnglishToGreekMcQuestion(
          target: item.word,
          distractorPool: distractorPool,
          random: _random,
        );
      case QuizQuestionType.spellTheWord:
        return SpellTheWordQuestion(target: item.word, random: _random);
      case QuizQuestionType.unscramble:
        return UnscrambleQuestion(target: item.word, random: _random);
      case QuizQuestionType.matchingPairs:
        return MatchingPairsQuestion(
          target: item.word,
          distractorPool: distractorPool,
          random: _random,
        );
      case QuizQuestionType.verseFillInBlank:
        return VerseFillInBlankQuestion(
          target: item.word,
          verseText: _verseText,
          distractorPool: distractorPool,
          random: _random,
        );
      case QuizQuestionType.tapWordInContext:
        return TapWordInContextQuestion(
          target: item.word,
          verseText: _verseText,
        );
      case QuizQuestionType.wordOrderChallenge:
        return WordOrderChallengeQuestion(
          target: item.word,
          verseText: _verseText,
          allWords: _allWords,
          random: _random,
        );
      case QuizQuestionType.grammarParsing:
        // _eligibleTypes only offers this type when _morphologyByWord
        // has an entry, but _pickReaskType never selects it either, so
        // this lookup is safe; the ! documents that invariant rather
        // than silently swallowing a null.
        final parsingWord = _morphologyByWord[item.word.word]!;
        return GrammarParsingQuestion(
          target: item.word,
          parsingWord: parsingWord,
          verseText: _verseText,
          random: _random,
        );
      case QuizQuestionType.listeningRecognition:
        return ListeningRecognitionQuestion(
          target: item.word,
          distractorPool: distractorPool,
          random: _random,
        );
    }
  }
}

class _QueueItem {
  final QuizWord word;
  final QuizQuestionType type;
  const _QueueItem({required this.word, required this.type});
}