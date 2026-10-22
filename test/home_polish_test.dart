import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/widgets/design.dart';

import 'home_accessibility_test.dart' show captureHome;

const sportAssets = [
  'sport-paddle',
  'sport-badminton',
  'sport-soccer',
  'sport-basketball',
  'sport-tennis',
  'sport-stadium',
];

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });

  Future<GlobalKey> home(
    WidgetTester t,
    String name,
    double width,
    double scale,
  ) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final s = DemoSession();
    addTearDown(s.dispose);
    await s.initialize();
    s.login(DemoSession.phone, DemoSession.password);
    s.updateName(name);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MyApp(session: s),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await t.pumpAndSettle();
    return key;
  }

  for (final width in [320.0, 360.0, 402.0]) {
    testWidgets('Home quick actions fit one row at $width', (t) async {
      final key = await home(t, 'Văn Hùng', width, 1);
      final actions = [
        for (final id in ['home-social', 'home-tournaments', 'home-community'])
          t.getRect(find.byKey(Key(id))),
      ];
      expect(actions[0].top, actions[1].top);
      expect(actions[1].top, actions[2].top);
      expect(actions.first.left, greaterThanOrEqualTo(16));
      expect(actions.last.right, lessThanOrEqualTo(width - 16));
      expect(t.takeException(), isNull);
      await captureHome(key, 'home-quick-actions-${width.toInt()}', t);
    });
  }
  for (final viewport in [
    (402.0, 1.0),
    (320.0, 1.0),
    (320.0, 2.0),
    (1024.0, 1.0),
  ]) {
    for (final long in [false, true]) {
      testWidgets('Customer header ${viewport.$1}/${viewport.$2} long=$long', (
        t,
      ) async {
        final name = long
            ? 'Nguyễn Hoàng Minh Phát Quốc Bảo Anh Tuấn'
            : 'Văn Hùng';
        final key = await home(t, name, viewport.$1, viewport.$2);
        final text = t.widget<Text>(
          find.byKey(const Key('home-customer-name')),
        );
        expect(text.data, name);
        expect(text.style!.fontFamily, 'Inter');
        expect(text.style!.fontSize, 14);
        expect(text.style!.height, 1.25);
        expect(text.maxLines, viewport.$2 == 2 ? 2 : 1);
        final location = t.getRect(find.text('Hồ Chí Minh, VN'));
        final account = t.getRect(
          find.byKey(const Key('home-customer-account')),
        );
        expect(location.overlaps(account), isFalse);
        expect(account.right, lessThanOrEqualTo(viewport.$1));
        expect(account.left, greaterThanOrEqualTo(0));
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'home-customer-${viewport.$1.toInt()}-${viewport.$2}-$long',
          t,
        );
        await t.tap(find.byKey(const Key('home-customer-account')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('account-logout')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'Each category uses its sport asset and selection still filters',
    (t) async {
      final key = await home(t, 'Văn Hùng', 402, 1);
      for (var i = 0; i < sportAssets.length; i++) {
        final asset = find.byKey(Key('home-sport-icon-$i'));
        await t.ensureVisible(find.byKey(Key('home-sport-$i')));
        await t.pumpAndSettle();
        expect(t.widget<DesignAsset>(asset).file, sportAssets[i]);
        await t.tap(find.byKey(Key('home-sport-$i')));
        await t.pumpAndSettle();
        expect(t.widget<DesignAsset>(asset).color, AppColors.green);
        expect(t.takeException(), isNull);
      }
      await t.ensureVisible(find.byKey(const Key('home-sport-1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('home-sport-1')));
      await t.pumpAndSettle();
      await captureHome(key, 'home-sport-badminton-selected', t);
      expect(find.text('Đặt sân ngay'), findsOneWidget);
    },
  );

  testWidgets('All six sport SVGs decode into distinct nonblank pixels', (
    t,
  ) async {
    final keys = [for (final _ in sportAssets) GlobalKey()];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (var i = 0; i < sportAssets.length; i++)
                RepaintBoundary(
                  key: keys[i],
                  child: DesignAsset(
                    sportAssets[i],
                    folder: 'figma',
                    size: 26,
                    color: AppColors.ink,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    final signatures = <String>{};
    for (final key in keys) {
      await t.runAsync(() async {
        final img =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = (await img.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var opaque = 0;
        for (var i = 3; i < bytes.length; i += 4) {
          if (bytes[i] > 0) opaque++;
        }
        expect(opaque, greaterThan(50));
        signatures.add(bytes.toString());
        img.dispose();
      });
    }
    expect(signatures.length, 6);
    expect(t.takeException(), isNull);
  });
}
