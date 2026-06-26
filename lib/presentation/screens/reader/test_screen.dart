// lib/presentation/screens/reader/test_screen.dart
//
// TEMPORARY: kept only so existing '/test' route still compiles while
// the new merged verse-quiz flow is being built. Will be deleted once
// that flow replaces this screen and LearnScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/verse_block.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/bible_provider.dart';

enum _TestResult { unanswered, correct, incorrect }

class _TestWord {
  final String word;
  final String translation;
  _TestResult result;

  _TestWord({
    required this.word,
    required this.translation,
    this.result = _TestResult.unanswered,
  });
}

class TestScreen extends ConsumerStatefulWidget {
  const TestScreen({super.key});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen> {
  late List<_TestWord> _testWords;
  int _currentIndex = 0;
  bool _revealed = false;
  bool _built = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_built) {
      _buildTestWords();
      _built = true;
    }
  }

  void _buildTestWords() {
    final block = ref.read(bibleProvider).currentBlock;
    final entries = ref.read(vocabularyProvider).entries;

    if (block == null) {
      _testWords = [];
      return;
    }

    _testWords = block.words
        .where((w) => entries.containsKey(w))
        .map((w) {
          final entry = entries[w]!;
          return _TestWord(
            word: w,
            translation: entry.translation,
          );
        })
        .toList()
      ..shuffle();
  }

  bool get _isFinished => _currentIndex >= _testWords.length;

  int get _correctCount =>
      _testWords.where((w) => w.result == _TestResult.correct).length;

  double get _score =>
      _testWords.isEmpty ? 0 : _correctCount / _testWords.length;

  void _reveal() => setState(() => _revealed = true);

  void _answer(bool correct) {
    setState(() {
      _testWords[_currentIndex].result =
          correct ? _TestResult.correct : _TestResult.incorrect;
      _currentIndex++;
      _revealed = false;
    });

    final word = _testWords[_currentIndex - 1].word;
    if (correct) {
      ref.read(vocabularyProvider.notifier).markKnown(word);
    } else {
      ref.read(vocabularyProvider.notifier).markUnknown(word);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final block = ref.watch(bibleProvider).currentBlock;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(block, colors),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _testWords.isEmpty
              ? _buildEmpty(colors)
              : _isFinished
                  ? _buildResults(colors)
                  : _buildCard(colors),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(VerseBlock? block, AppColors colors) {
    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: colors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        _isFinished
            ? 'Results'
            : 'Test — ${_currentIndex + 1} of ${_testWords.length}',
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Center(
      child: Text(
        'No words with translations to test yet.\nMark some words in Learn mode first.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 15,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildCard(AppColors colors) {
    final current = _testWords[_currentIndex];

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _currentIndex / _testWords.length,
            minHeight: 6,
            backgroundColor: colors.border,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 32),

        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
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
                      fontSize: 13,
                      color: colors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    current.word,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (!_revealed)
                    GestureDetector(
                      onTap: _reveal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Tap to reveal answer',
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      current.translation,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        if (_revealed)
          Row(
            children: [
              Expanded(
                child: _AnswerButton(
                  label: '✗  Didn\'t know',
                  correct: false,
                  colors: colors,
                  onTap: () => _answer(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnswerButton(
                  label: '✓  Got it',
                  correct: true,
                  colors: colors,
                  onTap: () => _answer(true),
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResults(AppColors colors) {
    final passed = _score >= 0.8;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: passed
                ? colors.primary.withValues(alpha: 0.1)
                : colors.accent.withValues(alpha: 0.1),
            border: Border.all(
              color: passed ? colors.primary : colors.accent,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(_score * 100).round()}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: passed ? colors.primary : colors.accent,
                ),
              ),
              Text(
                '$_correctCount / ${_testWords.length}',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text(
          passed ? 'Great work!' : 'Keep practicing',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          passed
              ? 'You\'ve passed this block. Continue reading!'
              : 'You need 80% to proceed. Review in Learn mode and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),

        Expanded(
          child: ListView.separated(
            itemCount: _testWords.length,
            separatorBuilder: (_, __) =>
                Divider(color: colors.border, height: 1),
            itemBuilder: (_, i) {
              final w = _testWords[i];
              final correct = w.result == _TestResult.correct;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  correct
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  color: correct ? colors.primary : colors.accent,
                ),
                title: Text(w.word,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
                subtitle: Text(w.translation,
                    style: TextStyle(color: colors.textSecondary)),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            if (!passed)
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() {
                      _currentIndex = 0;
                      _revealed = false;
                      for (final w in _testWords) {
                        w.result = _TestResult.unanswered;
                      }
                      _testWords.shuffle();
                    });
                  },
                  child: Text('Try again',
                      style: TextStyle(color: colors.textPrimary)),
                ),
              ),
            if (!passed) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  passed ? 'Continue reading' : 'Back to learn',
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
// Answer button
// ---------------------------------------------------------------------------

class _AnswerButton extends StatelessWidget {
  final String label;
  final bool correct;
  final AppColors colors;
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
            color: correct ? colors.primary : colors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: correct ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// Unused import kept commented for reference: word_entry.dart is not
// referenced directly in this file (entries come through VocabularyState).