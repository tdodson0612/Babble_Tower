// lib/domain/quiz/question_types/matching_pairs.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';

/// Shows 4 Greek words (target + 3 distractors) and their English meanings
/// in two shuffled columns. User taps one Greek word then its matching
/// English meaning to form a pair.
///
/// Fix #5: user must complete ALL 4 pairs before the question resolves.
/// The question is scored correct if the target word was matched to its
/// own translation, incorrect if it was matched to a wrong translation.
/// The question does not advance automatically after one match.
class MatchingPairsQuestion implements QuizQuestion {
  MatchingPairsQuestion({
    required QuizWord target,
    required List<QuizWord> distractorPool,
    required Random random,
  })  : _target = target,
        _pairWords = _buildPairWords(target, distractorPool, random);

  final QuizWord _target;
  final List<QuizWord> _pairWords;

  static List<QuizWord> _buildPairWords(
    QuizWord target,
    List<QuizWord> pool,
    Random random,
  ) {
    final candidates = pool
        .where((w) => w.translation.isNotEmpty && w.word.isNotEmpty)
        .toList()
      ..shuffle(random);
    final distractors = candidates.take(3).toList();
    return [target, ...distractors];
  }

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.matchingPairs;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    return _MatchingPairsView(
      target: _target,
      pairWords: _pairWords,
      onAnswered: onAnswered,
    );
  }
}

class _MatchingPairsView extends StatefulWidget {
  final QuizWord target;
  final List<QuizWord> pairWords;
  final void Function(bool correct) onAnswered;

  const _MatchingPairsView({
    required this.target,
    required this.pairWords,
    required this.onAnswered,
  });

  @override
  State<_MatchingPairsView> createState() => _MatchingPairsViewState();
}

class _MatchingPairsViewState extends State<_MatchingPairsView> {
  late List<QuizWord> _greekColumn;
  late List<QuizWord> _englishColumn;

  int? _selectedGreekIndex;

  /// Words that have been correctly matched, keyed by word string.
  final Set<String> _matched = {};

  /// Words that were incorrectly attempted — shown in red briefly.
  final Set<String> _wrongAttempt = {};

  /// Whether the target word has been resolved (correctly or incorrectly).
  /// Once resolved, the score is locked — later distractors don't
  /// change the outcome but the user still completes the board.
  bool _targetResolved = false;
  bool _targetCorrect = false;

  @override
  void initState() {
    super.initState();
    _greekColumn = List<QuizWord>.from(widget.pairWords)..shuffle(Random());
    _englishColumn = List<QuizWord>.from(widget.pairWords)..shuffle(Random());
  }

  void _tapGreek(int index) {
    if (_matched.contains(_greekColumn[index].word)) return;
    setState(() {
      _selectedGreekIndex = index;
      _wrongAttempt.clear();
    });
  }

  void _tapEnglish(int index) {
    final sel = _selectedGreekIndex;
    if (sel == null) return;
    final greekWord = _greekColumn[sel];
    final englishWord = _englishColumn[index];
    if (_matched.contains(englishWord.word)) return;

    final isMatch = greekWord.word == englishWord.word;

    if (isMatch) {
      setState(() {
        _matched.add(greekWord.word);
        _wrongAttempt.clear();
        _selectedGreekIndex = null;
      });

      // Track whether the target word was correctly matched.
      if (greekWord.word == widget.target.word && !_targetResolved) {
        _targetResolved = true;
        _targetCorrect = true;
      }

      // All 4 pairs matched — report result now.
      if (_matched.length == widget.pairWords.length) {
        Future.delayed(const Duration(milliseconds: 300), () {
          widget.onAnswered(_targetCorrect);
        });
      }
    } else {
      // Wrong match — flash red on the English tile, deselect Greek.
      setState(() {
        _wrongAttempt
          ..clear()
          ..add(englishWord.word);
        _selectedGreekIndex = null;
      });

      // If the wrong attempt involved the target word, score it
      // incorrect now — but keep the board alive so the user can
      // finish matching the remaining words before Next appears.
      if ((greekWord.word == widget.target.word ||
              englishWord.word == widget.target.word) &&
          !_targetResolved) {
        _targetResolved = true;
        _targetCorrect = false;
      }

      // Clear the red flash after a short delay.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _wrongAttempt.clear());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Match each word to its meaning',
          style: TextStyle(
            fontSize: 15,
            color: colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Match all ${widget.pairWords.length} pairs to continue',
          style: TextStyle(
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: List.generate(_greekColumn.length, (i) {
                  final w = _greekColumn[i];
                  final matched = _matched.contains(w.word);
                  final selected = _selectedGreekIndex == i;
                  return _PairTile(
                    label: w.word,
                    matched: matched,
                    selected: selected,
                    wrong: false,
                    onTap: matched ? null : () => _tapGreek(i),
                  );
                }),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: List.generate(_englishColumn.length, (i) {
                  final w = _englishColumn[i];
                  final matched = _matched.contains(w.word);
                  final wrong = _wrongAttempt.contains(w.word);
                  return _PairTile(
                    label: w.translation,
                    matched: matched,
                    selected: false,
                    wrong: wrong,
                    onTap: matched ? null : () => _tapEnglish(i),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PairTile extends StatelessWidget {
  final String label;
  final bool matched;
  final bool selected;
  final bool wrong;
  final VoidCallback? onTap;

  const _PairTile({
    required this.label,
    required this.matched,
    required this.selected,
    required this.wrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Color bg;
    Color border;

    if (matched) {
      bg = colors.primary.withValues(alpha: 0.1);
      border = colors.primary;
    } else if (wrong) {
      bg = colors.accent.withValues(alpha: 0.12);
      border = colors.accent;
    } else if (selected) {
      bg = colors.highlight;
      border = colors.accent;
    } else {
      bg = colors.surface;
      border = colors.border;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
              color: border,
              width: (selected || wrong || matched) ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: matched ? colors.primary : colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}