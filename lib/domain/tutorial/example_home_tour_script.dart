// lib/domain/tutorial/example_home_tour_script.dart

import 'tutorial_models.dart';

/// The app's first-launch guided tour — NOW WIRED to real widgets in
/// home_screen.dart (was a placeholder-only example before that file
/// was available). Auto-starts once on Home (see
/// _HomeScreenState.initState's maybeAutoStart call) and stays
/// manually re-triggerable forever via Settings > "Replay Tutorial"
/// (see settings_screen.dart).
///
/// Target ids referenced here must match the TutorialTarget wrappers
/// in home_screen.dart exactly:
///   - 'home_book_picker'     — the Book section (label + chip picker)
///   - 'home_review_button'   — the AppBar review/spaced-repetition icon
///   - 'home_progress_button' — the AppBar progress-dashboard icon
///
/// Still a reasonable starting point, not a committed final tour —
/// feel free to add/reorder/reword steps once real usage feedback
/// exists. The engine itself doesn't care how many steps a script has
/// or what order they're in.
const homeIntroTutorial = TutorialScript(
  id: 'home_intro_v1',
  steps: [
    TutorialStep.centered(
      message: "Welcome to Babble Tower! Let me show you around.",
      pose: MascotPose.waving,
    ),
    TutorialStep(
      targetId: 'home_book_picker',
      message: "Pick any book of the Gospels here to start reading — "
          "Matthew, Mark, Luke, or John.",
      pose: MascotPose.pointing,
      bubbleSide: BubbleSide.below,
    ),
    TutorialStep(
      targetId: 'home_review_button',
      message: "Tap here anytime to review words you're due to "
          "practice again.",
      pose: MascotPose.pointing,
      bubbleSide: BubbleSide.below,
    ),
    TutorialStep(
      targetId: 'home_progress_button',
      message: "Your Progress page tracks everything — vocabulary, "
          "verses, and grammar — in one place.",
      pose: MascotPose.pointing,
      bubbleSide: BubbleSide.below,
    ),
    TutorialStep.centered(
      message: "That's it — you're ready to start reading. Have fun!",
      pose: MascotPose.celebrating,
    ),
  ],
);