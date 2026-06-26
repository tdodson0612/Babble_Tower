// lib/presentation/screens/onboarding/alphabet_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/alphabet_data.dart';
import '../../providers/user_profile_provider.dart';

/// Teaches the Greek alphabet. This is now a mandatory first step for
/// every user — Babble Tower has a single fixed pair (English speakers
/// reading Koine Greek), so there is no "skip if Latin script" branch
/// anymore.
class AlphabetScreen extends ConsumerStatefulWidget {
  const AlphabetScreen({super.key});

  @override
  ConsumerState<AlphabetScreen> createState() => _AlphabetScreenState();
}

class _AlphabetScreenState extends ConsumerState<AlphabetScreen> {
  int _currentIndex = 0;
  bool _revealed = false;
  final Set<int> _mastered = {};

  static const AlphabetData _data = greekAlphabetData;

  LetterEntry get _current => _data.letters[_currentIndex];
  int get _total => _data.letters.length;
  double get _progress => (_currentIndex + 1) / _total;

  Future<void> _next() async {
    if (_currentIndex < _total - 1) {
      setState(() {
        _currentIndex++;
        _revealed = false;
      });
    } else {
      // Last letter — mark alphabet complete before navigating
      await ref.read(userProfileProvider.notifier).completeAlphabet();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _revealed = false;
      });
    }
  }

  Future<void> _markMastered() async {
    setState(() => _mastered.add(_currentIndex));
    await _next();
  }

  Future<void> _skipAll() async {
    await ref.read(userProfileProvider.notifier).completeAlphabet();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(colors),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              _buildProgressBar(colors),
              const SizedBox(height: 8),
              _buildProgressLabel(colors),
              const SizedBox(height: 32),
              Expanded(child: _buildCard(colors)),
              const SizedBox(height: 24),
              _buildControls(colors),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors colors) {
    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_data.languageName} Alphabet',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Text(
            _data.scriptNote,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _skipAll,
          child: Text(
            'Skip',
            style: TextStyle(color: colors.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(AppColors colors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: _progress,
        minHeight: 6,
        backgroundColor: colors.border,
        color: colors.primary,
      ),
    );
  }

  Widget _buildProgressLabel(AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_currentIndex + 1} of $_total',
          style: TextStyle(
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
        Text(
          '${_mastered.length} mastered',
          style: TextStyle(
            fontSize: 12,
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(AppColors colors) {
    final isRtl = _data.isRtl;

    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _mastered.contains(_currentIndex)
                ? colors.primary.withValues(alpha: 0.4)
                : colors.border,
            width: _mastered.contains(_currentIndex) ? 2 : 1,
          ),
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
              // Main character
              Directionality(
                textDirection:
                    isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  _current.uppercase != null
                      ? '${_current.uppercase}  ${_current.character}'
                      : _current.character,
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

              // Romanization
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _current.romanized,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Tap to reveal
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
                // Pronunciation
                Text(
                  _current.pronunciation,
                  style: TextStyle(
                    fontSize: 17,
                    color: colors.textPrimary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_current.ipa != null &&
                    _current.ipa!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'IPA: /${_current.ipa}/',
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

                // Example word
                Directionality(
                  textDirection:
                      isRtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    _current.exampleWord,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${_current.exampleMeaning}"',
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

  Widget _buildControls(AppColors colors) {
    final isLast = _currentIndex == _total - 1;

    return Column(
      children: [
        // Mark mastered button
        if (_revealed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _markMastered,
              child: Text(
                _mastered.contains(_currentIndex)
                    ? '✓ Mastered'
                    : isLast
                        ? 'Finish & Start Reading'
                        : 'Got it — next letter',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Prev / Next row
        Row(
          children: [
            _NavBtn(
              label: '← Back',
              enabled: _currentIndex > 0,
              colors: colors,
              onTap: _prev,
            ),
            const Spacer(),
            _NavBtn(
              label: isLast ? 'Finish →' : 'Skip letter →',
              enabled: true,
              colors: colors,
              onTap: _next,
              subtle: true,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private nav button
// ---------------------------------------------------------------------------

class _NavBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool subtle;
  final AppColors colors;
  final VoidCallback onTap;

  const _NavBtn({
    required this.label,
    required this.enabled,
    required this.colors,
    required this.onTap,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: !enabled
              ? colors.border
              : subtle
                  ? colors.textSecondary
                  : colors.accent,
        ),
      ),
    );
  }
}