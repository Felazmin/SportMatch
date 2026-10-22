import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/osm_venue_detail_screen.dart';
import 'package:test_do_an/screens/customer_account_views.dart';
import 'package:test_do_an/screens/customer_discovery_screen.dart';
import 'package:test_do_an/venues/osm_venue_catalog.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<VenueSummary> catalog;
  late Map<String, dynamic> references;
  setUpAll(() async {
    catalog = await loadOsmVenues();
    references = jsonDecode(
      await rootBundle.loadString('assets/data/venue_price_references.json'),
    ) as Map<String, dynamic>;
    for (final font in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  test(
    'Public prices preserve provenance and cannot become checkout prices',
    () async {
      final venues = await loadOsmVenues();
      final venue = venues.singleWhere((v) => v.id == 'osm-node-12418249325');
      expect(venue.priceReference!.min, 40000);
      expect(venue.priceReference!.max, 80000);
      expect(
        venue.priceReference!.sourceUrl,
        startsWith('https://shopvnb.com/'),
      );
      expect(venue.priceReference!.checkedAt, '2026-10-19');
      expect(venue.priceLabel, contains('tham khảo'));
      expect(venue.price, isNull);
      expect(venue.bookingEnabled, isFalse);
      expect(venues.where((v) => v.priceReference != null).length, 16);
      for (final v in venues.where((v) => v.priceReference != null)) {
        expect(v.price, isNull);
        expect(v.bookingEnabled, isFalse);
        expect(v.sports, contains(v.priceReference!.sport));
        expect(v.priceReference!.min, greaterThan(0));
      }
      expect(
        venues.singleWhere((v) => v.id == 'osm-way-165567733').priceLabel,
        'Liên hệ sân để biết giá',
      );
    },
  );

  test('Invalid amount, unit and source are rejected', () async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/data/venue_price_references.json'),
    ) as Map<String, dynamic>;
    final row = Map<String, dynamic>.from(data['osm-node-12418249325'] as Map);
    for (final change in [
      {'min': -1},
      {'max': 1},
      {'unit': 'ticket'},
      {'sourceUrl': 'javascript:alert(1)'},
      {'checkedAt': 'unknown'},
      {'checkedAt': '2026-02-31'},
      {'sport': 'Bơi lội'},
      {'kind': 'indicative'},
      {'kind': 'unknown'},
      {'publishedAt': '2027-01-01'},
    ]) {
      expect(
        () => VenuePriceReference.fromJson({...row, ...change}),
        throwsFormatException,
      );
    }
    expect(
      () => parseOsmVenues('{"venues":[]}', pricingSource: jsonEncode(data)),
      throwsFormatException,
    );
  });

  testWidgets('Price provenance fits a narrow display with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final venues = (await tester.runAsync(loadOsmVenues))!;
    final session = DemoSession(store: TestSessionStore());
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: OsmVenueDetailScreen(
          session: session,
          venue: venues.singleWhere((v) => v.id == 'osm-node-12418249325'),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Xem nguồn giá'), 200);
    expect(tester.takeException(), isNull);
    expect(find.text('Xem nguồn giá'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  test(
    'Every OSM record has an audit result and correct per-sport coverage',
    () {
      final audit = jsonDecode(
        File('data/imported_osm/price_review_2026-10-19.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final rows = (audit['venues'] as List).cast<Map<String, dynamic>>();
      expect(rows.length, catalog.length);
      expect(
        rows.map((r) => r['id']).toSet(),
        catalog.map((v) => v.id).toSet(),
      );
      expect(audit['withReference'], references.length);
      expect(audit['withoutReference'], catalog.length - references.length);
      for (final row in rows) {
        final v = catalog.singleWhere((v) => v.id == row['id']);
        expect(row['bookingEnabled'], isFalse);
        expect(row['ownerConfirmed'], isFalse);
        expect(row['reason'], isNotEmpty);
        final priced = (row['pricedSports'] as List).cast<String>();
        expect(
          priced,
          v.priceReference == null ? isEmpty : [v.priceReference!.sport],
        );
        expect(
          row['missingPriceSports'],
          v.sports.where((s) => !priced.contains(s)).toList(),
        );
      }
      for (final sport in (audit['bySport'] as Map).keys) {
        final coverage = audit['bySport'][sport];
        expect(
          coverage['total'],
          catalog.where((v) => v.sports.contains(sport)).length,
        );
        expect(
          coverage['withReference'],
          catalog.where((v) => v.priceReference?.sport == sport).length,
        );
      }
    },
  );

  test(
    'Unknown and placeholder amounts use contact text, never zero or free',
    () {
      for (final price in <int?>[null, 0, -1]) {
        final v = VenueSummary(
          id: 'unknown',
          name: 'Sân chưa có giá',
          address: '',
          sport: 'Cầu lông',
          image: '',
          price: price,
          rating: null,
        );
        expect(v.priceLabel, 'Liên hệ sân để biết giá');
      }
      expect(demoVenues.single.priceLabel, isNot(contains('Liên hệ')));
    },
  );

  test(
    'Average rates are not minimum prices and multi-sport rates are scoped',
    () {
      final average = catalog.singleWhere((v) => v.id == 'osm-way-1162776052');
      expect(average.priceLabel, startsWith('Khoảng '));
      expect(average.priceLabel, isNot(contains('–')));
      final multi = catalog.singleWhere((v) => v.id == 'osm-way-1246308670');
      expect(multi.sports, contains('Bóng rổ'));
      expect(multi.priceLabel, startsWith('Bóng đá: '));
      expect(multi.priceReference!.sport, 'Bóng đá');
      final source = jsonEncode({
        'venues': [
          {
            'id': 'osm-way-1',
            'name': 'Sân bóng rổ',
            'sports': ['Bóng rổ'],
            'latitude': 10,
            'longitude': 106,
            'sourceId': 'way/1',
            'sourceUrl': 'https://www.openstreetmap.org/way/1',
          },
        ],
      });
      expect(
        () => parseOsmVenues(
          source,
          pricingSource: jsonEncode({
            'osm-way-1': references['osm-node-12418249325'],
          }),
        ),
        throwsFormatException,
      );
    },
  );

  for (final config in [(320.0, 2.0), (402.0, 1.0)]) {
    for (final id in [
      'osm-way-165567733',
      'osm-way-1246308670',
      'osm-way-1162776052',
    ]) {
      testWidgets('Price detail and discovery card fit $id at $config', (
        tester,
      ) async {
        tester.view.physicalSize = Size(config.$1, 950);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = config.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final s = DemoSession(
          store: TestSessionStore(),
          venueCatalogLoader: () async => catalog,
        );
        await s.initialize();
        final v = catalog.singleWhere((v) => v.id == id);
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Inter'),
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: ListView(
                  children: [CustomerVenueCard(session: s, venue: v)],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(v.priceLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await captureHome(
          capture,
          'price-card-$id-${config.$1}-${config.$2}',
          tester,
        );
        final detail = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: detail,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Inter'),
              debugShowCheckedModeBanner: false,
              home: OsmVenueDetailScreen(session: s, venue: v),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(
            v.priceReference == null ? missingVenuePriceLabel : 'Xem nguồn giá',
          ),
          180,
        );
        expect(tester.takeException(), isNull);
        await captureHome(
          detail,
          'price-detail-$id-${config.$1}-${config.$2}',
          tester,
        );
        await tester.pumpWidget(const SizedBox());
        await s.flush();
        s.dispose();
      });
    }

    testWidgets(
      'Favorites show contact or reference price without misleading from-label at $config',
      (tester) async {
        tester.view.physicalSize = Size(config.$1, 950);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = config.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final s = DemoSession(
          store: TestSessionStore(),
          venueCatalogLoader: () async => catalog,
        );
        await s.initialize();
        s.toggleFavorite('osm-way-165567733');
        s.toggleFavorite('osm-way-1246308670');
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Inter'),
            home: CustomerFavoritesScreen(session: s),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Liên hệ sân để biết giá'),
          180,
        );
        expect(find.text('Giá chỉ từ'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Giá tham khảo'), 180);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await s.flush();
        s.dispose();
      },
    );
  }
}
