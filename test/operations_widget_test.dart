import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_operations.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/operations_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession session() {
    final s = DemoSession(now: () => DateTime(2026, 10, 6, 10));
    addTearDown(s.dispose);
    s.login(DemoSession.phone, DemoSession.password);
    s.createPost('public', 'Nội dung diễn đàn cần kiểm duyệt');
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s, {
    String view = 'courts',
    double width = 402,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MyApp());
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
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
            child: OperationsScreen(session: s, initialView: view),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Owner submits price change and admin approves actual booking rates',
    (t) async {
      final s = session();
      await pump(t, s);
      await press(t, 'court-edit');
      await t.enterText(find.byKey(const Key('court-rate-2')), '180000');
      await press(t, 'court-submit');
      expect(s.courtReviewState, 'pending');
      expect(s.courtRate(2), 120000);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await t.pumpAndSettle();
      await press(t, 'court-approve');
      await press(t, 'finance-confirm');
      expect(s.courtRate(2), 180000);
      expect(find.text('Đã duyệt'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Employee validation then create and edit', (t) async {
    final s = session();
    await pump(t, s, view: 'employees');
    await press(t, 'employee-add');
    await press(t, 'employee-save');
    expect(find.text('Nhập tên và số điện thoại hợp lệ.'), findsOneWidget);
    await t.enterText(find.byKey(const Key('employee-name')), 'Nhân viên thử');
    await t.enterText(find.byKey(const Key('employee-phone')), '0901234567');
    await press(t, 'employee-save');
    expect(s.employees.single.name, 'Nhân viên thử');
    await press(t, 'employee-edit-NS0001');
    await t.enterText(find.byKey(const Key('employee-name')), 'Đã sửa');
    await press(t, 'employee-save');
    expect(s.employees.single.name, 'Đã sửa');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Admin account blocking and moderation actions work with confirmations',
    (t) async {
      final s = session();
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await pump(t, s, view: 'accounts');
      await press(t, 'account-block-0901234567');
      await t.enterText(
        find.byKey(const Key('player-access-reason')),
        'Demo access review',
      );
      await t.enterText(
        find.byKey(const Key('player-access-password')),
        DemoSession.password,
      );
      await press(t, 'player-access-confirm');
      expect(s.isBlocked(DemoSession.phone), isTrue);
      await press(t, 'operations-moderation');
      await press(t, 'post-hide-BD0001');
      await press(t, 'finance-confirm');
      expect(s.posts, isEmpty);
      expect(find.textContaining('Đã ẩn'), findsOneWidget);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('post-hide-BD0001')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final view in [
    'courts',
    'employees',
    'customers',
    'reports',
    'audit',
    'accounts',
    'moderation',
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$view fits ${scale == 1 ? 402 : 320}px scale $scale', (
        t,
      ) async {
        final s = session();
        s.saveEmployee(
          name: 'Nhân viên thử',
          phone: DemoSession.phone,
          job: 'Lễ tân',
          active: true,
        );
        s.submitCourtSettings(
          CourtSettings(
            rates: [120000, 180000, 150000],
            enabled: [true, true, false],
          ),
        );
        if (view == 'accounts' || view == 'moderation') {
          s.loginStaff(
            DemoRole.admin,
            DemoSession.adminEmail,
            DemoSession.password,
          );
        }
        final key = await pump(
          t,
          s,
          view: view,
          width: scale == 1 ? 402 : 320,
          scale: scale,
        );
        await captureHome(
          key,
          'operations-$view-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
        await t.drag(find.byType(ListView), const Offset(0, -400));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('Player denied operational data', (t) async {
    final s = session();
    s.login(DemoSession.phone, DemoSession.password);
    await pump(t, s);
    expect(find.text('Cần tài khoản Chủ sân hoặc Admin.'), findsOneWidget);
    expect(find.byKey(const Key('court-edit')), findsNothing);
    expect(t.takeException(), isNull);
  });
}
