// lib/presentation/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/book_names.dart';
import '../../../core/constants/supported_languages.dart';
import '../../../data/services/prefs_service.dart';
import '../../../domain/tutorial/example_home_tour_script.dart';
import '../../providers/bible_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../widgets/review_entry_point.dart';
import '../../widgets/tutorial/tutorial_target.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _selectedChapter;
  String? _resumeBook;
  int?    _resumeChapter;
  int?    _resumeBlock;

  @override
  void initState() {
    super.initState();
    _loadResume();

    // First-time app tour — auto-starts exactly once (see
    // TrackTutorialProgressUseCase), and stays manually re-triggerable
    // forever via Settings > "Replay Tutorial". Post-frame callback so
    // the TutorialTarget widgets below have actually mounted and
    // registered their bounds before the overlay tries to spotlight
    // them — same pattern reader_screen.dart already uses for its own
    // one-time-per-block checks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(tutorialControllerProvider.notifier)
          .maybeAutoStart(homeIntroTutorial);
    });
  }

  void _loadResume() {
    setState(() {
      _resumeBook    = PrefsService.lastBook(pairKey: AppLanguage.pairKey);
      _resumeChapter = PrefsService.lastChapter(pairKey: AppLanguage.pairKey);
      _resumeBlock   = PrefsService.lastBlock(pairKey: AppLanguage.pairKey);
    });
  }

  Future<void> _resume() async {
    if (_resumeBook == null || _resumeChapter == null) return;
    final notifier = ref.read(bibleProvider.notifier);
    await notifier.loadChapter(_resumeBook!, _resumeChapter!);
    notifier.goToBlock(_resumeBlock ?? 0);
    if (mounted) Navigator.of(context).pushNamed('/reader');
  }

  @override
  Widget build(BuildContext context) {
    final colors     = context.colors;
    final bibleState = ref.watch(bibleProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 1,
        title: Text(
          'Babble Tower',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          // Spaced-repetition review entry point. Self-contained widget
          // (watches its own due-count provider) — see
          // review_entry_point.dart. Wrapped for the app tour — see
          // example_home_tour_script.dart.
          const TutorialTarget(
            id: 'home_review_button',
            child: ReviewIconButton(),
          ),
          // Phase 9: progress dashboard entry point. Wrapped for the
          // app tour — see example_home_tour_script.dart.
          TutorialTarget(
            id: 'home_progress_button',
            child: IconButton(
              icon: Icon(Icons.bar_chart_rounded, color: colors.textPrimary),
              onPressed: () =>
                  Navigator.of(context).pushNamed('/progress'),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colors.textPrimary),
            onPressed: () =>
                Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubtitle(colors),
              const SizedBox(height: 16),
              const _HomeStreakBanner(),
              const SizedBox(height: 10),
              const _AchievementsEntryCard(),
              const SizedBox(height: 20),
              if (_resumeBook != null) ...[
                _ContinueCard(
                  book:    _resumeBook!,
                  chapter: _resumeChapter ?? 1,
                  block:   _resumeBlock   ?? 0,
                  onTap:   _resume,
                ),
                const SizedBox(height: 20),
              ],
              TutorialTarget(
                id: 'home_book_picker',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Book', colors),
                    const SizedBox(height: 10),
                    _buildBookPicker(bibleState, colors),
                  ],
                ),
              ),
              if (bibleState.selectedBook != null) ...[
                const SizedBox(height: 24),
                _buildSectionLabel('Chapter', colors),
                const SizedBox(height: 10),
                _buildChapterPicker(bibleState, colors),
              ],
              if (bibleState.selectedBook != null &&
                  _selectedChapter != null) ...[
                const SizedBox(height: 32),
                _buildStartButton(bibleState, colors),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(AppColors colors) {
    return Row(
      children: [
        _Badge(
          label: 'Reading',
          value: 'Koine Greek',
          color: colors.primary,
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text, AppColors colors) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: colors.textSecondary,
      ),
    );
  }

  Widget _buildBookPicker(BibleState bibleState, AppColors colors) {
    final books        = bibleState.availableBooks;
    final englishNames = getBookNames('en');
    // Primary chip label should be the Greek book name, with English as
    // a subtitle underneath -- see book_names.dart's doc comment. `book`
    // itself (the manifest's identifier, currently English) is left
    // untouched below: it's what gets passed to selectBook() and
    // compared against bibleState.selectedBook, and BibleService's
    // _bookFile() already resolves either form correctly, so changing
    // only the DISPLAYED label carries no risk to book/chapter loading.
    final greekNames   = getBookNames('el');

    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(books.length, (index) {
        final book     = books[index];
        final selected = book == bibleState.selectedBook;
        final label = index < greekNames.length
            ? greekNames[index]
            : book;
        final subtitle = index < englishNames.length
            ? englishNames[index]
            : null;
        return _BookChip(
          label:    label,
          subtitle: subtitle,
          selected: selected,
          colors:   colors,
          onTap: () {
            setState(() => _selectedChapter = null);
            ref.read(bibleProvider.notifier).selectBook(book);
          },
        );
      }),
    );
  }

  Widget _buildChapterPicker(BibleState bibleState, AppColors colors) {
    final chapterCount = bibleState.selectedBookChapterCount;

    if (bibleState.isLoading && chapterCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    if (chapterCount == 0) {
      return Text(
        'No chapters available for this book yet.\nAdd a JSON file to assets/bible/el/ to enable it.',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(chapterCount, (index) {
        final chapter  = index + 1;
        final selected = chapter == _selectedChapter;
        return _PillChip(
          label:    '$chapter',
          selected: selected,
          colors:   colors,
          onTap:    () => setState(() => _selectedChapter = chapter),
        );
      }),
    );
  }

  Widget _buildStartButton(BibleState bibleState, AppColors colors) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: () async {
          await ref.read(bibleProvider.notifier).loadChapter(
            bibleState.selectedBook!,
            _selectedChapter!,
          );
          if (mounted) Navigator.of(context).pushNamed('/reader');
        },
        child: Text(
          'Start  ${bibleState.selectedBook} $_selectedChapter',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak banner — the FIRST thing seen on every app open, by design.
// Reads directly from PrefsService (sync, already in memory) — same
// data source as the Progress Dashboard's streak card, just given the
// visual/psychological treatment that card intentionally doesn't have.
// ---------------------------------------------------------------------------

class _HomeStreakBanner extends StatelessWidget {
  const _HomeStreakBanner();

  void _explainStreak(BuildContext context, AppColors colors, int streak) {
    final message = streak == 0
        ? "This is your streak flame — it's a good thing! It lights up "
            'each day you study and grows brighter the longer you keep '
            'it going (orange → red → violet at 30+ days). It just '
            "hasn't lit up yet because you haven't started a streak."
        : "This is your streak — it's a good thing, not a warning! It "
            'just glows warmer the longer your streak runs. If it looks '
            "red right now, that's only because you haven't studied yet "
            "today — finish one quiz and it settles back down.";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Color _flameColor(AppColors colors, int streak) {
    if (streak >= 30) return const Color(0xFF7B61FF); // "on fire" violet
    if (streak >= 7) return const Color(0xFFFF5A36);  // deep orange-red
    if (streak >= 1) return const Color(0xFFFF9F1C);  // warm orange
    return colors.textSecondary.withValues(alpha: 0.4); // unlit / grey
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final streak = PrefsService.currentStreak;
    final atRisk = streak > 0 && !PrefsService.hasSessionToday;
    final flameColor = _flameColor(colors, streak);

    String headline;
    String subtext;
    if (streak == 0) {
      headline = 'Start your streak today';
      subtext = 'Finish one quiz to begin';
    } else if (atRisk) {
      headline = '$streak day${streak == 1 ? '' : 's'} — keep it going!';
      subtext = "You haven't studied today yet";
    } else {
      headline = '$streak day${streak == 1 ? '' : 's'} in a row';
      subtext = 'Come back tomorrow to keep it up';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: atRisk ? flameColor : colors.border,
          width: atRisk ? 1.5 : 1,
        ),
        boxShadow: atRisk
            ? [
                BoxShadow(
                  color: flameColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // UX fix: the flame read as alarming rather than encouraging
          // ("why is this a flame? seems like a bad thing"), especially
          // in its red at-risk coloring. A tap explains what it means
          // instead of leaving it to look like a warning icon.
          GestureDetector(
            onTap: () => _explainStreak(context, colors, streak),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: flameColor,
                size: 34,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: atRisk ? flameColor : colors.textSecondary,
                    fontWeight: atRisk ? FontWeight.w600 : FontWeight.w400,
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
// Achievements entry point
// ---------------------------------------------------------------------------

class _AchievementsEntryCard extends StatelessWidget {
  const _AchievementsEntryCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/achievements'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: colors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Achievements',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Continue Reading card
// ---------------------------------------------------------------------------

class _ContinueCard extends StatelessWidget {
  final String       book;
  final int          chapter;
  final int          block;
  final VoidCallback onTap;

  const _ContinueCard({
    required this.book,
    required this.chapter,
    required this.block,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      elevation: 2,
      color: colors.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continue Reading',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$book — Chapter $chapter, Block ${block + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _Badge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookChip extends StatelessWidget {
  final String  label;
  final String? subtitle;
  final bool    selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _BookChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : colors.textPrimary,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.7)
                      : colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _PillChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}