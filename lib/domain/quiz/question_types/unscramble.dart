// lib/domain/quiz/question_types/unscramble.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';

/// Shows the Greek word's letters shuffled into tiles; user taps them in
/// order to reconstruct the correct spelling. Distinct from SpellTheWord
/// in that the prompt here is the scrambled letters themselves (no
/// English translation shown) — this tests recognition of the written
/// form, not recall from meaning.
class UnscrambleQuestion implements QuizQuestion {
  UnscrambleQuestion({required QuizWord target, required Random random})
      : _target = target,
        _random = random;

  final QuizWord _target;
  final Random _random;

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.unscramble;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    return _UnscrambleView(
      target: _target,
      random: _random,
      onAnswered: onAnswered,
    );
  }
}

class _UnscrambleView extends StatefulWidget {
  final QuizWord target;
  final Random random;
  final void Function(bool correct) onAnswered;

  const _UnscrambleView({
    required this.target,
    required this.random,
    required this.onAnswered,
  });

  @override
  State<_UnscrambleView> createState() => _UnscrambleViewState();
}

class _UnscrambleViewState extends State<_UnscrambleView> {
  late List<String> _tiles; // scrambled letters
  late List<bool> _used;
  late List<String> _answer; // letters placed so far, in order
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    final letters = widget.target.word.split('');
    _tiles = List<String>.from(letters);
    // Guarantee the scramble isn't accidentally identical to the answer
    // for words longer than 1 letter.
    do {
      _tiles.shuffle(widget.random);
    } while (_tiles.join() == widget.target.word && letters.length > 1);
    _used = List<bool>.filled(_tiles.length, false);
    _answer = [];
  }

  void _tapTile(int index) {
    if (_locked || _used[index]) return;
    setState(() {
      _used[index] = true;
      _answer.add(_tiles[index]);
    });
    if (_answer.length == _tiles.length) {
      _checkAnswer();
    }
  }

  void _undoLast() {
    if (_locked || _answer.isEmpty) return;
    final letter = _answer.removeLast();
    for (var i = _used.length - 1; i >= 0; i--) {
      if (_used[i] && _tiles[i] == letter) {
        setState(() => _used[i] = false);
        break;
      }
    }
    setState(() {});
  }

  void _checkAnswer() {
    _locked = true;
    final correct = _answer.join() == widget.target.word;
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onAnswered(correct);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final correctSoFar = _answer.join() == widget.target.word;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Unscramble the word',
          style: TextStyle(
            fontSize: 15,
            color: colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // Issue #1 fix: show English translation so user knows what
        // word they are trying to spell.
        Text(
          widget.target.translation.isNotEmpty
              ? widget.target.translation
              : '(no translation)',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Answer row
        GestureDetector(
          onTap: _undoLast,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.highlight,
              border: Border.all(
                color: _locked
                    ? (correctSoFar ? colors.primary : colors.accent)
                    : colors.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _answer.isEmpty ? ' ' : _answer.join(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Scrambled tile pool
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_tiles.length, (i) {
            final used = _used[i];
            return GestureDetector(
              onTap: () => _tapTile(i),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: used ? 0.25 : 1.0,
                child: Container(
                  width: 44,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: used
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Text(
                    _tiles[i],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap the answer to undo',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ],
    );
  }
}