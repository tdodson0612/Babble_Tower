// lib/domain/quiz/quiz_models.dart

import '../entities/word_entry.dart';
import 'quiz_question.dart';

/// A single vocabulary word being tested in this quiz session, carrying
/// everything a question type needs to render itself without going back
/// to Hive or the dictionary mid-quiz.
class QuizWord {
  final String word;
  final String translation;
  final String definition;
  final String lemma;
  final int masteryLevel;

  const QuizWord({
    required this.word,
    required this.translation,
    required this.definition,
    required this.lemma,
    required this.masteryLevel,
  });

  factory QuizWord.fromEntry(String word, WordEntry? entry) {
    return QuizWord(
      word: word,
      translation: entry?.translation ?? '',
      definition: entry?.definition ?? '',
      lemma: entry?.lemma ?? '',
      masteryLevel: entry?.masteryLevel ?? 0,
    );
  }
}

/// Record of a single answered question, kept for the results screen and
/// for the engine's re-ask-incorrect-near-the-end logic.
class QuizAnswerRecord {
  final QuizWord word;
  final QuizQuestionType type;
  final bool correct;

  const QuizAnswerRecord({
    required this.word,
    required this.type,
    required this.correct,
  });
}

/// Final summary handed to the results screen when a quiz session ends.
class QuizResult {
  final int totalAsked;
  final int totalCorrect;
  final int xpEarned;
  final int bestStreak;
  final List<QuizWord> missedWords;

  const QuizResult({
    required this.totalAsked,
    required this.totalCorrect,
    required this.xpEarned,
    required this.bestStreak,
    required this.missedWords,
  });

  double get scoreFraction => totalAsked == 0 ? 0 : totalCorrect / totalAsked;

  bool get passed => scoreFraction >= QuizScoring.passThreshold;
}

/// Scoring constants and pure functions. Kept separate from QuizEngine so
/// scoring rules can be unit-tested or tuned without touching selection
/// logic.
class QuizScoring {
  static const double passThreshold = 0.8;
  static const int xpPerCorrect = 10;
  static const int streakBonusAt = 5;
  static const int streakBonusAmount = 20;
  static const int bigStreakBonusAt = 10;
  static const int bigStreakBonusAmount = 50;

  /// Returns XP earned for a single correct answer given the streak length
  /// *after* this answer is counted (i.e. call with the updated streak).
  static int xpForCorrectAnswer(int streakAfterThisAnswer) {
    var xp = xpPerCorrect;
    if (streakAfterThisAnswer == bigStreakBonusAt) {
      xp += bigStreakBonusAmount;
    } else if (streakAfterThisAnswer == streakBonusAt) {
      xp += streakBonusAmount;
    }
    return xp;
  }
}