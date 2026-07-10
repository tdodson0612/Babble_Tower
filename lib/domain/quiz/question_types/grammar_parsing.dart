// lib/domain/quiz/question_types/grammar_parsing.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../entities/parsing_word.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';
import 'greek_to_english_mc.dart' show McQuestionView;

/// Highlights a Greek word within its verse context and asks the user to
/// identify one grammatical dimension of it — case for nominals (noun,
/// article, adjective, pronoun), or a randomly chosen one of
/// person/tense/voice/mood for verbs. Only ever constructed by the engine
/// for words where ParsingWord.isQuizzable is true — see
/// QuizEngine._eligibleTypes.
///
/// Phase 10. Per the handoff doc's "Adding a new question type" note,
/// this class is the only new file the question itself required; engine
/// wiring is one enum value + one switch case (quiz_question.dart /
/// quiz_engine.dart), plus one additive optional constructor param on
/// QuizEngine so it can be told about a verse's morphology data at all.
class GrammarParsingQuestion implements QuizQuestion {
  factory GrammarParsingQuestion({
    required QuizWord target,
    required ParsingWord parsingWord,
    required String verseText,
    required Random random,
  }) {
    // Computed once, here, and threaded through — NOT called twice with
    // the same Random instance, which would silently pick two different
    // categories (verbs have multiple available dimensions) and desync
    // the displayed question from the "correct" answer.
    final category =
        parsingWord.quizCategory(random) ?? GrammarCategory.grammaticalCase;
    return GrammarParsingQuestion._(
      target: target,
      parsingWord: parsingWord,
      category: category,
      verseText: verseText,
      options: _buildOptions(parsingWord, category, random),
    );
  }

  GrammarParsingQuestion._({
    required QuizWord target,
    required this.parsingWord,
    required this.category,
    required String verseText,
    required List<String> options,
  })  : _target = target,
        _verseText = verseText,
        _options = options;

  final QuizWord _target;
  final String _verseText;
  final ParsingWord parsingWord;
  final GrammarCategory category;

  /// Human-readable labels — correct answer + up to 3 distractors, all
  /// drawn from the same category so options are never trivially
  /// distinguishable by type (e.g. never mixes a case with a tense).
  final List<String> _options;

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.grammarParsing;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    final colors = context.colors;
    final correctCode = parsingWord.codeFor(category)!;
    final correctLabel = ParsingWord.labelFor(category, correctCode);
    final index = _verseText.indexOf(parsingWord.word);
    final before = index == -1 ? _verseText : _verseText.substring(0, index);
    final highlighted =
        index == -1 ? '' : parsingWord.word;
    final after =
        index == -1 ? '' : _verseText.substring(index + parsingWord.word.length);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 28),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 20,
                height: 1.6,
                color: colors.textPrimary,
              ),
              children: [
                TextSpan(text: before),
                TextSpan(
                  text: highlighted,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                TextSpan(text: after),
              ],
            ),
          ),
        ),
        Expanded(
          child: McQuestionView(
            prompt:
                'What ${category.displayName.toLowerCase()} is the highlighted word?',
            promptIsGreek: false,
            options: _options,
            correctIndex: _options.indexOf(correctLabel),
            onAnswered: onAnswered,
          ),
        ),
      ],
    );
  }

  static List<String> _buildOptions(
    ParsingWord word,
    GrammarCategory category,
    Random random,
  ) {
    final correctCode = word.codeFor(category)!;
    final distractorCodes = ParsingWord.allCodesFor(category)
        .where((c) => c != correctCode)
        .toList()
      ..shuffle(random);
    final chosenCodes = [correctCode, ...distractorCodes.take(3)]
      ..shuffle(random);
    return chosenCodes.map((c) => ParsingWord.labelFor(category, c)).toList();
  }
}