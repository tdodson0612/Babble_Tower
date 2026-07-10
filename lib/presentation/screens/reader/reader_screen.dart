// lib/presentation/screens/reader/reader_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/pronunciation_service.dart';
import '../../../domain/usecases/track_progress_usecase.dart';
import '../../../domain/usecases/track_verse_progress_usecase.dart';
import '../../providers/bible_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/verse_block_view.dart';
import 'verse_quiz_screen.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _progress = const TrackProgressUseCase();
  int? _lastLoadedBlockIndex;

  /// Which verse indices have passed their quiz this session, allowing
  /// the user to advance past them. Verse TEXT is always visible regardless
  /// of this set — it only gates forward navigation, never reading.
  final Set<int> _quizPassedThisSession = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _savePosition();
      _loadVocabForCurrentBlock();
    });
  }

  // ── Vocabulary loading ────────────────────────────────────────────────────

  void _loadVocabForCurrentBlock() {
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

  // ── Gate logic ────────────────────────────────────────────────────────────
  //
  // IMPORTANT: Verse text is ALWAYS visible — there is no read-lock on
  // content itself, for any verse including verse 0. What IS gated is
  // forward navigation: you cannot advance past a verse until you've
  // passed its quiz, either in a previous session (tracked via
  // highestBlock/_isInReviewMode) or this session
  // (tracked via _quizPassedThisSession). Do not reintroduce a
  // text-visibility lock — see project handoff doc, Phase 3.

  bool _hasPassedQuizThisSession(int blockIndex) {
    return _quizPassedThisSession.contains(blockIndex);
  }

  // ── Quiz ──────────────────────────────────────────────────────────────────

  Future<void> _startQuiz() async {
    final bibleState = ref.read(bibleProvider);
    final langState  = ref.read(languageProvider);
    final block = bibleState.currentBlock;
    if (block == null) return;

    // Build the verse label e.g. "Matthew 1:3"
    final book    = bibleState.selectedBook ?? '';
    final chapter = bibleState.selectedChapter ?? 1;
    final verse   = block.verses.isNotEmpty ? block.verses.first.number : 1;
    final label   = '$book $chapter:$verse';

    final passed = await Navigator.of(context).pushNamed(
      '/verse_quiz',
      arguments: VerseQuizArgs(
        verseText:   block.verses.map((v) => v.text).join(' '),
        verseLabel:  label,
        pairKey:     langState.pairKey,
        book:        book,
        chapter:     chapter,
        verseNumber: verse,
      ),
    ) as bool?;

    if (passed == true && mounted) {
      setState(() {
        _quizPassedThisSession.add(bibleState.currentBlockIndex);
      });
      // Auto-advance to next verse
      await _goNext();
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _goNext() async {
    final bibleState = ref.read(bibleProvider);
    final langState  = ref.read(languageProvider);
    final nextBlock  = bibleState.currentBlockIndex + 1;

    await _progress.unlockBlock(
      pairKey:    langState.pairKey,
      book:       bibleState.selectedBook!,
      chapter:    bibleState.selectedChapter ?? 1,
      blockIndex: nextBlock,
    );

    ref.read(bibleProvider.notifier).nextBlock();
    _loadVocabForCurrentBlock();
    await _savePosition();
    if (mounted) setState(() {});
  }

  void _goPrev() {
    ref.read(bibleProvider.notifier).prevBlock();
    _loadVocabForCurrentBlock();
    _savePosition();
    if (mounted) setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors     = context.colors;
    final bibleState = ref.watch(bibleProvider);
    final vocabState = ref.watch(vocabularyProvider);
    final langState  = ref.watch(languageProvider);

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadVocabForCurrentBlock(),
    );

    final block   = bibleState.currentBlock;
    final isFirst = bibleState.currentBlockIndex == 0;
    final isLast  = !bibleState.hasNextBlock;

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
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/vocabulary'),
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
              isFirst:    isFirst,
              isLast:     isLast,
              progress:   _progress,
              quizPassedThisSession:
                  _hasPassedQuizThisSession(bibleState.currentBlockIndex),
              onPrev:      _goPrev,
              onNext:      _goNext,
              onStartQuiz: _startQuiz,
            ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ReaderBody extends StatelessWidget {
  final BibleState       bibleState;
  final VocabularyState  vocabState;
  final LanguageState    langState;
  final dynamic          block;
  final bool             isFirst;
  final bool             isLast;
  final bool             quizPassedThisSession;
  final TrackProgressUseCase progress;
  final VoidCallback     onPrev;
  final Future<void> Function() onNext;
  final Future<void> Function() onStartQuiz;

  const _ReaderBody({
    required this.bibleState,
    required this.vocabState,
    required this.langState,
    required this.block,
    required this.isFirst,
    required this.isLast,
    required this.quizPassedThisSession,
    required this.progress,
    required this.onPrev,
    required this.onNext,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: progress.highestBlock(pairKey: langState.pairKey),
      builder: (context, snap) {
        final highest  = snap.data ?? 0;
        final inReview = bibleState.currentBlockIndex < highest;

        // Forward-navigation gate ONLY. Verse text below is always
        // rendered in full — _VerseContent never receives or checks
        // a lock flag.
        final canAdvance = inReview || quizPassedThisSession;

        // Plain-text concatenation of the currently-displayed verse(s),
        // for the "listen to this verse" audio button. Same construction
        // _startQuiz() already uses for the quiz's verseText argument.
        final verseText =
            (block.verses as List).map((v) => v.text as String).join(' ');

        return Column(
          children: [
            if (inReview) const _ReviewBanner(),

            _VerseIndicator(
              current: bibleState.currentBlockIndex + 1,
              total:   bibleState.blocks.length,
              pairKey: langState.pairKey,
              book:    bibleState.selectedBook ?? '',
              chapter: bibleState.selectedChapter ?? 1,
              verseNumber:
                  block.verses.isNotEmpty ? block.verses.first.number : 1,
            ),

            // Verse content — ALWAYS readable, never blurred/locked,
            // for every verse including verse 0.
            Expanded(
              child: _VerseContent(
                block: block,
                book: bibleState.selectedBook ?? '',
                chapter: bibleState.selectedChapter ?? 1,
              ),
            ),

            // Bottom nav — quiz gates forward movement only.
            _BottomNav(
              isFirst:     isFirst,
              isLast:      isLast,
              canAdvance:  canAdvance,
              inReview:    inReview,
              verseText:   verseText,
              onPrev:      onPrev,
              onNext:      isLast ? null : onNext,
              onStartQuiz: onStartQuiz,
            ),
          ],
        );
      },
    );
  }
}

// ── Verse content — always readable, no lock/blur ────────────────────────────

class _VerseContent extends StatelessWidget {
  final dynamic block;
  final String book;
  final int chapter;

  const _VerseContent({
    required this.block,
    required this.book,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: VerseBlockView(block: block, book: book, chapter: chapter),
    );
  }
}

// ── Review banner ─────────────────────────────────────────────────────────────

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
            'Review Mode',
            style: TextStyle(
              fontSize: 13,
              color: colors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Verse indicator ───────────────────────────────────────────────────────────

class _VerseIndicator extends StatelessWidget {
  final int current;
  final int total;
  final String pairKey;
  final String book;
  final int chapter;
  final int verseNumber;

  const _VerseIndicator({
    required this.current,
    required this.total,
    required this.pairKey,
    required this.book,
    required this.chapter,
    required this.verseNumber,
  });

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
              fontSize: 13,
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          _RetryBadge(
            pairKey: pairKey,
            book: book,
            chapter: chapter,
            verseNumber: verseNumber,
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

// ── Retry count badge ─────────────────────────────────────────────────────
// "Future ideas" item from the handoff doc's to-do list — surfaces
// VerseProgressModel.retryCount (cumulative quiz attempts, pass or fail,
// forever) for the verse currently on screen. Self-contained: does its
// own Hive lookup via TrackVerseProgressUseCase rather than threading
// state through _ReaderScreenState, since nothing else in the reader
// needs this value. Renders nothing on a verse that's never been
// attempted (retryCount == 0) — a badge reading "Attempt 0" would just
// be noise on every verse the user hasn't reached yet.

class _RetryBadge extends StatelessWidget {
  final String pairKey;
  final String book;
  final int chapter;
  final int verseNumber;

  const _RetryBadge({
    required this.pairKey,
    required this.book,
    required this.chapter,
    required this.verseNumber,
  });

  @override
  Widget build(BuildContext context) {
    if (book.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;

    return FutureBuilder(
      future: const TrackVerseProgressUseCase().load(
        pairKey: pairKey,
        book: book,
        chapter: chapter,
        verseNumber: verseNumber,
      ),
      builder: (context, snapshot) {
        final retryCount = snapshot.data?.retryCount ?? 0;
        if (retryCount == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.highlight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            retryCount == 1 ? '1 attempt' : '$retryCount attempts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

// ── Verse audio button ────────────────────────────────────────────────────
// In-progress task from the handoff doc: reads the whole currently-
// displayed verse aloud in Greek, via the already-working Koine
// phonetic-respelling pipeline (PronunciationService.speakKoine),
// NOT raw Greek text through an el-GR voice. Always visible — unlike
// the quiz button, listening is never gated by quiz-pass state.
// Self-contained play state, mirroring _RetryBadge's pattern of owning
// its own small bit of state rather than threading it through
// _ReaderScreenState, since nothing else in the reader needs it.

class _VerseAudioButton extends StatefulWidget {
  final String verseText;

  const _VerseAudioButton({required this.verseText});

  @override
  State<_VerseAudioButton> createState() => _VerseAudioButtonState();
}

class _VerseAudioButtonState extends State<_VerseAudioButton> {
  final _pronunciation = const PronunciationService();
  bool _isSpeaking = false;

  Future<void> _toggle() async {
    if (widget.verseText.trim().isEmpty) return;

    if (_isSpeaking) {
      // Tapping again while playing stops it early, rather than
      // disabling the button until the whole verse finishes.
      await _pronunciation.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    try {
      await _pronunciation.speakKoine(widget.verseText);
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  @override
  void dispose() {
    // Don't let audio for a verse the user has navigated away from
    // keep playing in the background.
    if (_isSpeaking) _pronunciation.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disabled = widget.verseText.trim().isEmpty;

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : _toggle,
        icon: Icon(
          _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
          size: 18,
          color: colors.primary,
        ),
        label: Text(
          _isSpeaking ? 'Stop' : 'Listen to this verse',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.surface,
          elevation: 0,
          side: BorderSide(color: colors.border),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool canAdvance;
  final bool inReview;
  final String verseText;
  final VoidCallback onPrev;
  final Future<void> Function()? onNext;
  final Future<void> Function() onStartQuiz;

  const _BottomNav({
    required this.isFirst,
    required this.isLast,
    required this.canAdvance,
    required this.inReview,
    required this.verseText,
    required this.onPrev,
    required this.onNext,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Listen button — always visible, never gated by quiz-pass
          // state. Sits above the quiz button per the handoff spec.
          _VerseAudioButton(verseText: verseText),
          const SizedBox(height: 10),

          // Quiz button — always offered when not in review; label
          // changes based on whether this verse's quiz has been passed.
          if (!inReview)
            SizedBox(
              width: double.infinity,
              child: _NavBtn(
                label: canAdvance
                    ? 'Practice this verse again'
                    : 'Take the quiz to continue',
                icon: canAdvance
                    ? Icons.replay_outlined
                    : Icons.school_outlined,
                color: canAdvance ? colors.accent : colors.primary,
                onPressed: onStartQuiz,
              ),
            ),
          if (!inReview) const SizedBox(height: 10),

          // Prev / Next. Prev is never gated — you can always go back
          // and re-read a previous verse. Next requires canAdvance.
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
                      ? 'Next verse →'
                      : (canAdvance ? 'Next verse →' : 'Quiz first →'),
                  icon:      Icons.chevron_right,
                  color:     (inReview || canAdvance)
                      ? colors.primary
                      : colors.border,
                  onPressed: (inReview || canAdvance) ? onNext : null,
                  compact:   true,
                )
              else
                Text(
                  'Chapter complete ✓',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.primary,
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
  final String    label;
  final IconData  icon;
  final Color     color;
  final dynamic   onPressed;
  final bool      compact;

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
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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