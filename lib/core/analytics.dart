import 'api.dart';

enum AnalyticsPeriod { day, week, month }

extension AnalyticsPeriodApi on AnalyticsPeriod {
  String get apiValue => switch (this) {
    AnalyticsPeriod.day => 'day',
    AnalyticsPeriod.week => 'week',
    AnalyticsPeriod.month => 'month',
  };

  String get label => switch (this) {
    AnalyticsPeriod.day => 'Day',
    AnalyticsPeriod.week => 'Week',
    AnalyticsPeriod.month => 'Month',
  };

  String get subtitle => switch (this) {
    AnalyticsPeriod.day => 'Compare today with yesterday',
    AnalyticsPeriod.week => 'Compare this week with last week',
    AnalyticsPeriod.month => 'Compare this month with the same period last month',
  };
}

/// Mirrors web `AnalyticsDashboard` from `/analytics/dashboard`.
class AnalyticsDashboard {
  final AnalyticsPeriod period;
  final AnalyticsSummary summary;
  final PeriodComparison comparison;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<InstrumentBreakdown> instrumentBreakdown;
  final List<MerchantBreakdown> topMerchants;
  final List<WeeklySpending> dailySpending;
  final String highestSpendCategory;

  const AnalyticsDashboard({
    required this.period,
    required this.summary,
    required this.comparison,
    required this.categoryBreakdown,
    required this.instrumentBreakdown,
    required this.topMerchants,
    required this.dailySpending,
    required this.highestSpendCategory,
  });

  factory AnalyticsDashboard.fromJson(Map<String, dynamic> j) {
    final summary = j['summary'] as Map<String, dynamic>? ?? {};
    final comparison = j['comparison'] as Map<String, dynamic>? ?? {};
    final periodStr = j['period'] as String? ?? summary['period'] as String? ?? 'month';
    return AnalyticsDashboard(
      period: switch (periodStr) {
        'day' => AnalyticsPeriod.day,
        'week' => AnalyticsPeriod.week,
        _ => AnalyticsPeriod.month,
      },
      summary: AnalyticsSummary.fromJson(summary),
      comparison: PeriodComparison.fromJson(comparison),
      categoryBreakdown: (j['categoryBreakdown'] as List<dynamic>? ?? [])
          .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      instrumentBreakdown: (j['instrumentBreakdown'] as List<dynamic>? ?? [])
          .map((e) => InstrumentBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      topMerchants: (j['topMerchants'] as List<dynamic>? ?? [])
          .map((e) => MerchantBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailySpending: (j['dailySpending'] as List<dynamic>? ??
              j['weeklySpending'] as List<dynamic>? ??
              [])
          .map((e) => WeeklySpending.fromJson(e as Map<String, dynamic>))
          .toList(),
      highestSpendCategory: j['highestSpendCategory'] as String? ?? '—',
    );
  }
}

class AnalyticsSummary {
  final AnalyticsPeriod period;
  final double currentSpend;
  final double previousSpend;
  final double changePercent;
  final bool isSpendingUp;
  final String currentLabel;
  final String previousLabel;
  final double avgDailySpend;

  const AnalyticsSummary({
    required this.period,
    required this.currentSpend,
    required this.previousSpend,
    required this.changePercent,
    required this.isSpendingUp,
    required this.currentLabel,
    required this.previousLabel,
    required this.avgDailySpend,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) {
    final periodStr = j['period'] as String? ?? 'month';
    return AnalyticsSummary(
      period: switch (periodStr) {
        'day' => AnalyticsPeriod.day,
        'week' => AnalyticsPeriod.week,
        _ => AnalyticsPeriod.month,
      },
      currentSpend: (j['currentSpend'] as num?)?.toDouble() ?? 0,
      previousSpend: (j['previousSpend'] as num?)?.toDouble() ?? 0,
      changePercent: (j['changePercent'] as num?)?.toDouble() ?? 0,
      isSpendingUp: j['isSpendingUp'] == true,
      currentLabel: j['currentLabel'] as String? ?? 'Current',
      previousLabel: j['previousLabel'] as String? ?? 'Previous',
      avgDailySpend: (j['avgDailySpend'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PeriodComparison {
  final String currentLabel;
  final double currentSpend;
  final String previousLabel;
  final double previousSpend;

  const PeriodComparison({
    required this.currentLabel,
    required this.currentSpend,
    required this.previousLabel,
    required this.previousSpend,
  });

  factory PeriodComparison.fromJson(Map<String, dynamic> j) {
    final current = j['current'] as Map<String, dynamic>? ?? {};
    final previous = j['previous'] as Map<String, dynamic>? ?? {};
    return PeriodComparison(
      currentLabel: current['label'] as String? ?? 'Current',
      currentSpend: (current['spend'] as num?)?.toDouble() ?? 0,
      previousLabel: previous['label'] as String? ?? 'Previous',
      previousSpend: (previous['spend'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CategoryBreakdown {
  final String categoryId;
  final String categoryName;
  final double total;
  final int count;
  final double percentage;

  const CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.total,
    required this.count,
    required this.percentage,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> j) =>
      CategoryBreakdown(
        categoryId: j['categoryId'] as String? ?? '',
        categoryName: j['categoryName'] as String? ?? 'Uncategorized',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0,
      );
}

class InstrumentBreakdown {
  final String? paymentInstrumentId;
  final String paymentInstrumentName;
  final double total;
  final int count;
  final double percentage;

  const InstrumentBreakdown({
    required this.paymentInstrumentId,
    required this.paymentInstrumentName,
    required this.total,
    required this.count,
    required this.percentage,
  });

  factory InstrumentBreakdown.fromJson(Map<String, dynamic> j) =>
      InstrumentBreakdown(
        paymentInstrumentId: j['paymentInstrumentId'] as String?,
        paymentInstrumentName: j['paymentInstrumentName'] as String? ?? 'Unassigned',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0,
      );
}

class MerchantBreakdown {
  final String merchant;
  final double total;
  final int count;

  const MerchantBreakdown({
    required this.merchant,
    required this.total,
    required this.count,
  });

  factory MerchantBreakdown.fromJson(Map<String, dynamic> j) =>
      MerchantBreakdown(
        merchant: j['merchant'] as String? ?? 'Unknown',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class WeeklySpending {
  final DateTime date;
  final double total;
  final int count;

  const WeeklySpending({
    required this.date,
    required this.total,
    required this.count,
  });

  factory WeeklySpending.fromJson(Map<String, dynamic> j) => WeeklySpending(
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    total: (j['total'] as num?)?.toDouble() ?? 0,
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

class MonthlyTrend {
  final int year;
  final int month;
  final String monthLabel;
  final double totalSpent;
  final double totalIncome;
  final int transactionCount;

  const MonthlyTrend({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.totalSpent,
    required this.totalIncome,
    required this.transactionCount,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> j) => MonthlyTrend(
    year: (j['year'] as num?)?.toInt() ?? 0,
    month: (j['month'] as num?)?.toInt() ?? 0,
    monthLabel: j['monthLabel'] as String? ?? '',
    totalSpent: (j['totalSpent'] as num?)?.toDouble() ?? 0,
    totalIncome: (j['totalIncome'] as num?)?.toDouble() ?? 0,
    transactionCount: (j['transactionCount'] as num?)?.toInt() ?? 0,
  );
}

Future<AnalyticsDashboard> fetchAnalyticsDashboard(
  ApiClient api, {
  AnalyticsPeriod period = AnalyticsPeriod.month,
}) async {
  final data = await api.get(
    '/analytics/dashboard',
    query: {'period': period.apiValue},
  ) as Map<String, dynamic>;
  return AnalyticsDashboard.fromJson(data);
}

Future<List<MonthlyTrend>> fetchAnalyticsTrends(
  ApiClient api, {
  int months = 6,
}) async {
  final data =
      await api.get('/analytics/trends', query: {'months': '$months'})
          as List<dynamic>;
  return data
      .map((e) => MonthlyTrend.fromJson(e as Map<String, dynamic>))
      .toList();
}

String formatInr(double amount) => '₹${amount.toStringAsFixed(0)}';
