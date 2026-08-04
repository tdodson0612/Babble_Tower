// lib/presentation/widgets/tutorial/tutorial_overlay.dart
//
// Full-screen overlay that renders a tutorial step's spotlight and
// speech bubble whenever a tutorial is active. Mounted once in
// app.dart's MaterialApp.builder (see Stack in BabbleTowerApp.build)
// and stays above every route — no per-screen wiring needed.
//
// When no tutorial is active this widget renders SizedBox.shrink
// (zero visual/behavioral impact).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/tutorial/tutorial_models.dart';
import '../../../domain/tutorial/tutorial_target_registry.dart';
import '../../providers/tutorial_provider.dart';

/// The mascot avatar — currently a placeholder circle with an emoji
/// face. Once real art exists, swap the Container for an Image widget
/// keyed on [pose] (see MascotPose doc in tutorial_models.dart).
class _MascotAvatar extends StatelessWidget {
  final MascotPose pose;
  final double size;

  const _MascotAvatar({
    required this.pose,
    // ignore: unused_element_parameter
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder: a colored circle with a pose-dependent emoji.
    // Replace with real art when available.
    final emoji = switch (pose) {
      MascotPose.neutral    => '👋',
      MascotPose.pointing   => '👉',
      MascotPose.celebrating => '🎉',
      MascotPose.thinking   => '🤔',
      MascotPose.waving     => '👋',
    };

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF4A90D9),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// The speech bubble shown alongside the mascot.
class _SpeechBubble extends StatelessWidget {
  final String message;

  const _SpeechBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1A1A2E),
          height: 1.4,
        ),
      ),
    );
  }
}

/// Renders the tutorial overlay — a semi-transparent dim over the
/// entire screen with a "spotlight" hole cut around the current step's
/// target, plus a mascot avatar and speech bubble.
///
/// When [TutorialState.isActive] is false, this widget renders nothing.
class TutorialOverlay extends ConsumerWidget {
  const TutorialOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tutorialControllerProvider);
    final step = state.currentStep;

    if (step == null) return const SizedBox.shrink();

    // Look up the target's bounds — null if the target hasn't mounted
    // yet (e.g. during a cross-screen navigation). The overlay handles
    // this gracefully by simply not painting a spotlight yet.
    final targetBounds = step.hasTarget
        ? TutorialTargetRegistry.boundsFor(step.targetId)
        : null;

    return Positioned.fill(
      child: Stack(
        children: [
          // Dim overlay with spotlight hole.
          if (targetBounds != null)
            ClipPath(
              clipper: _SpotlightClipper(hole: targetBounds),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            )
          else
            Container(color: Colors.black.withValues(alpha: 0.5)),

          // Mascot + speech bubble positioned relative to the target.
          if (targetBounds != null)
            Positioned(
              left: targetBounds.left,
              top: targetBounds.bottom + 16,
              child: _buildBubbleAndMascot(context, step),
            )
          else
            // Centered message (no target — e.g. welcome/ending steps).
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _MascotAvatar(pose: MascotPose.waving),
                  const SizedBox(height: 16),
                  _SpeechBubble(message: step.message),
                ],
              ),
            ),

          // Next / Skip buttons at the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 32,
            child: _buildControls(context, ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleAndMascot(BuildContext context, TutorialStep step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MascotAvatar(pose: step.pose),
            const SizedBox(width: 12),
            Flexible(child: _SpeechBubble(message: step.message)),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(
      BuildContext context, WidgetRef ref, TutorialState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () =>
                ref.read(tutorialControllerProvider.notifier).skip(),
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90D9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () =>
                ref.read(tutorialControllerProvider.notifier).next(),
            child: Text(
              state.isLastStep ? 'Finish' : 'Next',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips a full-screen rectangle EXCEPT for a circular/rounded-rect
/// "spotlight" hole around [hole].
class _SpotlightClipper extends CustomClipper<Path> {
  final Rect hole;

  _SpotlightClipper({required this.hole});

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final spot = Path()..addOval(
      Rect.fromCenter(
        center: hole.center,
        width: hole.width + 24,
        height: hole.height + 24,
      ),
    );
    return Path.combine(PathOperation.reverseDifference, full, spot);
  }

  @override
  bool shouldReclip(_SpotlightClipper old) => old.hole != hole;
}