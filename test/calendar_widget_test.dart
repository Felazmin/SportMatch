import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/calendar_screen.dart';
import 'package:test_do_an/screens/workflow_screen.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 7, 10), day = DateTime(2026, 10, 8, 10);
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession session([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    if (store == null) {
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
    }
    return s;
  }

  Future<GlobalKey> pump(WidgetTester t, Widget w, {double scale = 1}) async {
    t.view.physicalSize = Size(scale == 1 ? 402 : 320, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
    await t.pumpAndSettle();
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: w,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'Free grid cell opens manual reservation and saves to player account',
    (t) async {
      final s = session();
      await pump(t, CalendarScreen(session: s));
      await press(t, 'calendar-slot-2-10');
      expect(find.byType(CalendarEditorScreen), findsOneWidget);
      await press(t, 'calendar-save');
      expect(s.managedBookings.length, 2);
      await press(t, 'finance-confirm');
      expect(s.managedBookings.length, 3);
      await press(t, 'calendar-close');
      expect(find.byType(CalendarEditorScreen), findsNothing);
      s.login(DemoSession.phone, DemoSession.password);
      expect(s.bookings.any((b) => b.court == 2 && b.start == day), isTrue);
      await finish(t);
    },
  );
  testWidgets(
    'Lock mode saves block; opening locked cell requires unlock confirmation',
    (t) async {
      final s = session();
      await pump(t, CalendarScreen(session: s));
      await press(t, 'calendar-mode-block');
      await t.enterText(
        find.byKey(const Key('calendar-reason')),
        'Bảo trì mặt sân',
      );
      await press(t, 'calendar-save');
      await press(t, 'finance-confirm');
      final block = s.courtBlocks.single;
      expect(s.available(block.court, block.start, 1), isFalse);
      await press(t, 'calendar-close');
      await press(t, 'calendar-slot-${block.court}-${block.start.hour}');
      expect(s.courtBlocks.length, 1);
      await press(t, 'finance-confirm');
      expect(s.courtBlocks, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'Failed save retains committed form; retry never creates duplicate booking',
    (t) async {
      final store = TestSessionStore();
      final live = session(store);
      await live.initialize();
      live.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      store.failWrite = true;
      await pump(t, CalendarEditorScreen(session: live, court: 2, start: day));
      await press(t, 'calendar-save');
      await press(t, 'finance-confirm');
      expect(live.managedBookings.length, 3);
      expect(find.byKey(const Key('calendar-save')), findsNothing);
      store.failWrite = false;
      await press(t, 'finance-retry-save');
      expect(live.managedBookings.length, 3);
      expect(live.saveFailed, isFalse);
      await finish(t);
    },
  );
  testWidgets('Stale reschedule form cannot overwrite a newer staff change', (
    t,
  ) async {
    final s = session();
    final b = s.managedBookings.first;
    await pump(
      t,
      CalendarEditorScreen(
        session: s,
        court: b.court,
        start: b.start,
        booking: b,
      ),
    );
    s.rescheduleBooking(b, court: 2, start: day, expectedRevision: 0);
    await t.pumpAndSettle();
    await press(t, 'calendar-save');
    await press(t, 'finance-confirm');
    expect(find.byKey(const Key('calendar-error')), findsOneWidget);
    expect(b.revision, 1);
    expect(b.court, 2);
    await finish(t);
  });
  testWidgets(
    'Player editor and calendar deny access without throwing in init',
    (t) async {
      final s = session();
      s.login(DemoSession.phone, DemoSession.password);
      await pump(t, CalendarEditorScreen(session: s, court: 2, start: day));
      expect(find.text('Không có quyền truy cập.'), findsOneWidget);
      await finish(t);
      await pump(t, CalendarScreen(session: s));
      expect(find.text('Không có quyền truy cập.'), findsOneWidget);
      await finish(t);
    },
  );
  testWidgets('Manual customer menu accepts long names at 200-percent text', (
    t,
  ) async {
    final s = session();
    s.register(
      'Khách hàng với tên khá dài để kiểm tra màn hình nhỏ',
      'long-customer@example.com',
      'Test1234',
    );
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await pump(
      t,
      CalendarEditorScreen(session: s, court: 2, start: day),
      scale: 2,
    );
    await press(t, 'calendar-customer');
    final f = find.textContaining('Khách hàng với tên khá dài').last;
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await finish(t);
  });
  testWidgets('Onsite UI confirms a payment once without choosing an image', (
    t,
  ) async {
    final s = session();
    final b = s.managedBookings.first;
    await pump(t, WorkflowDetailScreen(session: s, id: b.id));
    await press(t, 'calendar-onsite');
    expect(s.paymentFor(b), isNull);
    await press(t, 'finance-confirm');
    expect(s.paymentFor(b)!.atVenue, isTrue);
    expect(s.paymentFor(b)!.state, DemoPaymentState.approved);
    expect(find.byKey(const Key('calendar-onsite')), findsNothing);
    await finish(t);
  });
  for (final view in ['grid', 'manual', 'block', 'reschedule', 'onsite']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$view calendar fits ${scale == 1 ? 402 : 320}px text $scale',
        (t) async {
          final s = session();
          s.blockCourt(
            court: 2,
            start: day,
            hours: 2,
            reason: 'Bảo trì mặt sân và kiểm tra thiết bị',
          );
          final b = s.managedBookings.first;
          final w = switch (view) {
            'grid' => CalendarScreen(session: s),
            'manual' => CalendarEditorScreen(session: s, court: 3, start: day),
            'block' => CalendarEditorScreen(
              session: s,
              court: 3,
              start: day,
              locking: true,
            ),
            'reschedule' => CalendarEditorScreen(
              session: s,
              court: b.court,
              start: b.start,
              booking: b,
            ),
            _ => WorkflowDetailScreen(session: s, id: b.id),
          };
          final key = await pump(t, w, scale: scale);
          await captureHome(
            key,
            'calendar-$view-${scale == 1 ? 'normal' : 'large'}',
            t,
          );
          for (var i = 0; i < 8; i++) {
            await t.drag(find.byType(ListView).first, const Offset(0, -350));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          }
          if (view == 'grid') {
            await t.drag(find.byType(ListView).first, const Offset(0, 4000));
            await t.pumpAndSettle();
            await t.drag(
              find.byKey(const Key('owner-calendar-grid')),
              const Offset(-1800, 0),
            );
            await t.pumpAndSettle();
            await t.ensureVisible(find.byKey(const Key('calendar-slot-3-21')));
            await t.pumpAndSettle();
            final visible = t.getCenter(
              find.byKey(const Key('calendar-slot-3-21')),
            );
            expect(visible.dx, lessThan(t.view.physicalSize.width));
            expect(t.takeException(), isNull);
          }
          await finish(t);
        },
      );
    }
  }
}
