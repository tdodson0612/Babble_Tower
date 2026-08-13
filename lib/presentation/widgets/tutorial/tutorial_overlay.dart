// lib/presentation/widgets/tutorial/tutorial_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/tutorial/tutorial_models.dart';
import '../../../domain/tutorial/tutorial_target_registry.dart';
import '../../providers/tutorial_provider.dart';

/// Renders the currently-active tutorial step, if any — a dimmed
/// full-screen scrim with a spotlight hole cut around the target
/// widget (looked up fresh from TutorialTargetRegistry every build, so
/// it's always correct even right after a cross-screen navigation),
/// plus a speech bubble and placeholder mascot. Tapping ANYWHERE on
/// the overlay (including inside the spotlight hole) advances to the
/// next step — matches the handoff doc's "Tap to continue" spec
/// literally, and is far simpler/safer than trying to let the real
/// widget underneath receive the tap while still gating advancement.
///
/// Mounted once, at the very top of the widget tree, via
/// MaterialApp.builder in app.dart — NOT per-screen — so it can paint
/// over literally any screen without every screen needing its own
/// copy of this logic.
class TutorialOverlay extends ConsumerWidget {
  const TutorialOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorialState = ref.watch(tutorialControllerProvider);
    final step = tutorialState.currentStep;
    if (step == null) return const SizedBox.shrink();

    final bounds =
        step.hasTarget ? TutorialTargetRegistry.boundsFor(step.targetId) : null;
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final safeInsets = media.padding;
    final safeTop = safeInsets.top;
    final safeBottom = safeInsets.bottom;
    final safeLeft = safeInsets.left;
    final safeRight = safeInsets.right;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(tutorialControllerProvider.notifier).next(),
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _SpotlightPainter(
                bounds: bounds,
                padding: step.spotlightPadding,
              ),
            ),
            _TutorialContent(
              step: step,
              bounds: bounds,
              colors: colors,
              isLastStep: tutorialState.isLastStep,
              onSkip: () => ref.read(tutorialControllerProvider.notifier).skip(),
              safeTop: safeTop,
              safeBottom: safeBottom,
              safeLeft: safeLeft,
              safeRight: safeRight,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuts a rounded-rect hole out of a dark scrim wherever [bounds] is —
/// or, if [bounds] is null (either a centered step, or the target
/// hasn't mounted/laid out yet right after a cross-screen navigation),
/// just dims the whole screen with no hole. That null case is handled
/// gracefully rather than crashing or flashing an error, since it's an
/// expected transient state, not a bug.
class _SpotlightPainter extends CustomPainter {
  final Rect? bounds;
  final double padding;

  const _SpotlightPainter({required this.bounds, required this.padding});

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()..color = const Color(0xCC000000);
    final background = Path()..addRect(Offset.zero & size);

    final b = bounds;
    if (b == null) {
      canvas.drawPath(background, scrimPaint);
      return;
    }

    final holeRect = RRect.fromRectAndRadius(
      b.inflate(padding),
      const Radius.circular(16),
    );
    final hole = Path()..addRRect(holeRect);
    final combined = Path.combine(PathOperation.difference, background, hole);
    canvas.drawPath(combined, scrimPaint);

    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(holeRect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.bounds != bounds || oldDelegate.padding != padding;
}

/// Positions the mascot + speech bubble relative to the target bounds
/// (or centered, for a targetless step), clamped to stay on-screen.
class _TutorialContent extends StatelessWidget {
  final TutorialStep step;
  final Rect? bounds;
  final AppColors colors;
  final bool isLastStep;
  final VoidCallback onSkip;
  final double safeTop;
  final double safeBottom;
  final double safeLeft;
  final double safeRight;

  const _TutorialContent({
    required this.step,
    required this.bounds,
    required this.colors,
    required this.isLastStep,
    required this.onSkip,
    required this.safeTop,
    required this.safeBottom,
    required this.safeLeft,
    required this.safeRight,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final usableWidth = screenSize.width - safeLeft - safeRight;

    final maxBubbleWidth = usableWidth - 32;
    final bubbleWidth = maxBubbleWidth.clamp(200.0, 320.0);
    const gap = 16.0;

    double left;
    double top;

    if (bounds == null || step.bubbleSide == BubbleSide.center) {
      left = (screenSize.width - bubbleWidth) / 2;
      top = screenSize.height * 0.4;
    } else {
      final b = bounds!.inflate(step.spotlightPadding);
      switch (step.bubbleSide) {
        case BubbleSide.above:
          left = b.center.dx - bubbleWidth / 2;
          top = b.top - gap - 160;
          break;
        case BubbleSide.below:
          left = b.center.dx - bubbleWidth / 2;
          top = b.bottom + gap;
          break;
        case BubbleSide.left:
          left = b.left - bubbleWidth - gap;
          top = b.center.dy - 60;
          break;
        case BubbleSide.right:
          left = b.right + gap;
          top = b.center.dy - 60;
          break;
        case BubbleSide.center:
          left = (screenSize.width - bubbleWidth) / 2;
          top = screenSize.height * 0.4;
          break;
      }
    }

    left = left.clamp(safeLeft + 16.0, screenSize.width - safeRight - bubbleWidth - 16.0);
    top = top.clamp(safeTop + 48.0, screenSize.height - safeBottom - 220.0);

    return Positioned(
      left: left,
      top: top,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bubbleWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MascotPlaceholder(pose: step.pose),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 12),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.message,
                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: onSkip,
                        child: Text(
                          'Skip',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                      Text(
                        isLastStep ? "Tap to finish →" : "Tap to continue →",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The mascot avatar — real illustrated art per [MascotPose] (see
/// assets/mascot/*.svg), replacing the earlier icon-in-a-circle
/// placeholder. Every script using MascotPose values keeps working
/// unchanged, since this widget is the only thing that had to change
/// to go from placeholder to real art — exactly the swap point that
/// placeholder's own doc comment described.
class _MascotPlaceholder extends StatelessWidget {
  final MascotPose pose;
  const _MascotPlaceholder({required this.pose});

  String get _assetPath {
    switch (pose) {
      case MascotPose.neutral:
        return 'assets/mascot/mascot_neutral.svg';
      case MascotPose.pointing:
        return 'assets/mascot/mascot_pointing.svg';
      case MascotPose.celebrating:
        return 'assets/mascot/mascot_celebrating.svg';
      case MascotPose.thinking:
        return 'assets/mascot/mascot_thinking.svg';
      case MascotPose.waving:
        return 'assets/mascot/mascot_waving.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(56.0, 96.0);
        return SizedBox(
          width: size,
          height: size * 1.08,
          child: SvgPicture.asset(_assetPath, fit: BoxFit.contain),
        );
      },
    );
  }
}