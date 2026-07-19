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
/// Responsibilities:
///   - Building the question queue from the verse's vocabulary — ONE
///     question per word, no re-asks (see the redesign note below).
///   - Selecting which question type to use for each word.
///   - Tracking score, XP, and streak.
///   - Reporting mastery changes via [onMasteryUpdate].
///
/// It does NOT know how any individual question type renders itself —
/// that is entirely encapsulated inside each QuizQuestion implementation.
///
/// REDESIGNED (this session) from an earlier version that ran a double
/// pass over every word (each word asked twice) plus re-asked any wrong
/// answer immediately, on real user feedback that quizzes had become too
/// long. Now: each word is asked EXACTLY ONCE, via one randomly-chosen
/// eligible question type — no double pass, no re-ask, no mastery-based
/// frequency weighting (weighting to ask low-mastery words MORE OFTEN
/// doesn't make sense once every word is capped at exactly one
/// appearance — a word either appears once or not at all).
///
/// Matching Pairs needs special handling under this "once per word" rule:
/// it shows 4 words on screen at once (1 nominal target + 3 companions),
/// and ALL 4 should count as asked — not just the nominal target — or
/// the 3 companions would just get queued again separately later,
/// silently reintroducing the "too long" problem for a subset of words.
/// So THIS engine (not MatchingPairsQuestion itself) chooses which 3
/// companion words go into each Matching Pairs board, so it can mark all
/// 4 as consumed at once. See _pickMatchingPairsCompanions.
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

  /// The full ordered queue of questions to ask this session. Built once
  /// at construction — no items are ever appended afterward (no re-ask).
  final List<_QueueItem> _queue = [];

  int _position = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _xpEarned = 0;
  final List<QuizAnswerRecord> _history = [];

  // ── Public surface ─────────────────────────────────────────────────────

  /// True once every queued question has been answered.
  bool get isComplete => _position >= _queue.length;

  int get totalAsked => _history.length;
  int get correctCount => _correctCount;
  int get currentStreak => _streak;
  int get xpEarned => _xpEarned;

  /// 0-based progress for a progress bar: answered / total questions.
  /// NOTE: total QUESTIONS, not total WORDS — a Matching Pairs question
  /// covers 4 words in one queue slot, so this denominator (and
  /// totalAsked) will legitimately be smaller than _allWords.length
  /// whenever any Matching Pairs questions were selected. That's
  /// expected, not a bug: fewer total steps for the same word coverage
  /// is the whole point of this session's redesign.
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
  /// widget reports an answer. Advances the queue, updates score/streak/
  /// XP, and reports the mastery change for every word this question
  /// covered (see class doc re: Matching Pairs covering 4 words at once).
  void submitAnswer(QuizQuestion question, bool correct) {
    // _position hasn't advanced yet, so this is guaranteed to be the
    // same item nextQuestion() just built the given question from.
    final item = _queue[_position];
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
      // Deliberately NO re-ask, per this session's redesign — every
      // word is asked exactly once, correct or not.
    }

    // Report mastery for EVERY word this question covered, not just the
    // nominal target. For most question types item.coveredWords is just
    // [word]; for matchingPairs it's all 4 words shown on that board —
    // all 4 get the SAME correctness verdict (whether the nominal target
    // was matched right), a deliberate simplification rather than
    // tracking each of the 4 independently (which would need changing
    // the shared onAnswered(bool) callback every question type uses).
    for (final coveredWord in item.coveredWords) {
      _onMasteryUpdate(coveredWord.word, correct);
    }

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
        missed.remove(record.word.word);
      }
    }
    // NOTE: missedWords only reflects each question's nominal target,
    // same as _history — a Matching Pairs board's 3 companion words
    // never get their own QuizAnswerRecord, so an individually-wrong
    // companion (rare — the board requires completing all 4 pairs)
    // won't appear in this list even though its mastery was decremented
    // above. Known, minor, deliberately out of scope for this redesign.

    return QuizResult(
      totalAsked: _history.length,
      totalCorrect: _correctCount,
      xpEarned: _xpEarned,
      bestStreak: _bestStreak,
      missedWords: missed.values.toList(),
    );
  }

  // ── Queue construction ────────────────────────────────────────────────
  // Single pass: every word is visited once, in shuffled order. A word
  // already swept into an earlier Matching Pairs board (as a companion)
  // is skipped when its own turn comes up — it's already been asked.

  void _buildQueue() {
    final order = List<QuizWord>.from(_allWords)..shuffle(_random);
    final consumed = <String>{};

    for (final w in order) {
      if (consumed.contains(w.word)) continue;

      final type = _pickTypeFor(w, consumed);

      if (type == QuizQuestionType.matchingPairs) {
        final companions = _pickMatchingPairsCompanions(w, consumed);
        consumed.add(w.word);
        for (final c in companions) {
          consumed.add(c.word);
        }
        _queue.add(_QueueItem(
          word: w,
          coveredWords: [w, ...companions],
          type: type,
        ));
      } else {
        consumed.add(w.word);
        _queue.add(_QueueItem(word: w, coveredWords: [w], type: type));
      }
    }
  }

  QuizQuestionType _pickTypeFor(QuizWord word, Set<String> consumed) {
    final eligible = _eligibleTypes(word, consumed);
    return eligible[_random.nextInt(eligible.length)];
  }

  /// Excludes types that can't function for this word (e.g. fill-in-blank
  /// and tap-in-context need the word to actually appear in verse text;
  /// grammarParsing needs aligned morphology data for this specific word;
  /// matchingPairs needs at least 3 other still-unconsumed, valid words
  /// left to pair it with — see _countValidCompanions).
  List<QuizQuestionType> _eligibleTypes(QuizWord word, Set<String> consumed) {
    final inVerse = _verseText.contains(word.word);
    final parsingWord = _morphologyByWord[word.word];
    final hasGrammarData = parsingWord != null && parsingWord.isQuizzable;
    final matchingPairsViable =
        _countValidCompanions(word, consumed) >= 3;

    return [
      QuizQuestionType.greekToEnglishMc,
      QuizQuestionType.englishToGreekMc,
      QuizQuestionType.spellTheWord,
      QuizQuestionType.unscramble,
      if (matchingPairsViable) QuizQuestionType.matchingPairs,
      if (inVerse) QuizQuestionType.verseFillInBlank,
      if (inVerse) QuizQuestionType.tapWordInContext,
      QuizQuestionType.wordOrderChallenge,
      if (hasGrammarData) QuizQuestionType.grammarParsing,
      QuizQuestionType.listeningRecognition,
    ];
  }

  /// Same validity filter the original MatchingPairsQuestion used
  /// internally (non-empty word/translation) — now applied here, since
  /// this engine is the one choosing companions.
  bool _isValidMatchCandidate(QuizWord w) =>
      w.translation.isNotEmpty && w.word.isNotEmpty;

  int _countValidCompanions(QuizWord word, Set<String> consumed) {
    return _allWords
        .where((w) =>
            w.word != word.word &&
            !consumed.contains(w.word) &&
            _isValidMatchCandidate(w))
        .length;
  }

  List<QuizWord> _pickMatchingPairsCompanions(
      QuizWord word, Set<String> consumed) {
    final candidates = _allWords
        .where((w) =>
            w.word != word.word &&
            !consumed.contains(w.word) &&
            _isValidMatchCandidate(w))
        .toList()
      ..shuffle(_random);
    return candidates.take(3).toList();
  }

  // ── Question construction ─────────────────────────────────────────────

  /// Translates a queue item into a concrete, ready-to-render QuizQuestion.
  /// This is the ONLY place the engine needs to know about concrete
  /// question classes — adding an 11th type means adding one case here
  /// and one entry in QuizQuestionType, nothing else in this file changes.
  QuizQuestion _buildQuestion(_QueueItem item) {
    final distractorPool =
        _allWords.where((w) => w.word != item.word.word).toList();

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
        // item.coveredWords is [target, ...3 companions] — see
        // _buildQueue. Strip the target back out since
        // MatchingPairsQuestion takes them separately.
        final companions =
            item.coveredWords.where((w) => w.word != item.word.word).toList();
        return MatchingPairsQuestion(
          target: item.word,
          otherWords: companions,
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
        // has an entry, so this lookup is safe; the ! documents that
        // invariant rather than silently swallowing a null.
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
  /// The nominal target — used for question construction, TTS button,
  /// feedback banner text, and QuizAnswerRecord/missedWords tracking.
  final QuizWord word;

  /// EVERY word this question covers/scores. Equal to [word] alone for
  /// every type except matchingPairs, where it's [word, ...3 companions]
  /// — see QuizEngine class doc for why all 4 need tracking together.
  final List<QuizWord> coveredWords;

  final QuizQuestionType type;

  const _QueueItem({
    required this.word,
    required this.coveredWords,
    required this.type,
  });
}