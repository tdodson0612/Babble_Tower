// lib/domain/tutorial/tutorial_target_registry.dart

import 'package:flutter/widgets.dart';

/// Maps a tutorial target id (e.g. "home_review_button") to the
/// GlobalKey of whatever widget currently claims that id. Populated by
/// TutorialTarget widgets as they mount/unmount (see
/// tutorial_target.dart) — NOT by scripts themselves, which only ever
/// reference targets by id string.
///
/// Looking keys up fresh from this registry (rather than a script
/// holding a GlobalKey captured once) is what makes cross-screen
/// tutorials safe: a GlobalKey captured on screen A is meaningless
/// (and potentially attached to an unmounted element) once the user
/// has navigated to screen B — by only ever resolving "give me
/// whatever's currently registered as X" at the moment a step is
/// actually shown, after navigation has settled, this never goes
/// stale.
///
/// Deliberately a plain static map, not a Riverpod provider — this is
/// pure widget-tree bookkeeping (which key currently owns an id), not
/// application state anything should watch/react to.
class TutorialTargetRegistry {
  TutorialTargetRegistry._();

  static final Map<String, GlobalKey> _keys = {};

  static void register(String id, GlobalKey key) {
    _keys[id] = key;
  }

  /// Called by TutorialTarget.dispose() — but ONLY removes the entry
  /// if it still points at THIS key. Guards against a subtle mount-
  /// order race: if a new TutorialTarget for the same id has already
  /// mounted (e.g. the same button exists on both the old and new
  /// frame during a route transition) before the old one's dispose()
  /// runs, blindly removing would delete the NEW registration instead
  /// of the stale one.
  static void unregister(String id, GlobalKey key) {
    if (_keys[id] == key) {
      _keys.remove(id);
    }
  }

  /// Returns the currently-registered GlobalKey for [id], or null if
  /// nothing with that id is mounted right now (e.g. the target lives
  /// on a screen that hasn't been navigated to yet).
  static GlobalKey? keyFor(String id) => _keys[id];

  /// The global bounding rect of whatever's currently registered under
  /// [id], in global (screen) coordinates — or null if not mounted, or
  /// not yet laid out. TutorialOverlay uses this directly to position
  /// the spotlight hole and speech bubble.
  static Rect? boundsFor(String id) {
    final key = _keys[id];
    if (key == null) return null;
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    if (!renderObject.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }
}