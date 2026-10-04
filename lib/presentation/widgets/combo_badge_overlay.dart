// lib/presentation/widgets/combo_badge_overlay.dart

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Shows a brief, escalating "N in a row!" toast for consecutive
/// correct answers within a single quiz session. Session-scoped only
/// (each quiz screen tracks its own combo count locally, resetting on
/// a wrong answer) — deliberately NOT persisted anywhere, since a
/// combo is meant to reward momentum within one sitting, not become
/// another permanent number to chase (that's what the streak banner
/// and achievement wall are already for).
///
/// Only worth showing at all from 3 in a row onward — 1 or 2 correct
/// answers in sequence isn't a notable pattern yet, and showing a
/// badge for every single correct answer would cheapen the ones that
/// actually feel like an accomplishment.
void showComboBadge(BuildContext context, int comboCount, AppColors colors) {
  if (comboCount < 3) return;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ComboBadgeWidget(
      comboCount: comboCount,
      colors: colors,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _ComboBadgeWidget extends StatefulWidget {
  final int comboCount;
  final AppColors colors;
  final VoidCallback onDone;

  const _ComboBadgeWidget({
    required this.comboCount,
    required this.colors,
    required this.onDone,
  });

  @override
  State<_ComboBadgeWidget> createState() => _ComboBadgeWidgetState();
}

class _ComboBadgeWidgetState extends State<_ComboBadgeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  /// Escalating visual intensity — bigger, warmer, and more saturated
  /// the higher the combo climbs. Capped at a top tier so the text
  /// doesn't grow indefinitely for very long combos.
  ({double scale, Color color, String label}) get _tier {
    final n = widget.comboCount;
    if (n >= 15) {
      return (scale: 1.5, color: const Color(0xFF7B61FF), label: '$n IN A ROW!');
    } else if (n >= 10) {
      return (scale: 1.3, color: const Color(0xFFFF5A36), label: '$n in a row!');
    } else if (n >= 5) {
      return (scale: 1.15, color: const Color(0xFFFF9F1C), label: '$n in a row!');
    }
    return (scale: 1.0, color: widget.colors.primary, label: '$n in a row!');
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 3,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 5),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.85),
        weight: 2,
      ),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 7),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 2),
    ]).animate(_controller);

    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tier;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 90,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value * tier.scale,
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: tier.color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: tier.color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    tier.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}