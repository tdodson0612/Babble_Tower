// lib/domain/quiz/question_types/tap_word_in_context.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/text_normalizer.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';

/// Shows the full verse broken into tappable word chips; gives the
/// English meaning of the target word as a prompt; user taps the matching
/// Greek word directly within the verse. Only constructed by the engine
/// for words that actually appear in the verse text — see
/// QuizEngine._eligibleTypes.
class TapWordInContextQuestion implements QuizQuestion {
  TapWordInContextQuestion({
    required QuizWord target,
    required String verseText,
  })  : _target = target,
        _verseText = verseText;

  final QuizWord _target;
  final String _verseText;

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.tapWordInContext;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    return _TapWordInContextView(
      target: _target,
      verseText: _verseText,
      onAnswered: onAnswered,
    );
  }
}

class _TapWordInContextView extends StatefulWidget {
  final QuizWord target;
  final String verseText;
  final void Function(bool correct) onAnswered;

  const _TapWordInContextView({
    required this.target,
    required this.verseText,
    required this.onAnswered,
  });

  @override
  State<_TapWordInContextView> createState() => _TapWordInContextViewState();
}

class _TapWordInContextViewState extends State<_TapWordInContextView> {
  int? _tappedTokenIndex;
  late List<String> _tokens;

  @override
  void initState() {
    super.initState();
    // Split on whitespace to preserve punctuation attached to each word
    // as displayed in the verse — TextNormalizer.extractWords would strip
    // punctuation and lose the original spacing/order needed to render
    // the verse as it actually appears.
    _tokens = widget.verseText.split(RegExp(r'\s+'));
  }

  /// Strips punctuation from a token for comparison purposes only,
  /// leaving the rendered chip text untouched.
  bool _tokenMatchesTarget(String token) {
    final normalized = TextNormalizer.extractWords(token);
    return normalized.contains(widget.target.word);
  }

  void _tapToken(int index) {
    if (_tappedTokenIndex != null) return;
    setState(() => _tappedTokenIndex = index);
    final correct = _tokenMatchesTarget(_tokens[index]);
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onAnswered(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Tap the word that means:',
          style: TextStyle(
            fontSize: 14,
            color: colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 10,
          children: List.generate(_tokens.length, (i) {
            final isTapped = _tappedTokenIndex == i;
            final isCorrectToken = _tokenMatchesTarget(_tokens[i]);
            Color bg = colors.surface;
            Color border = colors.border;
            if (_tappedTokenIndex != null) {
              if (isCorrectToken) {
                bg = colors.primary.withValues(alpha: 0.15);
                border = colors.primary;
              } else if (isTapped) {
                bg = colors.accent.withValues(alpha: 0.15);
                border = colors.accent;
              }
            }
            return GestureDetector(
              onTap: () => _tapToken(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _tokens[i],
                  style: TextStyle(
                    fontSize: 18,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
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