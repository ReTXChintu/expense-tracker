import 'package:flutter/material.dart';

// ─── User ────────────────────────────────────────────────────────────────────

class User {
  final String id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['_id'] ?? j['id'] ?? '',
        name: j['name'] ?? '',
        email: j['email'] ?? '',
      );
}

// ─── Category ────────────────────────────────────────────────────────────────

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['_id'] ?? j['id'] ?? '',
        name: j['name'] ?? '',
        icon: _icon(j['icon'] ?? ''),
        color: _color(j['color'] ?? '#6366F1'),
      );

  static IconData _icon(String name) => switch (name.toLowerCase()) {
        'restaurant' || 'fastfood' || 'food_bank' => Icons.restaurant,
        'directions_car' || 'commute' || 'local_taxi' => Icons.directions_car,
        'shopping_bag' || 'shopping_cart' || 'local_mall' => Icons.shopping_bag,
        'health_and_safety' || 'local_hospital' || 'medication' => Icons.health_and_safety,
        'movie' || 'sports_esports' || 'music_note' => Icons.movie,
        'home' || 'house' || 'apartment' => Icons.home,
        'school' || 'book' || 'menu_book' => Icons.school,
        'bolt' || 'water_drop' || 'wifi' => Icons.bolt,
        'flight' || 'hotel' || 'travel_explore' => Icons.flight,
        'more_horiz' || 'category' => Icons.category,
        _ => Icons.category,
      };

  static Color _color(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}

// ─── Transaction ─────────────────────────────────────────────────────────────

enum TxSource { sms, gmail, manual }

class Transaction {
  final String? id;
  final String merchant;
  final double amount;
  final bool isDebit;
  final DateTime date;
  final String? categoryId;
  final Category? category;
  final TxSource source;
  final String? rawText;

  const Transaction({
    this.id,
    required this.merchant,
    required this.amount,
    required this.isDebit,
    required this.date,
    this.categoryId,
    this.category,
    required this.source,
    this.rawText,
  });

  bool get isSaved => id != null;
  bool get isCategorized => categoryId != null;

  Transaction withCategory(String catId) => Transaction(
        id: id,
        merchant: merchant,
        amount: amount,
        isDebit: isDebit,
        date: date,
        categoryId: catId,
        category: category,
        source: source,
        rawText: rawText,
      );

  Transaction withId(String newId) => Transaction(
        id: newId,
        merchant: merchant,
        amount: amount,
        isDebit: isDebit,
        date: date,
        categoryId: categoryId,
        category: category,
        source: source,
        rawText: rawText,
      );

  factory Transaction.fromJson(Map<String, dynamic> j) {
    final cat = j['category'];
    return Transaction(
      id: j['_id'] ?? j['id'] ?? '',
      merchant: j['merchant'] ?? j['title'] ?? 'Unknown',
      amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
      isDebit: (j['type'] ?? 'debit') == 'debit',
      date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
      categoryId: cat is Map ? cat['_id'] ?? cat['id'] : j['categoryId'],
      category: cat is Map ? Category.fromJson(cat as Map<String, dynamic>) : null,
      source: switch (j['source']) {
        'sms' => TxSource.sms,
        'gmail' => TxSource.gmail,
        _ => TxSource.manual,
      },
      rawText: j['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'merchant': merchant,
        'amount': amount,
        'type': isDebit ? 'debit' : 'credit',
        // Always UTC+Z — some validators reject dates without a timezone
        'date': DateTime.fromMillisecondsSinceEpoch(
                date.millisecondsSinceEpoch, isUtc: true)
            .toIso8601String(),
        'source': source.name,
        if (categoryId != null) 'categoryId': categoryId,
        if (rawText != null) 'note': _noteText(rawText!),
      };

  static String _noteText(String raw) {
    // Remove <style> and <script> blocks entirely (keeps CSS/JS from leaking in)
    var plain = raw
        .replaceAll(
            RegExp(r'<style[^>]*>.*?</style>',
                dotAll: true, caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'<script[^>]*>.*?</script>',
                dotAll: true, caseSensitive: false),
            '')
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[a-z]+;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return plain.length > 2900 ? plain.substring(0, 2900) : plain;
  }
}

// ─── Dashboard data ───────────────────────────────────────────────────────────

class DashboardData {
  final List<double> monthTotals;  // index 0 = Jan, 11 = Dec
  final List<double> weekTotals;   // index 0 = 6 days ago, 6 = today
  final double monthTotal;

  const DashboardData({
    required this.monthTotals,
    required this.weekTotals,
    required this.monthTotal,
  });
}
