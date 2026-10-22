import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/osm_venue_detail_screen.dart';
import 'package:test_do_an/venues/osm_venue_catalog.dart';
import 'package:test_do_an/venues/venue_catalog.dart';
import 'package:test_do_an/venues/venue_illustrations.dart';
import 'package:test_do_an/widgets/venue_image.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

VenueSummary sample(String sport, {String image = ''}) => VenueSummary(
  id: 'illustration-test',
  name: 'Sân thử nghiệm',
  address: '',
  sport: sport,
  image: image,
  price: null,
  rating: null,
);

Future<void> finishImages(WidgetTester tester) async {
  for (final image in tester.widgetList<Image>(find.byType(Image)).toList()) {
    final context = tester.element(find.byType(VenueImage).first);
    await tester.runAsync(() => precacheImage(image.image, context));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<VenueSummary> catalog;
  setUpAll(() async {
    catalog = await loadOsmVenues();
    for (final font in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  test(
    'Every supported sport has a distinct decodable bundled illustration',
    () async {
      expect(venueIllustrations.keys.toSet(), venueSports.toSet());
      expect(venueIllustrations.values.toSet().length, 8);
      for (final path in venueIllustrations.values) {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThanOrEqualTo(768));
        expect(frame.image.height, greaterThanOrEqualTo(512));
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test(
    'All 129 imported venues are covered without fabricating source photos',
    () {
      expect(catalog.length, 129);
      for (final venue in catalog) {
        expect(venue.image, isEmpty);
        expect(
          venueIllustrationFor(venue.sport),
          isIn(venueIllustrations.values),
        );
        expect(venue.bookingEnabled, isFalse);
        expect(venue.price, isNull);
      }
      expect(venueIllustrationFor('Môn mới'), venueIllustrations['Đa năng']);
    },
  );

  for (final size in [
    const Size(320, 200),
    const Size(98, 88),
    const Size(40, 40),
  ]) {
    testWidgets('Missing photos render at $size with 2x text', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: VenueImage(
                  venue: sample('Cầu lông'),
                  width: size.width,
                  height: size.height,
                ),
              ),
            ),
          ),
        ),
      );
      await finishImages(tester);
      expect(tester.takeException(), isNull);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      if (size.width >= 140) {
        expect(find.text('Ảnh minh họa'), findsOneWidget);
      } else {
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      }
      expect(
        find.bySemanticsLabel(RegExp('Ảnh minh họa sân Cầu lông')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  }

  testWidgets(
    'Existing asset photos take precedence with no illustration label',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: VenueImage(
              venue: sample('Cầu lông', image: 'assets/figma/c0697.png'),
              width: 320,
              height: 200,
            ),
          ),
        ),
      );
      await finishImages(tester);
      expect(find.text('Ảnh minh họa'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        const AssetImage('assets/figma/c0697.png'),
      );
    },
  );

  testWidgets('Eight illustrations display in a gallery without blank images', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Inter'),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 4,
                childAspectRatio: .8,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: venueIllustrations.keys
                    .map(
                      (sport) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 1.5,
                            child: VenueImage(venue: sample(sport)),
                          ),
                          const SizedBox(height: 8),
                          Text(sport),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
    await finishImages(tester);
    expect(find.text('Ảnh minh họa'), findsNWidgets(8));
    expect(
      tester
          .widgetList<RawImage>(find.byType(RawImage))
          .every((image) => image.image != null),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await captureHome(key, 'venue_illustrations_gallery', tester);
  });

  testWidgets('Imported venue detail displays a labeled image on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final session = DemoSession(store: TestSessionStore());
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Inter', colorSchemeSeed: Colors.green),
          home: OsmVenueDetailScreen(
            session: session,
            venue: catalog.singleWhere((v) => v.id == 'osm-way-1350606729'),
          ),
        ),
      ),
    );
    await finishImages(tester);
    expect(find.text('Ảnh minh họa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureHome(key, 'venue_illustration_mobile_detail', tester);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
