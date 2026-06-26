// lib/presentation/widgets/tappable_word.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/text_normalizer.dart';
import '../providers/vocabulary_provider.dart';
import '../providers/settings_provider.dart';

/// Renders a single word that can be tapped to reveal its translation.
/// Shows a bottom sheet with the translation and mark-known controls.
class TappableWord extends ConsumerWidget {
  /// The raw word token as it appears in the verse (may have punctuation).
  final String rawToken;

  /// Whether this word is already known (affects highlight color).
  final bool isKnown;

  /// Font scale multiplier passed down from settings (0.8 – 1.6).
  final double textScale;

  const TappableWord({
    super.key,
    required this.rawToken,
    this.isKnown = false,
    this.textScale = 1.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final normalized = TextNormalizer.normalizeWord(rawToken);
    final entry = ref.watch(
      vocabularyProvider.select((s) => s.entries[normalized]),
    );
    final haptic = ref.watch(
      settingsProvider.select((s) => s.hapticFeedback),
    );

    return GestureDetector(
      onTap: () {
        if (haptic) HapticFeedback.lightImpact();
        _showTranslationSheet(context, ref, normalized, entry?.translation);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        decoration: isKnown
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              )
            : null,
        child: Text(
          rawToken,
          style: TextStyle(
            fontSize: 18 * textScale,
            height: 1.8,
            color: isKnown ? colors.primary : colors.textPrimary,
            fontWeight: isKnown ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _showTranslationSheet(
    BuildContext context,
    WidgetRef ref,
    String word,
    String? translation,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TranslationSheet(
        word: word,
        translation: translation,
        onMarkKnown: () =>
            ref.read(vocabularyProvider.notifier).markKnown(word),
        onMarkUnknown: () =>
            ref.read(vocabularyProvider.notifier).markUnknown(word),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Translation bottom sheet
// ---------------------------------------------------------------------------

class _TranslationSheet extends StatelessWidget {
  final String word;
  final String? translation;
  final VoidCallback onMarkKnown;
  final VoidCallback onMarkUnknown;

  const _TranslationSheet({
    required this.word,
    required this.translation,
    required this.onMarkKnown,
    required this.onMarkUnknown,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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

            // Word
            Text(
              word,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Translation
            Text(
              translation?.isNotEmpty == true
                  ? translation!
                  : 'No translation saved yet.',
              style: TextStyle(
                fontSize: 18,
                color: translation?.isNotEmpty == true
                    ? colors.accent
                    : colors.textSecondary,
                fontStyle: translation?.isNotEmpty == true
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
            const SizedBox(height: 28),

            // Action row
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    label: '✓  I know this',
                    primary: true,
                    onTap: () {
                      onMarkKnown();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetButton(
                    label: '✗  Not yet',
                    primary: false,
                    onTap: () {
                      onMarkUnknown();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary ? colors.primary : colors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primary ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}