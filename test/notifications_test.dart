import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/notifications/notification_center.dart';
import 'package:test_do_an/notifications/notification_models.dart';
import 'package:test_do_an/notifications/notification_store.dart';
import 'package:test_do_an/notifications/reminder_gateway.dart';

import 'multi_facility_test.dart' show sampleFacilityProof;

class FakeReminderGateway implements ReminderGateway {
  bool available = true, allowed = true, failSchedule = false;
  int scheduledCalls = 0, cancelledAll = 0;
  final pending = <int, InboxNotice>{};
  void Function(int)? tap;
  Completer<bool>? permissionBarrier;
  @override
  bool get supported => available;
  @override
  Future<void> initialize(void Function(int) onTap) async {
    tap = onTap;
  }

  @override
  Future<bool> requestPermission() async =>
      permissionBarrier?.future ?? allowed;
  @override
  Future<bool> permissionGranted() async => available && allowed;
  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelledAll++;
    pending.clear();
  }

  @override
  Future<void> schedule(InboxNotice notice) async {
    if (failSchedule) throw StateError('Native scheduler failed');
    scheduledCalls++;
    pending[notice.id] = notice;
  }
}

NotificationStore memoryNoticeStore() =>
    NotificationStore(factory: databaseFactoryFfi, path: inMemoryDatabasePath);

DemoBooking approveReminderBooking(DemoSession s) {
  s.login(DemoSession.phone, DemoSession.password);
  final b = s.bookings.first;
  s.startTransfer(b);
  s.saveProofDraft(b, decodeProof(sampleFacilityProof));
  s.submitProof(b, 'TEST-REMINDER');
  s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
  s.reviewPayment(b, approve: true);
  s.login(DemoSession.phone, DemoSession.password);
  return b;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final now = DateTime(2026, 10, 20, 8);
  BookingNoticeState state({
    int revision = 0,
    bool confirmed = true,
    bool cancelled = false,
    bool suppressed = false,
    DateTime? start,
  }) => BookingNoticeState(
    id: 'NVH0001',
    venue: 'Sân thử nghiệm',
    court: 1,
    start: start ?? DateTime(2026, 10, 21, 9),
    hours: 1,
    revision: revision,
    confirmed: confirmed,
    cancelled: cancelled,
    suppressed: suppressed,
  );
  NotificationStore store() {
    final s = memoryNoticeStore();
    addTearDown(s.close);
    return s;
  }

  test('SQLite CRUD is scoped to owner, due unread counts exclude future reminders', () async {
    final db = store();
    await db.savePreferences('a', const ReminderPreferences(enabled: true));
    await db.reconcile('a', [state()], now);
    final rows = await db.list('a');
    expect(rows.length, 2);
    expect(await db.list('b'), isEmpty);
    final confirmed = rows.singleWhere((n) => n.kind == 'confirmed');
    await db.markRead('b', confirmed.id, now);
    await db.delete('b', confirmed.id);
    expect((await db.find('a', confirmed.id))!.readAt, isNull);
    expect(await db.find('b', confirmed.id), isNull);
    await db.markAllRead('a', now);
    expect(
      (await db.list('a')).singleWhere((n) => n.kind == 'confirmed').readAt,
      isNotNull,
    );
    expect(
      (await db.list('a')).singleWhere((n) => n.kind == 'reminder').readAt,
      isNull,
    );
  });

  test('Deleted notices and manually canceled reminders do not reappear after reconciliation', () async {
    final db = store();
    await db.savePreferences('a', const ReminderPreferences(enabled: true));
    await db.reconcile('a', [state()], now);
    for (final n in await db.list('a')) {
      await db.delete('a', n.id);
    }
    await db.reconcile('a', [state()], now);
    expect(await db.list('a'), isEmpty);
    expect((await (await db.database).query('notifications')).length, 2);
  });

  test('Unconfirmed, canceled, checked-in and cancellation-pending games have no reminders', () async {
    for (final b in [
      state(confirmed: false),
      state(cancelled: true),
      state(suppressed: true),
    ]) {
      final db = store();
      await db.savePreferences('a', const ReminderPreferences(enabled: true));
      await db.reconcile('a', [b], now);
      expect((await db.list('a')).where((n) => n.kind == 'reminder'), isEmpty);
    }
  });

  test(
    'Rescheduling replaces pending reminder and generates one change notice',
    () async {
      final db = store();
      await db.savePreferences('a', const ReminderPreferences(enabled: true));
      await db.reconcile('a', [state()], now);
      final oldId = (await db.list('a'))
          .singleWhere((n) => n.kind == 'reminder')
          .id;
      final changed = state(revision: 1, start: DateTime(2026, 10, 21, 11));
      await db.reconcile('a', [changed], now);
      await db.reconcile('a', [changed], now);
      final rows = await db.list('a');
      expect(rows.where((n) => n.kind == 'changed').length, 1);
      expect(
        rows.singleWhere((n) => n.kind == 'reminder').scheduled,
        DateTime(2026, 10, 21, 10),
      );
      expect(await db.find('a', oldId), isNull);
      await db.reconcile('a', [state(revision: 1, cancelled: true)], now);
      expect((await db.list('a')).where((n) => n.kind == 'reminder'), isEmpty);
      expect(
        (await db.list('a')).where((n) => n.kind == 'cancelled').length,
        1,
      );
    },
  );

  test('Late confirmations and games already started never schedule reminders in the past', () async {
    final db = store();
    await db.savePreferences('a', const ReminderPreferences(enabled: true));
    await db.reconcile('a', [
      state(start: now.add(const Duration(minutes: 20))),
    ], now);
    expect((await db.list('a')).where((n) => n.kind == 'reminder'), isEmpty);
  });

  test(
    'Read state, preferences and deletion survive database reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sportmatch-notifications-test-',
      );
      final path = '${dir.path}/notifications.db';
      final a = NotificationStore(factory: databaseFactoryFfi, path: path);
      await a.savePreferences(
        'a',
        const ReminderPreferences(enabled: true, minutes: 15),
      );
      await a.reconcile('a', [state()], now);
      final first = (await a.list('a'))
          .singleWhere((n) => n.kind == 'confirmed');
      await a.markRead('a', first.id, now);
      await a.close();
      final b = NotificationStore(factory: databaseFactoryFfi, path: path);
      addTearDown(b.close);
      expect((await b.preferences('a')).minutes, 15);
      expect((await b.find('a', first.id))!.readAt, now);
      await b.delete('a', first.id);
      await b.reconcile('a', [state()], now);
      expect(await b.find('a', first.id), isNull);
    },
  );

  test(
    'SQLite transaction rolls back a partly written event on failure',
    () async {
      final db = store();
      await (await db.database).execute(
        "CREATE TRIGGER fail_state BEFORE INSERT ON booking_notice_states BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
      );
      await expectLater(
        db.reconcile('a', [state()], now),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.list('a'), isEmpty);
    },
  );

  test('Reminder preference validation rejects invalid times', () async {
    final db = store();
    await expectLater(
      db.savePreferences('a', const ReminderPreferences(minutes: -1)),
      throwsArgumentError,
    );
    expect((await db.preferences('a')).enabled, isFalse);
  });

  Future<
    ({
      DemoSession session,
      DemoBooking booking,
      NotificationCenter center,
      FakeReminderGateway gateway,
    })
  >
  setup() async {
    final s = DemoSession(now: () => now);
    final b = approveReminderBooking(s);
    final g = FakeReminderGateway();
    final c = NotificationCenter(
      session: s,
      store: memoryNoticeStore(),
      gateway: g,
    );
    c.start(periodic: false);
    await c.flush();
    addTearDown(() async {
      await c.shutdown();
      s.dispose();
    });
    return (session: s, booking: b, center: c, gateway: g);
  }

  test('Confirmed booking schedules once; mark read and refresh do not duplicate alarms', () async {
    final f = await setup();
    expect(f.center.notices.length, 1);
    await f.center.setPreferences(true, 60);
    expect(f.gateway.pending.length, 1);
    final n = f.gateway.pending.values.single;
    expect(n.scheduled, f.booking.start.subtract(const Duration(hours: 1)));
    final count = f.gateway.scheduledCalls;
    await f.center.markAllRead();
    await f.center.sync();
    expect(f.gateway.scheduledCalls, count);
    expect(f.center.unread, 0);
  });

  test('Logout cancels device reminders, clears visible rows, and never exposes another owner', () async {
    final f = await setup();
    await f.center.setPreferences(true, 60);
    final id = f.center.notices.first.id;
    f.session.logout();
    expect(f.center.notices, isEmpty);
    await f.center.flush();
    expect(f.gateway.pending, isEmpty);
    expect(await f.center.resolve(id), isNull);
    f.session.loginStaff(
      DemoRole.admin,
      DemoSession.adminEmail,
      DemoSession.password,
    );
    await f.center.flush();
    expect(f.center.notices, isEmpty);
    expect(await f.center.resolve(id), isNull);
  });

  test(
    'Permission denial leaves the SQLite inbox usable and allows retry',
    () async {
      final f = await setup();
      f.gateway.allowed = false;
      await f.center.setPreferences(true, 15);
      expect(f.center.permissionDenied, isTrue);
      expect(f.center.preferences.enabled, isFalse);
      expect(f.center.notices, isNotEmpty);
      expect(f.gateway.pending, isEmpty);
      f.gateway.allowed = true;
      await f.center.setPreferences(true, 15);
      expect(f.center.preferences.enabled, isTrue);
      expect(f.gateway.pending.length, 1);
    },
  );

  test('Account switch during permission prompt cannot enable or schedule for new account', () async {
    final f = await setup();
    final barrier = Completer<bool>();
    f.gateway.permissionBarrier = barrier;
    final saving = f.center.setPreferences(true, 15);
    await Future<void>.delayed(Duration.zero);
    f.session.logout();
    barrier.complete(true);
    await saving;
    await f.center.flush();
    expect(f.gateway.pending, isEmpty);
    expect(f.center.owner, isNull);
    expect(
      (await f.center.store.preferences(DemoSession.phone)).enabled,
      isFalse,
    );
  });

  test('Reschedule cancels old alarm and schedules the changed start after next customer login', () async {
    final f = await setup();
    await f.center.setPreferences(true, 60);
    final oldId = f.gateway.pending.keys.single;
    f.session.loginStaff(
      DemoRole.owner,
      DemoSession.ownerEmail,
      DemoSession.password,
    );
    f.session.rescheduleBooking(
      f.booking,
      court: 2,
      start: f.booking.start.add(const Duration(hours: 1)),
      expectedRevision: f.booking.revision,
    );
    f.session.login(DemoSession.phone, DemoSession.password);
    await f.center.flush();
    expect(f.gateway.pending.containsKey(oldId), isFalse);
    expect(
      f.gateway.pending.values.single.scheduled,
      f.booking.start.subtract(const Duration(hours: 1)),
    );
    expect(f.center.notices.where((n) => n.kind == 'changed').length, 1);
  });

  test(
    'Native scheduler failure reports an error and retries from persisted rows',
    () async {
      final f = await setup();
      f.gateway.failSchedule = true;
      await f.center.setPreferences(true, 60);
      expect(f.center.error, isNotNull);
      f.gateway.failSchedule = false;
      await f.center.sync();
      expect(f.center.error, isNull);
      expect(f.gateway.pending.length, 1);
    },
  );

  test(
    'OS tap resolves only a real row belonging to the current customer',
    () async {
      final f = await setup();
      await f.center.setPreferences(true, 60);
      InboxNotice? opened;
      f.center.onOpen = (row) => opened = row;
      f.gateway.tap!(f.gateway.pending.keys.single);
      await f.center.flush();
      expect(opened!.bookingId, f.booking.id);
      opened = null;
      f.gateway.tap!(999999);
      await f.center.flush();
      expect(opened, isNull);
    },
  );
  test('Cancellation request stops reminders, rejection restores them, approval cancels them', () async {
    final f = await setup();
    await f.center.setPreferences(true, 60);
    f.session.requestCancellation(
      f.booking,
      'Tôi có việc đột xuất không thể đến sân.',
    );
    await f.center.flush();
    expect(f.gateway.pending, isEmpty);
    f.session.loginStaff(
      DemoRole.owner,
      DemoSession.ownerEmail,
      DemoSession.password,
    );
    f.session.reviewCancellation(
      f.booking,
      approve: false,
      note: 'Cần bổ sung thông tin liên hệ.',
    );
    f.session.login(DemoSession.phone, DemoSession.password);
    await f.center.flush();
    expect(f.gateway.pending.length, 1);
    f.session.requestCancellation(
      f.booking,
      'Tôi đã bổ sung thông tin yêu cầu hủy lịch.',
    );
    f.session.loginStaff(
      DemoRole.owner,
      DemoSession.ownerEmail,
      DemoSession.password,
    );
    f.session.reviewCancellation(f.booking, approve: true);
    f.session.login(DemoSession.phone, DemoSession.password);
    await f.center.flush();
    expect(f.gateway.pending, isEmpty);
    expect(f.center.notices.where((n) => n.kind == 'cancelled').length, 1);
  });

  test(
    'Normal app shutdown preserves already scheduled native reminders',
    () async {
      final f = await setup();
      await f.center.setPreferences(true, 60);
      await f.center.shutdown();
      expect(f.gateway.pending.length, 1);
    },
  );
}
