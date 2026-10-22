import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/main.dart';

Future<void> setUpApp(
  WidgetTester tester, {
  double width = 402,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = Size(width, 879);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    capture == null
        ? const MyApp()
        : RepaintBoundary(key: capture, child: const MyApp()),
  );
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('auth-submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('auth-submit')));
  await tester.pumpAndSettle();
}

Future<void> login(WidgetTester tester) async {
  await tester.tap(find.text('Đăng nhập').first);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('auth-identifier')),
    '0901234567',
  );
  await tester.enterText(find.byKey(const Key('auth-password')), 'Demo1234');
  await submit(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });

  testWidgets('Phone login displays profile and logout restores guest', (
    tester,
  ) async {
    await setUpApp(tester);
    await login(tester);
    expect(find.text('Văn Hùng'), findsOneWidget);
    expect(find.text('THÀNH VIÊN BẠC'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('account-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất').last);
    await tester.pumpAndSettle();
    expect(find.text('Khách'), findsOneWidget);
    expect(find.byKey(const Key('account-logout')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid login stays on form and email method succeeds', (
    tester,
  ) async {
    await setUpApp(tester);
    await tester.tap(find.text('Đăng nhập').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-identifier')),
      '0901234567',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'Wrong1234');
    await submit(tester);
    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-identifier')),
      'demo@nvh.vn',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'Demo1234');
    await submit(tester);
    expect(find.text('Văn Hùng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Registration validates confirmation and consent before success',
    (tester) async {
      await setUpApp(tester);
      await tester.tap(find.text('Đăng ký').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('auth-name')), 'Minh Phát');
      await tester.enterText(
        find.byKey(const Key('auth-identifier')),
        '0912345678',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'Newpass123',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirmation')),
        'Different123',
      );
      await submit(tester);
      expect(find.text('Mật khẩu xác nhận chưa khớp'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('auth-confirmation')),
        'Newpass123',
      );
      await submit(tester);
      expect(find.byKey(const Key('auth-error')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('auth-consent')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth-consent')));
      await submit(tester);
      expect(find.byKey(const Key('registration-code')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('registration-code')),
        '123456',
      );
      await tester.ensureVisible(find.byKey(const Key('registration-verify')));
      await tester.tap(find.byKey(const Key('registration-verify')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('registration-continue')),
      );
      await tester.tap(find.byKey(const Key('registration-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Minh Phát'), findsOneWidget);
      expect(find.text('THÀNH VIÊN MỚI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Profile name can be edited', (tester) async {
    await setUpApp(tester);
    await login(tester);
    await tester.tap(find.byTooltip('Sửa hồ sơ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Tên Mới');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Tên Mới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Login remains usable with a visible keyboard on a small screen',
    (tester) async {
      await setUpApp(tester, width: 320);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await login(tester);
      expect(find.text('Văn Hùng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  if (const bool.fromEnvironment('SCREENSHOT')) {
    for (final width in [402.0, 320.0]) {
      for (final screen in ['login', 'register', 'account', 'guest']) {
        testWidgets('Capture $screen at $width', (tester) async {
          final key = GlobalKey();
          await setUpApp(tester, width: width, capture: key);
          if (screen == 'account') {
            await login(tester);
          } else if (screen == 'guest') {
            await tester.tap(find.text('Tài khoản').last);
            await tester.pumpAndSettle();
          } else {
            await tester.tap(
              find.text(screen == 'register' ? 'Đăng ký' : 'Đăng nhập').first,
            );
            await tester.pumpAndSettle();
          }
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/previews').create(recursive: true);
            await File('build/previews/${screen}_${width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
