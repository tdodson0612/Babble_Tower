// lib/domain/quiz/review_session_engine.dart

import 'dart:math';
import 'quiz_engine.dart' show MasteryUpdateCallback;
import 'quiz_models.dart';
import 'quiz_question.dart';
import 'question_types/greek_to_english_mc.dart';
import 'question_types/english_to_greek_mc.dart';
import 'question_types/spell_the_word.dart';
import 'question_types/unscramble.dart';
import 'question_types/matching_pairs.dart';
import 'question_types/listening_recognition.dart';

/// Drives a spaced-repetition review session — a flashcard-style pass
/// over words pulled from ACROSS THE WHOLE VOCABULARY (see
/// SpacedRepetitionUseCase), not a single verse's words.
///
/// This is a deliberate sibling to QuizEngine, not a reuse of it:
/// QuizEngine's own doc scopes it to "a single verse quiz session", and
/// several of its question types (verseFillInBlank, tapWordInContext,
/// and especially wordOrderChallenge, which is unconditionally eligible
/// with no verse-membership guard) need one real, coherent verse's text
/// to build a question from. A review session has no single verse in
/// common across its words, so this engine only draws from the six
/// question types that never depended on verse context in the first
/// place — reusing those exact same classes unchanged, not
/// reimplementing them.
///
/// Excluded vs. QuizEngine, and why: verseFillInBlank / tapWordInContext
/// (need the word inside specific verse text), wordOrderChallenge (needs
/// a whole verse to reorder), grammarParsing (needs per-verse aligned
/// morphology data, which this session has no single verse to look up).
///
/// Pure — no file I/O, no Hive, no platform channels — same reasoning
/// as QuizEngine staying I/O-free. Mastery updates are reported via the
/// same [MasteryUpdateCallback] QuizEngine uses, so the screen layer
/// persists them through the exact same VocabularyNotifier.markKnown/
/// markUnknown path — no new persistence logic anywhere.
class ReviewSessionEngine {
  ReviewSessionEngine({
    required List<QuizWord> words,
    required MasteryUpdateCallback onMasteryUpdate,
    Random? random,
  })  : _allWords = words,
        _onMasteryUpdate = onMasteryUpdate,
        _random = random ?? Random() {
    _buildQueue();
  }

  final List<QuizWord> _allWords;
  final MasteryUpdateCallback _onMasteryUpdate;
  final Random _random;

  final List<_QueueItem> _queue = [];
  int _position = 0;
  int _correctCount = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _xpEarned = 0;
  final List<QuizAnswerRecord> _history = [];
  final Set<String> _wordsNeedingReask = {};

  // ── Public surface — mirrors QuizEngine's, so the screen layer can
  // reuse the exact same UI patterns (feedback banner, score pills,
  // progress bar) with no special-casing between the two session types.

  bool get isComplete => _position >= _queue.length;
  int get totalAsked => _history.length;
  int get correctCount => _correctCount;
  int get currentStreak => _streak;
  int get xpEarned => _xpEarned;
  double get progressEstimate =>
      _queue.isEmpty ? 0 : _position / _queue.length;

  QuizQuestion? nextQuestion() {
    if (isComplete) return null;
    return _buildQuestion(_queue[_position]);
  }

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
      if (!_wordsNeedingReask.contains(word.word)) {
        _wordsNeedingReask.add(word.word);
        _queue.add(_QueueItem(word: word, type: _pickReaskType()));
      }
    }

    _onMasteryUpdate(word.word, correct);
    _position++;
  }

  QuizResult buildResult() {
    final missed = <String, QuizWord>{};
    for (final record in _history) {
      if (!record.correct) {
        missed[record.word.word] = record.word;
      } else {
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
  // Single pass only, unlike QuizEngine's double pass — a review session
  // is meant to be a quick daily check-in over potentially many due
  // words pulled from the whole vocabulary, not a thorough per-verse
  // drill. Weighting by mastery is also skipped: unlike QuizEngine
  // (which sees every word in a verse regardless of due-ness),
  // [SpacedRepetitionUseCase] has ALREADY filtered this engine's input
  // down to only overdue words, so every word here already deserves
  // attention — there's no "already mastered, ask less often" word left
  // in the pool to de-weight.

  void _buildQueue() {
    final shuffled = List<QuizWord>.from(_allWords)..shuffle(_random);
    for (final w in shuffled) {
      _queue.add(_QueueItem(word: w, type: _pickTypeFor()));
    }
  }

  QuizQuestionType _pickTypeFor() {
    const eligible = [
      QuizQuestionType.greekToEnglishMc,
      QuizQuestionType.englishToGreekMc,
      QuizQuestionType.spellTheWord,
      QuizQuestionType.unscramble,
      QuizQuestionType.matchingPairs,
      QuizQuestionType.listeningRecognition,
    ];
    return eligible[_random.nextInt(eligible.length)];
  }

  /// Same reasoning as QuizEngine._pickReaskType: favor simpler,
  /// diagnostic multiple-choice over construction-heavy types when
  /// confirming a word that was just missed.
  QuizQuestionType _pickReaskType() {
    const simple = [
      QuizQuestionType.greekToEnglishMc,
      QuizQuestionType.englishToGreekMc,
    ];
    return simple[_random.nextInt(simple.length)];
  }

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
        final otherWords = List<QuizWord>.from(distractorPool)
          ..shuffle(_random);

        return MatchingPairsQuestion(
          target: item.word,
          otherWords: otherWords.take(3).toList(),
          random: _random,
        );
      case QuizQuestionType.listeningRecognition:
        return ListeningRecognitionQuestion(
          target: item.word,
          distractorPool: distractorPool,
          random: _random,
        );
      // The remaining QuizQuestionType values (verseFillInBlank,
      // tapWordInContext, wordOrderChallenge, grammarParsing) are never
      // produced by _pickTypeFor/_pickReaskType above — see this
      // class's doc for why they're excluded from review sessions.
      default:
        throw StateError(
          'ReviewSessionEngine does not support ${item.type} — this is '
          'an engine bug (a verse-context question type was selected), '
          'not a data/content issue.',
        );
    }
  }
}

class _QueueItem {
  final QuizWord word;
  final QuizQuestionType type;
  const _QueueItem({required this.word, required this.type});
}