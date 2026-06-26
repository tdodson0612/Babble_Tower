// lib/presentation/screens/reader/reader_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/usecases/track_progress_usecase.dart';
import '../../providers/bible_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/verse_block_view.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _progress = const TrackProgressUseCase();

  int? _lastLoadedBlockIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _savePosition();
      _loadVocabForCurrentVerse();
    });
  }

  // ── Vocabulary loading ────────────────────────────────────────────────────

  void _loadVocabForCurrentVerse() {
    final bibleState = ref.read(bibleProvider);
    final block = bibleState.currentBlock;
    if (block == null) return;
    if (_lastLoadedBlockIndex == bibleState.currentBlockIndex) return;

    _lastLoadedBlockIndex = bibleState.currentBlockIndex;
    ref.read(vocabularyProvider.notifier).loadForBlock(block.words);
  }

  // ── Position saving ───────────────────────────────────────────────────────

  Future<void> _savePosition() async {
    final bibleState = ref.read(bibleProvider);
    final langState  = ref.read(languageProvider);
    if (bibleState.selectedBook == null) return;

    await _progress.savePosition(
      pairKey:    langState.pairKey,
      book:       bibleState.selectedBook!,
      chapter:    bibleState.selectedChapter ?? 1,
      blockIndex: bibleState.currentBlockIndex,
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<bool> _isInReviewMode() async {
    final langState  = ref.read(languageProvider);
    final bibleState = ref.read(bibleProvider);
    if (bibleState.selectedBook == null) return false;

    final highest = await _progress.highestBlock(pairKey: langState.pairKey);
    return bibleState.currentBlockIndex < highest;
  }

  Future<void> _goNext() async {
    final inReview   = await _isInReviewMode();
    final vocabState = ref.read(vocabularyProvider);

    if (!inReview && vocabState.blockMastery < 0.8) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz this verse first to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final langState  = ref.read(languageProvider);
    final bibleState = ref.read(bibleProvider);
    final nextBlock  = bibleState.currentBlockIndex + 1;

    await _progress.unlockBlock(
      pairKey:    langState.pairKey,
      book:       bibleState.selectedBook!,
      chapter:    bibleState.selectedChapter ?? 1,
      blockIndex: nextBlock,
    );

    ref.read(bibleProvider.notifier).nextBlock();
    _loadVocabForCurrentVerse();
    await _savePosition();
    if (mounted) setState(() {});
  }

  void _goPrev() {
    ref.read(bibleProvider.notifier).prevBlock();
    _loadVocabForCurrentVerse();
    _savePosition();
    if (mounted) setState(() {});
  }

  /// Launch the quiz and unlock the verse if the student passes.
  Future<void> _startQuiz() async {
    final passed = await Navigator.of(context).pushNamed('/verse_quiz');
    if (passed == true && mounted) {
      // Student passed — advance to next verse automatically.
      await _goNext();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors     = context.colors;
    final bibleState = ref.watch(bibleProvider);
    final vocabState = ref.watch(vocabularyProvider);
    final langState  = ref.watch(languageProvider);

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadVocabForCurrentVerse(),
    );

    final block   = bibleState.currentBlock;
    final isFirst = bibleState.currentBlockIndex == 0;
    final isLast  = !bibleState.hasNextBlock;
    final mastery = vocabState.blockMastery;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          bibleState.selectedBook != null
              ? '${bibleState.selectedBook} ${bibleState.selectedChapter}'
              : 'Reading',
          style: TextStyle(
            color:      colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize:   17,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/vocabulary'),
            child: Text('Words', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
      body: block == null
          ? const Center(child: CircularProgressIndicator())
          : _ReaderBody(
              bibleState: bibleState,
              vocabState: vocabState,
              langState:  langState,
              block:      block,
              mastery:    mastery,
              isFirst:    isFirst,
              isLast:     isLast,
              progress:   _progress,
              onPrev:     _goPrev,
              onNext:     _goNext,
              onQuiz:     _startQuiz,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _ReaderBody extends StatelessWidget {
  final BibleState       bibleState;
  final VocabularyState  vocabState;
  final LanguageState    langState;
  final dynamic          block;
  final double           mastery;
  final bool             isFirst;
  final bool             isLast;
  final TrackProgressUseCase           progress;
  final VoidCallback                   onPrev;
  final Future<void> Function()        onNext;
  final Future<void> Function()        onQuiz;

  const _ReaderBody({
    required this.bibleState,
    required this.vocabState,
    required this.langState,
    required this.block,
    required this.mastery,
    required this.isFirst,
    required this.isLast,
    required this.progress,
    required this.onPrev,
    required this.onNext,
    required this.onQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: progress.highestBlock(pairKey: langState.pairKey),
      builder: (context, snap) {
        final highest  = snap.data ?? 0;
        final inReview = bibleState.currentBlockIndex < highest;
        final canNext  = inReview || mastery >= 0.8;

        return Column(
          children: [
            if (inReview) const _ReviewBanner(),

            _VerseIndicator(
              current: bibleState.currentBlockIndex + 1,
              total:   bibleState.blocks.length,
            ),

            if (!inReview)
              _MasteryBar(percent: mastery),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: VerseBlockView(block: block),
              ),
            ),

            _BottomNav(
              isFirst:  isFirst,
              isLast:   isLast,
              canNext:  canNext,
              inReview: inReview,
              onPrev:   onPrev,
              onNext:   isLast ? null : onNext,
              onQuiz:   onQuiz,
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Review banner
// ---------------------------------------------------------------------------

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      color: colors.highlight,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.replay, size: 16, color: colors.accent),
          const SizedBox(width: 6),
          Text(
            'Review Mode — no mastery required',
            style: TextStyle(
              fontSize:   13,
              color:      colors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verse indicator (was "Block indicator")
// ---------------------------------------------------------------------------

class _VerseIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _VerseIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            'Verse $current of $total',
            style: TextStyle(
              fontSize:   13,
              color:      colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          ...List.generate(
            total > 10 ? 10 : total,
            (i) => Container(
              width:  i < current ? 10 : 6,
              height: 6,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: i < current ? colors.primary : colors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mastery bar
// ---------------------------------------------------------------------------

class _MasteryBar extends StatelessWidget {
  final double percent;
  const _MasteryBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pct   = (percent * 100).round();
    final ready = percent >= 0.8;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Word mastery: $pct%',
                style: TextStyle(
                  fontSize:   12,
                  color:      ready ? colors.primary : colors.textSecondary,
                  fontWeight: ready ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              if (ready) ...[
                const SizedBox(width: 6),
                Text(
                  '✓ Ready to advance',
                  style: TextStyle(
                    fontSize:   12,
                    color:      colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value:      percent.clamp(0.0, 1.0),
              minHeight:  4,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                ready ? colors.primary : colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool canNext;
  final bool inReview;
  final VoidCallback onPrev;
  final Future<void> Function()? onNext;
  final Future<void> Function()  onQuiz;

  const _BottomNav({
    required this.isFirst,
    required this.isLast,
    required this.canNext,
    required this.inReview,
    required this.onPrev,
    required this.onNext,
    required this.onQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color:  colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quiz button — full width, prominent
          if (!inReview)
            SizedBox(
              width: double.infinity,
              child: _NavBtn(
                label:     'Quiz this verse',
                icon:      Icons.quiz_outlined,
                color:     canNext ? colors.accent : colors.primary,
                onPressed: onQuiz,
              ),
            ),

          if (!inReview) const SizedBox(height: 10),

          // Prev / Next row
          Row(
            children: [
              _NavBtn(
                label:     '← Prev',
                icon:      Icons.chevron_left,
                color:     colors.textSecondary,
                onPressed: isFirst ? null : onPrev,
                compact:   true,
              ),
              const Spacer(),
              if (!isLast)
                _NavBtn(
                  label: inReview
                      ? 'Next →'
                      : (canNext ? 'Next →' : 'Quiz first →'),
                  icon:      Icons.chevron_right,
                  color:     (inReview || canNext)
                      ? colors.primary
                      : colors.border,
                  onPressed: onNext,
                  compact:   true,
                )
              else
                Text(
                  'Chapter complete ✓',
                  style: TextStyle(
                    fontSize:   14,
                    color:      colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final dynamic  onPressed;
  final bool     compact;

  const _NavBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors   = context.colors;
    final disabled = onPressed == null;

    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : () => onPressed(),
        icon:  Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? colors.border : color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 12,
            vertical:   0,
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
