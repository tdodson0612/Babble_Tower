// lib/presentation/widgets/verse_block_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/text_normalizer.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/verse_block.dart';
import '../providers/vocabulary_provider.dart';
import '../providers/settings_provider.dart';
import 'tappable_word.dart';

/// Renders a full VerseBlock as interactive, tappable verse text.
/// Each verse has its own reveal toggle that shows the English
/// translation under every word in that verse at once.
class VerseBlockView extends ConsumerStatefulWidget {
  final VerseBlock block;
  const VerseBlockView({super.key, required this.block});

  @override
  ConsumerState<VerseBlockView> createState() => _VerseBlockViewState();
}

class _VerseBlockViewState extends ConsumerState<VerseBlockView> {
  /// Verse numbers currently showing their word-by-word translations.
  final Set<int> _revealedVerses = {};

  void _toggleReveal(int verseNumber) {
    setState(() {
      if (_revealedVerses.contains(verseNumber)) {
        _revealedVerses.remove(verseNumber);
      } else {
        _revealedVerses.add(verseNumber);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final knownWords = ref.watch(
      vocabularyProvider.select((s) => s.knownWords),
    );
    final entries = ref.watch(
      vocabularyProvider.select((s) => s.entries),
    );
    final textScale = ref.watch(
      settingsProvider.select((s) => s.textScale),
    );

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: widget.block.verses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final verse = widget.block.verses[index];
        return _VerseRow(
          verse: verse,
          knownWords: knownWords,
          entries: entries,
          textScale: textScale,
          revealed: _revealedVerses.contains(verse.number),
          onToggleReveal: () => _toggleReveal(verse.number),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single verse row
// ---------------------------------------------------------------------------

class _VerseRow extends StatelessWidget {
  final Verse verse;
  final Set<String> knownWords;
  final Map<String, dynamic> entries; // word -> WordEntry
  final double textScale;
  final bool revealed;
  final VoidCallback onToggleReveal;

  const _VerseRow({
    required this.verse,
    required this.knownWords,
    required this.entries,
    required this.textScale,
    required this.revealed,
    required this.onToggleReveal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Text(
                '${verse.number}',
                style: TextStyle(
                  fontSize: 12 * textScale,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ),

            // Tappable word tokens
            Expanded(
              child: _buildWordWrap(),
            ),
          ],
        ),

        // Reveal toggle button
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 6),
          child: GestureDetector(
            onTap: onToggleReveal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  revealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 14,
                  color: colors.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  revealed ? 'Hide translation' : 'Show translation',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Word-by-word translation row (only when revealed)
        if (revealed) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: _buildTranslationWrap(colors),
          ),
        ],
      ],
    );
  }

  Widget _buildWordWrap() {
    // Split on spaces while preserving punctuation attached to words.
    final tokens = verse.text.split(' ').where((t) => t.isNotEmpty).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 0,
      children: tokens.map((token) {
        // Use TextNormalizer to match the same key TappableWord uses internally.
        final normalized = TextNormalizer.normalizeWord(token);
        return TappableWord(
          rawToken: token,
          isKnown: knownWords.contains(normalized),
          textScale: textScale,
        );
      }).toList(),
    );
  }

  Widget _buildTranslationWrap(AppColors colors) {
    final tokens = verse.text.split(' ').where((t) => t.isNotEmpty).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: tokens.map((token) {
        final normalized = TextNormalizer.normalizeWord(token);
        final entry = entries[normalized];
        final translation =
            (entry?.translation as String?)?.isNotEmpty == true
                ? entry.translation as String
                : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              token,
              style: TextStyle(
                fontSize: 11 * textScale,
                color: colors.textSecondary,
              ),
            ),
            Text(
              translation ?? '—',
              style: TextStyle(
                fontSize: 13 * textScale,
                fontWeight: FontWeight.w600,
                color: translation != null
                    ? colors.primary
                    : colors.border,
                fontStyle: translation != null
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}