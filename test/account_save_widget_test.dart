import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/auth_screen.dart';
import 'package:test_do_an/screens/registration_screen.dart';
import 'package:test_do_an/screens/recovery_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  Future<DemoSession> session(TestSessionStore store) async {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    await s.initialize();
    return s;
  }

  Future<GlobalKey> open(
    WidgetTester t,
    Widget screen, {
    bool large = false,
  }) async {
    t.view.physicalSize = Size(large ? 320 : 402, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
    await t.pumpAndSettle();
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => screen),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Home'));
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
    return key;
  }

  Future<void> press(WidgetTester t, String key, {bool settle = true}) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
    }
  }

  Future<void> loginInputs(WidgetTester t) async {
    await t.enterText(
      find.byKey(const Key('auth-identifier')),
      DemoSession.phone,
    );
    await t.enterText(
      find.byKey(const Key('auth-password')),
      DemoSession.password,
    );
  }

  void other(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );

  testWidgets(
    'Player login failed save stays open and retry restores one session',
    (t) async {
      final store = TestSessionStore();
      final s = await session(store);
      await open(t, AuthScreen(session: s));
      await loginInputs(t);
      store.failWrite = true;
      await press(t, 'auth-submit');
      expect(find.text('Thử lưu lại'), findsOneWidget);
      expect(
        find.textContaining('Chưa lưu được phiên đăng nhập'),
        findsOneWidget,
      );
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('auth-identifier')))
            .enabled,
        isFalse,
      );
      store.failWrite = false;
      await press(t, 'auth-submit');
      expect(find.byType(AuthScreen), findsNothing);
      final restored = await session(store);
      expect(restored.user?.identifier, DemoSession.phone);
    },
  );

  testWidgets('Player login rejects actor change during save', (t) async {
    final store = TestSessionStore();
    final s = await session(store);
    await open(t, AuthScreen(session: s));
    await loginInputs(t);
    final gate = Completer<void>();
    store.beforeWrite = () => gate.future;
    await press(t, 'auth-submit', settle: false);
    other(s);
    gate.complete();
    await t.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.textContaining('Phiên tài khoản đã thay đổi'), findsOneWidget);
    expect(s.user?.role, DemoRole.admin);
  });

  testWidgets('Player login cannot retry over a different actor', (t) async {
    final store = TestSessionStore();
    final s = await session(store);
    await open(t, AuthScreen(session: s));
    await loginInputs(t);
    store.failWrite = true;
    await press(t, 'auth-submit');
    other(s);
    await s.flush();
    final writes = store.writes;
    store.failWrite = false;
    await press(t, 'auth-submit');
    expect(store.writes, writes);
    expect(s.user?.role, DemoRole.admin);
    expect(find.textContaining('Phiên tài khoản đã thay đổi'), findsOneWidget);
  });

  for (final during in [false, true]) {
    testWidgets(
      'Registration actor switch ${during ? 'during save' : 'before verification'} hides stale challenge',
      (t) async {
        final store = TestSessionStore();
        final s = await session(store);
        final challenge = s.beginDemoRegistration(
          'New player',
          '0912345678',
          'Test1234',
        );
        await open(t, RegistrationScreen(session: s, challenge: challenge));
        if (during) {
          await t.enterText(
            find.byKey(const Key('registration-code')),
            '123456',
          );
          final gate = Completer<void>();
          store.beforeWrite = () => gate.future;
          await press(t, 'registration-verify', settle: false);
          other(s);
          gate.complete();
        } else {
          other(s);
        }
        await t.pumpAndSettle();
        expect(
          find.textContaining('Phiên tài khoản đã thay đổi'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('registration-target')), findsNothing);
        expect(find.byKey(const Key('registration-continue')), findsNothing);
        expect(challenge.consumed, during);
        expect(s.user?.role, DemoRole.admin);
      },
    );
  }

  testWidgets(
    'Registration unsaved continuation dialog rejects account switch',
    (t) async {
      final store = TestSessionStore();
      final s = await session(store);
      final challenge = s.beginDemoRegistration(
        'New player',
        '0912345678',
        'Test1234',
      );
      await open(t, RegistrationScreen(session: s, challenge: challenge));
      await t.enterText(find.byKey(const Key('registration-code')), '123456');
      store.failWrite = true;
      await press(t, 'registration-verify');
      await press(t, 'registration-continue');
      expect(find.byType(AlertDialog), findsOneWidget);
      other(s);
      await t.pump();
      await press(t, 'finance-confirm');
      expect(find.byType(RegistrationScreen), findsOneWidget);
      expect(
        find.textContaining('Phiên tài khoản đã thay đổi'),
        findsOneWidget,
      );
    },
  );

  Future<void> recoveryInputs(WidgetTester t) async {
    await press(t, 'recovery-request');
    await t.enterText(find.byKey(const Key('recovery-code')), '123456');
    await press(t, 'recovery-verify');
    await t.enterText(find.byKey(const Key('recovery-password')), 'New12345');
    await t.enterText(find.byKey(const Key('recovery-confirm')), 'New12345');
  }

  testWidgets('Recovery actor switch before reset preserves password', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = await session(store);
    await open(t, RecoveryScreen(session: s, identifier: DemoSession.phone));
    await recoveryInputs(t);
    other(s);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recovery-reset')), findsNothing);
    expect(find.textContaining('Phiên tài khoản đã thay đổi'), findsOneWidget);
    expect(s.login(DemoSession.phone, DemoSession.password), isTrue);
  });

  testWidgets('Recovery actor switch during save hides old success and retry', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = await session(store);
    await open(t, RecoveryScreen(session: s, identifier: DemoSession.phone));
    await recoveryInputs(t);
    final gate = Completer<void>();
    store.beforeWrite = () => gate.future;
    await press(t, 'recovery-reset', settle: false);
    other(s);
    gate.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('recovery-done')), findsNothing);
    expect(find.textContaining('Phiên tài khoản đã thay đổi'), findsOneWidget);
    expect(s.user?.role, DemoRole.admin);
  });

  testWidgets(
    'Recovery retry reports repeated failure and restores the committed password',
    (t) async {
      final store = TestSessionStore();
      final s = await session(store);
      await open(t, RecoveryScreen(session: s, identifier: DemoSession.phone));
      await recoveryInputs(t);
      store.failWrite = true;
      await press(t, 'recovery-reset');
      await press(t, 'recovery-retry-save');
      await t.scrollUntilVisible(
        find.byKey(const Key('recovery-error')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Chưa lưu được mật khẩu mới'), findsOneWidget);
      store.failWrite = false;
      await press(t, 'recovery-retry-save');
      final restored = await session(store);
      expect(restored.login(DemoSession.phone, 'New12345'), isTrue);
      expect(restored.login(DemoSession.phone, DemoSession.password), isFalse);
      expect(s.saveFailed, isFalse);
    },
  );

  for (final recovery in [false, true]) {
    testWidgets(
      '${recovery ? 'Recovery' : 'Login'} failed save fits 320px 200 percent',
      (t) async {
        final store = TestSessionStore();
        final s = await session(store);
        final key = await open(
          t,
          recovery
              ? RecoveryScreen(session: s, identifier: DemoSession.phone)
              : AuthScreen(session: s),
          large: true,
        );
        if (recovery) {
          await recoveryInputs(t);
        } else {
          await loginInputs(t);
        }
        store.failWrite = true;
        await press(t, recovery ? 'recovery-reset' : 'auth-submit');
        await captureHome(
          key,
          'account-save-${recovery ? 'recovery' : 'login'}-2.0',
          t,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
