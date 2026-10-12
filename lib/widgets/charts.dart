import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../engine/adapt_alert.dart';
import '../engine/study.dart';
import '../theme/ios_theme.dart';

double _niceStep(double x) {
  if (x <= 0) return 1;
  final p = pow(10, (log(x) / ln10).floor()).toDouble();
  final m = x / p;
  return (m < 1.5 ? 1 : m < 3 ? 2 : m < 7 ? 5 : 10) * p;
}

/// A vital over time, with the person's normal range (±2 SD) shaded,
/// unreliable windows left as gaps, and alerts / held-back alerts marked.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.history, required this.vital, required this.color});
  final List<WindowRecord> history;
  final String vital;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    if (history.length < 2) return const SizedBox(height: 200);
    final dec = vital == 'temp' ? 1 : 0;
    double hiOf(WindowRecord h) => min(vital == 'spo2' ? 100.0 : 1e9, h.mu[vital]! + 2 * h.sd[vital]!);
    double loOf(WindowRecord h) => h.mu[vital]! - 2 * h.sd[vital]!;
    final good = history.where((h) => h.good).toList();
    var lo = good.map((h) => min(h.value(vital), loOf(h))).reduce(min);
    var hi = good.map((h) => max(h.value(vital), hiOf(h))).reduce(max);
    final pad = max((hi - lo) * .08, vital == 'temp' ? .1 : 1.0);
    lo -= pad;
    hi += pad;
    final step = _niceStep((hi - lo) / 4);
    final t0 = history.first.t.toDouble(), t1 = history.last.t.toDouble();

    FlSpot sp(WindowRecord h, double y) => FlSpot(h.t.toDouble(), y);
    final value = LineChartBarData(
      spots: [for (final h in history) h.good ? sp(h, h.value(vital)) : FlSpot.nullSpot],
      color: color,
      barWidth: 2.2,
      isCurved: true,
      curveSmoothness: .15,
      preventCurveOverShooting: true,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (s, _) {
          final h = history.firstWhere((x) => x.t == s.x.round(), orElse: () => history.last);
          return h.alert > 0 || h.held || h == history.last;
        },
        getDotPainter: (s, _, _, _) {
          final h = history.firstWhere((x) => x.t == s.x.round(), orElse: () => history.last);
          if (h.alert > 0) return FlDotCirclePainter(radius: 4, color: c.red, strokeWidth: 1.5, strokeColor: c.card);
          if (h.held) return FlDotCirclePainter(radius: 3.5, color: c.card, strokeWidth: 2, strokeColor: c.indigo);
          return FlDotCirclePainter(radius: 4.5, color: color, strokeWidth: 2, strokeColor: c.card);
        },
      ),
    );
    final upper = LineChartBarData(spots: [for (final h in history) sp(h, hiOf(h))], color: Colors.transparent, barWidth: 0, dotData: const FlDotData(show: false));
    final lower = LineChartBarData(spots: [for (final h in history) sp(h, loOf(h))], color: Colors.transparent, barWidth: 0, dotData: const FlDotData(show: false));

    String hhmmOf(double t) => hhmm(t.round());
    return SizedBox(
      height: 210,
      child: LineChart(
        duration: const Duration(milliseconds: 350),
        LineChartData(
          minX: t0,
          maxX: max(t1, t0 + 30),
          minY: lo,
          maxY: hi,
          clipData: const FlClipData.all(),
          lineBarsData: [upper, lower, value],
          betweenBarsData: [BetweenBarsData(fromIndex: 0, toIndex: 1, color: c.blue.withValues(alpha: .13))],
          rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: [
            for (final h in history)
              if (!h.good) VerticalRangeAnnotation(x1: h.t - .5, x2: h.t + .5, color: c.fill2),
          ]),
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: step, getDrawingHorizontalLine: (_) => FlLine(color: c.sep, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: step,
                getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text(v.toStringAsFixed(dec), style: T.caption.copyWith(color: c.label2, fontFeatures: T.num))),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 30,
                getTitlesWidget: (v, m) => v % 30 == 0 ? SideTitleWidget(meta: m, child: Text(hhmmOf(v), style: T.caption.copyWith(color: c.label2))) : const SizedBox.shrink(),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.card2,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  s.barIndex == 2 ? LineTooltipItem('${s.y.toStringAsFixed(dec)} · ${hhmmOf(s.x)}', T.footnote.copyWith(color: c.label, fontWeight: FontWeight.w600)) : null,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 30-day simulated study: false alarms per patient per day, three systems.
Color systemColor(BuildContext context, String s) {
  final c = context.ios;
  return switch (s) { 'A' => c.gray, 'B' => c.blue, 'C' => c.green, 'D' => c.orange, _ => c.purple };
}

class StudyChart extends StatelessWidget {
  const StudyChart({super.key, required this.result, this.systems = const ['A', 'B', 'C']});
  final StudyResult result;
  final List<String> systems;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final all = [for (final s in systems) ...result.series[s]!];
    final maxY = max(1.0, all.reduce(max).ceilToDouble());
    LineChartBarData line(String k, Color col, double w) => LineChartBarData(
          spots: [for (var i = 0; i < result.days; i++) FlSpot(i + 1.0, result.series[k]![i])],
          color: col,
          barWidth: w,
          isCurved: true,
          curveSmoothness: .2,
          preventCurveOverShooting: true,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true, checkToShowDot: (s, _) => s.x == result.days, getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 4, color: col, strokeWidth: 0)),
          belowBarData: k == 'C' ? BarAreaData(show: true, gradient: LinearGradient(colors: [col.withValues(alpha: .25), col.withValues(alpha: 0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)) : BarAreaData(),
        );
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: result.days.toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [for (final s in systems) line(s, systemColor(context, s), s == 'C' ? 3 : 2)],
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (_) => FlLine(color: c.sep, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.card2,
              getTooltipItems: (spots) => [
                for (final s in spots) LineTooltipItem('${systemNames[systems[s.barIndex]]} ${s.y.toStringAsFixed(2)}', T.caption.copyWith(color: s.bar.color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: 1, getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text(v.toInt().toString(), style: T.caption.copyWith(color: c.label2)))),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, m) => [1, 7, 14, 21, 30].contains(v.toInt()) ? SideTitleWidget(meta: m, child: Text('Day ${v.toInt()}', style: T.caption.copyWith(color: c.label2))) : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alerts per hour today: fixed-threshold alarms vs alerts AdaptAlert sent.
class AlertLoadChart extends StatelessWidget {
  const AlertLoadChart({super.key, required this.history});
  final List<WindowRecord> history;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    final byHour = <int, (int, int)>{};
    final sentEpisodes = <int>{};
    for (final h in history) {
      final hr = (h.t ~/ 60) % 24;
      final cur = byHour[hr] ?? (0, 0);
      var sent = 0;
      if (h.alert > 0 && !sentEpisodes.contains(h.t - 1)) sent = 1;
      if (h.alert > 0) sentEpisodes.add(h.t);
      byHour[hr] = (cur.$1 + (h.fixed ? 1 : 0), cur.$2 + sent);
    }
    final hours = byHour.keys.toList()..sort();
    final maxY = max(2, byHour.values.map((v) => max(v.$1, v.$2)).fold(0, max)).toDouble();
    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (_) => FlLine(color: c.sep, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text(v.toInt().toString(), style: T.caption.copyWith(color: c.label2))))),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text('${hours[v.toInt()]}:00', style: T.caption.copyWith(color: c.label2)))),
            ),
          ),
          barGroups: [
            for (var i = 0; i < hours.length; i++)
              BarChartGroupData(x: i, barsSpace: 3, barRods: [
                BarChartRodData(toY: byHour[hours[i]]!.$1.toDouble(), color: c.gray, width: 9, borderRadius: BorderRadius.circular(3)),
                BarChartRodData(toY: byHour[hours[i]]!.$2.toDouble(), color: c.green, width: 9, borderRadius: BorderRadius.circular(3)),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Sensitivity as patients dismiss more real alerts (alarm fatigue).
class FatigueChart extends StatelessWidget {
  const FatigueChart({super.key, required this.points});
  final List<NoisePoint> points;
  @override
  Widget build(BuildContext context) {
    final c = context.ios;
    LineChartBarData line(double Function(NoisePoint) y, Color col, {bool dashed = false}) => LineChartBarData(
          spots: [for (final p in points) FlSpot(p.noise * 100, y(p) * 100)],
          color: col,
          barWidth: 2.5,
          dashArray: dashed ? [6, 4] : null,
          isStrokeCapRound: true,
          dotData: FlDotData(getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3.5, color: col, strokeWidth: 0)),
        );
    final lo = points.map((p) => min(p.sensC, p.sensD)).reduce(min) * 100;
    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: points.last.noise * 100,
          minY: (lo - 2).floorToDouble().clamp(0, 98),
          maxY: 100.5,
          lineBarsData: [line((p) => p.sensC, c.green), line((p) => p.sensD, c.orange), line((p) => p.critC, c.green, dashed: true), line((p) => p.critD, c.orange, dashed: true)],
          gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: c.sep, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text('${v.round()}%', style: T.caption.copyWith(color: c.label2))))),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: 10, getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text('${v.round()}%', style: T.caption.copyWith(color: c.label2)))),
            ),
          ),
        ),
      ),
    );
  }
}
