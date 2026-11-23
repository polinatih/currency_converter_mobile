import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/dates.dart';
import '../../domain/number_format.dart';
import '../../domain/period_stats.dart';

/// Line chart of a rate over a period, drawn with CustomPainter (no chart package).
///
/// X axis is calendar time from [start] to [end], so days without published
/// rates (weekends) appear as gaps between points instead of being squeezed out.
class RateChart extends StatelessWidget {
  const RateChart({
    super.key,
    required this.points,
    required this.start,
    required this.end,
    this.height = 220,
  });

  final List<RatePoint> points;
  final DateTime start;
  final DateTime end;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _RateChartPainter(
          points: points,
          start: start,
          end: end,
          line: theme.colorScheme.primary,
          grid: theme.colorScheme.outlineVariant,
          label: theme.colorScheme.onSurfaceVariant,
          minColor: const Color(0xFF185FA5),
          maxColor: const Color(0xFFBA7517),
          textStyle: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

class _RateChartPainter extends CustomPainter {
  _RateChartPainter({
    required this.points,
    required this.start,
    required this.end,
    required this.line,
    required this.grid,
    required this.label,
    required this.minColor,
    required this.maxColor,
    required this.textStyle,
  });

  final List<RatePoint> points;
  final DateTime start;
  final DateTime end;
  final Color line;
  final Color grid;
  final Color label;
  final Color minColor;
  final Color maxColor;
  final TextStyle textStyle;

  static const double _left = 56;
  static const double _right = 8;
  static const double _top = 10;
  static const double _bottom = 24;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    var lo = sorted.map((p) => p.value).reduce(math.min);
    var hi = sorted.map((p) => p.value).reduce(math.max);
    // Flat series: give it some vertical room so the line sits in the middle.
    final pad = hi == lo ? (hi.abs() * 0.01 + 0.0001) : (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;

    final plot = Rect.fromLTRB(_left, _top, size.width - _right, size.height - _bottom);
    final double spanDays = math.max(1.0, end.difference(start).inHours / 24.0);

    Offset at(RatePoint p) {
      final dx = p.date.difference(start).inHours / 24.0 / spanDays;
      final dy = (p.value - lo) / (hi - lo);
      return Offset(plot.left + dx * plot.width, plot.bottom - dy * plot.height);
    }

    // Horizontal grid with value labels.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = plot.bottom - plot.height * i / gridLines;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final value = lo + (hi - lo) * i / gridLines;
      _text(canvas, formatNumber(value, decimals: 4), Offset(0, y - 7), width: _left - 6, align: TextAlign.right);
    }

    // Date labels: start, middle, end.
    final mid = daysBefore(end, (spanDays / 2).round());
    for (final (day, align) in [(start, TextAlign.left), (mid, TextAlign.center), (end, TextAlign.right)]) {
      final x = plot.left + day.difference(start).inHours / 24.0 / spanDays * plot.width;
      const w = 48.0;
      final left = switch (align) {
        TextAlign.left => x,
        TextAlign.right => x - w,
        _ => x - w / 2,
      };
      _text(canvas, formatDayShort(day), Offset(left, plot.bottom + 6), width: w, align: align);
    }

    final offsets = sorted.map(at).toList();

    // Area under the line.
    if (offsets.length > 1) {
      final area = Path()..moveTo(offsets.first.dx, plot.bottom);
      for (final o in offsets) {
        area.lineTo(o.dx, o.dy);
      }
      area
        ..lineTo(offsets.last.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [line.withValues(alpha: 0.25), line.withValues(alpha: 0.0)],
          ).createShader(plot),
      );

      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final o in offsets.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Points; min and max highlighted.
    final minPoint = sorted.reduce((a, b) => b.value < a.value ? b : a);
    final maxPoint = sorted.reduce((a, b) => b.value > a.value ? b : a);
    for (var i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final color = identical(p, maxPoint) && minPoint.value != maxPoint.value
          ? maxColor
          : identical(p, minPoint) && minPoint.value != maxPoint.value
              ? minColor
              : line;
      final big = color != line;
      canvas.drawCircle(offsets[i], big ? 5 : 3, Paint()..color = color);
      if (big) {
        canvas.drawCircle(offsets[i], 5, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
    }
  }

  void _text(Canvas canvas, String text, Offset offset, {required double width, TextAlign align = TextAlign.left}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle.copyWith(color: label)),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_RateChartPainter old) =>
      old.points != points || old.start != start || old.end != end || old.line != line;
}
