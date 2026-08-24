import 'dart:math';
import 'package:flutter/material.dart';

/// A circular progress ring painted with a sweeping, slowly-rotating
/// gradient stroke instead of a flat color — the "flowing" progress look
/// Xender-style transfer screens use, instead of Material's flat ring.
class GradientProgressRing extends StatefulWidget {
  final double progress; // 0..1
  final double strokeWidth;
  final Gradient gradient;

  const GradientProgressRing({
    super.key,
    required this.progress,
    required this.gradient,
    this.strokeWidth = 10,
  });

  @override
  State<GradientProgressRing> createState() => _GradientProgressRingState();
}

class _GradientProgressRingState extends State<GradientProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotation,
      builder: (context, _) {
        return CustomPaint(
          painter: _RingPainter(
            progress: widget.progress.clamp(0.0, 1.0),
            strokeWidth: widget.strokeWidth,
            gradient: widget.gradient,
            rotationTurns: _rotation.value,
            trackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Gradient gradient;
  final double rotationTurns;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradient,
    required this.rotationTurns,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweepAngle = 2 * pi * progress;
    final startAngle = -pi / 2 + (2 * pi * rotationTurns * 0.15); // slow drift, not a full spin

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.rotationTurns != rotationTurns;
  }
}
