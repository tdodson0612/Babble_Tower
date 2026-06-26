// lib/presentation/screens/reader/learn_screen.dart
//
// TEMPORARY: kept only so existing '/learn' route still compiles while
// the new merged verse-quiz flow is being built. Will be deleted once
// that flow replaces this screen and TestScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/verse_block.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/bible_provider.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bibleState = ref.watch(bibleProvider);
    final vocabState = ref.watch(vocabularyProvider);
    final block = bibleState.currentBlock;

    if (block == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Text(
            'No block loaded.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(block, colors),
      body: _buildWordList(block, vocabState, colors),
      bottomNavigationBar: _buildBottomBar(vocabState, colors),
    );
  }

  PreferredSizeWidget _buildAppBar(VerseBlock block, AppColors colors) {
    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: colors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Learn — Verses ${block.rangeLabel}',
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildWordList(
    VerseBlock block,
    VocabularyState vocabState,
    AppColors colors,
  ) {
    final words = block.words;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: words.length,
      separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
      itemBuilder: (context, index) {
        final word = words[index];
        final isKnown = vocabState.knownWords.contains(word);
        final entry = vocabState.entries[word];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isKnown ? colors.primary : colors.border,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (entry != null && entry.translation.isNotEmpty)
                      Text(
                        entry.translation,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textSecondary,
                        ),
                      )
                    else
                      Text(
                        'No translation yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.border,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (isKnown) {
                    ref.read(vocabularyProvider.notifier).markUnknown(word);
                  } else {
                    ref.read(vocabularyProvider.notifier).markKnown(word);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isKnown ? colors.primary : colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isKnown ? colors.primary : colors.border,
                    ),
                  ),
                  child: Text(
                    isKnown ? '✓ Known' : 'Mark known',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isKnown ? Colors.white : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(VocabularyState vocabState, AppColors colors) {
    final canProceed = vocabState.canProceed;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: vocabState.blockMastery,
              minHeight: 6,
              backgroundColor: colors.border,
              color: canProceed ? colors.primary : colors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canProceed
                ? 'Ready! Head back to continue reading.'
                : '${(vocabState.blockMastery * 100).round()}% — mark 80% of words to proceed',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canProceed ? colors.primary : colors.border,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: canProceed ? () => Navigator.of(context).pop() : null,
              child: const Text(
                'Back to reading',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}