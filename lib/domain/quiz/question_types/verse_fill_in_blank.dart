// lib/domain/quiz/question_types/verse_fill_in_blank.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';
import 'greek_to_english_mc.dart' show McQuestionView;

/// Shows the full verse with the target word replaced by a blank; user
/// selects the missing Greek word from multiple choice. Only constructed
/// by the engine for words that actually appear in the verse text — see
/// QuizEngine._eligibleTypes.
class VerseFillInBlankQuestion implements QuizQuestion {
  VerseFillInBlankQuestion({
    required QuizWord target,
    required String verseText,
    required List<QuizWord> distractorPool,
    required Random random,
  })  : _target = target,
        _blankedVerse = _buildBlankedVerse(verseText, target.word),
        _options = _buildOptions(target, distractorPool, random);

  final QuizWord _target;
  final String _blankedVerse;
  final List<QuizWord> _options;

  static String _buildBlankedVerse(String verseText, String word) {
    // Replace only the first occurrence so repeated words elsewhere in
    // the verse don't all get blanked out, which would make the
    // question ambiguous or trivially easy.
    final index = verseText.indexOf(word);
    if (index == -1) return verseText; // shouldn't happen, see engine guard
    return verseText.replaceRange(index, index + word.length, '_____');
  }

  static List<QuizWord> _buildOptions(
    QuizWord target,
    List<QuizWord> pool,
    Random random,
  ) {
    final candidates = pool.where((w) => w.word.isNotEmpty).toList()
      ..shuffle(random);
    final distractors = candidates.take(3).toList();
    return [target, ...distractors]..shuffle(random);
  }

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.verseFillInBlank;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    final colors = context.colors;

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
          child: Text(
            _blankedVerse,
            style: TextStyle(
              fontSize: 20,
              height: 1.6,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: McQuestionView(
            prompt: 'Which word completes the verse?',
            promptIsGreek: false,
            options: _options.map((w) => w.word).toList(),
            correctIndex: _options.indexOf(_target),
            onAnswered: onAnswered,
          ),
        ),
      ],
    );
  }
}