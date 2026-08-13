// lib/presentation/screens/reader/grammar_lesson_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/sound_service.dart';
import '../../../data/services/pronunciation_service.dart';
import '../../../domain/entities/parsing_word.dart';
import '../../../domain/grammar/grammar_lesson_engine.dart';
import '../../../domain/usecases/track_grammar_lesson_progress_usecase.dart';

/// Navigation arguments for the /grammar_lesson route.
class GrammarLessonArgs {
  /// Already filtered down to due (word, category) pairs by
  /// reader_screen.dart's _startQuiz — see GrammarLessonEngine's doc for
  /// why this screen doesn't do its own due-filtering.
  final List<DueGrammarItem> items;
  final String pairKey;

  const GrammarLessonArgs({required this.items, required this.pairKey});
}

/// Auto-launched from reader_screen.dart's "Take the quiz" button,
/// before /verse_quiz — teaches only the grammar values, across all five
/// GrammarCategory dimensions (case, person, tense, voice, mood),
/// actually present in the current verse and due for teaching. See the
/// project handoff doc's Grammar cluster, items 3 and 4.
///
/// Generalizes the original Cases-only pilot screen — same
/// teach-phase/quiz-phase mechanic, now driven by GrammarLessonEngine.
/// Replaces the retired CasesLessonScreen.
class GrammarLessonScreen extends StatefulWidget {
  final GrammarLessonArgs args;
  const GrammarLessonScreen({super.key, required this.args});

  @override
  State<GrammarLessonScreen> createState() => _GrammarLessonScreenState();
}

class _GrammarLessonScreenState extends State<GrammarLessonScreen> {
  static const _progress = TrackGrammarLessonProgressUseCase();
  static const _pronunciation = PronunciationService();
  late final GrammarLessonEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = GrammarLessonEngine(dueItems: widget.args.items);
  }

  void _finish() {
    // Persist "taught" for every (category, code) this session actually
    // covered — resets the weekly clock for exactly these, and no others.
    _progress.recordTaught(widget.args.pairKey, _engine.taughtKeys);
    Navigator.of(context).pop();
  }

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
          onPressed: () => Navigator.of(context).pop('exited'),
        ),
        title: Text(
          'Why did the ending change?',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: _engine.isTeachPhase ? _buildTeach(colors) : _buildQuiz(colors),
      ),
    );
  }

  // ── Teach phase ──────────────────────────────────────────────────────

  Widget _buildTeach(AppColors colors) {
    final card = _engine.currentCard;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_engine.teachIndex + 1} of ${_engine.cardCount}',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    card.word.word,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                   const SizedBox(height: 12),
                   if (card.word.lemma.isNotEmpty)
                     _LemmaVerseFormDiff(
                       lemma: card.word.lemma,
                       verseForm: card.word.word,
                       colors: colors,
                       pronunciation: _pronunciation,
                     ),
                   const SizedBox(height: 20),
                   if (card.comparisonWord != null)
                     _ComparisonRow(
                       primaryWord: card.word,
                       comparisonWord: card.comparisonWord!,
                       colors: colors,
                     ),
                   const SizedBox(height: 20),
                   ...card.explanations.map((exp) {
                    final properName =
                        ParsingWord.labelFor(exp.category, exp.code);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.highlight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exp.category.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: colors.textSecondary,
                                ),
                              ),
                              Text(
                                properName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          exp.question,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          exp.plainEnglish,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15, color: colors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          exp.exampleGloss,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => setState(() => _engine.advanceTeach()),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _engine.isLastCard ? 'Quiz me' : 'Next',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quiz phase ───────────────────────────────────────────────────────

  Widget _buildQuiz(AppColors colors) {
    if (_engine.isQuizComplete) return _buildSummary(colors);
    final q = _engine.currentQuestion!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Question ${_engine.quizPosition + 1} of ${_engine.quizTotal}',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          Text(
            q.word.word,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "What's going on with this word?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _answerQuiz(i),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    q.options[i].plainEnglish,
                    style: TextStyle(fontSize: 15, color: colors.textPrimary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _answerQuiz(int index) {
    final q = _engine.currentQuestion!;
    final correct = index == q.correctIndex;
    if (correct) {
      SoundService.instance.playCorrect();
    } else {
      SoundService.instance.playIncorrect();
    }
    setState(() => _engine.submitQuizAnswer(index));
  }

  Widget _buildSummary(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 56, color: colors.primary),
          const SizedBox(height: 16),
          Text(
            '${_engine.quizCorrect} of ${_engine.quizTotal} correct',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You won't see these again for a week.",
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Continue to quiz',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consolidated lemma → verse-form presentation.
///
/// Replaces the earlier pair of [_LemmaVerseFormRow] + [_WordEndingDiff],
/// which both presented the same lemma-vs-verse-form comparison — the row
/// showed "Lemma: X" / "Verse Form: Y" + pronunciation romanization, while
/// the diff re-shown the same two forms as a split-word ending highlight.
/// That was redundant: the lemma and verse form appeared twice on the same
/// card.
///
/// This single widget now:
///   1. Identifies the lemma and verse form once (with labels).
///   2. Makes pronunciation available once — a working TTS button that
///      plays the verse form (the word as it actually appears in this
///      verse), plus the romanized modern-Greek pronunciation for both
///      forms shown as display text (no separate Koine audio, per the
///      PronunciationService class doc).
///   3. Shows the ending-diff visualization (stem dimmed, ending
///      accented) ONLY when the forms genuinely differ, so the "what
///      changed" hint isn't wasted on identical forms.
class _LemmaVerseFormDiff extends StatefulWidget {
  final String lemma;
  final String verseForm;
  final AppColors colors;
  final PronunciationService pronunciation;

  const _LemmaVerseFormDiff({
    required this.lemma,
    required this.verseForm,
    required this.colors,
    required this.pronunciation,
  });

  @override
  State<_LemmaVerseFormDiff> createState() => _LemmaVerseFormDiffState();
}

class _LemmaVerseFormDiffState extends State<_LemmaVerseFormDiff> {
  bool _speaking = false;

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await widget.pronunciation.stop();
      if (mounted) setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await widget.pronunciation.speak(widget.verseForm);
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final lemmaPair = widget.pronunciation.getPair(widget.lemma);
    final formPair = widget.pronunciation.getPair(widget.verseForm);
    final formsDiffer =
        _formsGenuinelyDiffer(widget.lemma, widget.verseForm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Lemma: ${widget.lemma}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  _TtsButtonSmall(
                    word: widget.verseForm,
                    colors: colors,
                    speaking: _speaking,
                    onTap: _toggleSpeak,
                  ),
                ],
              ),
              if (lemmaPair.modernDisplay.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    lemmaPair.modernDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Verse Form: ${widget.verseForm}',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.textSecondary,
                ),
              ),
              if (formPair.modernDisplay.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    formPair.modernDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (formsDiffer) ...[
          const SizedBox(height: 20),
          Divider(color: colors.border),
          const SizedBox(height: 12),
          Text(
            'Dictionary form → this verse',
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _WordEndingDiff(
            lemma: widget.lemma,
            surfaceForm: widget.verseForm,
            colors: colors,
          ),
          const SizedBox(height: 6),
          Text(
            'Same word — the ending changed to show its job '
            'in this sentence.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small circular TTS button matching the pattern in verse_quiz_screen.dart.
class _TtsButtonSmall extends StatelessWidget {
  final String word;
  final AppColors colors;
  final bool speaking;
  final VoidCallback onTap;

  const _TtsButtonSmall({
    required this.word,
    required this.colors,
    required this.speaking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: speaking
              ? colors.primary.withValues(alpha: 0.15)
              : colors.highlight,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
          size: 14,
          color: speaking ? colors.primary : colors.textSecondary,
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final ParsingWord primaryWord;
  final ParsingWord comparisonWord;
  final AppColors colors;

  const _ComparisonRow({
    required this.primaryWord,
    required this.comparisonWord,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.highlight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compare:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comparisonWord.word,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, size: 16, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Same lemma:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comparisonWord.lemma,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word-ending diff — highlights just the part of the word that changed
// between the dictionary citation form and how it actually appears in
// this verse. Finds the longest shared prefix between the two strings
// and treats everything after that point as "the ending" — a simple,
// honest approximation (not a real morphological stem analyzer) that
// works well for Greek's suffix-driven inflection and matches what a
// beginner visually perceives as "the part that changed."
// ---------------------------------------------------------------------------

class _WordSplit {
  final String stem;
  final String ending;
  const _WordSplit({required this.stem, required this.ending});
}

String _normalizeForComparison(String s) {
  final buffer = StringBuffer();
  for (final codePoint in s.runes) {
    if ((codePoint >= 0x0300 && codePoint <= 0x036F) ||
        (codePoint >= 0x1AB0 && codePoint <= 0x1AFF) ||
        (codePoint >= 0x1DC0 && codePoint <= 0x1DFF) ||
        (codePoint >= 0x20D0 && codePoint <= 0x20FF) ||
        (codePoint >= 0xFE20 && codePoint <= 0xFE2F)) {
      continue;
    }
    buffer.writeCharCode(codePoint);
  }
  return buffer.toString().toLowerCase();
}

bool _formsGenuinelyDiffer(String lemma, String surfaceForm) {
  if (lemma.isEmpty) return false;
  final a = _normalizeForComparison(lemma);
  final b = _normalizeForComparison(surfaceForm);
  return a != b;
}

(_WordSplit, _WordSplit) _splitAtCommonPrefix(String lemma, String surfaceForm) {
  var i = 0;
  final minLen = lemma.length < surfaceForm.length
      ? lemma.length
      : surfaceForm.length;
  while (i < minLen && lemma[i] == surfaceForm[i]) {
    i++;
  }
  final stem = lemma.substring(0, i);
  return (
    _WordSplit(stem: stem, ending: lemma.substring(i)),
    _WordSplit(stem: stem, ending: surfaceForm.substring(i)),
  );
}

class _WordEndingDiff extends StatelessWidget {
  final String lemma;
  final String surfaceForm;
  final AppColors colors;

  const _WordEndingDiff({
    required this.lemma,
    required this.surfaceForm,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final (lemmaSplit, formSplit) = _splitAtCommonPrefix(lemma, surfaceForm);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSplitWord(lemmaSplit, dimStem: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Icon(Icons.arrow_forward, size: 16, color: colors.textSecondary),
        ),
        _buildSplitWord(formSplit, dimStem: false),
      ],
    );
  }

  Widget _buildSplitWord(_WordSplit split, {required bool dimStem}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: split.stem,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: dimStem ? colors.textSecondary : colors.textPrimary,
            ),
          ),
          TextSpan(
            text: split.ending,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.accent,
              decoration: TextDecoration.underline,
              decorationColor: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}