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
        _SummaryCard(
          label: 'Spent in $monthName',
          value: _inr(data.monthTotal),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                title: 'Last month',
                value: _inr(data.lastMonthTotal),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(
                title: 'Daily avg',
                value: _inr(data.avgDailyThisMonth),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
        const SizedBox(height: 16),
        _Card(
          title: 'Category wise spend (this month)',
          child: _CategoryBreakdown(
            rows: data.monthCategorySpends.take(6).toList(),
            monthTotal: data.monthTotal,
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Top merchants (this month)',
          child: _TopMerchants(rows: data.topMerchants),
        ),
      ],
    );
  }
}

String _inr(double amount) => '₹${amount.toStringAsFixed(0)}';

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
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
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

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  const _KpiTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final List<CategorySpend> rows;
  final double monthTotal;
  const _CategoryBreakdown({required this.rows, required this.monthTotal});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty || monthTotal <= 0) {
      return const Text('No debit transactions this month.');
    }

    return Column(
      children: rows.map((row) {
        final pct = (row.amount / monthTotal).clamp(0, 1).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _inr(row.amount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AC.accent),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TopMerchants extends StatelessWidget {
  final List<MerchantSpend> rows;
  const _TopMerchants({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No debit transactions this month.');
    final maxAmount = rows.first.amount <= 0 ? 1.0 : rows.first.amount;

    return Column(
      children: rows.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        final pct = (row.amount / maxAmount).clamp(0, 1).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AC.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${i + 1}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.merchant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          _inr(row.amount),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).dividerColor,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AC.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.count} transaction${row.count == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
                  child: Text(
                    labels[v.toInt()],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
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
    final maxVal = monthTotals.fold<double>(0, (m, v) => v > m ? v : m);
    final effectiveMax = maxVal < 1 ? 1000.0 : maxVal * 1.3;
    final currentMonth = DateTime.now().month - 1;

    const labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

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
                final month = DateFormat(
                  'MMM',
                ).format(DateTime(DateTime.now().year, group.x + 1));
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
                  child: Text(
                    labels[v.toInt()],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
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
