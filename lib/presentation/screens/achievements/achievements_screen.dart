// lib/presentation/screens/achievements/achievements_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/achievement_service.dart';
import '../../../domain/achievements/achievement.dart';

/// The achievement wall — every achievement shown at once, locked
/// (greyed, progress bar toward it) or unlocked (full color, tier
/// badge, "NEW" treatment if unseen since last unlock). Grouped by
/// category (Vocabulary / Mastery / Streak / Reading), matching
/// AchievementDefinitions' own grouping.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _service = AchievementService();
  List<AchievementProgress>? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.evaluateAll();
    if (!mounted) return;
    setState(() => _progress = result);

    // Mark newly-unlocked ones as seen once they've actually been
    // displayed on this screen — subsequent visits won't show "NEW"
    // for the same achievement again.
    for (final p in result) {
      if (p.isNewlyUnlocked) {
        await _service.markSeen(p.achievement.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = _progress;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text('Achievements', style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: progress == null
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _buildBody(colors, progress),
    );
  }

  Widget _buildBody(AppColors colors, List<AchievementProgress> progress) {
    final unlockedCount = progress.where((p) => p.unlocked).length;
    final categories = <String>[];
    for (final p in progress) {
      if (!categories.contains(p.achievement.category)) {
        categories.add(p.achievement.category);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '$unlockedCount of ${progress.length} unlocked',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        for (final category in categories) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 12),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: colors.textSecondary,
              ),
            ),
          ),
          ...progress
              .where((p) => p.achievement.category == category)
              .map((p) => _AchievementCard(progress: p, colors: colors)),
        ],
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementProgress progress;
  final AppColors colors;

  const _AchievementCard({required this.progress, required this.colors});

  Color _tierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFFA8A9AD);
      case AchievementTier.gold:
        return const Color(0xFFD4AF37);
      case AchievementTier.platinum:
        return const Color(0xFF7B61FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievement = progress.achievement;
    final unlocked = progress.unlocked;
    final tierColor = _tierColor(achievement.tier);
    final displayColor = unlocked ? tierColor : colors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: progress.isNewlyUnlocked ? tierColor : colors.border,
          width: progress.isNewlyUnlocked ? 2 : 1,
        ),
        boxShadow: progress.isNewlyUnlocked
            ? [
                BoxShadow(
                  color: tierColor.withValues(alpha: 0.3),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: displayColor.withValues(alpha: unlocked ? 0.18 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
              color: displayColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        achievement.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: unlocked ? colors.textPrimary : colors.textSecondary,
                        ),
                      ),
                    ),
                    if (progress.isNewlyUnlocked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress.progressFraction,
                      minHeight: 5,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation(tierColor.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${progress.currentValue} / ${achievement.threshold}',
                    style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}