// lib/domain/tutorial/tutorial_models.dart

/// Placeholder expression/pose for the mascot character — the actual
/// artwork is being illustrated separately (see project handoff doc's
/// to-do list: "Tutorial/walkthrough mascot system... User is
/// illustrating the character art themselves — only the overlay/
/// highlight/scripting mechanics are needed from Claude"). This enum
/// is the ONLY thing the art side needs to hook into: once real art
/// exists, MascotAvatar (see tutorial_overlay.dart) swaps its placeholder
/// shape for an actual image asset per pose, with zero changes needed
/// to any script or the engine itself.
enum MascotPose { neutral, pointing, celebrating, thinking, waving }

/// Which side of the spotlighted target the speech bubble should
/// appear on. `center` is used for steps with no target at all (a
/// pure "welcome" or "all done" message shown mid-screen).
enum BubbleSide { above, below, left, right, center }

/// One step in a scripted tutorial. [targetId] must match a widget
/// wrapped in a TutorialTarget with the same id (see
/// tutorial_target.dart) — TutorialOverlay looks it up in the shared
/// registry at render time, so steps never hold a GlobalKey directly
/// (a GlobalKey from a screen that's since been popped would be stale;
/// looking it up fresh by id every time avoids that entirely).
///
/// [routeName] is optional: set it when this step's target lives on a
/// screen OTHER than wherever the tutorial was started from. The
/// controller will navigate there automatically before showing the
/// spotlight — see TutorialController.next()'s doc.
class TutorialStep {
  final String targetId;
  final String? routeName;
  final String message;
  final MascotPose pose;
  final BubbleSide bubbleSide;

  /// Extra padding (px) around the target's bounds when cutting the
  /// spotlight hole — a little breathing room around a small icon
  /// button reads better than a hole exactly the size of the widget.
  final double spotlightPadding;

  const TutorialStep({
    required this.targetId,
    this.routeName,
    required this.message,
    this.pose = MascotPose.neutral,
    this.bubbleSide = BubbleSide.below,
    this.spotlightPadding = 8,
  });

  /// A step with no real target — full-screen dimmed message, mascot
  /// centered. Used for a tour's opening "Welcome!" or closing
  /// "You're all set!" moment.
  const TutorialStep.centered({
    this.routeName,
    required this.message,
    this.pose = MascotPose.waving,
  })  : targetId = '',
        bubbleSide = BubbleSide.center,
        spotlightPadding = 0;

  bool get hasTarget => targetId.isNotEmpty;
}

/// A named, ordered sequence of steps — one full guided tour. Multiple
/// scripts can exist independently (e.g. a first-launch home-screen
/// tour, a separate "how grammar lessons work" tour) — see
/// TrackTutorialProgressUseCase for how completion is tracked per
/// script id, not globally.
class TutorialScript {
  final String id;
  final List<TutorialStep> steps;

  const TutorialScript({required this.id, required this.steps});
}