// lib/presentation/screens/vocabulary/vocabulary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/word_entry.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/settings_provider.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vocabState = ref.watch(vocabularyProvider);
    final showKnown = ref.watch(
      settingsProvider.select((s) => s.showKnownWords),
    );

    final allEntries = vocabState.entries.values.toList();
    final known = allEntries.where((e) => e.known).toList();
    final unknown = allEntries.where((e) => !e.known).toList();

    final displayKnown = showKnown ? known : <WordEntry>[];

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
          'Vocabulary',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.primary,
          indicatorWeight: 2,
          tabs: [
            Tab(text: 'Learning  (${unknown.length})'),
            Tab(text: 'Known  (${known.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _WordList(
            entries: unknown,
            emptyMessage: 'No words to learn — great work!',
            colors: colors,
            onMarkKnown: (w) =>
                ref.read(vocabularyProvider.notifier).markKnown(w),
            onMarkUnknown: null,
          ),
          _WordList(
            entries: displayKnown,
            emptyMessage: showKnown
                ? 'No known words yet.'
                : 'Known words are hidden in settings.',
            colors: colors,
            onMarkKnown: null,
            onMarkUnknown: (w) =>
                ref.read(vocabularyProvider.notifier).markUnknown(w),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word list
// ---------------------------------------------------------------------------

class _WordList extends StatelessWidget {
  final List<WordEntry> entries;
  final String emptyMessage;
  final AppColors colors;
  final void Function(String)? onMarkKnown;
  final void Function(String)? onMarkUnknown;

  const _WordList({
    required this.entries,
    required this.emptyMessage,
    required this.colors,
    required this.onMarkKnown,
    required this.onMarkUnknown,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => Divider(
        color: colors.border,
        height: 1,
      ),
      itemBuilder: (_, i) => _WordRow(
        entry: entries[i],
        colors: colors,
        onMarkKnown: onMarkKnown,
        onMarkUnknown: onMarkUnknown,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single word row
// ---------------------------------------------------------------------------

class _WordRow extends StatelessWidget {
  final WordEntry entry;
  final AppColors colors;
  final void Function(String)? onMarkKnown;
  final void Function(String)? onMarkUnknown;

  const _WordRow({
    required this.entry,
    required this.colors,
    required this.onMarkKnown,
    required this.onMarkUnknown,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _MasteryPip(level: entry.masteryLevel, colors: colors),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.word,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (entry.translation.isNotEmpty)
                  Text(
                    entry.translation,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          if (onMarkKnown != null)
            _ActionChip(
              label: 'Known',
              color: colors.primary,
              onTap: () => onMarkKnown!(entry.word),
            ),
          if (onMarkUnknown != null)
            _ActionChip(
              label: 'Unlearn',
              color: colors.accent,
              onTap: () => onMarkUnknown!(entry.word),
            ),
        ],
      ),
    );
  }
}

class _MasteryPip extends StatelessWidget {
  final int level; // 0–3
  final AppColors colors;

  const _MasteryPip({required this.level, required this.colors});

  @override
  Widget build(BuildContext context) {
    final pipColors = [
      colors.border,
      colors.accent.withValues(alpha: 0.5),
      colors.accent,
      colors.primary,
    ];
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: pipColors[level.clamp(0, 3)],
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}