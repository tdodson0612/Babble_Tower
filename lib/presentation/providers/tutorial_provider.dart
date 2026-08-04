// lib/presentation/providers/tutorial_provider.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/tutorial/tutorial_models.dart';
import '../../domain/usecases/track_tutorial_progress_usecase.dart';

/// Current tutorial state — null [script] means no tutorial is active,
/// which is the normal state almost all the time.
class TutorialState {
  final TutorialScript? script;
  final int stepIndex;

  const TutorialState({this.script, this.stepIndex = 0});

  bool get isActive => script != null;

  TutorialStep? get currentStep {
    final s = script;
    if (s == null || stepIndex >= s.steps.length) return null;
    return s.steps[stepIndex];
  }

  bool get isLastStep {
    final s = script;
    return s == null || stepIndex >= s.steps.length - 1;
  }

  TutorialState copyWith({TutorialScript? script, int? stepIndex}) =>
      TutorialState(
        script: script ?? this.script,
        stepIndex: stepIndex ?? this.stepIndex,
      );
}

/// Drives one tutorial session end-to-end: which step is showing,
/// advancing to the next one (including navigating to a different
/// screen first, when a step's [TutorialStep.routeName] differs from
/// wherever the user currently is), and recording completion so the
/// SAME script doesn't auto-start again next launch — while remaining
/// fully re-runnable on demand (see [start], always callable
/// regardless of prior completion — the handoff doc's explicit
/// "re-triggerable anytime" requirement).
///
/// Needs a [GlobalKey<NavigatorState>] to drive cross-screen
/// navigation — see app.dart's MaterialApp.navigatorKey, which this
/// reads from the same key the whole app already uses.
class TutorialController extends StateNotifier<TutorialState> {
  TutorialController(this._navigatorKey)
      : _progress = const TrackTutorialProgressUseCase(),
        super(const TutorialState());

  final GlobalKey<NavigatorState> _navigatorKey;
  final TrackTutorialProgressUseCase _progress;

  /// Starts a script from its first step. Always available — does NOT
  /// check TrackTutorialProgressUseCase, so this is exactly what a
  /// manual "Replay Tutorial" entry point should call directly.
  void start(TutorialScript script) {
    state = TutorialState(script: script, stepIndex: 0);
    _navigateIfNeeded(script.steps.first);
  }

  /// Starts [script] only if it's never been shown before (completed
  /// OR skipped) — the auto-launch path for a screen's initState,
  /// e.g. "show the home-screen tour the first time the user lands
  /// here." Never re-triggers itself once shown; use [start] directly
  /// for anything that should always run regardless of history.
  Future<void> maybeAutoStart(TutorialScript script) async {
    final alreadyShown = await _progress.hasBeenShown(script.id);
    if (alreadyShown) return;
    start(script);
  }

  /// Advances to the next step, navigating first if that step lives on
  /// a different screen. Ends the tutorial and records it as shown if
  /// this was the last step.
  Future<void> next() async {
    final script = state.script;
    if (script == null) return;

    if (state.isLastStep) {
      await _finish();
      return;
    }

    final nextIndex = state.stepIndex + 1;
    state = state.copyWith(stepIndex: nextIndex);
    _navigateIfNeeded(script.steps[nextIndex]);
  }

  /// Ends the tutorial early (user tapped "Skip") — still records it
  /// as shown, since an explicitly-skipped tour shouldn't auto-launch
  /// again either.
  Future<void> skip() async {
    await _finish();
  }

  Future<void> _finish() async {
    final script = state.script;
    state = const TutorialState();
    if (script != null) {
      await _progress.markShown(script.id);
    }
  }

  /// Pushes [step]'s route if it's set and different from whatever's
  /// currently on top — then waits one frame so the destination
  /// screen's TutorialTarget widgets have mounted and registered
  /// themselves before the overlay tries to look up their bounds (see
  /// TutorialTargetRegistry.boundsFor, which returns null until then —
  /// TutorialOverlay already handles a transient null gracefully by
  /// simply not painting a spotlight yet, so this frame-delay isn't
  /// load-bearing for correctness, just for a cleaner first paint).
  void _navigateIfNeeded(TutorialStep step) {
    final route = step.routeName;
    if (route == null) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamed(route);
  }
}

/// Shared navigator key — app.dart's MaterialApp uses this SAME
/// instance (`MaterialApp(navigatorKey: tutorialNavigatorKey, ...)`),
/// so TutorialController can drive cross-screen navigation without
/// needing a ProviderScope override wired up in main.dart. One key,
/// imported wherever it's needed, rather than passed through
/// provider-override plumbing.
final GlobalKey<NavigatorState> tutorialNavigatorKey =
    GlobalKey<NavigatorState>();

final tutorialControllerProvider =
    StateNotifierProvider<TutorialController, TutorialState>((ref) {
  return TutorialController(tutorialNavigatorKey);
});