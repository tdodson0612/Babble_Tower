// lib/domain/usecases/track_tutorial_progress_usecase.dart

import '../../data/services/hive_service.dart';

/// Tracks, per tutorial script id, whether it's already been shown
/// (completed OR explicitly skipped — both count as "don't auto-show
/// again"). A SEPARATE, tiny model from every other progress tracker
/// in the app — same "one small model per distinct question" pattern
/// TrackGrammarLessonProgressUseCase and TrackParsingProgressUseCase
/// already use, since this answers a completely different question
/// ("has the user seen tour X") from anything vocabulary/verse/grammar
/// related.
///
/// Per the handoff doc's explicit "re-triggerable anytime" requirement:
/// this class only gates AUTOMATIC first-time display — see
/// TutorialController.maybeAutoStart. A manual "Replay Tutorial" entry
/// point (see settings_screen.dart) always calls
/// TutorialController.start() directly, bypassing this check entirely,
/// so completion status never blocks a deliberate replay.
class TrackTutorialProgressUseCase {
  const TrackTutorialProgressUseCase();

  static const _boxName = 'tutorial_progress';
  static const _key = 'shownScriptIds';

  Future<Set<String>> _loadShownIds() async {
    try {
      final box = await HiveService.openBox(_boxName);
      final raw = box.get(_key) as List?;
      return raw?.map((e) => e as String).toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> hasBeenShown(String scriptId) async {
    final shown = await _loadShownIds();
    return shown.contains(scriptId);
  }

  Future<void> markShown(String scriptId) async {
    final shown = await _loadShownIds();
    if (shown.add(scriptId)) {
      final box = await HiveService.openBox(_boxName);
      await box.put(_key, shown.toList());
    }
  }

  /// Resets a single script back to "never shown" — not currently
  /// exposed in any UI, but useful for debugging/QA without needing to
  /// clear the whole box.
  Future<void> reset(String scriptId) async {
    final shown = await _loadShownIds();
    if (shown.remove(scriptId)) {
      final box = await HiveService.openBox(_boxName);
      await box.put(_key, shown.toList());
    }
  }
}