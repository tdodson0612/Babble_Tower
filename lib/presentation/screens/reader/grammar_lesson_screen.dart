// lib/presentation/screens/reader/grammar_lesson_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/sound_service.dart';
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
        automaticallyImplyLeading: false,
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
    final exp = card.explanation;
    // Canonical grammatical term, e.g. "Aorist" or "Passive" — pulled
    // directly from ParsingWord.labelFor rather than duplicated here.
    final properName = ParsingWord.labelFor(exp.category, exp.code);

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
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.word.word,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.highlight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 20),
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
                      style:
                          TextStyle(fontSize: 15, color: colors.textSecondary),
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
                    // Dictionary form vs. this verse's actual form —
                    // ALWAYS shown, for every category (case, person,
                    // tense, voice, mood), since every ParsingWord
                    // already carries its own citation form via
                    // .lemma. Replaces an earlier version of this
                    // section that only appeared when another due word
                    // happened to share the same lemma — this works
                    // every time instead. The part of the word that
                    // actually differs is highlighted in both forms,
                    // so the ending change is visually obvious rather
                    // than making the learner compare two full words
                    // letter by letter.
                    if (card.word.lemma.isNotEmpty &&
                        card.word.lemma != card.word.word) ...[
                      const SizedBox(height: 24),
                      Divider(color: colors.border),
                      const SizedBox(height: 12),
                      Text(
                        'Dictionary form → this verse',
                        style: TextStyle(
                            fontSize: 12, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      _WordEndingDiff(
                        lemma: card.word.lemma,
                        surfaceForm: card.word.word,
                        colors: colors,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Same word — the ending changed to show its job '
                        'in this sentence.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ],
                ),
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

/// Splits [lemma] and [surfaceForm] at their longest common prefix.
/// E.g. ("λόγος", "λόγῳ") -> stem "λόγ", lemma ending "ος", form
/// ending "ῳ". If the two strings share no prefix at all (rare, but
/// possible for irregular/suppletive forms), the "stem" is simply
/// empty and each ending is the whole word — still renders correctly,
/// just without a highlighted common part.
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

  /// [dimStem] uses a muted color for the dictionary-form's stem (since
  /// it's the reference point, not the focus) versus the full-strength
  /// text color for the verse's actual form. The ending is ALWAYS the
  /// accent color, in both words — that's the part the learner should
  /// be looking at.
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