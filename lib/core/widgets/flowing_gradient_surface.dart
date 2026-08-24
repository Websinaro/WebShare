import 'package:flutter/material.dart';

/// A gradient-filled, rounded surface with a soft diagonal sheen that
/// continuously sweeps across it — the "flowing" highlight look used on
/// Xender's primary buttons and cards. Wrap any child in this instead of
/// using a flat Container color for anything that should feel "premium".
class FlowingGradientSurface extends StatefulWidget {
  final Widget child;
  final Gradient gradient;
  final BorderRadius borderRadius;

  const FlowingGradientSurface({
    super.key,
    required this.child,
    required this.gradient,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  State<FlowingGradientSurface> createState() => _FlowingGradientSurfaceState();
}

class _FlowingGradientSurfaceState extends State<FlowingGradientSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          DecoratedBox(decoration: BoxDecoration(gradient: widget.gradient), child: widget.child),
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final bandWidth = width * 0.5;
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      // Slides from fully off the left edge to fully off the
                      // right edge, on a continuous loop.
                      final dx = -bandWidth + (width + bandWidth * 2) * _controller.value;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Transform.rotate(
                          angle: -0.35,
                          child: Container(
                            width: bandWidth * 0.5,
                            height: constraints.maxHeight * 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.16),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
