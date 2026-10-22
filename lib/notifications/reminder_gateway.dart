import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_models.dart';

abstract interface class ReminderGateway {
  bool get supported;
  Future<void> initialize(void Function(int id) onTap);
  Future<bool> requestPermission();
  Future<bool> permissionGranted();
  Future<void> schedule(InboxNotice notice);
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

class LocalReminderGateway implements ReminderGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  @override
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  @override
  Future<void> initialize(void Function(int id) onTap) async {
    if (!supported || _initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_booking_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = int.tryParse(response.payload ?? '');
        if (id != null && id > 0) onTap(id);
      },
    );
    _initialized = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final id = int.tryParse(launch?.notificationResponse?.payload ?? '');
      if (id != null && id > 0) onTap(id);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<bool> permissionGranted() async {
    if (!supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    return (await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ??
        false;
  }

  @override
  Future<void> schedule(InboxNotice notice) async {
    if (!supported || notice.scheduled == null) return;
    await _plugin.zonedSchedule(
      id: notice.id,
      title: 'SportMatch · Nhắc lịch chơi',
      body: 'Bạn có lịch chơi sắp bắt đầu. Mở SportMatch để xem chi tiết.',
      scheduledDate: tz.TZDateTime.from(notice.scheduled!, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sportmatch_booking_reminders',
          'Nhắc lịch chơi',
          channelDescription: 'Nhắc trước giờ chơi của lịch đặt đã xác nhận',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
          icon: 'ic_booking_notification',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      // A sports reminder does not require restricted exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '${notice.id}',
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (supported && _initialized) await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    if (supported && _initialized) await _plugin.cancelAll();
  }
}
