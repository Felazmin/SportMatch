import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/customer_checkout_screen.dart';
import 'package:test_do_an/screens/facility_booking_screen.dart';

import 'multi_facility_test.dart' show publishTestFacility;
import 'persistence_test.dart' show TestSessionStore;
import 'home_accessibility_test.dart' show captureHome;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  Future<DemoSession> session(TestSessionStore store, bool facility) async {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 8, 10));
    addTearDown(s.dispose);
    await s.initialize();
    if (facility) publishTestFacility(s);
    s.login(DemoSession.phone, DemoSession.password);
    await s.flush();
    return s;
  }

  Future<void> open(WidgetTester t, DemoSession s, bool facility) async {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
    await t.pumpWidget(
      MaterialApp(
        home: facility
            ? FacilityBookingScreen(session: s, id: 'CS0001')
            : CustomerCheckoutConfirmScreen(
                session: s,
                court: 2,
                start: DateTime(2026, 10, 9, 12),
                hours: 1,
              ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> submit(
    WidgetTester t,
    bool facility, {
    bool settle = true,
  }) async {
    var f = find.byKey(
      Key(facility ? 'facility-book-submit' : 'booking-confirm'),
    );
    if (facility) {
      await t.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    if (facility) {
      await t.pumpAndSettle();
      f = find.byKey(const Key('booking-confirm'));
    }
    await t.pumpAndSettle();
    final terms = find.byKey(const Key('checkout-terms'));
    await t.scrollUntilVisible(
      terms,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(terms);
    await t.pumpAndSettle();
    await t.tap(terms);
    await t.pumpAndSettle();
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
    }
  }

  for (final facility in [false, true]) {
    final label = facility ? 'facility' : 'primary';
    testWidgets('$label pending save fits 320px at 200 percent text', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 879);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final store = TestSessionStore();
      final s = await session(store, facility);
      final key = GlobalKey();
      await t.pumpWidget(const MyApp());
      await t.pumpAndSettle();
      final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: facility
                ? FacilityBookingScreen(session: s, id: 'CS0001')
                : CustomerCheckoutConfirmScreen(
                    session: s,
                    court: 2,
                    start: DateTime(2026, 10, 9, 12),
                    hours: 1,
                  ),
          ),
        ),
      );
      await t.pumpAndSettle();
      store.failWrite = true;
      await submit(t, facility);
      await t.scrollUntilVisible(
        find.textContaining('Đơn đã tạo nhưng chưa lưu được'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await captureHome(key, 'booking-save-$label-2.0', t);
      expect(find.text('Thử lưu lại'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets(
      '$label failed save retries one booking and restores its contract',
      (t) async {
        final store = TestSessionStore();
        final s = await session(store, facility);
        final count = s.bookings.length;
        final ids = s.bookings.map((b) => b.id).toSet();
        await open(t, s, facility);
        store.failWrite = true;
        await submit(t, facility);
        expect(find.byType(CustomerCheckoutPaymentScreen), findsNothing);
        expect(find.text('Thử lưu lại'), findsOneWidget);
        await t.scrollUntilVisible(
          find.textContaining('Đơn đã tạo nhưng chưa lưu được'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.textContaining('Đơn đã tạo nhưng chưa lưu được'),
          findsOneWidget,
        );
        expect(s.bookings.length, count + 1);
        final b = s.bookings.singleWhere((b) => !ids.contains(b.id));
        final id = b.id;
        final rates = b.hourlyRates;
        final total = b.total;
        store.failWrite = false;
        final retry = find.text('Thử lưu lại');
        await t.ensureVisible(retry);
        await t.pumpAndSettle();
        await t.tap(retry);
        await t.pumpAndSettle();
        expect(find.byType(CustomerCheckoutPaymentScreen), findsOneWidget);
        expect(s.bookings.length, count + 1);
        final restored = DemoSession(
          store: store,
          now: () => DateTime(2026, 10, 8, 10),
        );
        addTearDown(restored.dispose);
        await restored.initialize();
        expect(restored.bookings.length, count + 1);
        final saved = restored.bookings.singleWhere((b) => b.id == id);
        expect(saved.hourlyRates, rates);
        expect(saved.total, total);
        expect(saved.facilityId, facility ? 'CS0001' : '');
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('$label account changed before submit creates no booking', (
      t,
    ) async {
      final store = TestSessionStore();
      final s = await session(store, facility);
      await open(t, s, facility);
      s.register('Other player', 'other@example.com', 'Test1234');
      await s.flush();
      final count = s.bookings.length;
      final f = find.byKey(
        Key(facility ? 'facility-book-submit' : 'booking-confirm'),
      );
      if (facility) {
        await t.scrollUntilVisible(
          f,
          150,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
      expect(s.bookings.length, count);
      await t.scrollUntilVisible(
        find.textContaining('Tài khoản đã thay đổi'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Tài khoản đã thay đổi'), findsOneWidget);
      expect(find.byType(CustomerCheckoutPaymentScreen), findsNothing);
    });

    testWidgets(
      '$label account changed during save cannot display another players booking',
      (t) async {
        final store = TestSessionStore();
        final s = await session(store, facility);
        await open(t, s, facility);
        final gate = Completer<void>();
        store.beforeWrite = () => gate.future;
        await submit(t, facility, settle: false);
        s.register('Other player', 'other@example.com', 'Test1234');
        gate.complete();
        await t.pumpAndSettle();
        expect(find.byType(CustomerCheckoutPaymentScreen), findsNothing);
        await t.scrollUntilVisible(
          find.textContaining('Tài khoản đã thay đổi'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('Tài khoản đã thay đổi'), findsOneWidget);
        expect(s.bookings, isEmpty);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('$label disposed screen does not navigate after delayed save', (
      t,
    ) async {
      final store = TestSessionStore();
      final s = await session(store, facility);
      await open(t, s, facility);
      final gate = Completer<void>();
      store.beforeWrite = () => gate.future;
      await submit(t, facility, settle: false);
      await t.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: const Scaffold(body: Text('Closed')),
        ),
      );
      gate.complete();
      await t.pumpAndSettle();
      expect(find.text('Closed'), findsOneWidget);
      expect(find.byType(CustomerCheckoutPaymentScreen), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
