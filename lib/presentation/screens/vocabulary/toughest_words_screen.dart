// lib/presentation/screens/vocabulary/toughest_words_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/vocabulary_service.dart';
import '../../../domain/entities/word_entry.dart';
import '../../providers/language_provider.dart';

/// Standalone, ungated view of the words the user has gotten wrong the
/// most — "still open" item from the project handoff doc's to-do list,
/// resolved as: sort by WordEntry.timesWrong descending, top N. Uses
/// timesWrong rather than masteryLevel specifically because mastery
/// alone can't distinguish "genuinely struggled with" from "brand new,
/// never quizzed yet" (both sit at masteryLevel 0) — see the handoff
/// doc's reasoning for adding timesWrong in the first place.
///
/// Deliberately excludes words with timesWrong == 0 — a "toughest
/// words" list has no reason to include words that have never been
/// missed at all.
class ToughestWordsScreen extends ConsumerStatefulWidget {
  const ToughestWordsScreen({super.key});

  @override
  ConsumerState<ToughestWordsScreen> createState() =>
      _ToughestWordsScreenState();
}

class _ToughestWordsScreenState extends ConsumerState<ToughestWordsScreen> {
  static final _service = VocabularyService();
  static const _limit = 30;

  late final Future<List<WordEntry>> _future;

  @override
  void initState() {
    super.initState();
    final pairKey = ref.read(languageProvider).pairKey;
    _future = _service.getAll(pairKey).then((words) {
      final missed = words.where((w) => w.timesWrong > 0).toList()
        ..sort((a, b) => b.timesWrong.compareTo(a.timesWrong));
      return missed.take(_limit).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
          'Toughest Words',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: FutureBuilder<List<WordEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: colors.primary),
            );
          }

          final words = snapshot.data ?? const <WordEntry>[];
          if (words.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 48, color: colors.border),
                    const SizedBox(height: 16),
                    Text(
                      'No tough words yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Words you miss in quizzes and reviews will show up "
                      "here — nothing tough to show yet.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: words.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _ToughWordTile(rank: i + 1, entry: words[i], colors: colors),
          );
        },
      ),
    );
  }
}

class _ToughWordTile extends StatelessWidget {
  final int rank;
  final WordEntry entry;
  final AppColors colors;

  const _ToughWordTile({
    required this.rank,
    required this.entry,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.word,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (entry.translation.isNotEmpty)
                  Text(
                    entry.translation,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '✗ ${entry.timesWrong}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}