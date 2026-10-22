import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/notifications/notification_center.dart';
import 'package:test_do_an/notifications/notification_models.dart';
import 'package:test_do_an/notifications/notification_scope.dart';
import 'package:test_do_an/notifications/notification_store.dart';
import 'package:test_do_an/screens/notification_inbox_screen.dart';
import 'package:test_do_an/screens/customer_checkout_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'notifications_test.dart'
    show FakeReminderGateway, approveReminderBooking;

class WidgetNoticeStore extends NotificationStore {
  final rows = <InboxNotice>[];
  final prefs = <String, ReminderPreferences>{};
  @override
  Future<void> reconcile(
    String owner,
    List<BookingNoticeState> bookings,
    DateTime now,
  ) async {}
  @override
  Future<List<InboxNotice>> list(String owner) async =>
      rows.where((n) => n.owner == owner).toList();
  @override
  Future<ReminderPreferences> preferences(String owner) async =>
      prefs[owner] ?? const ReminderPreferences();
  @override
  Future<void> savePreferences(String owner, ReminderPreferences p) async {
    prefs[owner] = p;
  }

  @override
  Future<InboxNotice?> find(String owner, int id) async =>
      rows.where((n) => n.owner == owner && n.id == id).firstOrNull;
  @override
  Future<void> markRead(String owner, int id, DateTime now) async {
    final i = rows.indexWhere((n) => n.owner == owner && n.id == id);
    if (i < 0) return;
    final n = rows[i];
    rows[i] = InboxNotice(
      id: n.id,
      owner: n.owner,
      bookingId: n.bookingId,
      kind: n.kind,
      title: n.title,
      body: n.body,
      created: n.created,
      scheduled: n.scheduled,
      readAt: now,
    );
  }

  @override
  Future<void> markAllRead(String owner, DateTime now) async {
    for (final n in rows.toList().where(
      (n) => n.owner == owner && n.due(now),
    )) {
      await markRead(owner, n.id, now);
    }
  }

  @override
  Future<void> delete(String owner, int id) async {
    rows.removeWhere((n) => n.owner == owner && n.id == id);
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  final now = DateTime(2026, 10, 20, 8);
  Future<({DemoSession s, NotificationCenter c, FakeReminderGateway g})>
  fixture() async {
    final s = DemoSession(now: () => now);
    final b = approveReminderBooking(s);
    final db = WidgetNoticeStore();
    db.prefs[DemoSession.phone] = const ReminderPreferences(enabled: true);
    for (final i in [1, 2, 3]) {
      db.rows.add(
        InboxNotice(
          id: i,
          owner: DemoSession.phone,
          bookingId: b.id,
          kind: i == 3
              ? 'reminder'
              : i == 1
              ? 'confirmed'
              : 'changed',
          title: i == 3
              ? 'Sắp đến giờ chơi'
              : i == 1
              ? 'Lịch đặt đã được xác nhận'
              : 'Lịch đặt đã thay đổi',
          body: 'Sân Cầu Lông Đại Học Công Thương · Sân 1\n21/10/2026 · 18:00',
          created: now,
          scheduled: i == 3 ? b.start.subtract(const Duration(hours: 1)) : null,
        ),
      );
    }
    final g = FakeReminderGateway();
    final c = NotificationCenter(session: s, store: db, gateway: g);
    c.start(periodic: false);
    await c.flush();
    return (s: s, c: c, g: g);
  }

  Widget app(
    DemoSession s,
    NotificationCenter c,
    GlobalKey key, {
    double scale = 1,
  }) => NotificationScope(
    center: c,
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Inter',
          colorSchemeSeed: const Color(0xFF00AB60),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: NotificationInboxScreen(session: s),
      ),
    ),
  );
  Future<void> reveal(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        180,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  for (final view in [(320.0, 2.0), (402.0, 1.0), (1200.0, 1.0)]) {
    testWidgets('Inbox and settings fit ${view.$1}/${view.$2}', (t) async {
      t.view.physicalSize = Size(view.$1, 950);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final f = await fixture(), key = GlobalKey();
      await t.pumpWidget(app(f.s, f.c, key, scale: view.$2));
      await t.pumpAndSettle();
      expect(find.text('Chưa đọc (2)'), findsOneWidget);
      expect(t.takeException(), isNull);
      await captureHome(key, 'notification_inbox_${view.$1.toInt()}', t);
      await t.tap(find.byKey(const Key('notification-settings')));
      await t.pumpAndSettle();
      expect(find.text('Cài đặt nhắc lịch'), findsOneWidget);
      expect(t.takeException(), isNull);
      await captureHome(key, 'notification_settings_${view.$1.toInt()}', t);
      await t.pumpWidget(const SizedBox());
      await f.c.shutdown();
      f.s.dispose();
    });
  }

  testWidgets(
    'Mark all read updates the unread tab and deleting requires confirmation',
    (t) async {
      final f = await fixture();
      await t.pumpWidget(app(f.s, f.c, GlobalKey()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('notification-mark-all')));
      await t.pumpAndSettle();
      expect(f.c.unread, 0);
      expect(find.text('Chưa đọc (0)'), findsOneWidget);
      final delete = find.byKey(const Key('notification-delete-1'));
      await reveal(t, delete);
      await t.tap(delete);
      await t.pumpAndSettle();
      expect(f.c.notices.any((n) => n.id == 1), isTrue);
      await t.tap(find.byKey(const Key('notification-delete-confirm')));
      await t.pumpAndSettle();
      expect(f.c.notices.any((n) => n.id == 1), isFalse);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await f.c.shutdown();
      f.s.dispose();
    },
  );

  testWidgets('Upcoming reminder can be canceled from its own tab', (t) async {
    final f = await fixture();
    await t.pumpWidget(app(f.s, f.c, GlobalKey()));
    await t.pumpAndSettle();
    await t.tap(find.text('Lịch nhắc'));
    await t.pumpAndSettle();
    expect(find.text('Sắp đến giờ chơi'), findsOneWidget);
    await t.tap(find.byKey(const Key('notification-delete-3')));
    await t.pumpAndSettle();
    expect(find.text('Hủy lịch nhắc này?'), findsOneWidget);
    await t.tap(find.byKey(const Key('notification-delete-confirm')));
    await t.pumpAndSettle();
    expect(f.g.pending, isEmpty);
    expect(find.text('Chưa có lịch nhắc.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await f.c.shutdown();
    f.s.dispose();
  });

  testWidgets('Tapping a notice marks it read and opens its actual booking', (
    t,
  ) async {
    final f = await fixture();
    await t.pumpWidget(app(f.s, f.c, GlobalKey()));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('notification-1')));
    await t.pumpAndSettle();
    expect(find.byType(CustomerCheckoutDetailScreen), findsOneWidget);
    expect(f.c.notices.singleWhere((n) => n.id == 1).readAt, isNotNull);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await f.c.shutdown();
    f.s.dispose();
  });

  testWidgets(
    'Logging out hides private notification bodies and settings immediately',
    (t) async {
      final f = await fixture();
      await t.pumpWidget(app(f.s, f.c, GlobalKey()));
      await t.pumpAndSettle();
      f.s.logout();
      await t.pumpAndSettle();
      expect(find.text('Lịch đặt đã được xác nhận'), findsNothing);
      expect(find.byKey(const Key('notification-settings')), findsNothing);
      expect(f.g.pending, isEmpty);
      expect(find.text('Đăng nhập'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await f.c.shutdown();
      f.s.dispose();
    },
  );
}
