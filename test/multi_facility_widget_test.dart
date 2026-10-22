import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/facility_booking_screen.dart';
import 'package:test_do_an/screens/facilities_screen.dart';
import 'package:test_do_an/screens/customer_checkout_screen.dart';
import 'package:test_do_an/screens/venue_browse_screen.dart';
import 'package:test_do_an/screens/calendar_screen.dart';

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
  DemoSession open() {
    final s = DemoSession(now: () => DateTime(2026, 10, 8, 10));
    addTearDown(s.dispose);
    publishTestFacility(s);
    s.login(DemoSession.phone, DemoSession.password);
    return s;
  }

  Future<GlobalKey> pump(WidgetTester t, Widget screen, double scale) async {
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
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Public facility entry books, displays real venue and joins history',
    (t) async {
      final s = open();
      await pump(t, PublicFacilityScreen(session: s, id: 'CS0001'), 1);
      await press(t, find.byKey(const Key('facility-book')));
      await press(t, find.byKey(const Key('facility-book-submit')));
      await t.scrollUntilVisible(
        find.byKey(const Key('checkout-terms')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await press(t, find.byKey(const Key('checkout-terms')));
      await press(t, find.byKey(const Key('booking-confirm')));
      expect(find.byType(CustomerCheckoutPaymentScreen), findsOneWidget);
      expect(find.text('Cơ sở đa sân'), findsOneWidget);
      expect(
        s.bookings.firstWhere((b) => b.facilityId == 'CS0001').total,
        150000,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Discovery opens the matching facility, not the primary demo venue',
    (t) async {
      final s = open();
      await pump(t, VenueBrowseScreen(session: s, title: 'Khám phá'), 1);
      await press(t, find.byKey(const Key('venue-result-CS0001')));
      expect(find.byType(PublicFacilityScreen), findsOneWidget);
      expect(find.text('Cơ sở đa sân'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Manager can reschedule court eight without primary pricing or court limits',
    (t) async {
      final s = open();
      final b = s.reserve(
        facilityId: 'CS0001',
        court: 8,
        start: DateTime(2026, 10, 9, 18),
        hours: 1,
        contact: 'Khách thử',
        contactPhone: DemoSession.phone,
        quotedRate: 150000,
      );
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await pump(
        t,
        CalendarEditorScreen(session: s, court: 8, start: b.start, booking: b),
        1,
      );
      await press(t, find.byKey(const Key('calendar-hour')));
      await press(t, find.text('19:00').last);
      await press(t, find.byKey(const Key('calendar-save')));
      await press(t, find.byKey(const Key('finance-confirm')));
      expect(b.start.hour, 19);
      expect(b.court, 8);
      expect(b.total, 150000);
      expect(t.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('Facility booking and independent slots fit $scale', (t) async {
      final s = open();
      final key = await pump(
        t,
        FacilityBookingScreen(session: s, id: 'CS0001'),
        scale,
      );
      await captureHome(key, 'facility-booking-$scale', t);
      expect(t.takeException(), isNull);
    });
  }
}
