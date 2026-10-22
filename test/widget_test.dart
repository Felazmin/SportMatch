import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  testWidgets('Home renders and navigation returns to home', (tester) async {
    tester.view.physicalSize = const Size(402, 879);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('NVH ACADEMY'), findsOneWidget);
    expect(find.text('Sân Cầu Lông Đại Học Công Thương'), findsOneWidget);
    await tester.tap(find.text('Bản đồ').last);
    await tester.pumpAndSettle();
    expect(find.text('Bản đồ'), findsNWidgets(2));
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    expect(find.text('NVH ACADEMY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search filters and reset restores venue', (tester) async {
    tester.view.physicalSize = const Size(402, 879);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byType(TextField).first, 'không tồn tại');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy sân phù hợp.'), findsOneWidget);
    await tester.ensureVisible(find.text('Xóa bộ lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Sân Cầu Lông Đại Học Công Thương'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home has no overflow at narrow width', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Favorites can be saved and viewed', (tester) async {
    tester.view.physicalSize = const Size(402, 879);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Lưu sân yêu thích'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lưu sân yêu thích'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Bỏ yêu thích'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Sân yêu thích'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sân yêu thích'));
    await tester.pumpAndSettle();
    expect(find.text('Sân yêu thích'), findsOneWidget);
    expect(find.text('Sân Cầu Lông Đại Học Công Thương'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('SCREENSHOT')) {
    for (final width in [402.0, 320.0]) {
      testWidgets('Capture home at $width', (tester) async {
        tester.view.physicalSize = Size(width, 879);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: boundaryKey, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/previews').create(recursive: true);
          await File('build/previews/home_${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
