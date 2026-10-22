import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/customer_venue_detail_screen.dart';
import 'package:test_do_an/screens/venue_browse_screen.dart';
import 'package:test_do_an/screens/venue_map_screen.dart';
import 'package:test_do_an/venues/venue_map_service.dart';
import 'package:test_do_an/venues/osm_venue_catalog.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'customer_tabs_test.dart' as map_test;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<VenueSummary> venues;
  setUpAll(() async {
    venues = await loadOsmVenues();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFFE9EFE8), BlendMode.src);
    final tile = await recorder.endRecording().toImage(16, 16);
    map_test.testTileBytes = (await tile.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    tile.dispose();
    for (final font in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  DemoSession session(TestSessionStore store) => DemoSession(
    store: store,
    venueCatalogLoader: () async => venues,
    now: () => DateTime(2026, 10, 19, 10),
  );
  test(
    'Bundled catalog has 129 unique coordinates and no fabricated rental data',
    () {
      expect(venues.length, 129);
      expect(venues.map((v) => v.id).toSet().length, 129);
      expect(
        venues.every(
          (v) =>
              v.latitude != null &&
              v.longitude != null &&
              !v.bookingEnabled &&
              v.price == null &&
              v.rating == null &&
              v.image.isEmpty,
        ),
        isTrue,
      );
      final hoaLu = filterVenues(
        venues: venues,
        query: 'hoa lu',
      ).singleWhere((v) => v.id == 'osm-way-165567733');
      expect(hoaLu.id, 'osm-way-165567733');
      expect(hoaLu.latitude, 10.7879111);
      expect(hoaLu.longitude, 106.7016179);
      expect(hoaLu.mapQuery, '10.7879111,106.7016179');
      expect(hoaLu.addressLabel, 'Chưa có địa chỉ chi tiết');
      expect(filterVenues(venues: venues, sport: 'Quần vợt'), isNotEmpty);
      expect(filterVenues(venues: venues, maxPrice: 100000), isEmpty);
      expect(filterVenues(venues: venues, minRating: 4), isEmpty);
    },
  );
  test(
    'Pickleball 426 has a corrected address and unchanged coordinates',
    () async {
      final venue = venues.singleWhere((v) => v.id == 'osm-way-1350606729');
      expect(
        venue.address,
        '16/15 Bình Lợi, Phường Bình Lợi Trung, TP. Hồ Chí Minh',
      );
      expect(venue.mapQuery, '10.8267479,106.7076706');
      expect(venue.bookingEnabled, isFalse);
      expect(
        filterVenues(venues: venues, query: '426 binh loi trung'),
        contains(venue),
      );
      final data = jsonDecode(
        await rootBundle.loadString('assets/data/hcm_venues.json'),
      ) as Map<String, dynamic>;
      final row = (data['venues'] as List).singleWhere(
        (v) => v['id'] == venue.id,
      );
      expect(row['osmTags']['addr:street'], 'Bình LợiB0Bìn0Bì0');
      expect(row['addressCorrection']['sourceUrls'], hasLength(2));
    },
  );

  test('Invalid coordinates and duplicate IDs reject the catalog', () async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/data/hcm_venues.json'),
    ) as Map<String, dynamic>;
    final row = Map<String, dynamic>.from(
      (data['venues'] as List).first as Map,
    );
    expect(
      () => parseOsmVenues(
        jsonEncode({
          'venues': [row, row],
        }),
      ),
      throwsFormatException,
    );
    row['latitude'] = 91;
    expect(
      () => parseOsmVenues(
        jsonEncode({
          'venues': [row],
        }),
      ),
      throwsFormatException,
    );
  });
  test(
    'Favorites survive restart; imported IDs cannot reserve courts',
    () async {
      final store = TestSessionStore();
      final first = session(store);
      await first.initialize();
      expect(first.loadFailed, isFalse);
      first.toggleFavorite(venues.first.id);
      first.login(DemoSession.phone, DemoSession.password);
      expect(
        () => first.reserve(
          court: 1,
          start: DateTime(2026, 10, 20, 14),
          hours: 1,
          contact: 'Test',
          contactPhone: DemoSession.phone,
          facilityId: venues.first.id,
        ),
        throwsStateError,
      );
      expect(first.bookings.length, 2);
      await first.flush();
      first.dispose();
      final second = session(store);
      await second.initialize();
      second.logout();
      expect(second.isFavorite(venues.first.id), isTrue);
      expect(second.currentVenues.length, 130);
      await second.flush();
      second.dispose();
    },
  );
  test('Catalog load failure can be retried', () async {
    var fails = true;
    final s = DemoSession(
      store: TestSessionStore(),
      venueCatalogLoader: () async {
        if (fails) throw const FormatException('catalog unavailable');
        return venues;
      },
    );
    await s.initialize();
    expect(s.loadFailed, isTrue);
    fails = false;
    await s.initialize();
    expect(s.initialized, isTrue);
    expect(s.currentVenues.length, 130);
    await s.flush();
    s.dispose();
  });
  testWidgets(
    'Map uses imported coordinates without geocoding their addresses',
    (tester) async {
      final service = map_test.TestMapService();
      VenueMapService.instance = service;
      addTearDown(() => VenueMapService.instance = VenueMapService());
      final s = session(TestSessionStore());
      await s.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VenueMapScreen(session: s)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        service.addressCalls,
        1,
      ); // Only the original demo venue needs lookup.
      await tester.enterText(
        find.byKey(const Key('map-search')),
        'san van dong hoa lu',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('map-marker-osm-way-165567733')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await s.flush();
      s.dispose();
    },
  );
  for (final config in [(320.0, 2.0), (402.0, 1.0), (1200.0, 1.0)]) {
    testWidgets(
      'OSM search and honest details at width ${config.$1}, scale ${config.$2}',
      (tester) async {
        tester.view.physicalSize = Size(config.$1, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = config.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final s = session(TestSessionStore());
        await s.initialize();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Inter'),
              home: VenueBrowseScreen(session: s),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'san van dong hoa lu',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('venue-result-osm-way-165567733')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(
          find.byKey(const Key('venue-result-osm-way-165567733')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sân vận động Hoa Lư'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Liên hệ sân để biết giá'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Liên hệ sân để biết giá'), findsOneWidget);
        expect(find.byKey(const Key('customer-detail-book')), findsNothing);
        expect(find.byKey(const Key('osm-directions')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump();
        final image = await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final img = await render.toImage(pixelRatio: 1);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/osm_qa/detail-${config.$1.toInt()}-${config.$2}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
          return true;
        });
        expect(image, isTrue);
        await tester.scrollUntilVisible(
          find.text('Bản quyền dữ liệu OpenStreetMap'),
          150,
          scrollable: find.byType(Scrollable).last,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await s.flush();
        s.dispose();
      },
    );
  }
  testWidgets('Booking entry opens discovery details rather than checkout', (
    tester,
  ) async {
    final s = session(TestSessionStore());
    await s.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  openCustomerBooking(context, s, 'osm-way-165567733'),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('osm-directions')), findsOneWidget);
    expect(find.text('HÌNH THỨC ĐẶT SÂN'), findsNothing);
    expect(s.bookings, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await s.flush();
    s.dispose();
  });
}
