// lib/presentation/screens/progress/readability_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/supported_languages.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../../data/services/bible_service.dart';
import '../../../domain/usecases/readability_usecase.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _readabilityProvider =
    FutureProvider.autoDispose<List<BookReadability>>((ref) async {
  final bibleService = BibleService();
  final useCase      = const ReadabilityUseCase();

  // Build verseWordMap by loading all chapters for all available books.
  final verseWordMap  = <String, List<String>>{};
  final verseToBook   = <String, String>{};
  final verseToChapter= <String, int>{};
  final verseToNumber = <String, int>{};

  final books = await bibleService.getAvailableBooks(AppLanguage.targetCode);

  for (final book in books) {
    final chapterCount =
        await bibleService.getChapterCount(AppLanguage.targetCode, book);
    for (var c = 1; c <= chapterCount; c++) {
      final verses =
          await bibleService.getVerses(AppLanguage.targetCode, book, c);
      for (final verse in verses) {
        final key   = '${book}_${c}_${verse.number}';
        final words = TextNormalizer.extractWords(verse.text).toSet().toList();
        verseWordMap[key]   = words;
        verseToBook[key]    = book;
        verseToChapter[key] = c;
        verseToNumber[key]  = verse.number;
      }
    }
  }

  return useCase.compute(
    verseWordMap:   verseWordMap,
    verseToBook:    verseToBook,
    verseToChapter: verseToChapter,
    verseToNumber:  verseToNumber,
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ReadabilityScreen extends ConsumerWidget {
  const ReadabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async  = ref.watch(_readabilityProvider);

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
          'You Can Read This Now',
          style: TextStyle(
            color:      colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize:   18,
          ),
        ),
      ),
      body: async.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colors.primary),
              const SizedBox(height: 16),
              Text(
                'Calculating readability…',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not compute readability.\n$e',
            style: AppTextStyles.body(context),
            textAlign: TextAlign.center,
          ),
        ),
        data: (books) => _ReadabilityBody(books: books),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _ReadabilityBody extends StatelessWidget {
  final List<BookReadability> books;

  const _ReadabilityBody({required this.books});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (books.isEmpty) {
      return Center(
        child: Text(
          'No verse data found.\nStart reading to see your readability stats.',
          style: AppTextStyles.body(context),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Explanation note
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color:        colors.highlight,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: colors.border),
          ),
          child: Text(
            'Based on your current vocabulary. This is informational only — '
            'reading a verse still requires passing its quiz.',
            style: TextStyle(
              fontSize: 13,
              color:    colors.textSecondary,
              height:   1.5,
            ),
          ),
        ),

        // Legend
        _Legend(colors: colors),
        const SizedBox(height: 20),

        // Per-book cards
        ...books.map((b) => _BookCard(book: b, colors: colors)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Legend
// ---------------------------------------------------------------------------

class _Legend extends StatelessWidget {
  final AppColors colors;
  const _Legend({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendDot(label: 'Fully (100%)',    color: _levelColor(ReadabilityLevel.fully,     colors)),
        _LegendDot(label: 'Mostly (80%+)',   color: _levelColor(ReadabilityLevel.mostly,    colors)),
        _LegendDot(label: 'Partially (50%+)',color: _levelColor(ReadabilityLevel.partially, colors)),
        _LegendDot(label: 'Not yet (<50%)',  color: _levelColor(ReadabilityLevel.notYet,    colors)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color  color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      ],
    );
  }
}

Color _levelColor(ReadabilityLevel level, AppColors colors) {
  switch (level) {
    case ReadabilityLevel.fully:     return colors.primary;
    case ReadabilityLevel.mostly:    return colors.primary.withValues(alpha: 0.6);
    case ReadabilityLevel.partially: return colors.accent;
    case ReadabilityLevel.notYet:    return colors.border;
  }
}

// ---------------------------------------------------------------------------
// Book card
// ---------------------------------------------------------------------------

class _BookCard extends StatelessWidget {
  final BookReadability book;
  final AppColors       colors;

  const _BookCard({required this.book, required this.colors});

  @override
  Widget build(BuildContext context) {
    final pct = (book.readableFraction * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color:        colors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    book.book,
                    style: TextStyle(
                      fontSize:   17,
                      fontWeight: FontWeight.w700,
                      color:      colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$pct% readable',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      pct >= 50 ? colors.primary : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Stacked bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _StackedBar(book: book, colors: colors),
          ),
          const SizedBox(height: 12),

          // Stat row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _StatChip(
                  count: book.fullyReadable,
                  label: 'Fully',
                  color: _levelColor(ReadabilityLevel.fully, colors),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  count: book.mostlyReadable,
                  label: 'Mostly',
                  color: _levelColor(ReadabilityLevel.mostly, colors),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  count: book.partiallyReadable,
                  label: 'Partial',
                  color: _levelColor(ReadabilityLevel.partially, colors),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  count: book.notYetReadable,
                  label: 'Not yet',
                  color: _levelColor(ReadabilityLevel.notYet, colors),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  final BookReadability book;
  final AppColors       colors;

  const _StackedBar({required this.book, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = book.totalVerses;
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            _BarSegment(
              flex:  book.fullyReadable,
              color: _levelColor(ReadabilityLevel.fully, colors),
            ),
            _BarSegment(
              flex:  book.mostlyReadable,
              color: _levelColor(ReadabilityLevel.mostly, colors),
            ),
            _BarSegment(
              flex:  book.partiallyReadable,
              color: _levelColor(ReadabilityLevel.partially, colors),
            ),
            _BarSegment(
              flex:  book.notYetReadable,
              color: _levelColor(ReadabilityLevel.notYet, colors),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarSegment extends StatelessWidget {
  final int   flex;
  final Color color;
  const _BarSegment({required this.flex, required this.color});

  @override
  Widget build(BuildContext context) {
    if (flex <= 0) return const SizedBox.shrink();
    return Expanded(flex: flex, child: Container(color: color));
  }
}

class _StatChip extends StatelessWidget {
  final int    count;
  final String label;
  final Color  color;

  const _StatChip({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize:   14,
              fontWeight: FontWeight.w700,
              color:      color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}