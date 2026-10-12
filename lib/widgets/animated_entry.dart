import 'package:flutter/material.dart';

class AnimatedEntry extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration delay;

  const AnimatedEntry({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDelay = delay + Duration(milliseconds: index * 60);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration + effectiveDelay,
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}
