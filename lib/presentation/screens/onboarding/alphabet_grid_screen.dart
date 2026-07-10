// lib/presentation/screens/onboarding/alphabet_grid_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/alphabet_data.dart';
import '../../providers/user_profile_provider.dart';

/// Shows all 24 Greek letters at once in a scrollable grid, each tile
/// displaying the letter pair (uppercase + lowercase), its romanization,
/// and a short pronunciation note.
///
/// This is the opening page of the app. For new users it leads into the
/// existing AlphabetScreen flashcard flow. For returning users it has a
/// direct "Go to Home" button. It is also reachable from Settings
/// (Phase 8 quick-reference requirement).
class AlphabetGridScreen extends ConsumerWidget {
  /// When true, shown as a reference screen from Settings — shows a
  /// back button instead of the onboarding action buttons.
  final bool fromSettings;

  const AlphabetGridScreen({super.key, this.fromSettings = false});

  static const AlphabetData _data = greekAlphabetData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profileState = ref.watch(userProfileProvider);
    final alphabetDone = profileState.hasCompletedAlphabet;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: fromSettings
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The Greek Alphabet',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              '24 letters — tap any to explore',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: fromSettings
            ? null
            : [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/home'),
                  child: Text(
                    'Skip',
                    style: TextStyle(color: colors.accent),
                  ),
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _LetterGrid(colors: colors),
            ),
            if (!fromSettings) _BottomActions(alphabetDone: alphabetDone),
          ],
        ),
      ),
    );
  }
}

// ── Letter grid ───────────────────────────────────────────────────────────

class _LetterGrid extends StatelessWidget {
  final AppColors colors;
  static const AlphabetData _data = greekAlphabetData;

  const _LetterGrid({required this.colors});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: _data.letters.length,
      itemBuilder: (context, i) {
        return _LetterTile(
          entry: _data.letters[i],
          colors: colors,
          onTap: () => _showLetterDetail(context, i),
        );
      },
    );
  }

  void _showLetterDetail(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LetterDetailSheet(
        entry: _data.letters[index],
        index: index,
        total: _data.letters.length,
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  final LetterEntry entry;
  final AppColors colors;
  final VoidCallback onTap;

  const _LetterTile({
    required this.entry,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Uppercase + lowercase
            Text(
              entry.uppercase != null
                  ? '${entry.uppercase} ${entry.character}'
                  : entry.character,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Romanization (name/sound)
            Text(
              entry.romanized,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 2),
            // Short pronunciation — first segment only to keep tile compact
            Text(
              _shortPronunciation(entry.pronunciation),
              style: TextStyle(
                fontSize: 10,
                color: colors.textSecondary,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Trims the pronunciation string to the first meaningful clause so it
  /// fits in a small tile. E.g. 'Like "a" in "father"' stays as-is;
  /// 'Like "v" in modern Greek; "b" in ancient' becomes
  /// 'Like "v" in modern Greek'.
  String _shortPronunciation(String full) {
    final semicolonIndex = full.indexOf(';');
    if (semicolonIndex != -1) return full.substring(0, semicolonIndex).trim();
    return full;
  }
}

// ── Letter detail bottom sheet ────────────────────────────────────────────

class _LetterDetailSheet extends StatelessWidget {
  final LetterEntry entry;
  final int index;
  final int total;

  static const AlphabetData _data = greekAlphabetData;

  const _LetterDetailSheet({
    required this.entry,
    required this.index,
    required this.total,
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

            // Letter + position
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  entry.uppercase != null
                      ? '${entry.uppercase}  ${entry.character}'
                      : entry.character,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    height: 1.0,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.romanized,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Letter ${index + 1} of $total',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pronunciation
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.pronunciation,
                style: TextStyle(
                  fontSize: 16,
                  color: colors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),

            if (entry.ipa != null && entry.ipa!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'IPA: /${entry.ipa}/',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            Divider(color: colors.border),
            const SizedBox(height: 16),

            // Example word
            Row(
              children: [
                Text(
                  entry.exampleWord,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '"${entry.exampleMeaning}"',
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Bottom action buttons (onboarding flow only) ──────────────────────────

class _BottomActions extends ConsumerWidget {
  final bool alphabetDone;

  const _BottomActions({required this.alphabetDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (alphabetDone) {
                  Navigator.of(context).pushReplacementNamed('/home');
                } else {
                  Navigator.of(context)
                      .pushReplacementNamed('/alphabet');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                alphabetDone
                    ? 'Go to Home'
                    : 'Start Learning the Alphabet',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}