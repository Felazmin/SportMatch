import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/screens/venue_claims_screen.dart';
import 'package:test_do_an/screens/facilities_screen.dart';
import 'package:test_do_an/screens/customer_venue_detail_screen.dart';
import 'package:test_do_an/screens/facility_booking_screen.dart';
import 'package:test_do_an/screens/customer_checkout_screen.dart';
import 'package:test_do_an/venues/osm_venue_catalog.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'claimed_venue_activation_test.dart' show activationProfile;
import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;
import 'venue_claims_test.dart'
    show
        claimVenueId,
        loginClaimOwner,
        loginClaimAdmin,
        submitTestClaim,
        reviewTestClaim;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<VenueSummary> catalog;
  late Uint8List photo;
  setUpAll(() async {
    catalog = await loadOsmVenues();
    photo = (await rootBundle.load('assets/figma/c0697.png')).buffer
        .asUint8List();
    for (final font in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  Future<DemoSession> open() async {
    final s = DemoSession(
      store: TestSessionStore(),
      venueCatalogLoader: () async => catalog,
      now: () => DateTime(2026, 10, 20, 10),
    );
    await s.initialize();
    loginClaimOwner(s);
    submitTestClaim(s, proof: base64Encode(photo));
    loginClaimAdmin(s);
    reviewTestClaim(s);
    loginClaimOwner(s);
    return s;
  }

  DemoFacility publish(DemoSession s) {
    final p = FacilityProfile.fromJson({
      ...activationProfile().toJson(),
      'photo': base64Encode(photo),
      'legalProof': base64Encode(photo),
    });
    final f = s.saveFacility(
      p,
      sourceVenueId: claimVenueId,
      expectedClaimRevision: 2,
    );
    s.submitFacility(f);
    loginClaimAdmin(s);
    s.reviewFacility(f, approve: true);
    s.login(DemoSession.phone, DemoSession.password);
    return f;
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 70,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String value) async {
    final target = find.byKey(Key(key));
    await reveal(tester, target);
    await tester.enterText(target, value);
    await tester.pumpAndSettle();
  }

  Widget app(Widget child, {double scale = 1, GlobalKey? capture}) =>
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Inter', colorSchemeSeed: Colors.green),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      );
  for (final view in [(320.0, 2.0), (402.0, 1.0)]) {
    testWidgets(
      'Approved claim opens prefilled operational form at ${view.$1}/${view.$2}',
      (tester) async {
        tester.view.physicalSize = Size(view.$1, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = await open();
        final capture = GlobalKey();
        await tester.pumpWidget(
          app(
            VenueClaimScreen(session: s, venueId: claimVenueId),
            scale: view.$2,
            capture: capture,
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const Key('venue-claim-configure'));
        await reveal(tester, button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(FacilityFormScreen), findsOneWidget);
        final name = find.byKey(const Key('facility-field-name'));
        expect(
          tester.widget<TextFormField>(name).controller!.text,
          'Pickleball 426',
        );
        await captureHome(
          capture,
          'claimed_venue_form_${view.$1.toInt()}',
          tester,
        );
        final bank = find.byKey(const Key('facility-bank-number'));
        await reveal(tester, bank);
        expect(find.text('Tài khoản nhận tiền mô phỏng'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await captureHome(
          capture,
          'claimed_venue_bank_${view.$1.toInt()}',
          tester,
        );
        await tester.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  }

  testWidgets(
    'Owner submits a complete linked form without duplicating the OSM venue',
    (tester) async {
      tester.view.physicalSize = const Size(402, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await open();
      await tester.pumpWidget(
        app(
          FacilityFormScreen(
            session: s,
            claimVenueId: claimVenueId,
            pickImage: () async => photo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await type(tester, 'facility-field-district', 'Bình Lợi Trung');
      await type(tester, 'facility-field-courtCount', '2');
      await type(tester, 'facility-field-baseRate', '160000');
      for (final key in ['facility-photo', 'facility-legal']) {
        final button = find.byKey(Key(key));
        await reveal(tester, button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }
      await type(tester, 'facility-bank-bank', 'Ngân hàng mô phỏng');
      await type(tester, 'facility-bank-holder', 'NGUYEN VAN HUNG');
      await type(tester, 'facility-bank-number', '123');
      final submit = find.byKey(const Key('facility-submit-application'));
      await reveal(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(s.managedFacilities, isEmpty);
      expect(find.text('Số tài khoản cần 6–24 chữ số.'), findsOneWidget);
      await type(tester, 'facility-bank-number', '0000000000');
      await reveal(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(s.managedFacilities.length, 1);
      expect(s.managedFacilities.single.state, 'pending');
      expect(s.managedFacilities.single.sourceVenueId, claimVenueId);
      expect(
        s.currentVenues.singleWhere((v) => v.id == claimVenueId).bookingEnabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );

  testWidgets(
    'Customer opens published OSM venue and reaches the correct facility calendar',
    (tester) async {
      tester.view.physicalSize = const Size(402, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await open(), capture = GlobalKey();
      final f = publish(s);
      await tester.pumpWidget(
        app(
          CustomerVenueDetailScreen(session: s, venueId: claimVenueId),
          capture: capture,
        ),
      );
      await tester.pumpAndSettle();
      await captureHome(capture, 'claimed_venue_customer_detail', tester);
      await tester.tap(find.byKey(const Key('customer-detail-book')));
      await tester.pumpAndSettle();
      expect(find.text('HÌNH THỨC ĐẶT SÂN'), findsOneWidget);
      await tester.tap(find.text('Đặt lịch theo sân'));
      await tester.pumpAndSettle();
      expect(find.byType(FacilityBookingScreen), findsOneWidget);
      expect(
        tester
            .widget<FacilityBookingScreen>(find.byType(FacilityBookingScreen))
            .id,
        f.id,
      );
      expect(tester.takeException(), isNull);
      await captureHome(capture, 'claimed_venue_customer_calendar', tester);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );

  testWidgets('Checkout shows the configured masked demo bank account', (
    tester,
  ) async {
    final s = await open();
    final f = publish(s);
    final b = s.reserve(
      facilityId: f.id,
      court: 1,
      start: DateTime(2026, 10, 21, 9),
      hours: 1,
      contact: 'Minh Phát',
      contactPhone: DemoSession.phone,
    );
    s.startTransfer(b, checkout: true);
    await tester.pumpWidget(
      app(CustomerCheckoutPaymentScreen(session: s, booking: b)),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Ngân hàng mô phỏng'));
    expect(find.text('•••• 0000'), findsOneWidget);
    expect(find.text('0000000000'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
