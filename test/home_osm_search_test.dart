import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/venues/osm_venue_catalog.dart';
import 'package:test_do_an/venues/venue_catalog.dart';
import 'package:test_do_an/venues/venue_map_service.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'customer_tabs_test.dart' as map_test;
import 'home_accessibility_test.dart' show captureHome;

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
  setUp(() => VenueMapService.instance = map_test.TestMapService());
  tearDown(() => VenueMapService.instance = VenueMapService());
  test(
    'Text search includes secondary sports for every multi-sport OSM entry',
    () {
      final multi = venues.where((v) => v.sports.length > 1);
      expect(multi, isNotEmpty);
      for (final venue in multi) {
        for (final sport in venue.sports.skip(1)) {
          expect(
            filterVenues(venues: [venue], query: sport).single.id,
            venue.id,
          );
        }
      }
    },
  );
  for (final config in [(402.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'Home finds OSM venue, opens correct details, and resets at $config',
      (tester) async {
        tester.view.physicalSize = Size(config.$1, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = config.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final s = DemoSession(
          store: TestSessionStore(),
          venueCatalogLoader: () async => venues,
        );
        await s.initialize();
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MyApp(session: s),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('home-search')), 'hoa lu');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final result = find.byKey(
          const Key('customer-venue-osm-way-165567733'),
        );
        await tester.scrollUntilVisible(
          result,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(result, findsOneWidget);
        expect(tester.takeException(), isNull);
        final title = find.descendant(
          of: result,
          matching: find.text('Sân vận động Hoa Lư'),
        );
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        await captureHome(
          capture,
          'osm-home-search-${config.$1}-${config.$2}',
          tester,
        );
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('osm-directions')), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('home-search')),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.byKey(const Key('home-search')),
          'khong co san nay xyz',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Không tìm thấy sân phù hợp.'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Không tìm thấy sân phù hợp.'), findsOneWidget);
        await tester.tap(find.text('Xóa bộ lọc').last);
        await tester.pumpAndSettle();
        final input = tester.widget<TextField>(
          find.byKey(const Key('home-search')),
        );
        expect(input.controller!.text, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await s.flush();
        s.dispose();
      },
    );
  }
}
