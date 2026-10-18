import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

class PremiumLineGraph extends StatefulWidget {
  final List<int> dailyCompleted; // Length 7 (Mon = index 0, Sun = index 6)
  final String weekRangeText;
  final int currentWeekday; // 1 = Mon, 7 = Sun

  const PremiumLineGraph({
    super.key,
    required this.dailyCompleted,
    required this.weekRangeText,
    required this.currentWeekday,
  });

  @override
  State<PremiumLineGraph> createState() => _PremiumLineGraphState();
}

class _PremiumLineGraphState extends State<PremiumLineGraph>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _chartAnimation;
  int? _selectedDayIndex;

  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = (widget.currentWeekday - 1).clamp(0, 6);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _chartAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant PremiumLineGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dailyCompleted != widget.dailyCompleted) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weeklyTotal = widget.dailyCompleted.fold(0, (sum, item) => sum + item);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graph Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.show_chart_rounded,
                            color: AppTheme.accentCyan,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Weekly Productivity Trend',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$weeklyTotal task${weeklyTotal == 1 ? '' : 's'} completed this week',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  widget.weekRangeText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Selected Day Interactive Tooltip Banner
          if (_selectedDayIndex != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentCyan.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_dayLabels[_selectedDayIndex!]} (${_selectedDayIndex! + 1 == widget.currentWeekday ? "Today" : "Day ${_selectedDayIndex! + 1}"}): ${widget.dailyCompleted[_selectedDayIndex!]} task${widget.dailyCompleted[_selectedDayIndex!] == 1 ? '' : 's'} completed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Custom Animated Line Chart
          SizedBox(
            height: 180,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return GestureDetector(
                  onTapDown: (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPos = box.globalToLocal(details.globalPosition);
                    final width = box.size.width;
                    const paddingLeft = 32.0;
                    const paddingRight = 16.0;
                    final chartWidth = width - paddingLeft - paddingRight;
                    final stepX = chartWidth / 6;

                    for (int i = 0; i < 7; i++) {
                      final pointX = paddingLeft + (i * stepX);
                      if ((localPos.dx - pointX).abs() < (stepX / 2)) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedDayIndex = i;
                        });
                        break;
                      }
                    }
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _LineChartPainter(
                      data: widget.dailyCompleted,
                      labels: _dayLabels,
                      progress: _chartAnimation.value,
                      currentWeekday: widget.currentWeekday,
                      selectedIndex: _selectedDayIndex,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Legend / Guidance Note
          const Center(
            child: Text(
              'Tap any day on the graph to view daily completion details',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> data;
  final List<String> labels;
  final double progress;
  final int currentWeekday;
  final int? selectedIndex;

  _LineChartPainter({
    required this.data,
    required this.labels,
    required this.progress,
    required this.currentWeekday,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double paddingLeft = 32.0;
    const double paddingRight = 16.0;
    const double paddingTop = 16.0;
    const double paddingBottom = 28.0;

    final double width = size.width - paddingLeft - paddingRight;
    final double height = size.height - paddingTop - paddingBottom;

    int maxVal = 4;
    for (int val in data) {
      if (val > maxVal) maxVal = val;
    }

    // 1. Draw Horizontal Grid Lines and Y-Axis Labels
    final gridLines = 3;
    final textStyle = const TextStyle(
      color: AppTheme.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= gridLines; i++) {
      final y = paddingTop + height - (i * (height / gridLines));
      final val = ((maxVal / gridLines) * i).round();

      // Draw Grid Line
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        linePaint,
      );

      // Draw Y-Axis Label
      final tp = TextPainter(
        text: TextSpan(text: '$val', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 8, y - (tp.height / 2)));
    }

    // Calculate Data Points
    final stepX = width / (data.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      final x = paddingLeft + (i * stepX);
      final normalizedY = (data[i] / maxVal).clamp(0.0, 1.0);
      final y = paddingTop + height - (normalizedY * height);
      points.add(Offset(x, y));
    }

    // 2. Draw Smooth Bezier Path
    if (points.isNotEmpty) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];

        final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY1 = p0.dy;
        final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
        final controlY2 = p1.dy;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
      }

      // Animate Path Progress
      final pathMetrics = path.computeMetrics();
      final animatedPath = Path();

      for (final metric in pathMetrics) {
        final extractLength = metric.length * progress;
        animatedPath.addPath(metric.extractPath(0, extractLength), Offset.zero);
      }

      // Fill Gradient Path under curve
      final fillPath = Path.from(animatedPath);
      final currentMaxX = paddingLeft + (width * progress);

      fillPath.lineTo(currentMaxX, paddingTop + height);
      fillPath.lineTo(paddingLeft, paddingTop + height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, paddingTop),
          Offset(0, paddingTop + height),
          [
            AppTheme.accentCyan.withValues(alpha: 0.35),
            AppTheme.primaryPurple.withValues(alpha: 0.02),
          ],
        )
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);

      // Stroke Paint with Glow
      final strokePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(paddingLeft, 0),
          Offset(size.width - paddingRight, 0),
          [
            AppTheme.accentCyan,
            AppTheme.primaryPurple,
          ],
        )
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(animatedPath, strokePaint);
    }

    // 3. Draw Data Point Markers & X-Axis Labels
    for (int i = 0; i < data.length; i++) {
      final point = points[i];
      final isToday = (i + 1) == currentWeekday;
      final isSelected = selectedIndex == i;

      // Only show points up to progress
      if (point.dx <= paddingLeft + (width * progress) + 2) {
        // Outer Halo for Selected or Today
        if (isSelected || isToday) {
          final haloPaint = Paint()
            ..color = (isSelected ? AppTheme.accentCyan : AppTheme.primaryPurple)
                .withValues(alpha: 0.3)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(point, 10, haloPaint);
        }

        // Inner Dot
        final dotPaint = Paint()
          ..color = isSelected
              ? AppTheme.accentCyan
              : (isToday
                  ? Colors.white
                  : (data[i] > 0 ? AppTheme.accentCyan : AppTheme.cardNavy))
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = isSelected
              ? Colors.white
              : (isToday ? AppTheme.accentCyan : AppTheme.primaryPurple)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(point, 4.5, dotPaint);
        canvas.drawCircle(point, 4.5, borderPaint);
      }

      // X-Axis Label
      final isLabelHighlighted = isSelected || isToday;
      final labelStyle = TextStyle(
        color: isLabelHighlighted ? AppTheme.accentCyan : AppTheme.textMuted,
        fontSize: 11,
        fontWeight: isLabelHighlighted ? FontWeight.bold : FontWeight.normal,
      );

      final labelPainter = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(point.dx - (labelPainter.width / 2), size.height - paddingBottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.data != data;
  }
}
