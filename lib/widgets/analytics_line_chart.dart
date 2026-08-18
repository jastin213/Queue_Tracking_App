import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnalyticsLineChart extends StatelessWidget {
  const AnalyticsLineChart({
    super.key,
    required this.labels,
    required this.servedValues,
    required this.appointmentValues,
  });

  final List<String> labels;
  final List<int> servedValues;
  final List<int> appointmentValues;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          "Line graph comparing monthly served customers and appointment activity",
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBFD),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD8E8EE)),
        ),
        child: Column(
          children: [
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 8,
              children: [
                _ChartLegend(color: Color(0xFF071F35), label: "Served"),
                _ChartLegend(
                  color: Color(0xFF1E9E6A),
                  label: "Appointments",
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 245,
              child: CustomPaint(
                painter: _AnalyticsLineChartPainter(
                  labels: labels,
                  servedValues: servedValues,
                  appointmentValues: appointmentValues,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF526776),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AnalyticsLineChartPainter extends CustomPainter {
  const _AnalyticsLineChartPainter({
    required this.labels,
    required this.servedValues,
    required this.appointmentValues,
  });

  final List<String> labels;
  final List<int> servedValues;
  final List<int> appointmentValues;

  static const Color _servedColor = Color(0xFF071F35);
  static const Color _appointmentColor = Color(0xFF1E9E6A);
  static const Color _gridColor = Color(0xFFD8E8EE);
  static const Color _labelColor = Color(0xFF6E7E88);

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    const double left = 38;
    const double top = 12;
    const double right = 10;
    const double bottom = 42;

    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);
    final chartBottom = top + chartHeight;

    final allValues = [...servedValues, ...appointmentValues];
    final rawMax = allValues.isEmpty ? 0 : allValues.reduce(math.max);
    final maxValue = math.max(4, rawMax);

    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;

    for (int index = 0; index <= 4; index++) {
      final fraction = index / 4;
      final y = chartBottom - (chartHeight * fraction);

      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);

      _paintText(
        canvas,
        (maxValue * fraction).round().toString(),
        Offset(0, y - 7),
        const Size(32, 16),
        TextAlign.right,
      );
    }

    final servedPoints = _pointsFor(
      values: servedValues,
      count: labels.length,
      left: left,
      top: top,
      width: chartWidth,
      height: chartHeight,
      maxValue: maxValue,
    );
    final appointmentPoints = _pointsFor(
      values: appointmentValues,
      count: labels.length,
      left: left,
      top: top,
      width: chartWidth,
      height: chartHeight,
      maxValue: maxValue,
    );

    if (servedPoints.length > 1) {
      final fillPath = Path()
        ..moveTo(servedPoints.first.dx, chartBottom)
        ..lineTo(servedPoints.first.dx, servedPoints.first.dy);

      for (final point in servedPoints.skip(1)) {
        fillPath.lineTo(point.dx, point.dy);
      }

      fillPath
        ..lineTo(servedPoints.last.dx, chartBottom)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()..color = _servedColor.withValues(alpha: 0.07),
      );
    }

    _drawSeries(canvas, servedPoints, _servedColor);
    _drawSeries(canvas, appointmentPoints, _appointmentColor);

    for (int index = 0; index < labels.length; index++) {
      final x = labels.length == 1
          ? left + (chartWidth / 2)
          : left + (chartWidth * index / (labels.length - 1));

      _paintText(
        canvas,
        labels[index],
        Offset(x - 26, chartBottom + 9),
        const Size(52, 30),
        TextAlign.center,
      );
    }
  }

  List<Offset> _pointsFor({
    required List<int> values,
    required int count,
    required double left,
    required double top,
    required double width,
    required double height,
    required int maxValue,
  }) {
    return List.generate(count, (index) {
      final value = index < values.length ? values[index] : 0;
      final x = count == 1
          ? left + (width / 2)
          : left + (width * index / (count - 1));
      final y = top + height - (height * value / maxValue);
      return Offset(x, y);
    });
  }

  void _drawSeries(Canvas canvas, List<Offset> points, Color color) {
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length == 1) {
      canvas.drawCircle(points.first, 4.5, Paint()..color = color);
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3.5, Paint()..color = color);
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    Size size,
    TextAlign align,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 2,
    )..layout(maxWidth: size.width);

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AnalyticsLineChartPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.servedValues != servedValues ||
        oldDelegate.appointmentValues != appointmentValues;
  }
}
