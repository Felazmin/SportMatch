import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/demo/demo_operations.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/owner_booking_views.dart';
import 'package:test_do_an/screens/owner_prices_view.dart';
import 'package:test_do_an/screens/calendar_screen.dart';
import 'package:test_do_an/screens/workflow_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'multi_facility_test.dart' show publishTestFacility;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession owner() {
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 8));
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    addTearDown(s.dispose);
    return s;
  }

  DemoBooking booking(DemoSession s, {int court = 2, int hour = 10}) =>
      s.manualReservation(
        customer: DemoSession.phone,
        court: court,
        start: DateTime(2026, 10, 10, hour),
        hours: 1,
        contact: 'Nguyễn Minh Anh',
        contactPhone: DemoSession.phone,
        quotedRate: s.courtRate(court),
      );
  Future<GlobalKey> pump(
    WidgetTester t,
    Widget view, {
    double width = 402,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: view,
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final e in find.byType(Image).evaluate().toList()) {
      await t.runAsync(() => precacheImage((e.widget as Image).image, e));
    }
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.scrollUntilVisible(
      f,
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final layout in [(402.0, 1.0), (320.0, 2.0)]) {
    for (final name in ['calendar', 'detail', 'revenue', 'prices']) {
      testWidgets('$name fits ${layout.$1}/${layout.$2}', (t) async {
        final s = owner();
        final actual = booking(s);
        if (name == 'revenue') s.confirmVenuePayment(actual);
        s.blockCourt(
          court: 3,
          start: DateTime(2026, 10, 10, 10),
          hours: 2,
          reason: 'Bảo trì mặt sân',
        );
        final view = switch (name) {
          'calendar' => OwnerCalendarView(session: s),
          'detail' => OwnerBookingView(session: s, id: actual.id),
          'revenue' => OwnerRevenueView(session: s),
          _ => OwnerPricesView(session: s),
        };
        final boundary = await pump(
          t,
          view,
          width: layout.$1,
          scale: layout.$2,
        );
        expect(t.takeException(), isNull);
        await captureHome(
          boundary,
          'owner-four-$name-${layout.$1.toInt()}-${layout.$2}',
          t,
        );
        final scroll = find.byType(Scrollable).first;
        for (var i = 0; i < 12; i++) {
          await t.drag(scroll, const Offset(0, -300));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          boundary,
          'owner-four-$name-bottom-${layout.$1.toInt()}-${layout.$2}',
          t,
        );
        await t.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Calendar opens booking and free cell editor', (t) async {
    final s = owner();
    booking(s);
    await pump(t, OwnerCalendarView(session: s));
    await t.tap(find.byKey(const Key('calendar-slot-2-10')));
    await t.pumpAndSettle();
    expect(find.byType(OwnerBookingView), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('calendar-slot-3-10')));
    await t.pumpAndSettle();
    expect(find.byType(CalendarEditorScreen), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Confirm payment requires confirmation and updates actual booking',
    (t) async {
      final s = owner();
      final actual = booking(s);
      await pump(
        t,
        WorkflowDetailScreen(
          session: s,
          id: actual.id,
          ownerPresentation: true,
        ),
      );
      await press(t, 'owner-booking-confirm');
      expect(s.paymentFor(actual), isNull);
      await t.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await t.pumpAndSettle();
      expect(s.paymentFor(actual)?.state, DemoPaymentState.approved);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Prices submits weekday and weekend without changing published rates',
    (t) async {
      final s = owner();
      final old = s.publishedCourts;
      await pump(t, OwnerPricesView(session: s));
      await t.enterText(
        find.byKey(const Key('owner-prices-weekday')),
        '100000',
      );
      await t.enterText(
        find.byKey(const Key('owner-prices-weekend')),
        '120000',
      );
      await press(t, 'owner-prices-save');
      await t.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await t.pumpAndSettle();
      expect(s.courtReviewState, 'pending');
      expect(s.publishedCourts, same(old));
      expect(s.draftCourts!.tariffs.length, 2);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Edit existing band preserves surcharge and creates no overlap', (
    t,
  ) async {
    final s = owner();
    s.submitCourtSettings(
      CourtSettings(
        rates: s.publishedCourts.rates,
        enabled: s.publishedCourts.enabled,
        tariffs: [
          for (final weekend in [false, true])
            CourtTariff(
              court: 1,
              weekend: weekend,
              fromHour: 6,
              toHour: 11,
              rate: 120000,
              effectiveFrom: DateTime(2026, 10, 9),
              surcharge: 5000,
            ),
        ],
      ),
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.reviewCourtSettings(approve: true);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await pump(t, OwnerPricesView(session: s));
    await press(t, 'owner-prices-band-0');
    await t.ensureVisible(find.byKey(const Key('owner-prices-weekday')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('owner-prices-weekday')), '100000');
    await press(t, 'owner-prices-save');
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.draftCourts!.tariffs.length, 2);
    expect(s.draftCourts!.tariffs.first.quotedRate, 105000);
    expect(s.publishedCourts.tariffs.first.quotedRate, 125000);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('Invalid prices do not create pending proposal', (t) async {
    final s = owner();
    await pump(t, OwnerPricesView(session: s));
    await t.enterText(find.byKey(const Key('owner-prices-weekday')), 'abc');
    await press(t, 'owner-prices-save');
    expect(s.courtReviewState, 'none');
    expect(find.byKey(const Key('owner-prices-error')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('Revenue includes only receipts from selected facility', (
    t,
  ) async {
    final s = owner();
    final f = publishTestFacility(s);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    final a = booking(s);
    s.confirmVenuePayment(a);
    final b = s.manualReservation(
      customer: DemoSession.phone,
      court: 1,
      start: DateTime(2026, 10, 10, 12),
      hours: 1,
      contact: 'Khách cơ sở hai',
      contactPhone: DemoSession.phone,
      quotedRate: f.published!.baseRate,
      facilityId: f.id,
    );
    s.confirmVenuePayment(b);
    await pump(t, OwnerRevenueView(session: s, facilityId: f.id));
    expect(
      t.widget<Text>(find.byKey(const Key('cashflow-received'))).data,
      bookingMoney(b.total),
    );
    await t.tap(find.byType(DropdownButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.text(DemoBooking.venue).last);
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('cashflow-received'))).data,
      bookingMoney(a.total),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Role switch during payment confirmation does not mutate booking',
    (t) async {
      final s = owner();
      final b = booking(s);
      await pump(t, OwnerBookingView(session: s, id: b.id));
      await press(t, 'owner-booking-confirm');
      s.login(DemoSession.phone, DemoSession.password);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(s.paymentFor(b), isNull);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Role switch during tariff confirmation does not submit', (
    t,
  ) async {
    final s = owner();
    await pump(t, OwnerPricesView(session: s));
    await press(t, 'owner-prices-save');
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    expect(s.courtReviewState, 'none');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
