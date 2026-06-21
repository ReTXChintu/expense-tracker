import 'api.dart';
import 'date_utils.dart';

/// Server-backed per-day scan flags (shared across devices).
class ScannedDaysApi {
  final ApiClient _api;

  ScannedDaysApi(this._api);

  Future<bool> isScanned(DateTime date) async {
    try {
      final res = await _api.get(
        '/scanned-days',
        query: {'date': dateKey(date)},
      ) as Map<String, dynamic>;
      return res['scanned'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markScanned(DateTime date) async {
    await _api.put('/scanned-days', data: {'date': dateKey(date)});
  }

  Future<void> clearScanned(DateTime date) async {
    await _api.delete('/scanned-days', query: {'date': dateKey(date)});
  }

  Future<void> clearAll() async {
    await _api.delete('/scanned-days');
  }
}
