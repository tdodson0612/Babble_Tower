// lib/presentation/widgets/tutorial/tutorial_target.dart
//
// Wraps a child widget so it can be spotlighted by TutorialOverlay
// during a guided tour. Each target registers itself with the shared
// TutorialTargetRegistry by id — the overlay looks up bounds at render
// time, so targets can live on any screen and survive navigation.

import 'package:flutter/material.dart';
import '../../../domain/tutorial/tutorial_target_registry.dart';

/// Wraps [child] with a GlobalKey registered under [id] so that
/// TutorialOverlay can look up its screen bounds and cut a spotlight
/// hole around it.
///
/// Usage:
/// ```dart
/// TutorialTarget(
///   id: 'home_review_button',
///   child: const ReviewIconButton(),
/// )
/// ```
class TutorialTarget extends StatefulWidget {
  final String id;
  final Widget child;

  const TutorialTarget({
    super.key,
    required this.id,
    required this.child,
  });

  @override
  State<TutorialTarget> createState() => _TutorialTargetState();
}

class _TutorialTargetState extends State<TutorialTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TutorialTargetRegistry.register(widget.id, _key);
  }

  @override
  void didUpdateWidget(TutorialTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      TutorialTargetRegistry.unregister(oldWidget.id, _key);
      TutorialTargetRegistry.register(widget.id, _key);
    }
  }

  @override
  void dispose() {
    TutorialTargetRegistry.unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: _key, child: widget.child);
  }
}