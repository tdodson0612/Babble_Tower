// lib/presentation/screens/progress/progress_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/supported_languages.dart';
import '../../../data/models/parsing_progress_model.dart';
import '../../../data/models/verse_progress_model.dart';
import '../../../data/services/vocabulary_service.dart';
import '../../../data/services/prefs_service.dart';
import '../../../domain/entities/parsing_word.dart';
import '../../../domain/entities/word_entry.dart';
import '../../../domain/usecases/track_parsing_progress_usecase.dart';
import '../../../domain/usecases/track_verse_progress_usecase.dart';
import '../../providers/language_provider.dart';

// ---------------------------------------------------------------------------
// Provider — loads all dashboard data in one async call so the screen
// stays simple and stateless.
// ---------------------------------------------------------------------------

class _DashboardData {
  final List<WordEntry> allWords;
  final List<VerseProgressModel> verseProgress;

  /// Phase 10 — grammar-parsing accuracy by category. Empty byCategory
  /// map is the normal state until the user has answered at least one
  /// grammarParsing question, which itself only happens on verses whose
  /// morphology data aligned at build time — see build_morphology.py.
  final ParsingProgressModel parsingProgress;

  const _DashboardData({
    required this.allWords,
    required this.verseProgress,
    required this.parsingProgress,
  });

  // ── Vocabulary stats ────────────────────────────────────────────────────

  int get totalWordsSeen => allWords.length;
  int get knownWords => allWords.where((w) => w.known).length;

  /// Mastered = masteryLevel >= 5 per word_entry.dart spec.
  /// Note: VocabularyService currently clamps markKnown at level 3 —
  /// this counter will show 0 until that cap is raised to 5. See
  /// vocabulary_service.dart:markKnown for the pre-existing discrepancy.
  int get masteredWords =>
      allWords.where((w) => w.masteryLevel >= 5).length;

  double get knownFraction =>
      totalWordsSeen == 0 ? 0 : knownWords / totalWordsSeen;

  // ── Verse stats ─────────────────────────────────────────────────────────

  int get versesAttempted => verseProgress.length;
  int get versesCompleted =>
      verseProgress.where((v) => v.completed).length;

  double get averageAccuracy {
    if (verseProgress.isEmpty) return 0;
    final sum =
        verseProgress.fold<double>(0, (acc, v) => acc + v.lastAccuracy);
    return sum / verseProgress.length;
  }

  int get totalRetries =>
      verseProgress.fold<int>(0, (acc, v) => acc + v.retryCount);
}

final _dashboardProvider =
    FutureProvider.autoDispose<_DashboardData>((ref) async {
  final pairKey = ref.watch(languageProvider).pairKey;
  final vocabService = VocabularyService();
  final verseUseCase = const TrackVerseProgressUseCase();
  final parsingUseCase = const TrackParsingProgressUseCase();

  final allWords = await vocabService.getAll(pairKey);
  final verseProgress = await verseUseCase.loadAll(pairKey);
  final parsingProgress = await parsingUseCase.load(pairKey);

  return _DashboardData(
    allWords: allWords,
    verseProgress: verseProgress,
    parsingProgress: parsingProgress,
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(_dashboardProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Your Progress',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: async.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load progress.\n$e',
            style: AppTextStyles.body(context),
            textAlign: TextAlign.center,
          ),
        ),
        data: (data) => _DashboardBody(data: data),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _DashboardBody extends StatelessWidget {
  final _DashboardData data;

  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ── Readability (Phase 11) ───────────────────────────────────────
        _SectionHeader(label: 'Readability', colors: colors),
        _ReadabilityCard(colors: colors),
        const SizedBox(height: 24),

        // ── Streak (placeholder) ─────────────────────────────────────────
        _SectionHeader(label: 'Streak', colors: colors),
        _StreakCard(colors: colors),
        const SizedBox(height: 24),

        // ── Vocabulary ───────────────────────────────────────────────────
        _SectionHeader(label: 'Vocabulary', colors: colors),
        _StatGrid(
          colors: colors,
          stats: [
            _Stat(
              label: 'Words seen',
              value: '${data.totalWordsSeen}',
              icon: Icons.visibility_outlined,
              color: colors.primary,
            ),
            _Stat(
              label: 'Known',
              value: '${data.knownWords}',
              icon: Icons.check_circle_outline,
              color: colors.primary,
            ),
            _Stat(
              label: 'Mastered',
              value: '${data.masteredWords}',
              icon: Icons.star_outline_rounded,
              color: colors.accent,
            ),
            _Stat(
              label: 'Known %',
              value: '${(data.knownFraction * 100).round()}%',
              icon: Icons.pie_chart_outline_rounded,
              color: colors.accent,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ProgressBar(
          label: 'Words known',
          value: data.knownFraction,
          colors: colors,
        ),
        const SizedBox(height: 24),

        // ── Verses ───────────────────────────────────────────────────────
        _SectionHeader(label: 'Verses', colors: colors),
        _StatGrid(
          colors: colors,
          stats: [
            _Stat(
              label: 'Attempted',
              value: '${data.versesAttempted}',
              icon: Icons.menu_book_outlined,
              color: colors.primary,
            ),
            _Stat(
              label: 'Completed',
              value: '${data.versesCompleted}',
              icon: Icons.lock_open_outlined,
              color: colors.primary,
            ),
            _Stat(
              label: 'Avg accuracy',
              value: '${(data.averageAccuracy * 100).round()}%',
              icon: Icons.track_changes_outlined,
              color: colors.accent,
            ),
            _Stat(
              label: 'Total retries',
              value: '${data.totalRetries}',
              icon: Icons.replay_outlined,
              color: colors.accent,
            ),
          ],
        ),
        if (data.versesAttempted > 0) ...[
          const SizedBox(height: 12),
          _ProgressBar(
            label: 'Verses completed',
            value: data.versesAttempted == 0
                ? 0
                : data.versesCompleted / data.versesAttempted,
            colors: colors,
          ),
        ],
        const SizedBox(height: 24),

        // ── Grammar (Phase 10) ──────────────────────────────────────────
        // Only shown once there's real data — most users won't have any
        // until they hit a verse whose morphology aligned and get asked
        // a grammarParsing question, so an empty state here would just
        // be dead space on day one.
        if (data.parsingProgress.byCategory.isNotEmpty) ...[
          _SectionHeader(label: 'Grammar', colors: colors),
          _GrammarAccuracyCard(progress: data.parsingProgress, colors: colors),
          const SizedBox(height: 24),
        ],

        // ── Recent verses ────────────────────────────────────────────────
        if (data.verseProgress.isNotEmpty) ...[
          _SectionHeader(label: 'Recent Activity', colors: colors),
          ..._recentVerses(data.verseProgress, colors),
        ],
      ],
    );
  }

  List<Widget> _recentVerses(
    List<VerseProgressModel> verses,
    AppColors colors,
  ) {
    // Sort by most recent attempt, show up to 10.
    final sorted = List<VerseProgressModel>.from(verses)
      ..sort((a, b) => b.lastAttemptAt.compareTo(a.lastAttemptAt));
    final recent = sorted.take(10).toList();

    return recent.map((v) => _RecentVerseTile(verse: v, colors: colors)).toList();
  }
}

// ---------------------------------------------------------------------------
// Streak card — reads directly from PrefsService (sync, already in memory)
// ---------------------------------------------------------------------------

class _StreakCard extends StatelessWidget {
  final AppColors colors;

  const _StreakCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    final current = PrefsService.currentStreak;
    final longest = PrefsService.longestStreak;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current == 0
                      ? 'No streak yet'
                      : '$current day${current == 1 ? '' : 's'} in a row',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  longest == 0
                      ? 'Complete a quiz to start your streak'
                      : 'Best: $longest day${longest == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
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
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final AppColors colors;

  const _SectionHeader({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatGrid extends StatelessWidget {
  final List<_Stat> stats;
  final AppColors colors;

  const _StatGrid({required this.stats, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: stats.map((s) => _StatCard(stat: s, colors: colors)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  final AppColors colors;

  const _StatCard({required this.stat, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(stat.icon, size: 20, color: stat.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stat.value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  stat.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final AppColors colors;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 13,
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
      ],
    );
  }
}

class _RecentVerseTile extends StatelessWidget {
  final VerseProgressModel verse;
  final AppColors colors;

  const _RecentVerseTile({required this.verse, required this.colors});

  @override
  Widget build(BuildContext context) {
    final pct = (verse.lastAccuracy * 100).round();
    final passed = verse.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: passed ? colors.primary : colors.border,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // verseKey format is "Book_chapter_verse"
              verse.verseKey.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: pct >= 80 ? colors.primary : colors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '×${verse.retryCount}',
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grammar accuracy card (Phase 10) — overall accuracy plus one bar per
// grammatical category the user has answered at least one question on.
// Reuses _ProgressBar rather than inventing a new bar widget.
// ---------------------------------------------------------------------------

class _GrammarAccuracyCard extends StatelessWidget {
  final ParsingProgressModel progress;
  final AppColors colors;

  const _GrammarAccuracyCard({required this.progress, required this.colors});

  @override
  Widget build(BuildContext context) {
    // Fixed pedagogical order (matches GrammarCategory's declared order
    // in parsing_word.dart), not whatever order Map iteration produces.
    // Only categories with at least one answered question are shown —
    // no point showing a 0/0 bar for "Voice" if the user has never hit
    // a passive-voice word yet.
    final rows = GrammarCategory.values
        .map((c) => MapEntry(c, progress.byCategory[c.name]))
        .where((e) => e.value != null && e.value!.total > 0)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                'Overall accuracy',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              Text(
                '${(progress.overallAccuracy * 100).round()}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            _ProgressBar(
              label:
                  '${row.key.displayName} (${row.value!.correct}/${row.value!.total})',
              value: row.value!.accuracy,
              colors: colors,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Readability summary card — links to the full ReadabilityScreen
// ---------------------------------------------------------------------------

class _ReadabilityCard extends StatelessWidget {
  final AppColors colors;
  const _ReadabilityCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/readability'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        colors.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:        colors.highlight,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.auto_stories_rounded,
                  size: 20, color: colors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You Can Read This Now',
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w600,
                      color:      colors.textPrimary,
                    ),
                  ),
                  Text(
                    'See which verses you can already read',
                    style: TextStyle(
                      fontSize: 12,
                      color:    colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.border),
          ],
        ),
      ),
    );
  }
}