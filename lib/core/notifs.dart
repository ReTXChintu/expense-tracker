import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

const _channelId = 'spendlog';
const _channelName = 'SpendLog';

final _plugin = FlutterLocalNotificationsPlugin();

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    _channelName,
    importance: Importance.high,
    priority: Priority.high,
    enableVibration: true,
  ),
);

class NotifManager {
  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedule a notification at midnight every night.
  static Future<void> scheduleMidnightReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    final midnight = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1, // tomorrow
      0,
      1,           // 00:01 so it fires just after midnight
    );

    await _plugin.zonedSchedule(
      1,
      "Time to log today's spends 💰",
      'Open the app and categorize your transactions.',
      midnight,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule N reminders every 30 min starting now + 30 min.
  /// Call this when yesterday has uncategorized transactions.
  static Future<void> scheduleHalfHourlyNags({int count = 12}) async {
    // Cancel any existing nags first
    await cancelNags();

    var next = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30));
    for (int i = 0; i < count; i++) {
      await _plugin.zonedSchedule(
        200 + i,
        'You forgot to categorize yesterday! 😤',
        'Get it done. Tap to open.',
        next,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      next = next.add(const Duration(minutes: 30));
    }
  }

  static Future<void> cancelNags() async {
    for (int i = 0; i < 20; i++) {
      await _plugin.cancel(200 + i);
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
