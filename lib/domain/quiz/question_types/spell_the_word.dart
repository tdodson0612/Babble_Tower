// lib/domain/quiz/question_types/spell_the_word.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';

/// Shows the English translation; user taps shuffled Greek letter tiles,
/// in order, to fill blank slots and spell the target Greek word.
class SpellTheWordQuestion implements QuizQuestion {
  SpellTheWordQuestion({required QuizWord target, required Random random})
      : _target = target,
        _random = random;

  final QuizWord _target;
  final Random _random;

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.spellTheWord;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    return _SpellTheWordView(
      target: _target,
      random: _random,
      onAnswered: onAnswered,
    );
  }
}

class _SpellTheWordView extends StatefulWidget {
  final QuizWord target;
  final Random random;
  final void Function(bool correct) onAnswered;

  const _SpellTheWordView({
    required this.target,
    required this.random,
    required this.onAnswered,
  });

  @override
  State<_SpellTheWordView> createState() => _SpellTheWordViewState();
}

class _SpellTheWordViewState extends State<_SpellTheWordView> {
  late List<String> _letters; // shuffled tile pool, each letter once placed
  late List<String?> _slots; // current placement, null = empty
  late List<bool> _used; // which tile indices have been placed
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    final word = widget.target.word;
    _letters = word.split('')..shuffle(widget.random);
    _slots = List<String?>.filled(word.length, null);
    _used = List<bool>.filled(_letters.length, false);
  }

  void _placeTile(int tileIndex) {
    if (_locked || _used[tileIndex]) return;
    final nextEmptySlot = _slots.indexOf(null);
    if (nextEmptySlot == -1) return;

    setState(() {
      _slots[nextEmptySlot] = _letters[tileIndex];
      _used[tileIndex] = true;
    });

    if (!_slots.contains(null)) {
      _checkAnswer();
    }
  }

  void _removeFromSlot(int slotIndex) {
    if (_locked || _slots[slotIndex] == null) return;
    final letter = _slots[slotIndex]!;
    // Free the first matching used tile so it can be re-placed.
    for (var i = 0; i < _letters.length; i++) {
      if (_used[i] && _letters[i] == letter) {
        setState(() {
          _used[i] = false;
          _slots[slotIndex] = null;
        });
        break;
      }
    }
  }

  void _checkAnswer() {
    _locked = true;
    final attempt = _slots.join();
    final correct = attempt == widget.target.word;
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onAnswered(correct);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.target.translation.isNotEmpty
              ? widget.target.translation
              : '(unknown word)',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Blank slots
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: List.generate(_slots.length, (i) {
            final filled = _slots[i] != null;
            return GestureDetector(
              onTap: filled ? () => _removeFromSlot(i) : null,
              child: Container(
                width: 36,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? colors.highlight : colors.surface,
                  border: Border.all(
                    color: _locked
                        ? (_slots.join() == widget.target.word
                            ? colors.primary
                            : colors.accent)
                        : colors.border,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _slots[i] ?? '',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 40),

        // Letter tile pool
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_letters.length, (i) {
            final used = _used[i];
            return GestureDetector(
              onTap: () => _placeTile(i),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: used ? 0.25 : 1.0,
                child: Container(
                  width: 40,
                  height: 48,
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
                    _letters[i],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}