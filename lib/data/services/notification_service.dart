// lib/data/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Daily streak reminder notification, wrapping flutter_local_notifications.
///
/// Deliberately does NOT extend or touch PrefsService (streak tracking) —
/// this owns its own three SharedPreferences keys directly
/// ('reminder_enabled', 'reminder_hour', 'reminder_minute'). Same reasoning
/// as WordFamilyService/MorphologyService staying separate from existing
/// services: additive new capability, zero risk of colliding with
/// PrefsService internals this session hasn't reviewed.
///
/// Per-user decision (see conversation): permission is requested
/// immediately on first app start (not gated behind enabling the
/// toggle), and the reminder time is user-configurable in Settings.
/// Uses inexact scheduling (AndroidScheduleMode.inexactAllowWhileIdle) —
/// a streak reminder doesn't need to-the-minute precision, and this
/// avoids Android 14's separate exact-alarm permission flow entirely.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _keyEnabled = 'reminder_enabled';
  static const _keyHour = 'reminder_hour';
  static const _keyMinute = 'reminder_minute';
  static const _defaultHour = 20; // 8pm fallback before the user picks one
  static const _reminderNotificationId = 1001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Sets up timezone data, initializes the plugin, requests notification
  /// permission, and (re)schedules the reminder if enabled. Safe to call
  /// multiple times — subsequent calls after the first no-op the setup
  /// steps but still refresh the schedule, which matters after a
  /// settings change.
  Future<void> init() async {
    if (!_initialized) {
      tz.initializeTimeZones();
      try {
        final localName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (_) {
        // Fall back to whatever default the timezone package ships with
        // rather than failing initialization entirely over a tz lookup.
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      );
      await _requestPermission();
      _initialized = true;
    }

    if (await isEnabled()) {
      final time = await reminderTime();
      await _schedule(time);
    }
  }

  Future<void> _requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ── Settings ─────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  /// Hour/minute in 24h local time, e.g. (20, 0) for 8:00pm.
  Future<(int, int)> reminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyHour) ?? _defaultHour;
    final minute = prefs.getInt(_keyMinute) ?? 0;
    return (hour, minute);
  }

  /// Enables or disables the reminder, scheduling/cancelling immediately.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    if (enabled) {
      await _schedule(await reminderTime());
    } else {
      await _plugin.cancel(id: _reminderNotificationId);
    }
  }

  /// Sets the reminder time and reschedules if currently enabled.
  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
    if (await isEnabled()) {
      await _schedule((hour, minute));
    }
  }

  // ── Scheduling ───────────────────────────────────────────────────────

  Future<void> _schedule((int, int) time) async {
    final (hour, minute) = time;
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _reminderNotificationId,
      title: 'Keep your streak going!',
      body: 'Take a few minutes to read some Koine Greek today.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminder',
          'Streak Reminders',
          channelDescription: 'Daily reminder to keep your reading streak',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
  }
}