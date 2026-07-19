// lib/presentation/screens/onboarding/alphabet_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/alphabet_data.dart';
import '../../../data/services/sound_service.dart';
import '../../../domain/alphabet/alphabet_quiz_engine.dart';
import '../../providers/user_profile_provider.dart';

/// Teaches the Greek alphabet, 5 letters at a time. This is a mandatory
/// first step for every user — Babble Tower has a single fixed pair
/// (English speakers reading Koine Greek), so there is no "skip if Latin
/// script" branch.
///
/// REPLACES an earlier flat 24-letter flashcard-only flow, on the
/// finding that recognizing a letter, sounding it out, and knowing its
/// name are three genuinely different skills that flashcards alone
/// don't test. Now: for each group of 5 letters — teach (flashcard,
/// tap to reveal), then a 15-question quiz (3 skills × 5 letters,
/// shuffled) — before moving to the next group. See
/// AlphabetQuizEngine's doc for the full design reasoning.
///
/// The only hard gate on reaching verses is finishing every group OR
/// tapping "Skip" (always available) — no per-group score threshold.
class AlphabetScreen extends ConsumerStatefulWidget {
  const AlphabetScreen({super.key});

  @override
  ConsumerState<AlphabetScreen> createState() => _AlphabetScreenState();
}

class _AlphabetScreenState extends ConsumerState<AlphabetScreen> {
  final _engine = AlphabetQuizEngine();

  // Teach-phase state
  bool _revealed = false;

  // Quiz-phase state
  int? _selectedOption;
  bool _answerLocked = false;
  bool _showGroupSummary = false;

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _skipAll() async {
    await ref.read(userProfileProvider.notifier).completeAlphabet();
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _finish() async {
    await ref.read(userProfileProvider.notifier).completeAlphabet();
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  void _advanceTeach() {
    setState(() {
      _engine.advanceTeach();
      _revealed = false;
    });
  }

  void _selectOption(int index) {
    if (_answerLocked) return;
    final correct = index == _engine.currentQuestion!.correctIndex;

    setState(() {
      _selectedOption = index;
      _answerLocked = true;
    });

    if (correct) {
      SoundService.instance.playCorrect();
    } else {
      SoundService.instance.playIncorrect();
    }

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _engine.submitQuizAnswer(index);
        _selectedOption = null;
        _answerLocked = false;
        if (_engine.isGroupQuizComplete) {
          _showGroupSummary = true;
        }
      });
    });
  }

  void _continueToNextGroup() {
    setState(() {
      _engine.advanceGroup();
      _showGroupSummary = false;
      _revealed = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${greekAlphabetData.languageName} Alphabet',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              greekAlphabetData.scriptNote,
              style: TextStyle(color: colors.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _skipAll,
            child: Text('Skip', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _showGroupSummary
              ? _buildGroupSummary(colors)
              : _engine.isTeachPhase
                  ? _buildTeachPhase(colors)
                  : _buildQuizPhase(colors),
        ),
      ),
    );
  }

  // ── Teach phase ──────────────────────────────────────────────────────

  Widget _buildTeachPhase(AppColors colors) {
    return Column(
      children: [
        _buildTeachProgress(colors),
        const SizedBox(height: 32),
        Expanded(
          child: Center(
            child: SingleChildScrollView(child: _buildTeachCard(colors)),
          ),
        ),
        const SizedBox(height: 24),
        _buildTeachControls(colors),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTeachProgress(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_engine.teachIndex + 1) / _engine.teachTotal,
            minHeight: 6,
            backgroundColor: colors.border,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Group ${_engine.currentGroupNumber} of ${_engine.groupCount}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            Text(
              'Letter ${_engine.teachIndex + 1} of ${_engine.teachTotal}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeachCard(AppColors colors) {
    final letter = _engine.currentTeachLetter;
    final isRtl = greekAlphabetData.isRtl;

    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
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
              Directionality(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  letter.uppercase != null
                      ? '${letter.uppercase}  ${letter.character}'
                      : letter.character,
                  style: TextStyle(
                    fontSize: isRtl ? 72 : 80,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  letter.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'romanized: ${letter.romanized}',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 28),
              if (!_revealed)
                Text(
                  'Tap to reveal pronunciation',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else ...[
                Text(
                  letter.pronunciation,
                  style: TextStyle(
                    fontSize: 17,
                    color: colors.textPrimary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (letter.ipa != null && letter.ipa!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'IPA: /${letter.ipa}/',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Divider(color: colors.border),
                const SizedBox(height: 16),
                Directionality(
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    letter.exampleWord,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${letter.exampleMeaning}"',
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeachControls(AppColors colors) {
    final isLastInGroup = _engine.isLastTeachLetterInGroup;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _advanceTeach,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(
          isLastInGroup ? 'Start quiz →' : 'Next letter →',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Quiz phase ───────────────────────────────────────────────────────

  Widget _buildQuizPhase(AppColors colors) {
    return Column(
      children: [
        _buildQuizProgress(colors),
        const SizedBox(height: 32),
        Expanded(
          child: Center(
            child: SingleChildScrollView(child: _buildQuizQuestion(colors)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizProgress(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _engine.quizPosition / _engine.quizTotal,
            minHeight: 6,
            backgroundColor: colors.border,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Group ${_engine.currentGroupNumber} of ${_engine.groupCount}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            Text(
              'Question ${_engine.quizPosition + 1} of ${_engine.quizTotal}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizQuestion(AppColors colors) {
    final q = _engine.currentQuestion!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          q.prompt,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ...List.generate(q.options.length, (i) {
          final isCorrectOption = i == q.correctIndex;
          final isSelected = i == _selectedOption;

          var bg = colors.surface;
          var border = colors.border;
          var fg = colors.textPrimary;

          if (_answerLocked) {
            if (isCorrectOption) {
              bg = colors.primary.withValues(alpha: 0.12);
              border = colors.primary;
              fg = colors.primary;
            } else if (isSelected) {
              bg = colors.accent.withValues(alpha: 0.12);
              border = colors.accent;
              fg = colors.accent;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _selectOption(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(
                    color: border,
                    width: (_answerLocked && (isCorrectOption || isSelected))
                        ? 2
                        : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  q.options[i],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Group summary ────────────────────────────────────────────────────

  Widget _buildGroupSummary(AppColors colors) {
    final pct = (_engine.quizCorrect / _engine.quizTotal * 100).round();
    final isLast = _engine.isLastGroup;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: colors.primary),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Group ${_engine.currentGroupNumber} complete!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$pct% — ${_engine.quizCorrect} of ${_engine.quizTotal} correct',
              style: TextStyle(fontSize: 16, color: colors.textSecondary),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLast ? _finish : _continueToNextGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  isLast ? 'Finish & Start Reading' : 'Continue to next group →',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}