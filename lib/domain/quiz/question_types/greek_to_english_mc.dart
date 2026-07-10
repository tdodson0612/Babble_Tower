// lib/domain/quiz/question_types/greek_to_english_mc.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';

/// Shows a Greek word; user selects its English translation from 4 choices.
class GreekToEnglishMcQuestion implements QuizQuestion {
  GreekToEnglishMcQuestion({
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
    final candidates = pool.where((w) => w.translation.isNotEmpty).toList()
      ..shuffle(random);
    final distractors = candidates.take(3).toList();
    final options = [target, ...distractors]..shuffle(random);
    return options;
  }

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.greekToEnglishMc;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    return McQuestionView(
      prompt: _target.word,
      promptIsGreek: true,
      options: _options.map((w) => w.translation).toList(),
      correctIndex: _options.indexOf(_target),
      onAnswered: onAnswered,
    );
  }
}

/// Shared multiple-choice rendering used by both MC question types so the
/// visual language stays consistent without duplicating layout code.
/// Lives here rather than in the engine — it is presentation, not engine
/// logic, and engine code must stay UI-free. Public so other question-type
/// files (e.g. english_to_greek_mc.dart) can reuse it directly.
class McQuestionView extends StatefulWidget {
  final String prompt;
  final bool promptIsGreek;
  final List<String> options;
  final int correctIndex;
  final void Function(bool correct) onAnswered;

  const McQuestionView({
    required this.prompt,
    required this.promptIsGreek,
    required this.options,
    required this.correctIndex,
    required this.onAnswered,
  });

  @override
  State<McQuestionView> createState() => _McQuestionViewState();
}

class _McQuestionViewState extends State<McQuestionView> {
  int? _selected;

  void _select(int index) {
    if (_selected != null) return; // single answer only
    setState(() => _selected = index);
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onAnswered(index == widget.correctIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.prompt,
          style: TextStyle(
            fontSize: widget.promptIsGreek ? 34 : 24,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ...List.generate(widget.options.length, (i) {
          final isSelected = _selected == i;
          final isCorrect = i == widget.correctIndex;
          Color bg = colors.surface;
          Color border = colors.border;
          if (_selected != null) {
            if (isCorrect) {
              bg = colors.primary.withValues(alpha: 0.15);
              border = colors.primary;
            } else if (isSelected) {
              bg = colors.accent.withValues(alpha: 0.15);
              border = colors.accent;
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _select(i),
                style: OutlinedButton.styleFrom(
                  backgroundColor: bg,
                  side: BorderSide(color: border, width: isSelected || (isCorrect && _selected != null) ? 2 : 1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.options[i],
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}