// lib/domain/quiz/question_types/listening_recognition.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/tts_service.dart';
import '../quiz_models.dart';
import '../quiz_question.dart';
import 'greek_to_english_mc.dart' show McQuestionView;

/// Phase 7 (now complete). Plays Modern Greek TTS audio of the target
/// word; user selects the matching Greek word from 4 choices WITHOUT
/// ever seeing it written first — the only text on screen at question
/// start is the instruction and the answer options, never the target
/// word itself. Audio auto-plays once when the question appears and is
/// replayable by tapping the speaker icon as many times as needed.
///
/// Now included in QuizEngine._eligibleTypes — see quiz_engine.dart. The
/// old exclusion comment there ("Phase 7, no TTS yet") no longer applies.
class ListeningRecognitionQuestion implements QuizQuestion {
  ListeningRecognitionQuestion({
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
    return [target, ...distractors]..shuffle(random);
  }

  @override
  QuizWord get targetWord => _target;

  @override
  QuizQuestionType get type => QuizQuestionType.listeningRecognition;

  @override
  Widget build(BuildContext context, void Function(bool correct) onAnswered) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AudioPromptButton(word: _target.word),
        const SizedBox(height: 28),
        Expanded(
          child: McQuestionView(
            prompt: 'Which word did you hear?',
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

// ── Audio prompt button ─────────────────────────────────────────────────
// Auto-plays the target word once when the question first appears
// (post-frame callback, so speech starts after the frame renders rather
// than mid-build), and lets the user tap to replay indefinitely before
// answering — there's no penalty or limit on replays.

class _AudioPromptButton extends StatefulWidget {
  final String word;
  const _AudioPromptButton({required this.word});

  @override
  State<_AudioPromptButton> createState() => _AudioPromptButtonState();
}

class _AudioPromptButtonState extends State<_AudioPromptButton> {
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  Future<void> _play() async {
    if (!mounted) return;
    setState(() => _speaking = true);
    await TtsService.instance.speak(widget.word);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    // A question that's been answered and dismissed shouldn't keep
    // talking over whatever appears next (feedback banner, next
    // question, results screen).
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: _play,
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _speaking
                  ? colors.primary.withValues(alpha: 0.15)
                  : colors.highlight,
            ),
            alignment: Alignment.center,
            child: Icon(
              _speaking ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
              size: 44,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to hear again',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}