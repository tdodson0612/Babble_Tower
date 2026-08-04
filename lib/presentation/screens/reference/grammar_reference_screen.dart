// lib/presentation/screens/reference/grammar_reference_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/parsing_word.dart';
import '../../../domain/grammar/grammar_lesson_engine.dart';

/// Fixed display order for the reference page's sections. Independent
/// of GrammarCategory's declared enum order (person, tense, voice,
/// mood, grammaticalCase) — Case leads here since it's the simpler,
/// nominal-declension concept a beginner meets first (matches the
/// original Cases-lesson pilot's teaching order).
const List<GrammarCategory> _sectionOrder = [
  GrammarCategory.grammaticalCase,
  GrammarCategory.person,
  GrammarCategory.tense,
  GrammarCategory.voice,
  GrammarCategory.mood,
];

/// Standalone, ungated, browsable reference for every grammar value the
/// Grammar lesson can teach (project handoff doc's Grammar cluster,
/// item 6 — "alphabet-grid equivalent for endings"). Unlike the Grammar
/// lesson itself, this page has NO due-filtering, NO teach/quiz
/// mechanic, and touches no progress tracking whatsoever — it's pure
/// reference material, reusing [grammarExplanations] (the same content
/// source grammar_lesson_engine.dart teaches from) so the two never
/// drift out of sync.
///
/// Reachable from both Settings and the Progress dashboard — always
/// pushed (never a root/onboarding screen), so always shows a back
/// button, unlike AlphabetGridScreen's conditional leading icon.
class GrammarReferenceScreen extends StatelessWidget {
  const GrammarReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grammar Reference',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              'Why Greek word endings change — tap any to explore',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _EndingsChartSection(),
          const SizedBox(height: 24),
          for (final category in _sectionOrder)
            _CategorySection(category: category, colors: colors),
        ],
      ),
    );
  }
}

// ── Category section ──────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final GrammarCategory category;
  final AppColors colors;

  const _CategorySection({required this.category, required this.colors});

  @override
  Widget build(BuildContext context) {
    final values = grammarExplanations[category]!.values.toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              category.displayName.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemCount: values.length,
            itemBuilder: (context, i) => _ValueTile(
              explanation: values[i],
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Value tile ───────────────────────────────────────────────────────

class _ValueTile extends StatelessWidget {
  final GrammarValueExplanation explanation;
  final AppColors colors;

  const _ValueTile({required this.explanation, required this.colors});

  @override
  Widget build(BuildContext context) {
    final properName =
        ParsingWord.labelFor(explanation.category, explanation.code);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              properName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              explanation.plainEnglish,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ValueDetailSheet(explanation: explanation),
    );
  }
}

// ── Detail bottom sheet ────────────────────────────────────────────────

class _ValueDetailSheet extends StatelessWidget {
  final GrammarValueExplanation explanation;
  const _ValueDetailSheet({required this.explanation});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final properName =
        ParsingWord.labelFor(explanation.category, explanation.code);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    properName,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    explanation.category.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              explanation.question,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              explanation.plainEnglish,
              style: TextStyle(
                fontSize: 15,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: colors.border),
            const SizedBox(height: 16),
            Text(
              explanation.exampleGloss,
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: colors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Endings charts — shows how a word's ending actually changes across
// grammatical values, side by side, for representative patterns. One
// chart for nouns (case, by declension) and one for verbs (person/tense/
// voice/mood, by conjugation). Deliberately live ONLY here, not in the
// per-verse Grammar lesson interstitial (grammar_lesson_screen.dart) —
// that screen stays scoped to one word at a time on purpose, per the
// original Cases-lesson spec's explicit "never dump huge grammar tables"
// rule. This standalone, ungated reference page is exactly where a
// fuller chart belongs instead.
//
// Both charts share one row/table shape (_ChartRow / _ChartParadigm /
// _ParadigmTable) even though nouns compare SINGULAR vs PLURAL forms of
// the same case, and verbs compare 1ST/2ND/3RD PERSON forms of the same
// tense — the visual "label | left column | right column" layout works
// for either comparison, so one widget renders both.
// ---------------------------------------------------------------------------

class _ChartRow {
  final String label;
  final String left;
  final String right;

  const _ChartRow({
    required this.label,
    required this.left,
    required this.right,
  });
}

class _ChartParadigm {
  final String title;
  final String subtitle;
  final String leftHeader;
  final String rightHeader;
  final List<_ChartRow> rows;

  const _ChartParadigm({
    required this.title,
    required this.subtitle,
    required this.rows,
    this.leftHeader = 'SINGULAR',
    this.rightHeader = 'PLURAL',
  });
}

// ── Noun declensions ─────────────────────────────────────────────────────
//
// Covers the two most common noun patterns beginners meet first in the
// Gospels (2nd declension masculine/neuter, 1st declension feminine).
// Third-declension nouns (e.g. σάρξ, πατήρ, ὄνομα) follow several
// different, more irregular stem patterns — deliberately left out of a
// single chart rather than compressed misleadingly; they're better
// introduced word-by-word as the Grammar lesson already does.

const List<_ChartParadigm> _declensionParadigms = [
  _ChartParadigm(
    title: '2nd Declension — Masculine',
    subtitle: 'like ὁ λόγος ("the word")',
    rows: [
      _ChartRow(label: 'Nominative', left: '-ος   λόγος', right: '-οι   λόγοι'),
      _ChartRow(label: 'Genitive', left: '-ου   λόγου', right: '-ων   λόγων'),
      _ChartRow(label: 'Dative', left: '-ῳ   λόγῳ', right: '-οις   λόγοις'),
      _ChartRow(
          label: 'Accusative', left: '-ον   λόγον', right: '-ους   λόγους'),
      _ChartRow(label: 'Vocative', left: '-ε   λόγε', right: '-οι   λόγοι'),
    ],
  ),
  _ChartParadigm(
    title: '2nd Declension — Neuter',
    subtitle: 'like τὸ ἔργον ("the work") — Nominative and Accusative are '
        'ALWAYS identical for neuter nouns',
    rows: [
      _ChartRow(label: 'Nominative', left: '-ον   ἔργον', right: '-α   ἔργα'),
      _ChartRow(label: 'Genitive', left: '-ου   ἔργου', right: '-ων   ἔργων'),
      _ChartRow(label: 'Dative', left: '-ῳ   ἔργῳ', right: '-οις   ἔργοις'),
      _ChartRow(label: 'Accusative', left: '-ον   ἔργον', right: '-α   ἔργα'),
      _ChartRow(label: 'Vocative', left: '-ον   ἔργον', right: '-α   ἔργα'),
    ],
  ),
  _ChartParadigm(
    title: '1st Declension — Feminine',
    subtitle: 'like ἡ γραφή ("the writing / scripture")',
    rows: [
      _ChartRow(label: 'Nominative', left: '-η   γραφή', right: '-αι   γραφαί'),
      _ChartRow(
          label: 'Genitive', left: '-ης   γραφῆς', right: '-ῶν   γραφῶν'),
      _ChartRow(label: 'Dative', left: '-ῃ   γραφῇ', right: '-αις   γραφαῖς'),
      _ChartRow(
          label: 'Accusative', left: '-ην   γραφήν', right: '-ας   γραφάς'),
      _ChartRow(label: 'Vocative', left: '-η   γραφή', right: '-αι   γραφαί'),
    ],
  ),
];

// ── Verb conjugations ────────────────────────────────────────────────────
//
// λύω ("I loose / destroy") is the standard model verb every Koine/NT
// Greek grammar uses to teach this — chosen for the same reason here.
// Four paradigms cover three of the four conjugation dimensions
// (tense, voice, mood) side by side with person; each row compares
// singular vs. plural for one person (1st/2nd/3rd), same shape as the
// declension tables above. Scope deliberately stops at four — enough to
// show tense (Present vs. Aorist), voice (Active vs. Middle/Passive),
// and mood (Indicative vs. Subjunctive) each changing the ending in a
// visibly different way, without trying to cram all 6 tense-forms ×
// 3 voices × 6 moods into one page.

const List<_ChartParadigm> _conjugationParadigms = [
  _ChartParadigm(
    title: 'Present Active Indicative',
    subtitle: 'λύω — "I loose" — happening now',
    leftHeader: '1ST / 2ND / 3RD (sing.)',
    rightHeader: '1ST / 2ND / 3RD (pl.)',
    rows: [
      _ChartRow(label: '1st person', left: 'λύω', right: 'λύομεν'),
      _ChartRow(label: '2nd person', left: 'λύεις', right: 'λύετε'),
      _ChartRow(label: '3rd person', left: 'λύει', right: 'λύουσι(ν)'),
    ],
  ),
  _ChartParadigm(
    title: 'Aorist Active Indicative',
    subtitle: 'ἔλυσα — "I loosed" — a simple, completed action',
    leftHeader: '1ST / 2ND / 3RD (sing.)',
    rightHeader: '1ST / 2ND / 3RD (pl.)',
    rows: [
      _ChartRow(label: '1st person', left: 'ἔλυσα', right: 'ἐλύσαμεν'),
      _ChartRow(label: '2nd person', left: 'ἔλυσας', right: 'ἐλύσατε'),
      _ChartRow(label: '3rd person', left: 'ἔλυσε(ν)', right: 'ἔλυσαν'),
    ],
  ),
  _ChartParadigm(
    title: 'Present Middle / Passive Indicative',
    subtitle: 'λύομαι — "I am loosed" / "I loose myself" — same tense, '
        'different voice endings',
    leftHeader: '1ST / 2ND / 3RD (sing.)',
    rightHeader: '1ST / 2ND / 3RD (pl.)',
    rows: [
      _ChartRow(label: '1st person', left: 'λύομαι', right: 'λυόμεθα'),
      _ChartRow(label: '2nd person', left: 'λύῃ', right: 'λύεσθε'),
      _ChartRow(label: '3rd person', left: 'λύεται', right: 'λύονται'),
    ],
  ),
  _ChartParadigm(
    title: 'Present Active Subjunctive',
    subtitle: 'λύω — "[that] I may loose" — possible or hoped-for, not a '
        'plain fact',
    leftHeader: '1ST / 2ND / 3RD (sing.)',
    rightHeader: '1ST / 2ND / 3RD (pl.)',
    rows: [
      _ChartRow(label: '1st person', left: 'λύω', right: 'λύωμεν'),
      _ChartRow(label: '2nd person', left: 'λύῃς', right: 'λύητε'),
      _ChartRow(label: '3rd person', left: 'λύῃ', right: 'λύωσι(ν)'),
    ],
  ),
];

class _EndingsChartSection extends StatelessWidget {
  const _EndingsChartSection();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CASE ENDINGS CHART',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Same word, five jobs — watch the ending change with each case.',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final paradigm in _declensionParadigms) ...[
          _ParadigmTable(paradigm: paradigm, colors: colors),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        Text(
          'CONJUGATION CHART',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Same verb, four settings — tense, voice, and mood each change '
          'the ending differently.',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final paradigm in _conjugationParadigms) ...[
          _ParadigmTable(paradigm: paradigm, colors: colors),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ParadigmTable extends StatelessWidget {
  final _ChartParadigm paradigm;
  final AppColors colors;

  const _ParadigmTable({required this.paradigm, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paradigm.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            paradigm.subtitle,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          // Header row
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 4,
                child: Text(
                  paradigm.leftHeader,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  paradigm.rightHeader,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Divider(color: colors.border, height: 14),
          for (final row in paradigm.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.left,
                      style: TextStyle(fontSize: 13, color: colors.accent),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.right,
                      style: TextStyle(fontSize: 13, color: colors.accent),
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