// lib/domain/quiz/quiz_question.dart

import 'package:flutter/widgets.dart';
import 'quiz_models.dart';

/// Contract every quiz question type must implement.
///
/// The core engine (`QuizEngine`) only ever interacts with question types
/// through this interface. Adding a new question type means creating a new
/// class that implements `QuizQuestion` — it does NOT require touching the
/// engine, the screen, or any other question type. See Phase 4 in the
/// project handoff doc: "Adding a new question type must NOT require
/// changing core engine code."
///
/// Each concrete question type is responsible for:
///   - Building itself from a `QuizWord` + the full word pool (so it can
///     generate plausible wrong-answer distractors).
///   - Rendering its own UI via [build].
///   - Reporting whether the most recent user action was correct via the
///     `onAnswered` callback passed into [build].
///
/// A question instance is single-use: one [QuizQuestion] = one screen of
/// interaction = exactly one call to `onAnswered`.
abstract class QuizQuestion {
  /// The word this question is testing. Used by the engine for mastery
  /// updates, re-ask tracking, and "every word appears at least once".
  QuizWord get targetWord;

  /// Which question type this is. Used for analytics/debugging, to avoid
  /// asking the same type twice in a row if the engine wants to enforce
  /// variety, and (for grammarParsing specifically) so the engine can
  /// route grammar-accuracy tracking separately from vocab mastery — see
  /// QuizEngine.submitAnswer.
  QuizQuestionType get type;

  /// Builds the interactive widget for this question.
  ///
  /// [onAnswered] must be called exactly once, with `true` if the user's
  /// final answer was correct and `false` otherwise. The widget returned
  /// is responsible for all of its own internal state (selected option,
  /// tile placement, drag state, etc.) — the engine and screen do not
  /// reach into it.
  Widget build(BuildContext context, void Function(bool correct) onAnswered);
}

/// Identifies each question type. Kept as an enum (rather than relying on
/// `runtimeType`) so the engine can do weighted random selection and
/// variety enforcement without importing every concrete question class.
enum QuizQuestionType {
  greekToEnglishMc,
  englishToGreekMc,
  spellTheWord,
  unscramble,
  matchingPairs,
  verseFillInBlank,
  tapWordInContext,
  wordOrderChallenge,
  grammarParsing, // Phase 10 — requires assets/morphology data, may be absent
  listeningRecognition, // future — requires TTS, see Phase 7
}