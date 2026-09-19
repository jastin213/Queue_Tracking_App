import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'localized_text.dart';

import '../theme/app_theme.dart';
import 'app_motion.dart';

const Color _analyticsAppointmentColor = Color(0xFF8B5CF6);

enum AnalyticsChartType { line, bar }

class AnalyticsLineChart extends StatefulWidget {
  const AnalyticsLineChart({
    super.key,
    required this.labels,
    required this.servedValues,
    required this.appointmentValues,
    required this.walkInValues,
    required this.passedValues,
    required this.failedValues,
    this.chartType = AnalyticsChartType.line,
  });

  final List<String> labels;
  final List<int> servedValues;
  final List<int> appointmentValues;
  final List<int> walkInValues;
  final List<int> passedValues;
  final List<int> failedValues;
  final AnalyticsChartType chartType;

  @override
  State<AnalyticsLineChart> createState() => _AnalyticsLineChartState();
}

class _AnalyticsLineChartState extends State<AnalyticsLineChart> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _positionAtLatestMonth();
  }

  @override
  void didUpdateWidget(covariant AnalyticsLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.labels, widget.labels)) {
      _positionAtLatestMonth();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _positionAtLatestMonth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          "${widget.chartType == AnalyticsChartType.line ? 'Line' : 'Bar'} graph comparing monthly served customers, appointments, walk-ins, passed customers, and failed customers",
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.activeBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.activeBorder),
        ),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 8,
              children: [
                _ChartLegend(color: AppColors.activePrimary, label: "Served"),
                const _ChartLegend(
                  color: _analyticsAppointmentColor,
                  label: "Appointments",
                ),
                const _ChartLegend(color: AppColors.warning, label: "Walk-ins"),
                const _ChartLegend(color: AppColors.success, label: "Passed"),
                _ChartLegend(color: AppColors.danger, label: "Failed"),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 263,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final monthWidth = math.max(120.0, constraints.maxWidth / 6);
                  final contentWidth = math.max(
                    constraints.maxWidth,
                    widget.labels.length * monthWidth,
                  );
                  final canScroll = contentWidth > constraints.maxWidth;

                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: canScroll,
                    trackVisibility: canScroll,
                    interactive: true,
                    thickness: 7,
                    radius: const Radius.circular(8),
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 18),
                      child: SizedBox(
                        width: contentWidth,
                        height: 245,
                        child: AppChartReveal(
                          key: ValueKey(widget.chartType),
                          child: CustomPaint(
                            painter: _AnalyticsLineChartPainter(
                              labels: widget.labels,
                              servedValues: widget.servedValues,
                              appointmentValues: widget.appointmentValues,
                              walkInValues: widget.walkInValues,
                              passedValues: widget.passedValues,
                              failedValues: widget.failedValues,
                              chartType: widget.chartType,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
    required this.walkInValues,
    required this.passedValues,
    required this.failedValues,
    required this.chartType,
  });

  final List<String> labels;
  final List<int> servedValues;
  final List<int> appointmentValues;
  final List<int> walkInValues;
  final List<int> passedValues;
  final List<int> failedValues;
  final AnalyticsChartType chartType;

  static Color get _servedColor => AppColors.activePrimary;
  static const Color _appointmentColor = _analyticsAppointmentColor;
  static const Color _walkInColor = AppColors.warning;
  static const Color _passedColor = AppColors.success;
  static const Color _failedColor = AppColors.danger;
  static Color get _gridColor => AppColors.activeBorder;
  static Color get _labelColor => AppColors.activeMutedText;

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

    final allValues = [
      ...servedValues,
      ...appointmentValues,
      ...walkInValues,
      ...passedValues,
      ...failedValues,
    ];
    final rawMax = allValues.isEmpty ? 0 : allValues.reduce(math.max);
    final maxValue = math.max(10, ((rawMax + 9) ~/ 10) * 10);

    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;

    final gridIntervalCount = maxValue ~/ 10;
    for (int index = 0; index <= gridIntervalCount; index++) {
      final gridValue = index * 10;
      final fraction = gridValue / maxValue;
      final y = chartBottom - (chartHeight * fraction);

      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);

      _paintText(
        canvas,
        gridValue.toString(),
        Offset(0, y - 7),
        const Size(32, 16),
        TextAlign.right,
      );
    }

    if (chartType == AnalyticsChartType.bar) {
      _drawGroupedBars(
        canvas,
        left: left,
        top: top,
        width: chartWidth,
        height: chartHeight,
        maxValue: maxValue,
      );
    } else {
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
      final walkInPoints = _pointsFor(
        values: walkInValues,
        count: labels.length,
        left: left,
        top: top,
        width: chartWidth,
        height: chartHeight,
        maxValue: maxValue,
      );
      final passedPoints = _pointsFor(
        values: passedValues,
        count: labels.length,
        left: left,
        top: top,
        width: chartWidth,
        height: chartHeight,
        maxValue: maxValue,
      );
      final failedPoints = _pointsFor(
        values: failedValues,
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
      _drawSeries(canvas, walkInPoints, _walkInColor);
      _drawSeries(canvas, passedPoints, _passedColor);
      _drawSeries(canvas, failedPoints, _failedColor);
    }

    for (int index = 0; index < labels.length; index++) {
      final x = chartType == AnalyticsChartType.bar
          ? left + (chartWidth * (index + 0.5) / labels.length)
          : labels.length == 1
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

  void _drawGroupedBars(
    Canvas canvas, {
    required double left,
    required double top,
    required double width,
    required double height,
    required int maxValue,
  }) {
    final series = <List<int>>[
      servedValues,
      appointmentValues,
      walkInValues,
      passedValues,
      failedValues,
    ];
    final colors = <Color>[
      _servedColor,
      _appointmentColor,
      _walkInColor,
      _passedColor,
      _failedColor,
    ];
    final groupWidth = width / labels.length;
    final availableWidth = groupWidth * 0.78;
    const gap = 1.5;
    final barWidth = math.min(
      14.0,
      math.max(
        2.0,
        (availableWidth - gap * (series.length - 1)) / series.length,
      ),
    );
    final barsWidth = (barWidth * series.length) + gap * (series.length - 1);
    final chartBottom = top + height;

    for (var monthIndex = 0; monthIndex < labels.length; monthIndex++) {
      final groupCenter = left + (groupWidth * (monthIndex + 0.5));
      final groupLeft = groupCenter - (barsWidth / 2);

      for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
        final values = series[seriesIndex];
        final value = monthIndex < values.length ? values[monthIndex] : 0;
        if (value <= 0) continue;

        final barHeight = height * value / maxValue;
        final rect = Rect.fromLTWH(
          groupLeft + seriesIndex * (barWidth + gap),
          chartBottom - barHeight,
          barWidth,
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = colors[seriesIndex],
        );
      }
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
        style: TextStyle(
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
        oldDelegate.appointmentValues != appointmentValues ||
        oldDelegate.walkInValues != walkInValues ||
        oldDelegate.passedValues != passedValues ||
        oldDelegate.failedValues != failedValues ||
        oldDelegate.chartType != chartType;
  }
}
