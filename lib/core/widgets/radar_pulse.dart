import 'package:flutter/material.dart';

/// Concentric rings expanding outward and fading, looped with staggered
/// starts — the "searching for a nearby device" radar visual Xender and
/// similar transfer apps use. Wrap around anything (typically a QR code
/// or an avatar) via [child]; the rings render behind it.
class RadarPulse extends StatefulWidget {
  final Widget child;
  final Color color;
  final double maxDiameter;
  final int ringCount;

  const RadarPulse({
    super.key,
    required this.child,
    required this.color,
    this.maxDiameter = 320,
    this.ringCount = 3,
  });

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.maxDiameter,
      height: widget.maxDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(widget.ringCount, (i) {
                  // Stagger each ring by an even fraction of the loop so
                  // they don't all pulse in lockstep. controller.value is
                  // already normalized 0..1 over the animation's duration.
                  final offset = i / widget.ringCount;
                  final t = (_controller.value + offset) % 1.0;
                  final size = widget.maxDiameter * t;
                  final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.35;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color.withValues(alpha: opacity), width: 2),
                    ),
                  );
                }),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}
