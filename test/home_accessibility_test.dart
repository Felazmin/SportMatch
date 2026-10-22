import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/main.dart';

Future<void> captureHome(
  GlobalKey key,
  String name,
  WidgetTester tester,
) async {
  if (!const bool.fromEnvironment('SCREENSHOT')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final font = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
      await font.load();
    }
  });
  for (final width in [320.0, 402.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('Home remains usable at $width and text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 879);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: capture, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        expect(
          MediaQuery.textScalerOf(tester.element(find.byType(TextField).first))
              .scale(10),
          10 * scale,
        );
        expect(tester.takeException(), isNull);
        await captureHome(
          capture,
          'home_large_top_${width.toInt()}_$scale',
          tester,
        );
        await tester.scrollUntilVisible(
          find.text('Đặt sân ngay'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await captureHome(
          capture,
          'home_large_card_${width.toInt()}_$scale',
          tester,
        );
        await tester.tap(find.text('Đặt sân ngay'));
        await tester.pumpAndSettle();
        expect(find.text('Chi tiết sân'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Khám phá ngay'),
          -180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Khám phá ngay'));
        await tester.pumpAndSettle();
        expect(find.text('NVH Academy'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(TextField),
          -180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'khong ton tai');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Xóa bộ lọc'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xóa bộ lọc'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
