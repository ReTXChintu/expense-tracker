import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models.dart';
import '../theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Stats', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => _Body(data: d),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final DashboardData data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Monthly total card
        _SummaryCard(
          label: 'Spent in $monthName',
          value: '₹${data.monthTotal.toStringAsFixed(0)}',
        ),
        const SizedBox(height: 20),

        // This week
        _Card(
          title: 'This Week',
          child: _WeekChart(weekTotals: data.weekTotals),
        ),
        const SizedBox(height: 16),

        // This year
        _Card(
          title: 'This Year',
          child: _YearChart(monthTotals: data.monthTotals),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF738EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Week chart (7 bars, Mon–Sun) ─────────────────────────────────────────────

class _WeekChart extends StatelessWidget {
  final List<double> weekTotals;
  const _WeekChart({required this.weekTotals});

  @override
  Widget build(BuildContext context) {
    final maxVal = weekTotals.fold<double>(0, (m, v) => v > m ? v : m);
    final effectiveMax = maxVal < 1 ? 100.0 : maxVal * 1.3;

    final now = DateTime.now();
    final labels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateFormat('E').format(d).substring(0, 2);
    });

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: effectiveMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).cardTheme.color ?? Colors.white,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '₹${rod.toY.toStringAsFixed(0)}',
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[v.toInt()],
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: effectiveMax / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).dividerColor,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            final isToday = i == 6;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weekTotals[i],
                  width: 24,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                  color: isToday
                      ? AC.accent
                      : AC.accent.withValues(alpha: 0.35),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─── Year chart (12 bars, Jan–Dec) ────────────────────────────────────────────

class _YearChart extends StatelessWidget {
  final List<double> monthTotals;
  const _YearChart({required this.monthTotals});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        monthTotals.fold<double>(0, (m, v) => v > m ? v : m);
    final effectiveMax = maxVal < 1 ? 1000.0 : maxVal * 1.3;
    final currentMonth = DateTime.now().month - 1;

    const labels = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
    ];

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: effectiveMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).cardTheme.color ?? Colors.white,
              getTooltipItem: (group, _, rod, __) {
                final month = DateFormat('MMM').format(
                    DateTime(DateTime.now().year, group.x + 1));
                return BarTooltipItem(
                  '$month\n₹${rod.toY.toStringAsFixed(0)}',
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[v.toInt()],
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: effectiveMax / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).dividerColor,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(12, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: monthTotals[i],
                  width: 16,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(5)),
                  color: i == currentMonth
                      ? AC.accent
                      : AC.accent.withValues(alpha: 0.35),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
