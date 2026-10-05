// lib/presentation/widgets/mystery_box_overlay.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/rewards_service.dart';

/// Guards against more than one mystery-box reveal being shown at once.
/// Quiz screens fire this from a fire-and-forget `.then()` after an
/// async reward roll, so with the ~6% per-answer odds it's possible for
/// a second correct answer to resolve while the first reveal is still
/// animating — stacking two `showGeneralDialog` routes on top of each
/// other. The second dialog then sits on top of a first one whose
/// AnimationController gets paused mid-flight (TickerMode turns off for
/// a covered route), which is what produced the "frozen" popup showing
/// only 2-3 colored circles with no visible way to continue: the user
/// was looking at the SECOND dialog, and dismissing it (if they found
/// its own button) would reveal a first dialog stuck between 50-60% of
/// its animation, where the reveal text/button are still at opacity 0.
/// The reward itself is never lost by skipping a reveal — RewardsService
/// already persists it to SharedPreferences before this is ever called.
bool _mysteryBoxShowing = false;

/// Shows the mystery-box reveal as a modal overlay. Call this after
/// RewardsService.rollForCorrectAnswer() returns a result where
/// result.isMysteryBox is true — nothing to show otherwise.
Future<void> showMysteryBoxReveal(
  BuildContext context,
  RewardResult result,
  AppColors colors,
) async {
  // Skip rather than stack — see _mysteryBoxShowing doc above. The XP/
  // theme unlock was already saved by RewardsService regardless.
  if (_mysteryBoxShowing) return;
  _mysteryBoxShowing = true;
  try {
    await showGeneralDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) =>
          _MysteryBoxContent(result: result, colors: colors),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  } finally {
    _mysteryBoxShowing = false;
  }
}

class _MysteryBoxContent extends StatefulWidget {
  final RewardResult result;
  final AppColors colors;

  const _MysteryBoxContent({required this.result, required this.colors});

  @override
  State<_MysteryBoxContent> createState() => _MysteryBoxContentState();
}

class _MysteryBoxContentState extends State<_MysteryBoxContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shake;
  late final Animation<double> _pop;
  late final Animation<double> _revealOpacity;

  /// Failsafe: if something ever prevents the user from dismissing this
  /// normally (a future, un-reproduced variant of the stacking issue
  /// described above, a layout issue hiding the "Nice!" button, etc.)
  /// this guarantees the dialog never sits on screen forever. Started
  /// once the reveal animation completes; cancelled on manual dismiss.
  Timer? _autoDismissTimer;

  final List<_ConfettiSpec> _confetti = List.generate(
    12,
    (i) => _ConfettiSpec(
      angle: (i / 12) * 2 * pi,
      color: Colors.primaries[i % Colors.primaries.length],
      delay: (i % 4) * 0.03,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    // Shake: 0.0-0.45 of the timeline, a few quick back-and-forth
    // rotations building anticipation before the reveal.
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeInOut),
    ));

    // Pop: box scales up and "bursts" open from 0.45-0.7.
    _pop = Tween<double>(begin: 1.0, end: 1.4).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.7, curve: Curves.elasticOut),
    ));

    // Reveal content fades/scales in from 0.55 onward, overlapping the
    // tail of the pop for a smooth handoff rather than a hard cut.
    _revealOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );

    _controller.addStatusListener(_onControllerStatus);
  }

  void _onControllerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Give the user a generous window to tap "Nice!" (or anywhere,
      // once revealed) before auto-dismissing on their behalf.
      _autoDismissTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  void _dismiss() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.removeStatusListener(_onControllerStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final result = widget.result;
    final revealed = _controller.value > 0.5;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final boxVisible = _controller.value < 0.6;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_controller.value > 0.5)
                          ..._confetti.map((c) => _buildConfettiDot(c)),
                        if (boxVisible)
                          Transform.rotate(
                            angle: _shake.value,
                            child: Transform.scale(
                              scale: _controller.value < 0.45
                                  ? 1.0
                                  : _pop.value,
                              child: Icon(
                                Icons.card_giftcard_rounded,
                                size: 72,
                                color: colors.primary,
                              ),
                            ),
                          )
                        else
                          Opacity(
                            opacity: _revealOpacity.value,
                            child: _buildRevealIcon(result, colors),
                          ),
                      ],
                    ),
                  ),
                  if (revealed) ...[
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: _revealOpacity.value,
                      child: GestureDetector(
                        // Belt-and-suspenders: once revealed, tapping
                        // anywhere in the text area dismisses too, not
                        // just the "Nice!" button — in case the button
                        // itself is ever missed (small hit area, font
                        // scaling, etc.).
                        onTap: _dismiss,
                        behavior: HitTestBehavior.opaque,
                        child: _buildRevealText(result, colors),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConfettiDot(_ConfettiSpec spec) {
    final progress = ((_controller.value - 0.5 - spec.delay) / 0.4)
        .clamp(0.0, 1.0);
    final distance = 70.0 * Curves.easeOut.transform(progress);
    final dx = cos(spec.angle) * distance;
    final dy = sin(spec.angle) * distance;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: (1.0 - progress).clamp(0.0, 1.0),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: spec.color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildRevealIcon(RewardResult result, AppColors colors) {
    if (result.unlockedThemeId != null) {
      final theme = AppColors.byUnlockableId(result.unlockedThemeId!);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _swatch(theme?.primary ?? colors.primary),
          const SizedBox(width: 6),
          _swatch(theme?.secondary ?? colors.secondary),
          const SizedBox(width: 6),
          _swatch(theme?.accent ?? colors.accent),
        ],
      );
    }
    return Icon(Icons.bolt_rounded, size: 72, color: colors.accent);
  }

  Widget _swatch(Color color) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildRevealText(RewardResult result, AppColors colors) {
    final title = result.unlockedThemeId != null
        ? 'New Theme Unlocked!'
        : 'Bonus Jackpot!';
    final subtitle = result.unlockedThemeId != null
        ? '${_themeName(result.unlockedThemeId!)} is now available in Settings'
        : '+${result.jackpotXp} XP';

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _dismiss,
          style: TextButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Nice!'),
        ),
      ],
    );
  }

  String _themeName(String id) {
    switch (id) {
      case 'ocean':
        return 'Ocean';
      case 'sunset':
        return 'Sunset';
      case 'royal':
        return 'Royal';
      case 'midnight':
        return 'Midnight';
      default:
        return id;
    }
  }
}

class _ConfettiSpec {
  final double angle;
  final Color color;
  final double delay;

  const _ConfettiSpec({
    required this.angle,
    required this.color,
    required this.delay,
  });
}