import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/activities_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Owner navigation and owned venue map on Android', (
    tester,
  ) async {
    final session = DemoSession();
    await session.initialize();
    session.loginStaff(
      DemoRole.owner,
      DemoSession.ownerEmail,
      DemoSession.password,
    );
    await tester.pumpWidget(MyApp(session: session));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('NVH ACADEMY'), findsNothing);
    await binding.takeScreenshot('owner-dashboard-device');
    await tester.tap(find.text('Khám phá').last);
    await tester.pumpAndSettle();
    expect(find.text('Quản lý hoạt động'), findsOneWidget);
    await binding.takeScreenshot('owner-activities-device');
    await tester.tap(find.byKey(const Key('owner-create-activity')));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityFormScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nổi bật').last);
    await tester.pumpAndSettle();
    expect(find.text('Sân của tôi'), findsOneWidget);
    expect(find.byKey(const Key('owner-venue-cong-thuong')), findsOneWidget);
    await binding.takeScreenshot('owner-facilities-device');
    await tester.tap(find.text('Bản đồ').last);
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      if (find
          .byKey(const Key('map-marker-cong-thuong'))
          .evaluate()
          .isNotEmpty)
        break;
    }
    expect(find.text('Bản đồ cơ sở'), findsOneWidget);
    expect(find.byKey(const Key('map-marker-cong-thuong')), findsOneWidget);
    expect(find.text('Quản lý sân'), findsOneWidget);
    final tileFinder = find.descendant(
      of: find.byType(FlutterMap),
      matching: find.byType(RawImage),
    );
    for (var attempt = 0; attempt < 30; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      if (tester.widgetList<RawImage>(tileFinder).any((i) => i.image != null)) {
        break;
      }
    }
    expect(
      tester.widgetList<RawImage>(tileFinder).where((i) => i.image != null),
      isNotEmpty,
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pump();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('owner-map-device');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
