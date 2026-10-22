import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:test_do_an/notifications/notification_models.dart';
import 'package:test_do_an/notifications/reminder_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  test('Android schedules an inexact private reminder with timezone and ID-only payload', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize' ||
              call.method == 'requestNotificationsPermission' ||
              call.method == 'areNotificationsEnabled') {
            return true;
          }
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {'notificationLaunchedApp': false};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final g = LocalReminderGateway();
    await g.initialize((_) {});
    expect(await g.requestPermission(), isTrue);
    expect(await g.permissionGranted(), isTrue);
    final now = DateTime.now();
    await g.schedule(
      InboxNotice(
        id: 42,
        owner: '0901234567',
        bookingId: 'NVH0001',
        kind: 'reminder',
        title: 'Thông tin riêng',
        body: 'Thông tin riêng của khách',
        created: now,
        scheduled: now.add(const Duration(days: 1)),
      ),
    );
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(args['id'], 42);
    expect(args['payload'], '42');
    expect(args['timeZoneName'], 'Asia/Ho_Chi_Minh');
    expect(
      (args['platformSpecifics'] as Map)['scheduleMode'],
      'inexactAllowWhileIdle',
    );
    expect(args['body'], isNot(contains('Thông tin riêng')));
    expect(args['body'], isNot(contains('0901234567')));
    await g.cancel(42);
    await g.cancelAll();
    expect(calls.where((c) => c.method == 'cancel').length, 1);
    expect(calls.where((c) => c.method == 'cancelAll').length, 1);
  });
}
