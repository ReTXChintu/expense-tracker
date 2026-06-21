import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/analytics.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_box.dart';

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
    final period = ref.watch(analyticsPeriodProvider);

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
        loading: () => const DashboardShimmer(),
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
          period: period,
          onPeriodChanged: (p) {
            ref.read(analyticsPeriodProvider.notifier).state = p;
            ref.invalidate(analyticsDashboardProvider);
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AnalyticsDashboard data;
  final AsyncValue<List<MonthlyTrend>> trends;
  final AsyncValue<List<Category>> categories;
  final AnalyticsPeriod period;
  final ValueChanged<AnalyticsPeriod> onPeriodChanged;

  const _Body({
    required this.data,
    required this.trends,
    required this.categories,
    required this.period,
    required this.onPeriodChanged,
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
          period.subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SegmentedButton<AnalyticsPeriod>(
          segments: AnalyticsPeriod.values
              .map(
                (p) => ButtonSegment(value: p, label: Text(p.label)),
              )
              .toList(),
          selected: {period},
          onSelectionChanged: (s) => onPeriodChanged(s.first),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          child: _HeroBanner(
            key: ValueKey('hero_${period.name}_${s.currentSpend}'),
            summary: s,
            comparison: data.comparison,
            topCategory: data.highestSpendCategory,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: GridView.count(
            key: ValueKey('stats_${period.name}'),
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _StatCard(
                label: s.currentLabel,
                value: formatInr(s.currentSpend),
                icon: Icons.trending_up,
                trend: '${s.changePercent.abs().toStringAsFixed(0)}%',
                trendUp: s.isSpendingUp,
                index: 0,
              ),
              _StatCard(
                label: s.previousLabel,
                value: formatInr(s.previousSpend),
                icon: Icons.shopping_bag_outlined,
                hint: 'Previous period',
                index: 1,
              ),
              _StatCard(
                label: 'Daily average',
                value: formatInr(s.avgDailySpend),
                icon: Icons.pie_chart_outline,
                hint: 'Selected ${period.label.toLowerCase()}',
                index: 2,
              ),
              _StatCard(
                label: 'Change',
                value: '${s.isSpendingUp ? '+' : '-'}${s.changePercent.abs().toStringAsFixed(0)}%',
                icon: Icons.bolt_outlined,
                hint: '${s.previousLabel} → ${s.currentLabel}',
                index: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Period comparison',
          subtitle: '${s.currentLabel} vs ${s.previousLabel}',
          child: _ComparisonChart(comparison: data.comparison),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Spending trend',
          subtitle: 'Last 6 months — debits vs credits',
          child: trends.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: ShimmerBox(height: 180, borderRadius: AppRadius.card)),
            ),
            error: (_, __) => const EmptyState(
              icon: Icons.show_chart,
              title: 'Could not load trends',
            ),
            data: (t) => _TrendChart(trends: t)
                .animate()
                .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                .slideY(begin: 0.04, duration: 400.ms),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'By category',
          subtitle: 'Share of spending · ${s.currentLabel}',
          child: _CategorySection(
            breakdown: data.categoryBreakdown,
            categoryById: _cat,
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'By card / account',
          subtitle: 'Net spend by payment instrument',
          child: _InstrumentSection(breakdown: data.instrumentBreakdown),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Spending rhythm',
          subtitle: 'Daily breakdown · ${s.currentLabel}',
          child: _WeekChart(weekly: data.dailySpending, period: period),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Top merchants',
          subtitle: 'Highest spend · ${s.currentLabel}',
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
  final AnalyticsSummary summary;
  final PeriodComparison comparison;
  final String topCategory;

  const _HeroBanner({
    super.key,
    required this.summary,
    required this.comparison,
    required this.topCategory,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget banner = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4361EE), Color(0xFF5B7AFF), Color(0xFF738EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.elevated(
          Theme.of(context).brightness == Brightness.dark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.currentLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatInr(summary.currentSpend),
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
                      '${summary.changePercent.abs().toStringAsFixed(0)}% vs ${summary.previousLabel.toLowerCase()}',
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
              Text(
                summary.previousLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                formatInr(summary.previousSpend),
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

    if (disableAnimations) return banner;

    return banner
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
        .slideY(begin: -0.04, duration: 400.ms, curve: Curves.easeOutCubic);
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
  final int index;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.trend,
    this.trendUp,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
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

    if (MediaQuery.disableAnimationsOf(context)) return card;

    return card
        .animate()
        .fadeIn(duration: 350.ms, delay: Duration(milliseconds: index * 40))
        .slideY(begin: 0.06, duration: 350.ms, delay: Duration(milliseconds: index * 40));
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
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, duration: 400.ms);
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
      return const EmptyState(
        icon: Icons.category_outlined,
        title: 'No categorized spending yet',
      );
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

class _InstrumentSection extends StatelessWidget {
  final List<InstrumentBreakdown> breakdown;
  const _InstrumentSection({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const EmptyState(
        icon: Icons.credit_card_outlined,
        title: 'No instrument-tagged spending yet',
      );
    }
    return Column(
      children: breakdown.take(6).toList().asMap().entries.map((entry) {
        final row = entry.value;
        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.paymentInstrumentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(formatInr(row.total)),
                  const SizedBox(width: 8),
                  Text('${row.percentage.toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (row.percentage / 100).clamp(0, 1)),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).dividerColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 350.ms, delay: Duration(milliseconds: entry.key * 40));
      }).toList(),
    );
  }
}

// ─── Period comparison chart ─────────────────────────────────────────────────

class _ComparisonChart extends StatelessWidget {
  final PeriodComparison comparison;
  const _ComparisonChart({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final values = [comparison.currentSpend, comparison.previousSpend];
    final maxVal = values.fold<double>(0, (m, v) => v > m ? v : m);
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
                reservedSize: 36,
                getTitlesWidget: (v, _) {
                  final label = v.toInt() == 0
                      ? comparison.currentLabel
                      : comparison.previousLabel;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
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
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: comparison.currentSpend,
                  color: AC.accent,
                  width: 40,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: comparison.previousSpend,
                  color: AC.accent.withValues(alpha: 0.45),
                  width: 40,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Weekly bar chart ────────────────────────────────────────────────────────

class _WeekChart extends StatelessWidget {
  final List<WeeklySpending> weekly;
  final AnalyticsPeriod period;
  const _WeekChart({required this.weekly, required this.period});

  @override
  Widget build(BuildContext context) {
    if (weekly.isEmpty) {
      return const Text('No spending in this period');
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
                      period == AnalyticsPeriod.month
                          ? DateFormat('d').format(weekly[i].date)
                          : DateFormat('E').format(weekly[i].date).substring(0, 2),
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
