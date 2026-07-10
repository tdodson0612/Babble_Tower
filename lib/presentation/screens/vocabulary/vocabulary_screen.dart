// lib/presentation/screens/vocabulary/vocabulary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/export_service.dart';
import '../../../domain/entities/word_entry.dart';
import '../../../domain/usecases/export_vocabulary_usecase.dart';
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
  bool _exporting = false;

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

  // ── Export ────────────────────────────────────────────────────────────
  // "Future ideas" item from the handoff doc's to-do list. Exports every
  // word currently in the vocabulary provider (both Learning and Known —
  // deliberately not scoped to whichever tab is open, since "export my
  // vocabulary" reads as the whole thing, not the current view).

  /// [buttonContext] is the export button's OWN context (see the
  /// Builder wrapping it below) — needed to compute
  /// sharePositionOrigin, the on-screen rectangle share_plus anchors
  /// its popover/share-sheet to. Required on iPad, and as of iOS 26
  /// required on iPhone too (share_plus throws otherwise) — see
  /// ExportService.exportAndShare's doc. The Scaffold's own context
  /// (from `build` below) isn't scoped to the button itself, so it
  /// can't produce the button's actual RenderBox — that's why this
  /// needs its own Builder rather than reusing the outer context.
  Future<void> _exportCsv(BuildContext buttonContext) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final allEntries =
          ref.read(vocabularyProvider).entries.values.toList();
      final csv = const ExportVocabularyUseCase().buildCsv(allEntries);
      final timestamp = DateTime.now().toIso8601String().split('T').first;

      final box = buttonContext.findRenderObject() as RenderBox?;
      final origin =
          box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

      await const ExportService().exportAndShare(
        content: csv,
        fileName: 'babble_tower_vocabulary_$timestamp.csv',
        subject: 'Babble Tower Vocabulary Export',
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
        actions: [
          // Wrapped in a Builder so the button has its OWN context to
          // compute sharePositionOrigin from — the AppBar/Scaffold
          // context above isn't scoped to this specific button's
          // on-screen position. See _exportCsv's doc.
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: 'Export as CSV',
              icon: _exporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textSecondary,
                      ),
                    )
                  : Icon(Icons.ios_share_rounded, color: colors.textPrimary),
              onPressed: allEntries.isEmpty || _exporting
                  ? null
                  : () => _exportCsv(buttonContext),
            ),
          ),
        ],
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
  final int level; // 0–5 — see WordEntry.masteryLevel / isMastered
  final AppColors colors;

  const _MasteryPip({required this.level, required this.colors});

  @override
  Widget build(BuildContext context) {
    // Six tiers matching WordEntry's actual 0-5 mastery range (was
    // previously a 4-entry array clamped to 3, so levels 3, 4, AND 5
    // all rendered as the exact same pip — a "fully mastered" word
    // (isMastered, level 5) looked identical to a merely level-3 word.
    // Now level 5 gets its own distinct top tier.
    final pipColors = [
      colors.border,
      colors.accent.withValues(alpha: 0.35),
      colors.accent.withValues(alpha: 0.65),
      colors.accent,
      colors.primary.withValues(alpha: 0.6),
      colors.primary,
    ];
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: pipColors[level.clamp(0, 5)],
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