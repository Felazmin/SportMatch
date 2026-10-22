import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/management_screen.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  Future<void> open(WidgetTester t, DemoSession s) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffLoginScreen(session: s),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('staff-identifier')),
      DemoSession.ownerEmail,
    );
    await t.enterText(
      find.byKey(const Key('staff-password')),
      DemoSession.password,
    );
  }

  testWidgets('Saved staff login closes and restores the selected owner', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = DemoSession(store: store);
    addTearDown(s.dispose);
    await s.initialize();
    await open(t, s);
    await t.tap(find.byKey(const Key('staff-submit')));
    await t.pumpAndSettle();
    expect(find.byType(StaffLoginScreen), findsNothing);
    final restored = DemoSession(store: store);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.user?.role, DemoRole.owner);
  });

  testWidgets('Failed save stays open and retry persists the same session', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = DemoSession(store: store);
    addTearDown(s.dispose);
    await s.initialize();
    await open(t, s);
    store.failWrite = true;
    await t.tap(find.byKey(const Key('staff-submit')));
    await t.pumpAndSettle();
    expect(find.text('Thử lưu lại'), findsOneWidget);
    expect(find.textContaining('Chưa lưu được phiên'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byKey(const Key('staff-identifier'))).enabled,
      isFalse,
    );
    final actor = s.user?.identifier;
    store.failWrite = false;
    await t.tap(find.byKey(const Key('staff-submit')));
    await t.pumpAndSettle();
    expect(find.byType(StaffLoginScreen), findsNothing);
    expect(s.user?.identifier, actor);
    final restored = DemoSession(store: store);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.user?.identifier, actor);
  });

  testWidgets('Account change during save cannot finish the old login', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = DemoSession(store: store);
    addTearDown(s.dispose);
    await s.initialize();
    await open(t, s);
    final gate = Completer<void>();
    store.beforeWrite = () => gate.future;
    await t.tap(find.byKey(const Key('staff-submit')));
    await t.pump();
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    gate.complete();
    await t.pumpAndSettle();
    expect(find.byType(StaffLoginScreen), findsOneWidget);
    expect(find.textContaining('Phiên tài khoản đã thay đổi'), findsOneWidget);
    expect(s.user?.role, DemoRole.admin);
    expect(
      t.widget<TextField>(find.byKey(const Key('staff-identifier'))).enabled,
      isTrue,
    );
  });

  testWidgets(
    'Account change before retry does not overwrite the new session',
    (t) async {
      final store = TestSessionStore();
      final s = DemoSession(store: store);
      addTearDown(s.dispose);
      await s.initialize();
      await open(t, s);
      store.failWrite = true;
      await t.tap(find.byKey(const Key('staff-submit')));
      await t.pumpAndSettle();
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await s.flush();
      final writes = store.writes;
      store.failWrite = false;
      await t.tap(find.byKey(const Key('staff-submit')));
      await t.pumpAndSettle();
      expect(store.writes, writes);
      expect(s.user?.role, DemoRole.admin);
      expect(
        find.textContaining('Phiên tài khoản đã thay đổi'),
        findsOneWidget,
      );
    },
  );
}
