// lib/presentation/screens/reader/verse_quiz_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../../data/services/morphology_service.dart';
import '../../../data/services/prefs_service.dart';
import '../../../data/services/sound_service.dart';
import '../../../data/services/pronunciation_service.dart';
import '../../../domain/entities/parsing_word.dart';
import '../../../domain/quiz/quiz_engine.dart';
import '../../../domain/quiz/quiz_models.dart';
import '../../../domain/quiz/quiz_question.dart';
import '../../../domain/usecases/track_parsing_progress_usecase.dart';
import '../../../domain/usecases/track_verse_progress_usecase.dart';
import '../../providers/vocabulary_provider.dart';

/// Arguments passed via Navigator when pushing /verse_quiz.
class VerseQuizArgs {
  final String verseText;
  final String verseLabel;

  /// Structured identity fields for Phase 6 per-verse progress tracking.
  final String pairKey;
  final String book;
  final int chapter;
  final int verseNumber;

  const VerseQuizArgs({
    required this.verseText,
    required this.verseLabel,
    required this.pairKey,
    required this.book,
    required this.chapter,
    required this.verseNumber,
  });
}

/// Multi-question-type quiz for a single verse, driven by QuizEngine.
///
/// Screen-level responsibilities:
///   - Navigation / routing.
///   - Feedback banner + "Next" gate between questions (issues #2 and #3).
///   - Results display.
///
/// Everything else (selection, weighting, scoring, mastery) lives in
/// QuizEngine. Pops true (>=80%) or false to caller.
class VerseQuizScreen extends ConsumerStatefulWidget {
  const VerseQuizScreen({super.key});

  @override
  ConsumerState<VerseQuizScreen> createState() => _VerseQuizScreenState();
}

class _VerseQuizScreenState extends ConsumerState<VerseQuizScreen> {
  final _verseProgress = const TrackVerseProgressUseCase();
  final _morphologyService = MorphologyService();
  final _parsingProgress = const TrackParsingProgressUseCase();
  late VerseQuizArgs _args;

  /// Phase 10 — grammar-parsing data for this verse, loaded once in
  /// [_initQuiz] and reused by [_retry] so retrying doesn't re-hit the
  /// asset bundle. Empty (the default) is the normal case for verses
  /// that weren't tagged or didn't align — see MorphologyService's doc
  /// comment. QuizEngine treats an empty list exactly like no morphology
  /// data was ever passed.
  List<ParsingWord> _morphology = const [];

  QuizEngine? _engine;
  QuizQuestion? _currentQuestion;
  bool _initialized = false;
  bool _done = false;
  QuizResult? _result;

  /// Stable identity for the currently-displayed question, used in the
  /// KeyedSubtree key below. Deliberately NOT engine.totalAsked — that
  /// increments the instant submitAnswer() runs in _onAnswered, which
  /// happens BEFORE the feedback-banner setState, causing the STILL-
  /// DISPLAYED question widget to see its key change and get torn down
  /// and remounted mid-answer (fresh shuffle, reset tiles) at the exact
  /// moment it's locked behind IgnorePointer for the banner — this is
  /// what caused unscramble/spell/word-order tiles to appear "stuck":
  /// they'd already been silently reset and were sitting inside an
  /// ignoring-pointer region. Incremented ONLY in _advance(), so the
  /// key stays stable for the whole time a question is actually on screen.
  int _questionIndex = 0;

  // ── Feedback gate state (issues #2 and #3) ────────────────────────────
  // After the question widget fires onAnswered, we show a feedback banner
  // and wait for the user to tap "Next" before advancing. The question
  // widget stays visible behind the banner so the user can see what they
  // answered and what the correct answer was.
  bool _awaitingNext = false;
  bool? _lastAnswerCorrect;
  String _lastAnswerWord = '';
  String _lastAnswerTranslation = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)!.settings.arguments as VerseQuizArgs;
    _args = args;

    _initQuiz();
  }

  /// Async because Phase 10 needs to load this verse's grammar-parsing
  /// data (an asset read) before QuizEngine can be constructed. Until
  /// this completes, _currentQuestion stays null and _buildQuiz shows
  /// its existing loading spinner — no new loading state needed.
  Future<void> _initQuiz() async {
    final extracted = TextNormalizer.extractWords(_args.verseText);
    final vocabState = ref.read(vocabularyProvider);
    final quizWords = extracted
        .toSet()
        .map((w) => QuizWord.fromEntry(w, vocabState.entries[w]))
        .toList();

    // Phase 10 — empty list is the normal, expected outcome for verses
    // that weren't tagged or didn't align cleanly against MorphGNT at
    // build time (see build_morphology.py). QuizEngine simply won't
    // offer grammarParsing questions in that case.
    _morphology = await _morphologyService.wordsForVerse(
      _args.book,
      _args.chapter,
      _args.verseNumber,
    );

    if (!mounted) return;

    _engine = QuizEngine(
      words: quizWords,
      verseText: _args.verseText,
      onMasteryUpdate: _handleMasteryUpdate,
      morphology: _morphology,
      onGrammarAnswered: _handleGrammarAnswered,
    );

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

  /// Phase 10 — records grammar-parsing accuracy separately from vocab
  /// mastery. Fire-and-forget, same pattern as _completeQuiz's call to
  /// _verseProgress.recordAttempt below: a background Hive write, not
  /// something the UI needs to block on or react to.
  void _handleGrammarAnswered(String categoryName, bool correct) {
    _parsingProgress.recordAnswer(
      pairKey: _args.pairKey,
      categoryName: categoryName,
      correct: correct,
    );
  }

  void _advance() {
    final engine = _engine!;
    if (engine.isComplete) {
      _completeQuiz(engine.buildResult());
      return;
    }
    setState(() {
      _currentQuestion = engine.nextQuestion();
      _questionIndex++;
      _awaitingNext = false;
      _lastAnswerCorrect = null;
    });
  }

  void _completeQuiz(QuizResult result) {
    setState(() {
      _done = true;
      _result = result;
      _awaitingNext = false;
    });

    // Record a session for streak tracking on every quiz completion
    // (pass or fail). Safe to call multiple times per day.
    PrefsService.recordSession();

    final allTested = TextNormalizer.extractWords(_args.verseText).toSet();
    final missedWordStrings = result.missedWords.map((w) => w.word).toSet();
    final knownWords = allTested.difference(missedWordStrings);

    _verseProgress.recordAttempt(
      pairKey: _args.pairKey,
      book: _args.book,
      chapter: _args.chapter,
      verseNumber: _args.verseNumber,
      knownWords: knownWords,
      totalWords: allTested.length,
      passed: result.passed,
      accuracy: result.scoreFraction,
    );
  }

  /// Called by the question widget when the user submits an answer.
  /// Instead of immediately advancing, we lock the question, record the
  /// result, show feedback, and wait for "Next" tap.
  void _onAnswered(bool correct) {
    final engine = _engine!;
    final question = _currentQuestion!;
    engine.submitAnswer(question, correct);

    // Sound feedback — fires immediately, before feedback banner appears.
    // No-ops silently if audio assets aren't present yet.
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

  void _onNext() {
    _advance();
  }

  void _skipRemaining() {
    _completeQuiz(_engine!.buildResult());
  }

  void _retry() {
    final vocabState = ref.read(vocabularyProvider);
    final extracted = TextNormalizer.extractWords(_args.verseText);
    final quizWords = extracted
        .toSet()
        .map((w) => QuizWord.fromEntry(w, vocabState.entries[w]))
        .toList();
    setState(() {
      _engine = QuizEngine(
        words: quizWords,
        verseText: _args.verseText,
        onMasteryUpdate: _handleMasteryUpdate,
        morphology: _morphology,
        onGrammarAnswered: _handleGrammarAnswered,
      );
      _done = false;
      _result = null;
      _awaitingNext = false;
      _lastAnswerCorrect = null;
    });
    _advance();
  }

  void _finish() {
    Navigator.of(context).pop(_result?.passed ?? false);
  }

  // ── Build ──────────────────────────────────────────────────────────────

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
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          _args.verseLabel,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        bottom: _done
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
      body: _done ? _buildResults(colors) : _buildQuiz(colors),
    );
  }

  // ── Quiz ───────────────────────────────────────────────────────────────

  Widget _buildQuiz(AppColors colors) {
    final engine = _engine;
    final question = _currentQuestion;

    if (engine == null || question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // ── Feedback banner (issues #2 and #3) ──────────────────────────
        // Shown after the user answers. Stays visible until "Next" is
        // tapped. Green = correct, red = wrong. Always shows the word
        // and its translation so the user knows the right answer.
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
                    Row(
                      children: [
                        Text(
                          'Question ${engine.totalAsked + 1}',
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        // Phase 7: hear the target Greek word before answering.
                        _TtsButton(word: question.targetWord.word),
                      ],
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
                  // KeyedSubtree tears down and rebuilds question widget
                  // state cleanly between questions so shuffled-tile types
                  // (Spell, Unscramble, Word Order) never bleed state.
                  child: IgnorePointer(
                    // Lock interaction while feedback banner is showing.
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
                      'End quiz now',
                      style: TextStyle(
                          color: colors.textSecondary, fontSize: 13),
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

  // ── Results ────────────────────────────────────────────────────────────

  Widget _buildResults(AppColors colors) {
    final result = _result!;
    final pct = (result.scoreFraction * 100).round();
    final passed = result.passed;

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
              color: passed ? colors.primary : colors.accent,
            ),
            child: Icon(
              passed ? Icons.check : Icons.close,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            passed ? 'Verse passed!' : 'Keep practicing',
            style: AppTextStyles.subheadline(context).copyWith(
              color: passed ? colors.primary : colors.accent,
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
          const SizedBox(height: 8),
          Text(
            passed
                ? 'You can continue to the next verse.'
                : 'Score 80% or more to continue.',
            style: AppTextStyles.body(context),
            textAlign: TextAlign.center,
          ),
          if (!passed && result.missedWords.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: result.missedWords
                  .map((w) => Chip(
                        label: Text(
                          '${w.word} — ${w.translation}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: colors.highlight,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: passed ? colors.primary : colors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                passed ? 'Continue →' : 'Try again',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (!passed) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _retry,
              child: Text(
                'Retry this verse',
                style: TextStyle(color: colors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Feedback banner ───────────────────────────────────────────────────────
// Shown at the top of the quiz area after every answer (issues #2 + #3).
// Displays correct/wrong status, the word, and its translation so the user
// knows the right answer before tapping Next.

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
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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

// ── TTS button ────────────────────────────────────────────────────────────
// Reusable speaker button for the quiz screen. Plays authentic Modern
// Greek audio for the target word via PronunciationService.speakKoine —
// which, after this session's pronunciation-system rollback, is just an
// alias for the plain Modern Greek voice (see PronunciationService's
// class doc). Called via speakKoine() rather than speak() only so this
// call site doesn't need to change if a genuinely distinct Koine audio
// path is ever reintroduced later; today, both methods do the same thing.

class _TtsButton extends StatefulWidget {
  final String word;
  const _TtsButton({required this.word});

  @override
  State<_TtsButton> createState() => _TtsButtonState();
}

class _TtsButtonState extends State<_TtsButton> {
  static const _pronunciation = PronunciationService();
  bool _speaking = false;

  Future<void> _tap() async {
    if (_speaking) {
      await _pronunciation.stop();
      setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await _pronunciation.speakKoine(widget.word);
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: _tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _speaking
              ? colors.primary.withValues(alpha: 0.15)
              : colors.highlight,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
          size: 16,
          color: _speaking ? colors.primary : colors.textSecondary,
        ),
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