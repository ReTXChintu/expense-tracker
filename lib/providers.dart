import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api.dart';
import 'core/storage.dart';
import 'core/sms_reader.dart';
import 'core/gmail_reader.dart';
import 'core/notifs.dart';
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

  Future<void> login(String email, String password) async {
    final data = await _api.post('/auth/login',
        data: {'email': email, 'password': password}) as Map<String, dynamic>;

    final tokens = data['tokens'] as Map<String, dynamic>;
    await AppStorage.saveToken(tokens['accessToken'] as String);

    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _ref.read(userProvider.notifier).state = user;
    _ref.read(isLoggedInProvider.notifier).state = true;
    state = true;

    await NotifManager.scheduleMidnightReminder();
  }

  Future<void> register(String name, String email, String password) async {
    final data = await _api.post('/auth/register',
        data: {'name': name, 'email': email, 'password': password})
        as Map<String, dynamic>;

    final tokens = data['tokens'] as Map<String, dynamic>;
    await AppStorage.saveToken(tokens['accessToken'] as String);

    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _ref.read(userProvider.notifier).state = user;
    _ref.read(isLoggedInProvider.notifier).state = true;
    state = true;

    // Seed default categories for new users
    try { await _api.post('/categories/seed'); } catch (_) {}

    await NotifManager.scheduleMidnightReminder();
  }

  Future<void> logout() async {
    try { await _api.post('/auth/logout'); } catch (_) {}
    await AppStorage.clearToken();
    await NotifManager.cancelAll();
    _ref.read(isLoggedInProvider.notifier).state = false;
    _ref.read(userProvider.notifier).state = null;
    state = false;
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, bool>((ref) => AuthNotifier(
          ref.watch(apiProvider),
          ref,
        ));

// ─── Categories ───────────────────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.watch(apiProvider);
  final data = await api.get('/categories') as List<dynamic>;
  return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
});

// ─── Today screen ─────────────────────────────────────────────────────────────

class TodayState {
  final List<Transaction> transactions; // all for the date, from DB
  final DateTime date;
  final bool loading;
  final bool scanning; // actively reading SMS/Gmail and saving to DB
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
  }) =>
      TodayState(
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

class TodayNotifier extends StateNotifier<TodayState> {
  final ApiClient _api;

  TodayNotifier(this._api)
      : super(TodayState(date: DateTime.now(), loading: true)) {
    load(DateTime.now());
  }

  /// [forceRescan] = true clears the scanned flag so SMS/Gmail are re-read.
  Future<void> load(DateTime date, {bool forceRescan = false}) async {
    state = TodayState(date: date, loading: true);

    try {
      if (forceRescan) {
        await AppStorage.clearScannedDate(date);
      }

      final alreadyScanned = await AppStorage.isDateScanned(date);

      if (!alreadyScanned) {
        // ── First visit: read SMS + Gmail and save everything to DB ────────────
        state = state.copyWith(scanning: true);

        // Fetch what's already in the DB so we can deduplicate
        List<Transaction> existing = [];
        try {
          final raw = await _api.get('/transactions', query: {
            'startDate': _startUtc(date),
            'endDate': _endUtc(date),
            'limit': '200',
          }) as List<dynamic>;
          existing = raw
              .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}

        // Scan sources (errors are caught individually so one failure doesn't block the other)
        final newTxs = <Transaction>[];
        try {
          newTxs.addAll(await SmsReader.fetchForDate(date));
        } catch (_) {}
        try {
          newTxs.addAll(await GmailReader.fetchForDate(date));
        } catch (e) {
          // Show Gmail error but still continue with SMS results
          state = state.copyWith(error: e.toString());
        }

        // Save only transactions not already in DB (dedup by amount + time)
        for (final tx in newTxs) {
          final isDuplicate = existing.any((e) =>
              e.amount == tx.amount &&
              e.date.difference(tx.date).inMinutes.abs() < 5);
          if (!isDuplicate) {
            try {
              final res = await _api.post('/transactions', data: tx.toJson())
                  as Map<String, dynamic>;
              existing.add(Transaction.fromJson(res));
            } catch (_) {}
          }
        }

        await AppStorage.markDateScanned(date);
        state = state.copyWith(scanning: false);
      }

      // ── Always load from DB ─────────────────────────────────────────────────
      final raw = await _api.get('/transactions', query: {
        'startDate': _startUtc(date),
        'endDate': _endUtc(date),
        'limit': '200',
      }) as List<dynamic>;

      final txs = raw
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();

      // Sort: uncategorized first, then by date descending
      txs.sort((a, b) {
        if (a.isCategorized != b.isCategorized) {
          return a.isCategorized ? 1 : -1;
        }
        return b.date.compareTo(a.date);
      });

      state = state.copyWith(transactions: txs, loading: false, scanning: false);
      await _checkMissedDay();
    } catch (e) {
      state = state.copyWith(loading: false, scanning: false, error: e.toString());
    }
  }

  Future<void> deleteSaved(String id) async {
    try {
      await _api.delete('/transactions/$id');
      state = state.copyWith(
        transactions: state.transactions.where((t) => t.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _checkMissedDay() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    try {
      final data = await _api.get('/transactions', query: {
        'startDate': _startUtc(yesterday),
        'endDate': _endUtc(yesterday),
        'isUncategorized': 'true',
        'limit': '10',
      }) as List<dynamic>;
      if (data.isNotEmpty) {
        await NotifManager.scheduleHalfHourlyNags();
      }
    } catch (_) {}
  }

  void goToDate(DateTime date) => load(date);

  // ── Create a manual transaction directly in the DB ──────────────────────────

  Future<void> createTransaction({
    required String merchant,
    required double amount,
    required bool isDebit,
    String? categoryId,
    required DateTime date,
  }) async {
    try {
      final res = await _api.post('/transactions', data: {
        'merchant': merchant,
        'amount': amount,
        'type': isDebit ? 'debit' : 'credit',
        'date': DateTime.fromMillisecondsSinceEpoch(
                date.millisecondsSinceEpoch, isUtc: true)
            .toIso8601String(),
        'source': 'manual',
        if (categoryId != null) 'categoryId': categoryId,
      }) as Map<String, dynamic>;
      final tx = Transaction.fromJson(res);
      final updated = [...state.transactions, tx];
      updated.sort((a, b) {
        if (a.isCategorized != b.isCategorized) return a.isCategorized ? 1 : -1;
        return b.date.compareTo(a.date);
      });
      state = state.copyWith(transactions: updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Update (category, merchant, amount, type) in the DB ────────────────────

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

      final res = await _api.patch('/transactions/$id', data: data)
          as Map<String, dynamic>;
      final updated = Transaction.fromJson(res);
      final list = state.transactions
          .map((t) => t.id == id ? updated : t)
          .toList();
      list.sort((a, b) {
        if (a.isCategorized != b.isCategorized) return a.isCategorized ? 1 : -1;
        return b.date.compareTo(a.date);
      });
      state = state.copyWith(transactions: list);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final todayProvider =
    StateNotifierProvider<TodayNotifier, TodayState>((ref) => TodayNotifier(
          ref.watch(apiProvider),
        ));

// ─── Dashboard ────────────────────────────────────────────────────────────────

String _startUtc(DateTime d) =>
    DateTime(d.year, d.month, d.day).toUtc().toIso8601String();

String _endUtc(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toUtc().toIso8601String();

final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final api = ref.watch(apiProvider);
  final now = DateTime.now();

  final data = await api.get('/transactions', query: {
    'startDate': _startUtc(DateTime(now.year, 1, 1)),
    'endDate': _endUtc(now),
    'limit': '2000',
  }) as List<dynamic>;

  final txs = data
      .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
      .where((t) => t.isDebit)
      .toList();

  // Monthly totals for this year
  final monthTotals = List<double>.filled(12, 0);
  for (final t in txs) {
    monthTotals[t.date.month - 1] += t.amount;
  }

  // Daily totals for last 7 days (index 0 = 6 days ago)
  final weekTotals = List<double>.filled(7, 0);
  final weekStart = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
  for (final t in txs) {
    final dayIndex = t.date.difference(weekStart).inDays;
    if (dayIndex >= 0 && dayIndex < 7) {
      weekTotals[dayIndex] += t.amount;
    }
  }

  final monthTotal = monthTotals[now.month - 1];

  return DashboardData(
    monthTotals: monthTotals,
    weekTotals: weekTotals,
    monthTotal: monthTotal,
  );
});
