// lib/presentation/screens/reader/verse_quiz_screen.dart
//
// Verse-gated quiz flow (replaces the old LearnScreen + TestScreen).
//
// Flow:
//   1. Words in the verse are shown one at a time.
//   2. Each card shows the Greek word → tap to reveal gloss.
//   3. Student self-rates: "Got it" or "Didn't know".
//   4. After all words: score screen.
//      ≥ 80% → verse unlocked, return to reader with success.
//      < 80% → option to retry or go back.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/bible_provider.dart';

// ---------------------------------------------------------------------------
// Data model for one quiz item
// ---------------------------------------------------------------------------

enum _QuizResult { unanswered, correct, incorrect }

class _QuizItem {
  final String word;
  final WordEntry entry;
  _QuizResult result;

  _QuizItem({
    required this.word,
    required this.entry,
    this.result = _QuizResult.unanswered,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VerseQuizScreen extends ConsumerStatefulWidget {
  const VerseQuizScreen({super.key});

  @override
  ConsumerState<VerseQuizScreen> createState() => _VerseQuizScreenState();
}

class _VerseQuizScreenState extends ConsumerState<VerseQuizScreen> {
  late List<_QuizItem> _items;
  int  _index    = 0;
  bool _revealed = false;
  bool _built    = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_built) {
      _buildItems();
      _built = true;
    }
  }

  void _buildItems() {
    final block   = ref.read(bibleProvider).currentBlock;
    final entries = ref.read(vocabularyProvider).entries;

    if (block == null) {
      _items = [];
      return;
    }

    // Include every word that has a gloss — skip words with no translation.
    _items = block.words
        .where((w) => entries.containsKey(w) &&
            entries[w]!.translation.isNotEmpty)
        .map((w) => _QuizItem(word: w, entry: entries[w]!))
        .toList()
      ..shuffle();
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  bool   get _done     => _index >= _items.length;
  int    get _correct  => _items.where((i) => i.result == _QuizResult.correct).length;
  double get _score    => _items.isEmpty ? 0 : _correct / _items.length;
  bool   get _passed   => _score >= 0.8;

  // ── Actions ───────────────────────────────────────────────────────────────

  void _reveal() => setState(() => _revealed = true);

  void _answer(bool correct) {
    final item = _items[_index];
    setState(() {
      item.result = correct ? _QuizResult.correct : _QuizResult.incorrect;
      _index++;
      _revealed = false;
    });

    if (correct) {
      ref.read(vocabularyProvider.notifier).markKnown(item.word);
    } else {
      ref.read(vocabularyProvider.notifier).markUnknown(item.word);
    }
  }

  void _retry() {
    setState(() {
      _index    = 0;
      _revealed = false;
      for (final item in _items) {
        item.result = _QuizResult.unanswered;
      }
      _items.shuffle();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final block  = ref.watch(bibleProvider).currentBlock;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(block, colors),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _items.isEmpty
              ? _buildEmpty(colors)
              : _done
                  ? _buildResults(colors)
                  : _buildCard(colors),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic block, AppColors colors) {
    final title = _done
        ? 'Results'
        : 'Verse Quiz — ${_index + 1} of ${_items.length}';

    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: colors.textPrimary),
        onPressed: () => Navigator.of(context).pop(false),
      ),
      title: Text(
        title,
        style: TextStyle(
          color:      colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize:   18,
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: colors.primary),
          const SizedBox(height: 20),
          Text(
            'All words already known!',
            style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This verse is ready to unlock.',
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 220,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unlock verse',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quiz card ─────────────────────────────────────────────────────────────

  Widget _buildCard(AppColors colors) {
    final item = _items[_index];

    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           _index / _items.length,
            minHeight:       6,
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
        const SizedBox(height: 32),

        // Card
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color:        colors.surface,
              borderRadius: BorderRadius.circular(24),
              border:       Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'What does this mean?',
                    style: TextStyle(
                      fontSize:    13,
                      color:       colors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Greek word
                  Text(
                    item.word,
                    style: TextStyle(
                      fontSize:   52,
                      fontWeight: FontWeight.w700,
                      color:      colors.textPrimary,
                      height:     1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Lemma badge (if different from the word form)
                  if (item.entry.lemma.isNotEmpty &&
                      item.entry.lemma != item.word) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        colors.highlight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'from ${item.entry.lemma}',
                        style: TextStyle(
                          fontSize: 13,
                          color:    colors.accent,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Reveal / Answer
                  if (!_revealed)
                    _RevealButton(colors: colors, onTap: _reveal)
                  else
                    _GlossDisplay(entry: item.entry, colors: colors),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Answer buttons (only visible after reveal)
        if (_revealed)
          Row(
            children: [
              Expanded(
                child: _AnswerButton(
                  label:   '✗  Didn\'t know',
                  correct: false,
                  colors:  colors,
                  onTap:   () => _answer(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnswerButton(
                  label:   '✓  Got it',
                  correct: true,
                  colors:  colors,
                  onTap:   () => _answer(true),
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(AppColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Score circle
        Container(
          width:  140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _passed
                ? colors.primary.withValues(alpha: 0.1)
                : colors.accent.withValues(alpha: 0.1),
            border: Border.all(
              color: _passed ? colors.primary : colors.accent,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(_score * 100).round()}%',
                style: TextStyle(
                  fontSize:   36,
                  fontWeight: FontWeight.w700,
                  color:      _passed ? colors.primary : colors.accent,
                ),
              ),
              Text(
                '$_correct / ${_items.length}',
                style: TextStyle(
                    fontSize: 14, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text(
          _passed ? 'Verse unlocked!' : 'Keep going',
          style: TextStyle(
            fontSize:   26,
            fontWeight: FontWeight.w700,
            color:      colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _passed
              ? 'Great work! You can read this verse.'
              : 'You need 80% to unlock this verse. Try again!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color:    colors.textSecondary,
            height:   1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Word review list
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, __) =>
                Divider(color: colors.border, height: 1),
            itemBuilder: (_, i) {
              final item    = _items[i];
              final correct = item.result == _QuizResult.correct;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  correct
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  color: correct ? colors.primary : colors.accent,
                ),
                title: Text(
                  item.word,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:      colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  item.entry.translation,
                  style: TextStyle(color: colors.textSecondary),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            if (!_passed) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _retry,
                  child: Text('Try again',
                      style: TextStyle(color: colors.textPrimary)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _passed ? colors.primary : colors.border,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                // Return true = passed (verse should unlock), false = did not pass
                onPressed: () => Navigator.of(context).pop(_passed),
                child: Text(
                  _passed ? 'Continue reading' : 'Back to verse',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _RevealButton extends StatelessWidget {
  final AppColors  colors;
  final VoidCallback onTap;
  const _RevealButton({required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          'Tap to reveal',
          style: TextStyle(
            fontSize:   16,
            color:      colors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GlossDisplay extends StatelessWidget {
  final WordEntry  entry;
  final AppColors  colors;
  const _GlossDisplay({required this.entry, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Short gloss — large and prominent
        Text(
          entry.translation,
          style: TextStyle(
            fontSize:   28,
            fontWeight: FontWeight.w700,
            color:      colors.accent,
            height:     1.3,
          ),
          textAlign: TextAlign.center,
        ),
        // Longer definition — if different and non-empty
        if (entry.definition.isNotEmpty &&
            entry.definition != entry.translation) ...[
          const SizedBox(height: 12),
          Text(
            entry.definition,
            style: TextStyle(
              fontSize: 14,
              color:    colors.textSecondary,
              height:   1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String     label;
  final bool       correct;
  final AppColors  colors;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.correct,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: correct ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: correct ? colors.primary : colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize:   15,
            fontWeight: FontWeight.w600,
            color:      correct ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
