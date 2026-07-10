// lib/domain/quiz/question_types/english_to_greek_mc.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';
import 'greek_to_english_mc.dart' show McQuestionView;

/// Shows an English translation; user selects the matching Greek word
/// from 4 choices. Mirror image of GreekToEnglishMcQuestion — reuses the
/// same McQuestionView so both MC types render identically.
class EnglishToGreekMcQuestion implements QuizQuestion {
  EnglishToGreekMcQuestion({
    required QuizWord target,
    required List<QuizWord> distractorPool,
    required Random random,
  })  : _target = target,
        _options = _buildOptions(target, distractorPool, random);

  final QuizWord _target;
  final List<QuizWord> _options;

  static List<QuizWord> _buildOptions(
    QuizWord target,
    List<QuizWord> pool,
    Random random,
  ) {
    final candidates = pool.where((w) => w.word.isNotEmpty).toList()
      ..shuffle(random);
    final distractors = candidates.take(3).toList();
    final options = [target, ...distractors]..shuffle(random);
    return options;
  }

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.englishToGreekMc;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    // Guard: if the target word has no translation at all (shouldn't
    // happen post dictionary-fix, but defensive), fall back to a label
    // that at least doesn't show a blank prompt.
    final prompt =
        _target.translation.isNotEmpty ? _target.translation : '(unknown word)';

    return McQuestionView(
      prompt: prompt,
      promptIsGreek: false,
      options: _options.map((w) => w.word).toList(),
      correctIndex: _options.indexOf(_target),
      onAnswered: onAnswered,
    );
  }
}