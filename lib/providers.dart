import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api.dart';
import 'core/storage.dart';
import 'core/sms_reader.dart';
import 'core/gmail_reader.dart';
import 'core/notifs.dart';
import 'core/date_utils.dart';
import 'models.dart';

// ─── Singletons ───────────────────────────────────────────────────────────────

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

// ─── Auth ─────────────────────────────────────────────────────────────────────

final isLoggedInProvider = StateProvider<bool>((ref) => false);

final userProvider = StateProvider<User?>((ref) => null);

class AuthNotifier extends StateNotifier<bool> {
  final ApiClient _api;
  final Ref _ref;
  AuthNotifier(this._api, this._ref) : super(false);

  Future<void> _ensureCategoriesSeeded() async {
    try {
      await _ref.read(categoriesNotifierProvider.notifier).ensureSeeded();
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    final data =
        await _api.post(
              '/auth/login',
              data: {'email': email, 'password': password},
            )
            as Map<String, dynamic>;

    final tokens = data['tokens'] as Map<String, dynamic>;
    await AppStorage.saveToken(tokens['accessToken'] as String);

    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _ref.read(userProvider.notifier).state = user;
    _ref.read(isLoggedInProvider.notifier).state = true;
    state = true;

    await _ensureCategoriesSeeded();
    await NotifManager.scheduleMidnightReminder();
  }

  Future<void> register(String name, String email, String password) async {
    final data =
        await _api.post(
              '/auth/register',
              data: {'name': name, 'email': email, 'password': password},
            )
            as Map<String, dynamic>;

    final tokens = data['tokens'] as Map<String, dynamic>;
    await AppStorage.saveToken(tokens['accessToken'] as String);

    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _ref.read(userProvider.notifier).state = user;
    _ref.read(isLoggedInProvider.notifier).state = true;
    state = true;

    await _ensureCategoriesSeeded();
    await NotifManager.scheduleMidnightReminder();
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await AppStorage.clearToken();
    await NotifManager.cancelAll();
    _ref.read(isLoggedInProvider.notifier).state = false;
    _ref.read(userProvider.notifier).state = null;
    state = false;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, bool>(
  (ref) => AuthNotifier(ref.watch(apiProvider), ref),
);

// ─── Categories ───────────────────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.watch(apiProvider);
  final data = await api.get('/categories') as List<dynamic>;
  return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
});

class CategoriesNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  final Ref _ref;

  CategoriesNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<void> ensureSeeded() async {
    final list = await _api.get('/categories') as List<dynamic>;
    if (list.isEmpty) {
      await _api.post('/categories/seed');
      _ref.invalidate(categoriesProvider);
    }
  }

  Future<Category> createCategory({
    required String name,
    required String icon,
    required String color,
  }) async {
    state = const AsyncValue.loading();
    try {
      final res =
          await _api.post(
                '/categories',
                data: {'name': name, 'icon': icon, 'color': color},
              )
              as Map<String, dynamic>;
      _ref.invalidate(categoriesProvider);
      state = const AsyncValue.data(null);
      return Category.fromJson(res);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    state = const AsyncValue.loading();
    try {
      await _api.delete('/categories/$id');
      _ref.invalidate(categoriesProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final categoriesNotifierProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<void>>(
      (ref) => CategoriesNotifier(ref.watch(apiProvider), ref),
    );

// ─── Today screen ─────────────────────────────────────────────────────────────

class TodayState {
  final List<Transaction> transactions;
  final DateTime date;
  final bool loading;
  final bool scanning;
  final String? error;

  const TodayState({
    this.transactions = const [],
    required this.date,
    this.loading = false,
    this.scanning = false,
    this.error,
  });

  TodayState copyWith({
    List<Transaction>? transactions,
    DateTime? date,
    bool? loading,
    bool? scanning,
    String? error,
    bool clearError = false,
  }) => TodayState(
    transactions: transactions ?? this.transactions,
    date: date ?? this.date,
    loading: loading ?? this.loading,
    scanning: scanning ?? this.scanning,
    error: clearError ? null : (error ?? this.error),
  );

  int get uncategorizedCount =>
      transactions.where((t) => !t.isCategorized).length;
  bool get allCategorized => uncategorizedCount == 0;
}

bool _isSamePayment(Transaction a, Transaction b) {
  if (a.amount != b.amount || a.isDebit != b.isDebit) return false;
  return a.date.difference(b.date).inMinutes.abs() < 5;
}

bool _isDuplicateSameSource(Transaction a, Transaction b) =>
    a.source == b.source && _isSamePayment(a, b);

Transaction? _findSamePayment(List<Transaction> list, Transaction tx) {
  for (final e in list) {
    if (_isSamePayment(e, tx)) return e;
  }
  return null;
}

/// One row per payment; SMS + Gmail text merged into a single transaction.
Future<List<Transaction>> _consolidateTransactions(
  ApiClient api,
  List<Transaction> txs,
) async {
  final out = <Transaction>[];
  final consumed = <String>{};

  for (var i = 0; i < txs.length; i++) {
    final idA = txs[i].id;
    if (idA != null && consumed.contains(idA)) continue;

    var primary = txs[i];
    for (var j = i + 1; j < txs.length; j++) {
      final idB = txs[j].id;
      if (idB != null && consumed.contains(idB)) continue;
      if (!_isSamePayment(primary, txs[j])) continue;

      if (_isDuplicateSameSource(primary, txs[j])) {
        if (idB != null) {
          consumed.add(idB);
          try {
            await api.delete('/transactions/$idB');
          } catch (_) {}
        }
        continue;
      }

      primary = Transaction.merge(primary, txs[j]);
      if (idB != null) {
        consumed.add(idB);
        try {
          await api.delete('/transactions/$idB');
        } catch (_) {}
      }
    }

    if (primary.id != null &&
        primary.hasMultipleSources &&
        !consumed.contains(primary.id)) {
      try {
        final res =
            await api.patch(
                  '/transactions/${primary.id}',
                  data: {
                    if (primary.noteForApi != null) 'note': primary.noteForApi,
                    'merchant': primary.merchant,
                  },
                )
                as Map<String, dynamic>;
        primary = Transaction.fromJson(res);
      } catch (_) {}
    }

    out.add(primary);
    if (idA != null) consumed.add(idA);
  }

  return out;
}

class TodayNotifier extends StateNotifier<TodayState> {
  final ApiClient _api;
  final Ref _ref;

  TodayNotifier(this._api, this._ref)
    : super(
        TodayState(date: normalizeCalendarDate(DateTime.now()), loading: true),
      ) {
    load(DateTime.now());
  }

  void _invalidateDashboard() => _ref.invalidate(dashboardProvider);

  Future<bool> _shouldScanSources(DateTime date, bool forceRescan) async {
    if (isFutureDate(date)) return false;
    if (isToday(date)) return true;
    if (forceRescan) return true;
    return !(await AppStorage.isDateScanned(date));
  }

  Future<List<Transaction>> _fetchTransactionsForDay(DateTime date) async {
    final raw =
        await _api.get(
              '/transactions',
              query: {
                'startDate': _startUtc(date),
                'endDate': _endUtc(date),
                'limit': '200',
              },
            )
            as List<dynamic>;
    return raw
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _scanAndPersist(
    DateTime date, {
    required bool markScannedAfter,
  }) async {
    state = state.copyWith(scanning: true, clearError: true);

    List<Transaction> existing = [];
    try {
      existing = await _fetchTransactionsForDay(date);
    } catch (_) {}

    final newTxs = <Transaction>[];
    try {
      newTxs.addAll(await SmsReader.fetchForDate(date));
    } catch (_) {}
    try {
      newTxs.addAll(await GmailReader.fetchForDate(date));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }

    for (final tx in newTxs) {
      final match = _findSamePayment(existing, tx);
      if (match != null) {
        if (_isDuplicateSameSource(match, tx)) continue;
        final merged = Transaction.merge(match, tx);
        try {
          final res =
              await _api.patch(
                    '/transactions/${match.id}',
                    data: {
                      if (merged.noteForApi != null) 'note': merged.noteForApi,
                      'merchant': merged.merchant,
                    },
                  )
                  as Map<String, dynamic>;
          final idx = existing.indexWhere((e) => e.id == match.id);
          if (idx >= 0) {
            existing[idx] = Transaction.fromJson(res);
          }
          _invalidateDashboard();
          debugPrint('[Scan] merged ${tx.source.name} into ${match.id}');
        } catch (e) {
          debugPrint('[Scan] failed to merge ${tx.source.name}: $e');
        }
        continue;
      }

      try {
        final res =
            await _api.post('/transactions', data: tx.toJson())
                as Map<String, dynamic>;
        existing.add(Transaction.fromJson(res));
        _invalidateDashboard();
      } catch (e) {
        debugPrint('[Scan] failed to save ${tx.source.name} tx: $e');
      }
    }

    if (markScannedAfter) {
      await AppStorage.markDateScanned(date);
    }

    state = state.copyWith(scanning: false);
  }

  Future<void> load(DateTime date, {bool forceRescan = false}) async {
    final normalized = normalizeCalendarDate(date);
    state = TodayState(date: normalized, loading: true);

    try {
      if (forceRescan && !isToday(normalized)) {
        await AppStorage.clearScannedDate(normalized);
      }

      final shouldScan = await _shouldScanSources(normalized, forceRescan);
      if (shouldScan) {
        await _scanAndPersist(
          normalized,
          markScannedAfter: isPastDate(normalized),
        );
      }

      var txs = await _fetchTransactionsForDay(normalized);
      txs = await _consolidateTransactions(_api, txs);
      txs.sort((a, b) {
        if (a.isCategorized != b.isCategorized) {
          return a.isCategorized ? 1 : -1;
        }
        return b.date.compareTo(a.date);
      });

      state = state.copyWith(
        transactions: txs,
        loading: false,
        scanning: false,
      );
      await _checkMissedDay();
    } catch (e) {
      state = state.copyWith(
        loading: false,
        scanning: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteSaved(String id) async {
    try {
      await _api.delete('/transactions/$id');
      state = state.copyWith(
        transactions: state.transactions.where((t) => t.id != id).toList(),
      );
      _invalidateDashboard();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _checkMissedDay() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    try {
      final data =
          await _api.get(
                '/transactions',
                query: {
                  'startDate': _startUtc(yesterday),
                  'endDate': _endUtc(yesterday),
                  'isUncategorized': 'true',
                  'limit': '10',
                },
              )
              as List<dynamic>;
      if (data.isNotEmpty) {
        await NotifManager.scheduleHalfHourlyNags();
      }
    } catch (_) {}
  }

  void goToDate(DateTime date) => load(normalizeCalendarDate(date));

  /// Call after Gmail is connected so past days are re-scanned for email.
  Future<void> onGmailConnected() async {
    await AppStorage.clearAllScannedDates();
    await load(state.date, forceRescan: true);
  }

  Future<void> createTransaction({
    required String merchant,
    required double amount,
    required bool isDebit,
    String? categoryId,
    required DateTime date,
  }) async {
    try {
      final txDate = transactionTimestampForDay(date);
      final res =
          await _api.post(
                '/transactions',
                data: {
                  'merchant': merchant,
                  'amount': amount,
                  'type': isDebit ? 'debit' : 'credit',
                  'date': DateTime.fromMillisecondsSinceEpoch(
                    txDate.millisecondsSinceEpoch,
                    isUtc: true,
                  ).toIso8601String(),
                  'source': 'manual',
                  if (categoryId != null) 'categoryId': categoryId,
                },
              )
              as Map<String, dynamic>;
      final tx = Transaction.fromJson(res);
      if (isSameCalendarDay(tx.date, state.date)) {
        final updated = [...state.transactions, tx];
        updated.sort((a, b) {
          if (a.isCategorized != b.isCategorized) {
            return a.isCategorized ? 1 : -1;
          }
          return b.date.compareTo(a.date);
        });
        state = state.copyWith(transactions: updated);
      }
      _invalidateDashboard();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateSaved(
    String id, {
    String? merchant,
    double? amount,
    bool? isDebit,
    String? categoryId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (merchant != null) data['merchant'] = merchant;
      if (amount != null) data['amount'] = amount;
      if (isDebit != null) data['type'] = isDebit ? 'debit' : 'credit';
      if (categoryId != null) data['categoryId'] = categoryId;
      if (data.isEmpty) return;

      final res =
          await _api.patch('/transactions/$id', data: data)
              as Map<String, dynamic>;
      final updated = Transaction.fromJson(res);
      final list = state.transactions
          .map((t) => t.id == id ? updated : t)
          .toList();
      list.sort((a, b) {
        if (a.isCategorized != b.isCategorized) {
          return a.isCategorized ? 1 : -1;
        }
        return b.date.compareTo(a.date);
      });
      state = state.copyWith(transactions: list);
      _invalidateDashboard();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final todayProvider = StateNotifierProvider<TodayNotifier, TodayState>(
  (ref) => TodayNotifier(ref.watch(apiProvider), ref),
);

// ─── Dashboard ────────────────────────────────────────────────────────────────

String _startUtc(DateTime d) =>
    DateTime(d.year, d.month, d.day).toUtc().toIso8601String();

String _endUtc(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toUtc().toIso8601String();

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final api = ref.watch(apiProvider);
  final now = DateTime.now();

  final data =
      await api.get(
            '/transactions',
            query: {
              'startDate': _startUtc(DateTime(now.year, 1, 1)),
              'endDate': _endUtc(now),
              'limit': '2000',
            },
          )
          as List<dynamic>;

  final txs = data
      .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
      .where((t) => t.isDebit)
      .toList();

  bool inCurrentMonth(Transaction t) =>
      t.date.year == now.year && t.date.month == now.month;

  final monthTotals = List<double>.filled(12, 0);
  for (final t in txs) {
    monthTotals[t.date.month - 1] += t.amount;
  }

  final weekTotals = List<double>.filled(7, 0);
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));
  for (final t in txs) {
    final dayIndex = t.date.difference(weekStart).inDays;
    if (dayIndex >= 0 && dayIndex < 7) {
      weekTotals[dayIndex] += t.amount;
    }
  }

  final monthTotal = monthTotals[now.month - 1];
  final lastMonthIndex = now.month == 1 ? 11 : now.month - 2;
  final lastMonthTotal = monthTotals[lastMonthIndex];
  final avgDailyThisMonth = monthTotal / now.day;

  final categoryAgg = <String, ({String name, double amount, int count})>{};
  final merchantAgg = <String, ({double amount, int count})>{};
  for (final t in txs.where(inCurrentMonth)) {
    final categoryId = t.categoryId ?? 'uncategorized';
    final categoryName = t.category?.name ?? 'Uncategorized';
    final currentCategory =
        categoryAgg[categoryId] ?? (name: categoryName, amount: 0.0, count: 0);
    categoryAgg[categoryId] = (
      name: currentCategory.name,
      amount: currentCategory.amount + t.amount,
      count: currentCategory.count + 1,
    );

    final merchant = t.merchant.trim().isEmpty ? 'Unknown' : t.merchant.trim();
    final currentMerchant = merchantAgg[merchant] ?? (amount: 0.0, count: 0);
    merchantAgg[merchant] = (
      amount: currentMerchant.amount + t.amount,
      count: currentMerchant.count + 1,
    );
  }

  final monthCategorySpends =
      categoryAgg.entries
          .map(
            (e) => CategorySpend(
              categoryId: e.key,
              name: e.value.name,
              amount: e.value.amount,
              count: e.value.count,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  final topMerchants =
      merchantAgg.entries
          .map(
            (e) => MerchantSpend(
              merchant: e.key,
              amount: e.value.amount,
              count: e.value.count,
            ),
          )
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  return DashboardData(
    monthTotals: monthTotals,
    weekTotals: weekTotals,
    monthTotal: monthTotal,
    lastMonthTotal: lastMonthTotal,
    avgDailyThisMonth: avgDailyThisMonth,
    monthCategorySpends: monthCategorySpends,
    topMerchants: topMerchants.take(5).toList(),
  );
});
