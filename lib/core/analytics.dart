import 'api.dart';

/// Mirrors web `AnalyticsDashboard` from `/analytics/dashboard`.
class AnalyticsDashboard {
  final AnalyticsSummary summary;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<MerchantBreakdown> topMerchants;
  final List<WeeklySpending> weeklySpending;
  final String highestSpendCategory;

  const AnalyticsDashboard({
    required this.summary,
    required this.categoryBreakdown,
    required this.topMerchants,
    required this.weeklySpending,
    required this.highestSpendCategory,
  });

  factory AnalyticsDashboard.fromJson(Map<String, dynamic> j) {
    final summary = j['summary'] as Map<String, dynamic>? ?? {};
    return AnalyticsDashboard(
      summary: AnalyticsSummary.fromJson(summary),
      categoryBreakdown: (j['categoryBreakdown'] as List<dynamic>? ?? [])
          .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      topMerchants: (j['topMerchants'] as List<dynamic>? ?? [])
          .map((e) => MerchantBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      weeklySpending: (j['weeklySpending'] as List<dynamic>? ?? [])
          .map((e) => WeeklySpending.fromJson(e as Map<String, dynamic>))
          .toList(),
      highestSpendCategory: j['highestSpendCategory'] as String? ?? '—',
    );
  }
}

class AnalyticsSummary {
  final double thisMonthSpend;
  final double lastMonthSpend;
  final double thisWeekSpend;
  final double avgDailySpend;
  final double monthlyChangePercent;
  final bool isSpendingUp;

  const AnalyticsSummary({
    required this.thisMonthSpend,
    required this.lastMonthSpend,
    required this.thisWeekSpend,
    required this.avgDailySpend,
    required this.monthlyChangePercent,
    required this.isSpendingUp,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) => AnalyticsSummary(
    thisMonthSpend: (j['thisMonthSpend'] as num?)?.toDouble() ?? 0,
    lastMonthSpend: (j['lastMonthSpend'] as num?)?.toDouble() ?? 0,
    thisWeekSpend: (j['thisWeekSpend'] as num?)?.toDouble() ?? 0,
    avgDailySpend: (j['avgDailySpend'] as num?)?.toDouble() ?? 0,
    monthlyChangePercent: (j['monthlyChangePercent'] as num?)?.toDouble() ?? 0,
    isSpendingUp: j['isSpendingUp'] == true,
  );
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

Future<AnalyticsDashboard> fetchAnalyticsDashboard(ApiClient api) async {
  final data = await api.get('/analytics/dashboard') as Map<String, dynamic>;
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
