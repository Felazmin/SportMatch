import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'auth_widget_test.dart' show setUpApp;

Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openCatalog(WidgetTester tester) async {
  await press(tester, find.text('Nổi bật').last);
  await press(tester, find.text('Xem tất cả').first);
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
  testWidgets('Venue catalog retains query when returning from booking flow', (
    tester,
  ) async {
    await setUpApp(tester, width: 320);
    await openCatalog(tester);
    await tester.enterText(
      find.byKey(const Key('browse-search')),
      'khong ton tai',
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy sân phù hợp.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('browse-search')))
          .controller!
          .text,
      'khong ton tai',
    );
    await tester.enterText(
      find.byKey(const Key('browse-search')),
      'dai hoc cong thuong',
    );
    await tester.pumpAndSettle();
    await press(tester, find.byKey(const Key('venue-result-cong-thuong')));
    expect(find.text('Chi tiết sân'), findsOneWidget);
    await press(tester, find.byKey(const Key('venue-book')));
    await press(tester, find.text('Đặt lịch theo sân'));
    expect(find.byKey(const Key('booking-day-0')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('browse-search')))
          .controller!
          .text,
      'dai hoc cong thuong',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Sport and price filter, cancel and reset work', (tester) async {
    await setUpApp(tester, width: 320);
    await openCatalog(tester);
    await press(tester, find.byKey(const Key('browse-sport-1')));
    expect(find.text('Không tìm thấy sân phù hợp.'), findsOneWidget);
    await press(tester, find.byKey(const Key('browse-reset')));
    await press(tester, find.byKey(const Key('browse-filter')));
    await tester.drag(
      find.byKey(const Key('browse-price')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    await press(tester, find.byTooltip('Đóng'));
    expect(find.text('1 sân'), findsOneWidget);
    await press(tester, find.byKey(const Key('browse-filter')));
    await tester.drag(
      find.byKey(const Key('browse-price')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    await press(tester, find.byKey(const Key('browse-apply')));
    expect(find.text('0 sân'), findsOneWidget);
    await press(tester, find.byKey(const Key('browse-reset')));
    expect(find.text('1 sân'), findsOneWidget);
    await press(tester, find.byTooltip('Sắp xếp'));
    await press(tester, find.text('Giá thấp đến cao'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Favorite updates detail, home, account count and empty saved screen',
    (tester) async {
      await setUpApp(tester, width: 320);
      await openCatalog(tester);
      await press(tester, find.byKey(const Key('venue-result-cong-thuong')));
      await press(tester, find.byTooltip('Lưu sân yêu thích'));
      expect(find.byTooltip('Bỏ yêu thích'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await press(tester, find.text('Trang chủ').last);
      expect(find.byTooltip('Bỏ yêu thích'), findsOneWidget);
      await press(tester, find.text('Tài khoản').last);
      expect(find.text('1 sân'), findsOneWidget);
      await press(tester, find.text('Sân yêu thích'));
      await press(tester, find.byTooltip('Bỏ yêu thích'));
      expect(find.text('Bạn chưa lưu sân yêu thích.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('0 sân'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Discovery keyboard and large text stay within narrow viewport', (
    tester,
  ) async {
    await setUpApp(tester, width: 320);
    await openCatalog(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byKey(const Key('browse-search')), 'cau long');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('browse-search'))),
      ).scale(10),
      15,
    );
    expect(tester.takeException(), isNull);
  });
  if (const bool.fromEnvironment('SCREENSHOT')) {
    for (final width in [402.0, 320.0]) {
      for (final screen in [
        'explore',
        'featured',
        'favorites',
        'filters',
        'empty',
      ]) {
        testWidgets('Capture $screen $width', (tester) async {
          tester.view.physicalSize = Size(width, 879);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          final session = DemoSession()..toggleFavorite(demoVenueId);
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MyApp(session: session),
            ),
          );
          await tester.pumpAndSettle();
          if (screen == 'favorites') {
            await press(tester, find.byTooltip('Sân yêu thích'));
          } else if (screen == 'filters' || screen == 'empty') {
            await openCatalog(tester);
          } else {
            await press(
              tester,
              find.text(screen == 'featured' ? 'Nổi bật' : 'Khám phá').last,
            );
          }
          if (screen == 'filters') {
            await press(tester, find.byKey(const Key('browse-filter')));
          }
          if (screen == 'empty') {
            await tester.enterText(
              find.byKey(const Key('browse-search')),
              'khong ton tai',
            );
            await tester.pumpAndSettle();
          }
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/previews').create(recursive: true);
            await File('build/previews/${screen}_${width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox());
          session.dispose();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
