// lib/presentation/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/book_names.dart';
import '../../../core/constants/supported_languages.dart';
import '../../../data/services/prefs_service.dart';
import '../../providers/bible_provider.dart';

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
    final colors = context.colors;
    final bibleState = ref.watch(bibleProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Babble Tower',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: colors.textPrimary),
            onPressed: () =>
                Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubtitle(colors),
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

              _buildSectionLabel('Book', colors),
              const SizedBox(height: 10),
              _buildBookPicker(bibleState, colors),

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
    final books = bibleState.availableBooks;
    final englishNames = getBookNames('en');

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
        final subtitle = index < englishNames.length
            ? englishNames[index]
            : null;

        return _BookChip(
          label:    book,
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
        // Await loadChapter before navigating so the reader has verses ready.
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