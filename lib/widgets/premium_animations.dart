import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

/// 1. Fade + slide entrance animation.
/// Wrap any existing widget with AnimatedEntrance.
class AnimatedEntrance extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double slideOffset;

  const AnimatedEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.slideOffset = 18,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

/// 2. Animated task card.
/// Wrap your existing task card; keep its existing content and logic.
class AnimatedTaskCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AnimatedTaskCard({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<AnimatedTaskCard> createState() => _AnimatedTaskCardState();
}

class _AnimatedTaskCardState extends State<AnimatedTaskCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: widget.child,
        ),
      ),
    );
  }
}

/// 3. Premium animated checkbox.
class PremiumTaskCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  const PremiumTaskCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 27,
  });

  @override
  Widget build(BuildContext context) {
    const purple = AppTheme.primaryPurple;
    const cyan = AppTheme.accentCyan;

    return Semantics(
      label: value ? 'Task completed' : 'Task not completed',
      checked: value,
      button: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: value ? purple : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: value ? cyan : Colors.white38,
                width: 1.6,
              ),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: value
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('checked'),
                      color: Colors.white,
                      size: 19,
                    )
                  : const SizedBox(
                      key: ValueKey('unchecked'),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 4. Animated circular progress ring.
/// Pass a real completion ratio between 0.0 and 1.0.
class PremiumProgressRing extends StatefulWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;

  const PremiumProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 9,
    this.child,
  });

  @override
  State<PremiumProgressRing> createState() => _PremiumProgressRingState();
}

class _PremiumProgressRingState extends State<PremiumProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  double get _target => widget.progress.clamp(0.0, 1.0).toDouble();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _animation = Tween<double>(
      begin: 0,
      end: _target,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant PremiumProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.progress != widget.progress) {
      final currentValue = _animation.value;

      _animation = Tween<double>(
        begin: currentValue,
        end: _target,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ),
      );

      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF9B6DFF);
    const cyan = Color(0xFF55E6E0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value.clamp(0.0, 1.0);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: progress,
              strokeWidth: widget.strokeWidth,
              trackColor: Colors.white.withValues(alpha: 0.2),
              progressColor: purple,
              endColor: cyan,
            ),
            child: Center(
              child: widget.child ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;
  final Color endColor;

  const _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -1.57079632679,
        endAngle: -1.57079632679 + 6.28318530718,
        colors: [progressColor, endColor],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -1.57079632679,
      6.28318530718 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.endColor != endColor;
  }
}

/// 5. Floating Add button with subtle press animation.
class PremiumAddButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const PremiumAddButton({
    super.key,
    required this.onPressed,
    this.label = 'Add Task',
  });

  @override
  State<PremiumAddButton> createState() => _PremiumAddButtonState();
}

class _PremiumAddButtonState extends State<PremiumAddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: FloatingActionButton.extended(
          heroTag: 'taskalert_premium_add_button',
          backgroundColor: AppTheme.primaryPurple,
          foregroundColor: Colors.white,
          elevation: _pressed ? 2 : 7,
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onPressed();
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(widget.label),
        ),
      ),
    );
  }
}
