// lib/domain/quiz/question_types/word_order_challenge.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/text_normalizer.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';

/// Shows a short phrase from the verse (centered on the target word)
/// with its words shuffled into tiles; user taps them in order to
/// reconstruct the correct word order.
///
/// The English meaning of the FULL phrase is shown at top as the goal
/// sentence — that's the actual challenge ("given this meaning, arrange
/// the Greek"). Individual tiles show ONLY the Greek word, deliberately
/// — showing each tile's own translation underneath it would let the
/// user solve the puzzle by matching English words to the goal
/// sentence's word order rather than actually knowing Greek word order,
/// defeating the point of the question type.
class WordOrderChallengeQuestion implements QuizQuestion {
  WordOrderChallengeQuestion({
    required QuizWord target,
    required String verseText,
    required List<QuizWord> allWords,
    required Random random,
  })  : _target = target,
        _phraseWords = _buildPhrase(verseText, target.word),
        _wordMap = {for (final w in allWords) w.word: w},
        _random = random;

  final QuizWord _target;
  final List<String> _phraseWords;
  final Map<String, QuizWord> _wordMap;
  final Random _random;

  static List<String> _buildPhrase(String verseText, String targetWord) {
    final tokens = verseText.split(RegExp(r'\s+'));
    final centerIndex = tokens.indexWhere((t) => t.contains(targetWord));
    if (centerIndex == -1) return tokens.take(5).toList();
    const radius = 2;
    final start = max(0, centerIndex - radius);
    final end = min(tokens.length, centerIndex + radius + 1);
    return tokens.sublist(start, end);
  }

  String _translationFor(String token) {
    final bare = TextNormalizer.extractWords(token).firstOrNull ?? token;
    return _wordMap[bare]?.translation ?? '';
  }

  /// The full phrase's English meaning, shown once at the top as the
  /// goal sentence — this is the ONLY translation surfaced anywhere in
  /// this question type. See class doc for why per-tile translations
  /// were removed.
  String get _englishPhrase =>
      _phraseWords.map(_translationFor).where((t) => t.isNotEmpty).join(' / ');

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.wordOrderChallenge;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    return _WordOrderChallengeView(
      phraseWords: _phraseWords,
      englishPhrase: _englishPhrase,
      random: _random,
      onAnswered: onAnswered,
    );
  }
}

class _WordOrderChallengeView extends StatefulWidget {
  final List<String> phraseWords;
  final String englishPhrase;
  final Random random;
  final void Function(bool correct) onAnswered;

  const _WordOrderChallengeView({
    required this.phraseWords,
    required this.englishPhrase,
    required this.random,
    required this.onAnswered,
  });

  @override
  State<_WordOrderChallengeView> createState() =>
      _WordOrderChallengeViewState();
}

class _WordOrderChallengeViewState extends State<_WordOrderChallengeView> {
  late List<String> _shuffled;
  late List<bool> _used;
  late List<String> _answer;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _shuffled = List<String>.from(widget.phraseWords);
    do {
      _shuffled.shuffle(widget.random);
    } while (_shuffled.join(' ') == widget.phraseWords.join(' ') &&
        widget.phraseWords.length > 1);
    _used = List<bool>.filled(_shuffled.length, false);
    _answer = [];
  }

  void _tapTile(int index) {
    if (_locked || _used[index]) return;
    setState(() {
      _used[index] = true;
      _answer.add(_shuffled[index]);
    });
    if (_answer.length == _shuffled.length) _checkAnswer();
  }

  void _undoLast() {
    if (_locked || _answer.isEmpty) return;
    final word = _answer.removeLast();
    for (var i = _used.length - 1; i >= 0; i--) {
      if (_used[i] && _shuffled[i] == word) {
        setState(() => _used[i] = false);
        break;
      }
    }
    setState(() {});
  }

  void _checkAnswer() {
    _locked = true;
    final correct = _answer.join(' ') == widget.phraseWords.join(' ');
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onAnswered(correct);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final correctSoFar = _answer.join(' ') == widget.phraseWords.join(' ');

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Put the words in order',
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.englishPhrase.isNotEmpty)
            Text(
              '"${widget.englishPhrase}"',
              style: TextStyle(
                fontSize: 14,
                color: colors.primary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: _undoLast,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: _answer
                    .map((w) => Text(
                          w,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: List.generate(_shuffled.length, (i) {
              final used = _used[i];
              return GestureDetector(
                onTap: () => _tapTile(i),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: used ? 0.25 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
                    // Greek word only — no translation. See class doc:
                    // showing each tile's meaning would let the user
                    // solve this by matching English words to the goal
                    // sentence instead of knowing Greek word order.
                    child: Text(
                      _shuffled[i],
                      style: TextStyle(
                        fontSize: 18,
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
            'Tap the answer zone to undo',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}