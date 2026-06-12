import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

/// Which trend series the line chart is showing.
enum TrendMetric { sessions, students, minutes }

String compactInt(num value) {
  final v = value.round();
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
  return v.toString();
}

TextStyle _numStyle(double size, Color color) => GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

/// A consistent surface for every dashboard module.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.espresso.withValues(alpha: 0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title!,
                        style: GoogleFonts.fraunces(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warmBlack,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppColors.mocha,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          if (title != null) const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// A single KPI stat with an optional period-over-period delta.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.deltaPct,
    this.higherIsBetter = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  /// Signed percent change vs the prior period (e.g. 12.5 = +12.5%). Null hides.
  final double? deltaPct;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: AppColors.forestDark),
              ),
              const Spacer(),
              if (deltaPct != null) _DeltaChip(deltaPct!, higherIsBetter),
            ],
          ),
          const SizedBox(height: 18),
          Text(value, style: _numStyle(30, AppColors.warmBlack)),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.espresso,
            ),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                caption!,
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.mocha),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip(this.deltaPct, this.higherIsBetter);
  final double deltaPct;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final bool flat = deltaPct.abs() < 0.5;
    final bool up = deltaPct >= 0;
    final bool good = flat ? true : (up == higherIsBetter);
    final Color color = flat
        ? AppColors.mocha
        : (good ? AppColors.forest : const Color(0xFFB3261E));
    final IconData icon = flat
        ? Icons.remove_rounded
        : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 2),
          Text(
            '${deltaPct.abs().toStringAsFixed(flat ? 0 : 1)}%',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Line chart of a single trend series over time.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.trend, required this.metric});

  final List<TrendPoint> trend;
  final TrendMetric metric;

  double _value(TrendPoint p) => switch (metric) {
        TrendMetric.sessions => p.sessions.toDouble(),
        TrendMetric.students => p.uniqueStudents.toDouble(),
        TrendMetric.minutes => p.focusMinutes.toDouble(),
      };

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return const _EmptyChart(message: 'No visits in this period yet.');
    }
    final spots = <FlSpot>[
      for (int i = 0; i < trend.length; i++) FlSpot(i.toDouble(), _value(trend[i])),
    ];
    final double maxY = spots.map((e) => e.y).fold<double>(0, (a, b) => a > b ? a : b);
    final double top = maxY <= 0 ? 4 : maxY * 1.25;
    final int labelEvery = (trend.length / 4).ceil().clamp(1, trend.length);

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          minY: 0,
          maxY: top,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.espresso.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: top / 4,
                getTitlesWidget: (value, meta) => Text(
                  compactInt(value),
                  style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.mocha),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= trend.length || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  final d = trend[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${d.month}/${d.day}',
                      style:
                          GoogleFonts.inter(fontSize: 10.5, color: AppColors.mocha),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.espresso,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        compactInt(s.y),
                        GoogleFonts.inter(
                          color: AppColors.cream,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.32,
              color: AppColors.forest,
              barWidth: 2.6,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.forest.withValues(alpha: 0.22),
                    AppColors.forest.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekday x hour grid; cell darkness scales with session volume.
class PeakHoursHeatmap extends StatelessWidget {
  const PeakHoursHeatmap({super.key, required this.cells});

  final List<HourCell> cells;

  static const _days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final grid = <String, int>{}; // 'weekday-hour' -> sessions
    int maxSessions = 0;
    for (final c in cells) {
      grid['${c.weekday}-${c.hour}'] = c.sessions;
      if (c.sessions > maxSessions) maxSessions = c.sessions;
    }
    if (maxSessions == 0) {
      return const _EmptyChart(message: 'Not enough visits to chart peak hours.');
    }

    Widget cell(int weekday, int hour) {
      final s = grid['$weekday-$hour'] ?? 0;
      final t = s / maxSessions;
      return Container(
        width: 15,
        height: 15,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: s == 0
              ? AppColors.espresso.withValues(alpha: 0.04)
              : AppColors.forest.withValues(alpha: 0.18 + 0.82 * t),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int wd = 1; wd <= 7; wd++)
            Row(
              children: <Widget>[
                SizedBox(
                  width: 30,
                  child: Text(
                    _days[wd - 1],
                    style:
                        GoogleFonts.inter(fontSize: 10.5, color: AppColors.mocha),
                  ),
                ),
                for (int h = 0; h < 24; h++) cell(wd, h),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 6),
            child: Row(
              children: <Widget>[
                for (int h = 0; h < 24; h += 6)
                  SizedBox(
                    width: 18 * 6.0,
                    child: Text(
                      '${h.toString().padLeft(2, '0')}:00',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.mocha),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar list for a demographic breakdown.
class BreakdownList extends StatelessWidget {
  const BreakdownList({super.key, required this.items, this.privacyThreshold = 3});

  final List<BreakdownItem> items;
  final int privacyThreshold;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _PrivacyNote(threshold: privacyThreshold);
    }
    final double maxPct =
        items.map((e) => e.percentage).fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.warmBlack,
                        ),
                      ),
                    ),
                    Text(
                      '${item.percentage.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.espresso,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxPct <= 0 ? 0 : (item.percentage / maxPct),
                    minHeight: 8,
                    backgroundColor: AppColors.espresso.withValues(alpha: 0.06),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.forest),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.threshold});
  final int threshold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.latte.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.mocha),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hidden to protect privacy — groups smaller than $threshold students aren\'t shown.',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.mocha),
            ),
          ),
        ],
      ),
    );
  }
}

/// One reward/deal with its progress stats.
class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.deal});
  final DealPerformance deal;

  @override
  Widget build(BuildContext context) {
    final double conversion =
        deal.studentsStarted == 0 ? 0 : deal.studentsUnlocked / deal.studentsStarted;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.espresso.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  deal.title,
                  style: GoogleFonts.fraunces(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warmBlack,
                  ),
                ),
              ),
              _StatusDot(active: deal.isActive),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${deal.requiredHours.toStringAsFixed(deal.requiredHours % 1 == 0 ? 0 : 1)} h to unlock',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mocha),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _MiniStat(value: compactInt(deal.studentsStarted), label: 'Started'),
              const SizedBox(width: 22),
              _MiniStat(
                  value: compactInt(deal.studentsUnlocked), label: 'Unlocked'),
              const SizedBox(width: 22),
              _MiniStat(
                value: '${(conversion * 100).toStringAsFixed(0)}%',
                label: 'Conversion',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(value, style: _numStyle(20, AppColors.espresso)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.mocha)),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.forest : AppColors.mocha;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Paused',
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// An auto-generated insight callout.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});
  final DashboardInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.forest.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: AppColors.forest, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: AppColors.forestDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warmBlack,
                  ),
                ),
              ),
            ],
          ),
          if (insight.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                insight.body,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.5, color: AppColors.mocha),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.bar_chart_rounded,
                size: 28, color: AppColors.mocha.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.mocha),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple skeleton block for loading states.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 120, this.width});
  final double height;
  final double? width;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.espresso.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
