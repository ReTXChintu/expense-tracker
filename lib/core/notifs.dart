import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
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
          AndroidFlutterLocalNotificationsPlugin
        >()
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
      1, // 00:01 so it fires just after midnight
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

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Expected next daily reminder (00:01 IST), whether or not it is queued yet.
  static tz.TZDateTime nextMidnightScheduleTime() {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 0, 1);
  }

  /// Re-queue midnight reminder (e.g. from Profile → Reminders).
  static Future<void> rescheduleReminders() => scheduleMidnightReminder();

  static Future<void> openNotificationSettings() => openAppSettings();

  /// Diagnostics for Profile → Reminders (release APK troubleshooting).
  static Future<NotificationDebugStatus> loadDebugStatus() async {
    final android = _android;

    bool permissionGranted = true;
    bool? exactAlarmsAllowed;
    if (defaultTargetPlatform == TargetPlatform.android && android != null) {
      permissionGranted = await android.areNotificationsEnabled() ?? false;
      exactAlarmsAllowed = await android.canScheduleExactNotifications();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final notif = await Permission.notification.status;
      permissionGranted = notif.isGranted || notif.isLimited;
      exactAlarmsAllowed = null; // N/A on iOS
    }

    var pendingStatusKnown = true;
    var pending = <PendingNotificationRequest>[];
    try {
      pending = await _plugin.pendingNotificationRequests();
    } on PlatformException {
      pendingStatusKnown = false;
    } catch (_) {
      pendingStatusKnown = false;
    }

    PendingNotificationRequest? midnightPending;
    for (final p in pending) {
      if (p.id == 1) {
        midnightPending = p;
        break;
      }
    }
    final nagPending = pending.where((p) => p.id >= 200 && p.id < 220).length;

    return NotificationDebugStatus(
      permissionGranted: permissionGranted,
      exactAlarmsAllowed: exactAlarmsAllowed,
      pendingStatusKnown: pendingStatusKnown,
      midnightReminderScheduled: midnightPending != null,
      midnightReminderTitle: midnightPending?.title,
      nextMidnightLocal: nextMidnightScheduleTime(),
      activeNagCount: nagPending,
      totalPendingCount: pending.length,
    );
  }
}

/// Snapshot for the Profile reminders panel.
class NotificationDebugStatus {
  final bool permissionGranted;
  final bool? exactAlarmsAllowed;
  final bool pendingStatusKnown;
  final bool midnightReminderScheduled;
  final String? midnightReminderTitle;
  final tz.TZDateTime nextMidnightLocal;
  final int activeNagCount;
  final int totalPendingCount;

  const NotificationDebugStatus({
    required this.permissionGranted,
    required this.exactAlarmsAllowed,
    required this.pendingStatusKnown,
    required this.midnightReminderScheduled,
    required this.midnightReminderTitle,
    required this.nextMidnightLocal,
    required this.activeNagCount,
    required this.totalPendingCount,
  });

  bool get isHealthy =>
      permissionGranted &&
      (exactAlarmsAllowed ?? true) &&
      (!pendingStatusKnown || midnightReminderScheduled);

  String? get issueHint {
    if (!permissionGranted) {
      return 'Allow notifications in system settings.';
    }
    if (exactAlarmsAllowed == false) {
      return 'Enable Alarms & reminders for SpendLog (exact schedule).';
    }
    if (!pendingStatusKnown) {
      return 'Could not read the reminder queue. Tap Reschedule to re-register.';
    }
    if (!midnightReminderScheduled) {
      return 'Tap Reschedule to register the daily midnight reminder.';
    }
    return null;
  }
}
