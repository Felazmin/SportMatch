import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/registration_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 7, 10));
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession make([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s, {
    double width = 402,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MyApp());
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
    final challenge = s.beginDemoRegistration('New', '0912345678', 'Test1234');
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 879),
            textScaler: TextScaler.linear(scale),
          ),
          child: RepaintBoundary(
            key: key,
            child: RegistrationScreen(session: s, challenge: challenge),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable).first;
      t.state<ScrollableState>(scrollable).position.jumpTo(0);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(f, 300, scrollable: scrollable);
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'Wrong code then correct code shows saved success and creates one account',
    (t) async {
      final s = make();
      await pump(t, s);
      expect(s.user, isNull);
      await t.enterText(find.byKey(const Key('registration-code')), '000000');
      await press(t, 'registration-verify');
      expect(find.text('Mã OTP không đúng. Còn 4 lần thử.'), findsOneWidget);
      expect(s.user, isNull);
      await t.enterText(find.byKey(const Key('registration-code')), '123456');
      await press(t, 'registration-verify');
      expect(s.user!.identifier, '0912345678');
      expect(find.text('Tài khoản demo đã được tạo và lưu.'), findsOneWidget);
      expect(find.byKey(const Key('registration-code')), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'Expiry disables verify; resend clears code and restores verification',
    (t) async {
      final s = make();
      await pump(t, s);
      now = now.add(const Duration(minutes: 5));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Mã OTP đã hết hạn'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('registration-verify')))
            .onPressed,
        isNull,
      );
      await press(t, 'registration-resend');
      expect(find.text('Xác nhận đăng ký'), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const Key('registration-resend')),
            )
            .onPressed,
        isNull,
      );
      await finish(t);
    },
  );
  testWidgets('Five wrong codes lock verify; cooldown then resend unlocks', (
    t,
  ) async {
    final s = make();
    await pump(t, s);
    await t.enterText(find.byKey(const Key('registration-code')), '000000');
    for (var i = 0; i < 5; i++) {
      await press(t, 'registration-verify');
    }
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('registration-verify')))
          .onPressed,
      isNull,
    );
    now = now.add(const Duration(seconds: 60));
    await t.pump(const Duration(seconds: 1));
    await press(t, 'registration-resend');
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('registration-verify')))
          .onPressed,
      isNotNull,
    );
    expect(s.user, isNull);
    await finish(t);
  });
  testWidgets(
    'Failed storage stays on success with retry instead of claiming persisted account',
    (t) async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      store.failWrite = true;
      await pump(t, s);
      await t.enterText(find.byKey(const Key('registration-code')), '123456');
      await press(t, 'registration-verify');
      expect(find.text('Đã xác nhận, tài khoản đang chờ lưu.'), findsOneWidget);
      expect(s.saveFailed, isTrue);
      store.failWrite = false;
      await press(t, 'finance-retry-save');
      expect(find.text('Tài khoản demo đã được tạo và lưu.'), findsOneWidget);
      final r = make(store);
      await r.initialize();
      expect(r.user!.identifier, '0912345678');
      await finish(t);
    },
  );
  for (final state in ['normal', 'wrong', 'expired', 'success']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$state registration fits ${scale == 1 ? 402 : 320}px text scale $scale',
        (t) async {
          final s = make();
          final key = await pump(
            t,
            s,
            width: scale == 1 ? 402 : 320,
            scale: scale,
          );
          if (state == 'wrong' || state == 'success') {
            final finder = find.byKey(const Key('registration-code'));
            await t.ensureVisible(finder);
            await t.pumpAndSettle();
            await t.enterText(finder, state == 'wrong' ? '000000' : '123456');
            await press(t, 'registration-verify');
          }
          if (state == 'expired') {
            now = now.add(const Duration(minutes: 5));
            await t.pump(const Duration(seconds: 1));
          }
          await captureHome(
            key,
            'registration-$state-${scale == 1 ? 'normal' : 'large'}',
            t,
          );
          await t.drag(find.byType(ListView), const Offset(0, -350));
          await t.pumpAndSettle();
          await finish(t);
        },
      );
    }
  }
}
