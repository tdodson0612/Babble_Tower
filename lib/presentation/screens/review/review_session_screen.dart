// lib/presentation/screens/review/review_session_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/services/prefs_service.dart';
import '../../../data/services/sound_service.dart';
import '../../../domain/quiz/quiz_models.dart';
import '../../../domain/quiz/quiz_question.dart';
import '../../../domain/quiz/review_session_engine.dart';
import '../../../domain/usecases/spaced_repetition_usecase.dart';
import '../../providers/language_provider.dart';
import '../../providers/vocabulary_provider.dart';

/// Spaced-repetition review session — pulls due words from ACROSS the
/// whole vocabulary (see SpacedRepetitionUseCase), not a single verse.
/// Deliberately simpler than VerseQuizScreen: no morphology, no
/// per-verse progress recording, no pass/fail verse-unlock gate to pop
/// back to a caller — a review session doesn't gate anything, so this
/// screen takes no arguments and returns nothing.
class ReviewSessionScreen extends ConsumerStatefulWidget {
  const ReviewSessionScreen({super.key});

  @override
  ConsumerState<ReviewSessionScreen> createState() =>
      _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends ConsumerState<ReviewSessionScreen> {
  ReviewSessionEngine? _engine;
  QuizQuestion? _currentQuestion;
  bool _loading = true;
  bool _noWordsDue = false;
  bool _done = false;
  QuizResult? _result;
  int _questionIndex = 0;

  // Same feedback-gate shape as VerseQuizScreen — see that screen's
  // doc for why answering doesn't immediately advance.
  bool _awaitingNext = false;
  bool? _lastAnswerCorrect;
  String _lastAnswerWord = '';
  String _lastAnswerTranslation = '';

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final pairKey = ref.read(languageProvider).pairKey;
    final service = ref.read(vocabularyServiceProvider);
    final allWords = await service.getAll(pairKey);
    final due = const SpacedRepetitionUseCase().dueWords(allWords);

    if (!mounted) return;

    if (due.isEmpty) {
      setState(() {
        _noWordsDue = true;
        _loading = false;
      });
      return;
    }

    final quizWords =
        due.map((e) => QuizWord.fromEntry(e.word, e)).toList();

    _engine = ReviewSessionEngine(
      words: quizWords,
      onMasteryUpdate: _handleMasteryUpdate,
    );

    setState(() => _loading = false);
    _advance();
  }

  void _handleMasteryUpdate(String word, bool correct) {
    final notifier = ref.read(vocabularyProvider.notifier);
    if (correct) {
      notifier.markKnown(word);
    } else {
      notifier.markUnknown(word);
    }
  }

  void _advance() {
    final engine = _engine!;
    if (engine.isComplete) {
      _completeSession(engine.buildResult());
      return;
    }
    setState(() {
      _currentQuestion = engine.nextQuestion();
      _questionIndex++;
      _awaitingNext = false;
      _lastAnswerCorrect = null;
    });
  }

  void _completeSession(QuizResult result) {
    setState(() {
      _done = true;
      _result = result;
      _awaitingNext = false;
    });
    // A completed review session is genuine daily engagement, same as
    // finishing a verse quiz — counts toward the streak the same way
    // VerseQuizScreen's _completeQuiz already does.
    PrefsService.recordSession();
  }

  void _onAnswered(bool correct) {
    final engine = _engine!;
    final question = _currentQuestion!;
    engine.submitAnswer(question, correct);

    if (correct) {
      SoundService.instance.playCorrect();
    } else {
      SoundService.instance.playIncorrect();
    }

    setState(() {
      _awaitingNext = true;
      _lastAnswerCorrect = correct;
      _lastAnswerWord = question.targetWord.word;
      _lastAnswerTranslation = question.targetWord.translation;
    });
  }

  void _onNext() => _advance();

  void _skipRemaining() {
    _completeSession(_engine!.buildResult());
  }

  void _finish() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Review',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        bottom: (_done || _loading || _noWordsDue)
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _engine?.progressEstimate ?? 0,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _noWordsDue
              ? _EmptyState(colors: colors, onDone: _finish)
              : _done
                  ? _buildResults(colors)
                  : _buildSession(colors),
    );
  }

  Widget _buildSession(AppColors colors) {
    final engine = _engine;
    final question = _currentQuestion;
    if (engine == null || question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_awaitingNext && _lastAnswerCorrect != null)
          _FeedbackBanner(
            correct: _lastAnswerCorrect!,
            word: _lastAnswerWord,
            translation: _lastAnswerTranslation,
            onNext: _onNext,
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Word ${engine.totalAsked + 1}',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                    Row(
                      children: [
                        _ScorePill(
                          label: '✓',
                          count: engine.correctCount,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        _ScorePill(
                          label: '🔥',
                          count: engine.currentStreak,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 8),
                        _ScorePill(
                          label: 'XP',
                          count: engine.xpEarned,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: IgnorePointer(
                    ignoring: _awaitingNext,
                    child: KeyedSubtree(
                      key: ValueKey(
                        '${question.targetWord.word}_${question.type}'
                        '_$_questionIndex',
                      ),
                      child: question.build(context, _onAnswered),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_awaitingNext)
                  TextButton(
                    onPressed: _skipRemaining,
                    child: Text(
                      'End review now',
                      style:
                          TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(AppColors colors) {
    final result = _result!;
    final pct = result.totalAsked == 0
        ? 0
        : (result.totalCorrect / result.totalAsked * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Review complete!',
            style: AppTextStyles.subheadline(context).copyWith(
              color: colors.primary,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$pct% — ${result.totalCorrect} of ${result.totalAsked} correct',
            style: AppTextStyles.body(context).copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '+${result.xpEarned} XP · best streak ${result.bestStreak}',
            style: AppTextStyles.body(context).copyWith(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onDone;

  const _EmptyState({required this.colors, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: colors.primary),
          const SizedBox(height: 20),
          Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No words are due for review right now. Check back later.',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feedback banner — same shape as VerseQuizScreen's, self-contained
// since that one's file-private and can't be imported. ───────────────────

class _FeedbackBanner extends StatelessWidget {
  final bool correct;
  final String word;
  final String translation;
  final VoidCallback onNext;

  const _FeedbackBanner({
    required this.correct,
    required this.word,
    required this.translation,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = correct
        ? colors.primary.withValues(alpha: 0.12)
        : colors.accent.withValues(alpha: 0.12);
    final fg = correct ? colors.primary : colors.accent;
    final icon = correct ? Icons.check_circle_outline : Icons.cancel_outlined;
    final label = correct ? 'Correct!' : 'Not quite.';

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$word  —  ${translation.isNotEmpty ? translation : "(no translation)"}',
                  style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: fg,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Next',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ScorePill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}