// lib/presentation/widgets/review_entry_point.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/review_provider.dart';

/// AppBar-style entry point into /review, for Home and Vocabulary
/// screens. Self-contained — watches dueWordsCountProvider itself
/// rather than requiring each screen to plumb the count through, so
/// all call sites stay in sync by construction rather than by
/// convention. Shows a numeric badge only when something's actually
/// due; silent (no badge, but still tappable) otherwise — a "0" badge
/// sitting on the icon permanently would just be visual noise.
class ReviewIconButton extends ConsumerWidget {
  const ReviewIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dueCount = ref.watch(dueWordsCountProvider).valueOrNull ?? 0;

    return IconButton(
      tooltip: 'Review due words',
      icon: Badge(
        label: Text('$dueCount'),
        isLabelVisible: dueCount > 0,
        backgroundColor: colors.accent,
        child: Icon(Icons.style_outlined, color: colors.textPrimary),
      ),
      onPressed: () => Navigator.of(context).pushNamed('/review'),
    );
  }
}

/// Dashboard-style card entry point into /review, matching this app's
/// existing card pattern (see progress_dashboard_screen.dart's
/// _ReadabilityCard, which this deliberately mirrors visually). Only
/// rendered by the caller when there's something worth surfacing —
/// see ReviewDueCard.shouldShow.
class ReviewDueCard extends ConsumerWidget {
  const ReviewDueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dueCount = ref.watch(dueWordsCountProvider).valueOrNull ?? 0;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/review'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.highlight,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.style_outlined, size: 20, color: colors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dueCount > 0
                        ? '$dueCount word${dueCount == 1 ? '' : 's'} due for review'
                        : 'Review',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    dueCount > 0
                        ? 'A quick spaced-repetition check-in'
                        : "You're all caught up — nothing due right now",
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
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