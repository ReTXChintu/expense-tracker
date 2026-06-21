import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api.dart';
import 'core/storage.dart';
import 'core/scanned_days.dart';
import 'core/sms_reader.dart';
import 'core/gmail_reader.dart';
import 'core/analytics.dart';
import 'core/notifs.dart';
import 'core/cc_bill_detector.dart';
import 'core/payment_instrument_parser.dart';
import 'core/date_utils.dart';
import 'core/transaction_merge.dart';
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

final paymentInstrumentsProvider = FutureProvider<List<PaymentInstrument>>((ref) async {
  final api = ref.watch(apiProvider);
  final data = await api.get('/payment-instruments') as List<dynamic>;
  return data.map((e) => PaymentInstrument.fromJson(e as Map<String, dynamic>)).toList();
});

class PaymentInstrumentsNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  final Ref _ref;

  PaymentInstrumentsNotifier(this._api, this._ref) : super(const AsyncValue.data(null));

  Future<PaymentInstrument> create({
    required String name,
    required PaymentInstrumentType type,
    String? issuer,
    String? last4,
    required String color,
    required String icon,
    int? billingCycleDay,
  }) async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.post('/payment-instruments', data: {
        'name': name,
        'type': switch (type) {
          PaymentInstrumentType.debitCard => 'debit_card',
          PaymentInstrumentType.bankAccount => 'bank_account',
          PaymentInstrumentType.upi => 'upi',
          PaymentInstrumentType.wallet => 'wallet',
          _ => 'credit_card',
        },
        if (issuer != null) 'issuer': issuer,
        if (last4 != null) 'last4': last4,
        'color': color,
        'icon': icon,
        if (billingCycleDay != null) 'billingCycleDay': billingCycleDay,
      }) as Map<String, dynamic>;
      _ref.invalidate(paymentInstrumentsProvider);
      state = const AsyncValue.data(null);
      return PaymentInstrument.fromJson(res);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> archive(String id) async {
    await _api.delete('/payment-instruments/$id');
    _ref.invalidate(paymentInstrumentsProvider);
  }
}

final paymentInstrumentsNotifierProvider =
    StateNotifierProvider<PaymentInstrumentsNotifier, AsyncValue<void>>(
  (ref) => PaymentInstrumentsNotifier(ref.watch(apiProvider), ref),
);

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

bool _autoMergeEnabled(Ref ref) =>
    ref.read(userProvider)?.autoMergeSources ?? true;

Transaction? _findSamePayment(List<Transaction> list, Transaction tx) {
  for (final e in list) {
    if (_isSamePayment(e, tx)) return e;
  }
  return null;
}

/// One row per payment; SMS + Gmail text merged into a single transaction.
Future<List<Transaction>> _consolidateTransactions(
  ApiClient api,
  List<Transaction> txs, {
  required bool autoMergeSources,
}) async {
  if (!autoMergeSources) return txs;

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
  late final ScannedDaysApi _scannedDays;

  static const _todayRescanTtl = Duration(minutes: 5);
  final Map<String, List<Transaction>> _dayCache = {};
  final Map<String, DateTime> _lastScanAt = {};

  final Map<String, Timer> _pendingDeletes = {};
  final Map<String, Transaction> _pendingDeleteSnapshots = {};

  TodayNotifier(this._api, this._ref)
    : super(
        TodayState(date: normalizeCalendarDate(DateTime.now()), loading: true),
      ) {
    _scannedDays = ScannedDaysApi(_api);
    load(DateTime.now());
  }

  void _invalidateDashboard() {
    _ref.invalidate(analyticsDashboardProvider);
    _ref.invalidate(analyticsTrendsProvider);
  }

  void _cacheTransactions(DateTime date, List<Transaction> txs) {
    _dayCache[dateKey(date)] = txs;
  }

  Future<List<Transaction>> _sortAndConsolidate(List<Transaction> txs) async {
    var list = await _consolidateTransactions(
      _api,
      txs,
      autoMergeSources: _autoMergeEnabled(_ref),
    );
    list.sort((a, b) {
      if (a.isCategorized != b.isCategorized) {
        return a.isCategorized ? 1 : -1;
      }
      return b.date.compareTo(a.date);
    });
    return list;
  }

  Future<bool> _shouldScanSources(DateTime date, bool forceRescan) async {
    if (isFutureDate(date)) return false;
    if (forceRescan) return true;
    if (isToday(date)) {
      final key = dateKey(date);
      final last = _lastScanAt[key];
      return last == null || DateTime.now().difference(last) > _todayRescanTtl;
    }
    return !(await _scannedDays.isScanned(date));
  }

  Future<List<Transaction>> _fetchTransactionsForDay(DateTime date) async {
    final raw =
        await _api.get(
              '/transactions',
              query: {
                'startDate': startUtc(date),
                'endDate': endUtc(date),
                'limit': '200',
              },
            )
            as List<dynamic>;
    return raw
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _scanAndPersist(DateTime date) async {
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

    final instruments = await _ref.read(paymentInstrumentsProvider.future);

    for (final tx in newTxs) {
      final tagged = applySuggestedKind(applyInstrumentMatch(tx, instruments));
      final match = _findSamePayment(existing, tagged);
      if (match != null) {
        if (_isDuplicateSameSource(match, tagged)) continue;
        if (_autoMergeEnabled(_ref)) {
          final merged = Transaction.merge(match, tagged);
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
            debugPrint('[Scan] merged ${tagged.source.name} into ${match.id}');
          } catch (e) {
            debugPrint('[Scan] failed to merge ${tagged.source.name}: $e');
          }
          continue;
        }
      }

      try {
        final res =
            await _api.post('/transactions', data: tagged.toJson())
                as Map<String, dynamic>;
        existing.add(Transaction.fromJson(res));
        _invalidateDashboard();
      } catch (e) {
        debugPrint('[Scan] failed to save ${tagged.source.name} tx: $e');
      }
    }

    state = state.copyWith(scanning: false);
  }

  Future<void> load(DateTime date, {bool forceRescan = false}) async {
    final normalized = normalizeCalendarDate(date);
    final key = dateKey(normalized);
    final cached = _dayCache[key];

    if (cached != null && !forceRescan) {
      state = state.copyWith(
        date: normalized,
        transactions: cached,
        loading: false,
        clearError: true,
      );
    } else {
      state = TodayState(
        date: normalized,
        loading: cached == null,
        transactions: cached ?? const [],
      );
    }

    try {
      if (forceRescan) {
        if (isPastDate(normalized)) {
          await _scannedDays.clearScanned(normalized);
        } else if (isToday(normalized)) {
          _lastScanAt.remove(key);
        }
      }

      var txs = await _fetchTransactionsForDay(normalized);
      txs = await _sortAndConsolidate(txs);
      _cacheTransactions(normalized, txs);
      state = state.copyWith(transactions: txs, loading: false);

      final shouldScan = await _shouldScanSources(normalized, forceRescan);
      if (shouldScan) {
        await _scanAndPersist(normalized);
        if (isPastDate(normalized)) {
          await _scannedDays.markScanned(normalized);
        } else if (isToday(normalized)) {
          _lastScanAt[key] = DateTime.now();
        }
        txs = await _fetchTransactionsForDay(normalized);
        txs = await _sortAndConsolidate(txs);
        _cacheTransactions(normalized, txs);
        state = state.copyWith(transactions: txs, scanning: false);
      }

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
      final list = state.transactions.where((t) => t.id != id).toList();
      state = state.copyWith(transactions: list);
      _cacheTransactions(state.date, list);
      _invalidateDashboard();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void stageDelete(Transaction tx) {
    final id = tx.id;
    if (id == null) return;

    _pendingDeletes[id]?.cancel();
    _pendingDeleteSnapshots[id] = tx;

    final list = state.transactions.where((t) => t.id != id).toList();
    state = state.copyWith(transactions: list);
    _cacheTransactions(state.date, list);

    _pendingDeletes[id] = Timer(const Duration(seconds: 2), () {
      unawaited(_commitDelete(id));
    });
  }

  void undoDelete(String id) {
    _pendingDeletes[id]?.cancel();
    _pendingDeletes.remove(id);
    final tx = _pendingDeleteSnapshots.remove(id);
    if (tx == null) return;

    final list = [...state.transactions, tx];
    list.sort((a, b) {
      if (a.isCategorized != b.isCategorized) {
        return a.isCategorized ? 1 : -1;
      }
      return b.date.compareTo(a.date);
    });
    state = state.copyWith(transactions: list);
    _cacheTransactions(state.date, list);
  }

  Future<void> _commitDelete(String id) async {
    _pendingDeletes.remove(id);
    _pendingDeleteSnapshots.remove(id);
    try {
      await _api.delete('/transactions/$id');
      _invalidateDashboard();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> mergeSaved(Transaction a, Transaction b, MergeOptions options) async {
    final primaryId = a.id;
    final secondaryId = b.id;
    if (primaryId == null || secondaryId == null) return;

    try {
      final merged = TransactionMerge.merge(a, b, options: options);
      final res =
          await _api.patch(
                '/transactions/$primaryId',
                data: {
                  'merchant': merged.merchant,
                  'amount': merged.amount,
                  'date': DateTime.fromMillisecondsSinceEpoch(
                    merged.date.millisecondsSinceEpoch,
                    isUtc: true,
                  ).toIso8601String(),
                  if (merged.noteForApi != null) 'note': merged.noteForApi,
                },
              )
              as Map<String, dynamic>;

      await _api.delete('/transactions/$secondaryId');

      final updated = Transaction.fromJson(res);
      final list = state.transactions
          .where((t) => t.id != secondaryId)
          .map((t) => t.id == primaryId ? updated : t)
          .toList();
      list.sort((a, b) {
        if (a.isCategorized != b.isCategorized) {
          return a.isCategorized ? 1 : -1;
        }
        return b.date.compareTo(a.date);
      });
      state = state.copyWith(transactions: list);
      _cacheTransactions(state.date, list);
      _invalidateDashboard();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> unmergeSaved(Transaction tx) async {
    final id = tx.id;
    if (id == null) return;

    final drafts = TransactionMerge.split(tx);
    if (drafts.length < 2) return;

    try {
      final keep = drafts.first;
      final res =
          await _api.patch(
                '/transactions/$id',
                data: {
                  if (keep.noteForApi != null) 'note': keep.noteForApi,
                  'source': keep.source == TxSource.gmail ? 'email' : keep.source.name,
                },
              )
              as Map<String, dynamic>;
      var kept = Transaction.fromJson(res);

      final created = <Transaction>[];
      for (final draft in drafts.skip(1)) {
        final body = draft.toJson();
        body['date'] = DateTime.fromMillisecondsSinceEpoch(
          tx.date.millisecondsSinceEpoch,
          isUtc: true,
        ).toIso8601String();
        final postRes = await _api.post('/transactions', data: body) as Map<String, dynamic>;
        created.add(Transaction.fromJson(postRes));
      }

      final list = state.transactions.map((t) => t.id == id ? kept : t).toList()
        ..addAll(created);
      list.sort((a, b) {
        if (a.isCategorized != b.isCategorized) {
          return a.isCategorized ? 1 : -1;
        }
        return b.date.compareTo(a.date);
      });
      state = state.copyWith(transactions: list);
      _cacheTransactions(state.date, list);
      _invalidateDashboard();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> _checkMissedDay() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    try {
      final data =
          await _api.get(
                '/transactions',
                query: {
                  'startDate': startUtc(yesterday),
                  'endDate': endUtc(yesterday),
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
    await _scannedDays.clearAll();
    _lastScanAt.clear();
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
        _cacheTransactions(state.date, updated);
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
    TxKind? kind,
    String? linkedTransactionId,
    String? paymentInstrumentId,
    String? counterpartyInstrumentId,
    bool clearLinkedTransactionId = false,
    bool clearPaymentInstrumentId = false,
    bool clearCounterpartyInstrumentId = false,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (merchant != null) data['merchant'] = merchant;
      if (amount != null) data['amount'] = amount;
      if (isDebit != null) data['type'] = isDebit ? 'debit' : 'credit';
      if (categoryId != null) data['categoryId'] = categoryId;
      if (kind != null) {
        data['kind'] = switch (kind) {
          TxKind.ccBillPayment => 'cc_bill_payment',
          TxKind.selfTransfer => 'self_transfer',
          _ => kind.name,
        };
      }
      if (linkedTransactionId != null) {
        data['linkedTransactionId'] = linkedTransactionId;
      } else if (clearLinkedTransactionId) {
        data['linkedTransactionId'] = null;
      }
      if (paymentInstrumentId != null) {
        data['paymentInstrumentId'] = paymentInstrumentId;
      } else if (clearPaymentInstrumentId) {
        data['paymentInstrumentId'] = null;
      }
      if (counterpartyInstrumentId != null) {
        data['counterpartyInstrumentId'] = counterpartyInstrumentId;
      } else if (clearCounterpartyInstrumentId) {
        data['counterpartyInstrumentId'] = null;
      }
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
      _cacheTransactions(state.date, list);
      _invalidateDashboard();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final todayProvider = StateNotifierProvider<TodayNotifier, TodayState>(
  (ref) => TodayNotifier(ref.watch(apiProvider), ref),
);

// ─── Analytics (same API as web panel) ────────────────────────────────────────

final analyticsPeriodProvider = StateProvider<AnalyticsPeriod>(
  (ref) => AnalyticsPeriod.month,
);

final analyticsDashboardProvider =
    FutureProvider.autoDispose<AnalyticsDashboard>((ref) async {
      final api = ref.watch(apiProvider);
      final period = ref.watch(analyticsPeriodProvider);
      return fetchAnalyticsDashboard(api, period: period);
    });

final analyticsTrendsProvider = FutureProvider.autoDispose<List<MonthlyTrend>>((
  ref,
) async {
  final api = ref.watch(apiProvider);
  return fetchAnalyticsTrends(api);
});
