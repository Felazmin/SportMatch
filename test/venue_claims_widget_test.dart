import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';
import 'package:test_do_an/screens/owner_management_views.dart';
import 'package:test_do_an/screens/osm_venue_detail_screen.dart';
import 'package:test_do_an/screens/venue_claims_screen.dart';
import 'package:test_do_an/venues/osm_venue_catalog.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;
import 'venue_claims_test.dart'
    show claimVenueId, loginClaimOwner, loginClaimAdmin, submitTestClaim;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<VenueSummary> venues;
  late Uint8List proof;
  setUpAll(() async {
    venues = await loadOsmVenues();
    final bytes = await rootBundle.load('assets/figma/c0697.png');
    proof = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  Future<DemoSession> open(WidgetTester t) async {
    final s = DemoSession(
      store: TestSessionStore(),
      venueCatalogLoader: () async => venues,
      now: () => DateTime(2026, 10, 19, 12),
    );
    addTearDown(s.dispose);
    await s.initialize();
    loginClaimOwner(s);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen,
    double width,
    double scale,
  ) async {
    t.view.physicalSize = Size(width, 950);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Inter',
            colorSchemeSeed: const Color(0xff00ad62),
          ),
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<Finder> reveal(WidgetTester t, String id) async {
    final f = find.byKey(Key(id));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        180,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    return f;
  }

  Future<void> enter(WidgetTester t, String id, String value) async {
    await t.enterText(await reveal(t, id), value);
    await t.pumpAndSettle();
  }

  Future<void> press(WidgetTester t, String id) async {
    final f = await reveal(t, id);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final size in [(402.0, 1.0), (320.0, 2.0), (1200.0, 1.0)]) {
    testWidgets('Owner submission and Admin approval at $size', (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final s = await open(t);
      final formKey = await pump(
        t,
        VenueClaimScreen(
          session: s,
          venueId: claimVenueId,
          pickImage: () async => proof,
        ),
        size.$1,
        size.$2,
      );
      await t.enterText(
        find.byKey(const Key('venue-claim-contact')),
        'Nguyễn Văn Hùng',
      );
      await t.enterText(
        find.byKey(const Key('venue-claim-phone')),
        DemoSession.phone,
      );
      await t.enterText(
        find.byKey(const Key('venue-claim-explanation')),
        'Tôi là người đại diện được ủy quyền quản lý cơ sở này.',
      );
      await press(t, 'venue-claim-proof');
      await t.runAsync(
        () => precacheImage(
          t.widget<Image>(find.byType(Image)).image,
          t.element(find.byType(VenueClaimScreen)),
        ),
      );
      await t.pumpAndSettle();
      await captureHome(formKey, 'venue-claim-form-${size.$1}-${size.$2}', t);
      await press(t, 'venue-claim-submit');
      await press(t, 'finance-confirm');
      expect(s.venueClaims.single.state, 'pending');
      expect(t.takeException(), isNull);

      loginClaimAdmin(s);
      await pump(t, ApprovalCenterScreen(session: s), size.$1, size.$2);
      // The history link remains available after the request leaves the pending queue.
      await press(t, 'admin-venue-claims');
      expect(find.text('Pickleball 426'), findsOneWidget);
      await t.tap(find.text('Pickleball 426'));
      await t.pumpAndSettle();
      await enter(t, 'venue-claim-password', DemoSession.password);
      await press(t, 'venue-claim-approve');
      await press(t, 'finance-confirm');
      expect(s.venueClaims.single.state, 'approved');
      expect(t.takeException(), isNull);
      loginClaimOwner(s);
      final statusKey = await pump(
        t,
        VenueClaimScreen(session: s, venueId: claimVenueId),
        size.$1,
        size.$2,
      );
      if (find.byType(Image).evaluate().isNotEmpty) {
        await t.runAsync(
          () => precacheImage(
            t.widget<Image>(find.byType(Image)).image,
            t.element(find.byType(VenueClaimScreen)),
          ),
        );
      }
      await t.pumpAndSettle();
      await captureHome(
        statusKey,
        'venue-claim-approved-${size.$1}-${size.$2}',
        t,
      );
      expect(find.text('Đã duyệt quyền quản lý'), findsOneWidget);
      expect(find.byKey(const Key('venue-claim-submit')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'Owner entry points, catalog search, withdrawal and private evidence',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final s = await open(t);
      await pump(t, OwnerFacilitiesView(session: s), 402, 1);
      await press(t, 'owner-venue-claims');
      await t.tap(find.text('Sân có sẵn'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('venue-claims-search')),
        '426 binh loi',
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('claim-catalog-$claimVenueId')),
        findsOneWidget,
      );
      submitTestClaim(s, proof: base64Encode(proof));
      await pump(
        t,
        VenueClaimScreen(session: s, venueId: claimVenueId),
        402,
        1,
      );
      await press(t, 'venue-claim-withdraw');
      await press(t, 'finance-confirm');
      expect(s.venueClaims.single.state, 'withdrawn');
      expect(find.byKey(const Key('venue-claim-submit')), findsOneWidget);
      final venue = venues.singleWhere((v) => v.id == claimVenueId);
      await pump(t, OsmVenueDetailScreen(session: s, venue: venue), 402, 1);
      await press(t, 'osm-claim-venue');
      expect(find.byType(VenueClaimScreen), findsOneWidget);
      s.login(DemoSession.phone, DemoSession.password);
      await t.pumpAndSettle();
      expect(find.text('Không có quyền xem hồ sơ.'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Owner catalog tabs fit narrow display with large text', (
    t,
  ) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final s = await open(t);
    final key = await pump(t, VenueClaimsScreen(session: s), 320, 2);
    await t.tap(find.text('Sân có sẵn'));
    await t.pumpAndSettle();
    await enter(t, 'venue-claims-search', '426');
    await captureHome(key, 'venue-claim-catalog-320-2', t);
    expect(
      find.byKey(const Key('claim-catalog-$claimVenueId')),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Admin queue opens a claim and rejection reaches the owner', (
    t,
  ) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final s = await open(t);
    submitTestClaim(s, proof: base64Encode(proof));
    loginClaimAdmin(s);
    await pump(t, ApprovalCenterScreen(session: s), 402, 1);
    await press(t, 'approval-venue-claim-__owner__:$claimVenueId');
    await enter(t, 'venue-claim-note', 'Cần bổ sung ảnh giấy ủy quyền rõ nét.');
    await enter(t, 'venue-claim-password', DemoSession.password);
    await press(t, 'venue-claim-reject');
    await press(t, 'finance-confirm');
    expect(s.venueClaims.single.state, 'rejected');
    loginClaimOwner(s);
    await pump(t, VenueClaimScreen(session: s, venueId: claimVenueId), 402, 1);
    expect(
      find.textContaining('Cần bổ sung ảnh giấy ủy quyền rõ nét.'),
      findsOneWidget,
    );
    await reveal(t, 'venue-claim-submit');
    expect(find.byKey(const Key('venue-claim-submit')), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
