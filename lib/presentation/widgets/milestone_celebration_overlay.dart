// lib/presentation/widgets/milestone_celebration_overlay.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum MilestoneTier { chapter, book }

/// A bigger, unmissable celebration than the combo badge or mystery
/// box — reserved for genuinely significant milestones (finishing a
/// chapter, finishing an entire Gospel), shown as a full modal rather
/// than a passing toast. Deliberately requires an explicit dismissal
/// tap rather than auto-fading, since these moments are meant to
/// register as a real accomplishment worth pausing for, not just
/// another passing animation.
Future<void> showMilestoneCelebration(
  BuildContext context, {
  required MilestoneTier tier,
  required String bookName,
  int? chapterNumber,
  required AppColors colors,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => _MilestoneContent(
      tier: tier,
      bookName: bookName,
      chapterNumber: chapterNumber,
      colors: colors,
    ),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}

class _MilestoneContent extends StatefulWidget {
  final MilestoneTier tier;
  final String bookName;
  final int? chapterNumber;
  final AppColors colors;

  const _MilestoneContent({
    required this.tier,
    required this.bookName,
    required this.chapterNumber,
    required this.colors,
  });

  @override
  State<_MilestoneContent> createState() => _MilestoneContentState();
}

class _MilestoneContentState extends State<_MilestoneContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentOpacity;
  final List<_Particle> _particles = List.generate(24, (i) {
    final rnd = Random(i);
    return _Particle(
      angle: rnd.nextDouble() * 2 * pi,
      distance: 90 + rnd.nextDouble() * 70,
      delay: rnd.nextDouble() * 0.3,
      color: Colors.primaries[i % Colors.primaries.length],
    );
  });

  bool get _isBook => widget.tier == MilestoneTier.book;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _isBook ? 1600 : 1000),
    )..forward();

    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.15)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 6,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6),
    ));

    _contentOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final tierColor = _isBook ? const Color(0xFFD4AF37) : colors.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (_controller.value > 0.15)
                  ..._particles.map((p) => _buildParticle(p)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _iconScale.value,
                      child: Icon(
                        _isBook
                            ? Icons.auto_awesome_rounded
                            : Icons.emoji_events_rounded,
                        size: _isBook ? 96 : 80,
                        color: tierColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: _contentOpacity.value,
                      child: Column(
                        children: [
                          Text(
                            _isBook ? 'Book Complete!' : 'Chapter Complete!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 26,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isBook
                                ? "You've finished the Gospel of ${widget.bookName}"
                                : '${widget.bookName} ${widget.chapterNumber}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tierColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildParticle(_Particle p) {
    final progress = ((_controller.value - p.delay) / 0.7).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(progress);
    final dx = cos(p.angle) * p.distance * eased;
    final dy = sin(p.angle) * p.distance * eased - (40 * eased * eased);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: (1.0 - progress * 0.9).clamp(0.0, 1.0),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double delay;
  final Color color;

  const _Particle({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.color,
  });
}