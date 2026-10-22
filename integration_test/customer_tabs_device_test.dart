import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Customer tabs and real embedded map on Android', (tester) async {
    final session = DemoSession();
    await session.initialize();
    session.login(DemoSession.phone, DemoSession.password);
    await tester.pumpWidget(MyApp(session: session));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    for (final tab in ['Khám phá', 'Nổi bật', 'Bản đồ']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      if (tab == 'Bản đồ') {
        // A single user-visible viewport, not a tile prefetch or map scan.
        await Future<void>.delayed(const Duration(seconds: 12));
        await tester.pumpAndSettle();
        expect(find.byType(FlutterMap), findsOneWidget);
        final rendered = tester
            .widgetList<RawImage>(
              find.descendant(
                of: find.byType(FlutterMap),
                matching: find.byType(RawImage),
              ),
            )
            .where((image) => image.image != null);
        expect(
          rendered,
          isNotEmpty,
          reason: 'Real map tiles must render, not only a background color.',
        );
        expect(
          find.text('Chưa tải được bản đồ. Kiểm tra kết nối mạng.'),
          findsNothing,
        );
        for (var attempt = 0; attempt < 20; attempt++) {
          if (find
              .byKey(const Key('map-marker-cong-thuong'))
              .evaluate()
              .isNotEmpty) {
            break;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
          await tester.pump();
        }
        expect(find.byKey(const Key('map-marker-cong-thuong')), findsOneWidget);
        expect(find.text('Đang xác định vị trí sân...'), findsNothing);
      }
      await binding.takeScreenshot(
        'customer-${tab == 'Khám phá'
            ? 'explore'
            : tab == 'Nổi bật'
            ? 'featured'
            : 'map'}-device',
      );
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(
      find.byKey(const Key('map-search')),
      'Nguyen Do Cung, Ho Chi Minh',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      if (find.byKey(const Key('map-search-position')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const Key('map-search-position')), findsOneWidget);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('customer-map-address-device');
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
