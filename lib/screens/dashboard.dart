import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/analytics.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

const _pieColors = [
  Color(0xFF4361EE),
  Color(0xFF7C3AED),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF06B6D4),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(analyticsDashboardProvider);
    ref.invalidate(analyticsTrendsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(analyticsDashboardProvider);
    final trends = ref.watch(analyticsTrendsProvider);
    final categories = ref.watch(categoriesProvider);
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics', style: Theme.of(context).textTheme.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load analytics',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('$e', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _refresh(ref),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (d) => _Body(
          data: d,
          trends: trends,
          categories: categories,
          monthName: monthName,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AnalyticsDashboard data;
  final AsyncValue<List<MonthlyTrend>> trends;
  final AsyncValue<List<Category>> categories;
  final String monthName;

  const _Body({
    required this.data,
    required this.trends,
    required this.categories,
    required this.monthName,
  });

  Category? _cat(String id) {
    return categories.valueOrNull?.where((c) => c.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final s = data.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          'Spending intelligence for $monthName — trends, categories, and where your money goes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _HeroBanner(
          monthName: monthName,
          summary: s,
          topCategory: data.highestSpendCategory,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _StatCard(
              label: 'Monthly spend',
              value: formatInr(s.thisMonthSpend),
              icon: Icons.trending_up,
              trend: '${s.monthlyChangePercent.abs().toStringAsFixed(0)}%',
              trendUp: s.isSpendingUp,
            ),
            _StatCard(
              label: 'This week',
              value: formatInr(s.thisWeekSpend),
              icon: Icons.bolt_outlined,
              hint: 'Last 7 days of debits',
            ),
            _StatCard(
              label: 'Daily average',
              value: formatInr(s.avgDailySpend),
              icon: Icons.pie_chart_outline,
              hint: 'Based on days elapsed',
            ),
            _StatCard(
              label: 'Last month',
              value: formatInr(s.lastMonthSpend),
              icon: Icons.shopping_bag_outlined,
              hint: 'Previous calendar month',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Spending trend',
          subtitle: 'Last 6 months — debits vs credits',
          child: trends.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const Text('Could not load trends'),
            data: (t) => _TrendChart(trends: t),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'By category',
          subtitle: 'Share of spending this month',
          child: _CategorySection(
            breakdown: data.categoryBreakdown,
            categoryById: _cat,
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Weekly rhythm',
          subtitle: 'Daily spend in the current week',
          child: _WeekChart(weekly: data.weeklySpending),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Top merchants',
          subtitle: 'Where you spend the most this month',
          child: _TopMerchants(rows: data.topMerchants),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

// ─── Hero banner ─────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String monthName;
  final AnalyticsSummary summary;
  final String topCategory;

  const _HeroBanner({
    required this.monthName,
    required this.summary,
    required this.topCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF5B7AFF), Color(0xFF738EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AC.accent.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total spent · $monthName',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatInr(summary.thisMonthSpend),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      summary.isSpendingUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${summary.monthlyChangePercent.abs().toStringAsFixed(0)}% vs last month',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Top: $topCategory',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'This week',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                formatInr(summary.thisWeekSpend),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stat card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? hint;
  final String? trend;
  final bool? trendUp;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.trend,
    this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AC.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AC.accent),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: Theme.of(context).textTheme.labelSmall),
          ],
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(
              '${trendUp == true ? '↑' : '↓'} $trend vs last month',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: trendUp == true ? AC.debit : AC.credit,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Panel ───────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Panel({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Trend area chart ────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<MonthlyTrend> trends;
  const _TrendChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return const Text('No trend data yet');
    }

    final maxY = trends.fold<double>(0, (m, t) {
      final hi = t.totalSpent > t.totalIncome ? t.totalSpent : t.totalIncome;
      return hi > m ? hi : m;
    });
    final effectiveMax = maxY < 1 ? 1000.0 : maxY * 1.2;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: effectiveMax,
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
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= trends.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      trends[i].monthLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
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
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).cardTheme.color ?? Colors.white,
              getTooltipItems: (spots) => spots.map((s) {
                final label = s.barIndex == 0 ? 'Spent' : 'Income';
                return LineTooltipItem(
                  '$label\n${formatInr(s.y)}',
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                trends.length,
                (i) => FlSpot(i.toDouble(), trends[i].totalSpent),
              ),
              isCurved: true,
              color: AC.accent,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AC.accent.withValues(alpha: 0.2),
              ),
            ),
            LineChartBarData(
              spots: List.generate(
                trends.length,
                (i) => FlSpot(i.toDouble(), trends[i].totalIncome),
              ),
              isCurved: true,
              color: AC.credit,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category pie + list ─────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final List<CategoryBreakdown> breakdown;
  final Category? Function(String id) categoryById;

  const _CategorySection({required this.breakdown, required this.categoryById});

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const Text('No categorized spending yet');
    }

    final sections = breakdown.asMap().entries.map((e) {
      final cat = categoryById(e.value.categoryId);
      final color = cat?.color ?? _pieColors[e.key % _pieColors.length];
      return PieChartSectionData(
        value: e.value.total,
        color: color,
        radius: 42,
        title: '',
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...breakdown.take(6).map((row) {
          final cat = categoryById(row.categoryId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    if (cat != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(cat.icon, size: 16, color: cat.color),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        row.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${row.percentage.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (row.percentage / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: Theme.of(context).dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      cat?.color ?? AC.accent,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Weekly bar chart ────────────────────────────────────────────────────────

class _WeekChart extends StatelessWidget {
  final List<WeeklySpending> weekly;
  const _WeekChart({required this.weekly});

  @override
  Widget build(BuildContext context) {
    if (weekly.isEmpty) {
      return const Text('No spending this week');
    }

    final maxVal = weekly.fold<double>(0, (m, w) => w.total > m ? w.total : m);
    final effectiveMax = maxVal < 1 ? 100.0 : maxVal * 1.3;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: effectiveMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).cardTheme.color ?? Colors.white,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                formatInr(rod.toY),
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= weekly.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('E').format(weekly[i].date).substring(0, 2),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
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
          barGroups: List.generate(weekly.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weekly[i].total,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  color: AC.accent,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─── Top merchants ───────────────────────────────────────────────────────────

class _TopMerchants extends StatelessWidget {
  final List<MerchantBreakdown> rows;
  const _TopMerchants({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No transactions this month');

    final maxAmount = rows.first.total <= 0 ? 1.0 : rows.first.total;

    return Column(
      children: rows.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        final pct = (row.total / maxAmount).clamp(0, 1).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AC.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AC.accent,
                  ),
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
                          formatInr(row.total),
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
