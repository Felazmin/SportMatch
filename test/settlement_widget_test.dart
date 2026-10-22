import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/management_screen.dart';
import 'package:test_do_an/screens/settlement_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final proof = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  String? copied;
  bool failCopy = false;
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  setUp(() {
    copied = null;
    failCopy = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (failCopy) throw PlatformException(code: 'test');
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  DemoSession make({bool payments = true}) {
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 8));
    addTearDown(s.dispose);
    s.login(DemoSession.phone, DemoSession.password);
    if (payments) {
      final a = s.reserve(
        court: 2,
        start: DateTime(2026, 10, 8, 12),
        hours: 1,
        contact: 'Test',
        contactPhone: DemoSession.phone,
        voucherCode: 'DEMO10',
      );
      s.startTransfer(a);
      s.saveProofDraft(a, proof);
      s.submitProof(a, 'TEST-001');
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      s.reviewPayment(a, approve: true);
      s.login(DemoSession.phone, DemoSession.password);
      final b = s.reserve(
        court: 2,
        start: DateTime(2026, 10, 9, 12),
        hours: 1,
        contact: 'Test',
        contactPhone: DemoSession.phone,
      );
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      s.confirmVenuePayment(b);
    } else {
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
    }
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s, {
    double width = 402,
    double scale = 1,
    Widget? screen,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MyApp());
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen ?? SettlementScreen(session: s),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Finder vertical() => find
      .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
      .last;
  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.drag(vertical(), const Offset(0, 6000));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(f, 350, scrollable: vertical());
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Channel/type filters and simulated fee update CSV without mutating payments',
    (t) async {
      final s = make();
      await pump(t, s);
      await press(t, 'settlement-channel-false');
      await press(t, 'settlement-export');
      expect(copied, contains('"108000"'));
      expect(copied, contains('"104760"'));
      expect(copied, isNot(contains('"onsite"')));
      await press(t, 'settlement-fee');
      await t.tap(find.text('5%').last);
      await t.pumpAndSettle();
      await press(t, 'settlement-export');
      expect(copied, contains('"102600"'));
      await press(t, 'settlement-channel-true');
      await press(t, 'settlement-export');
      expect(copied, contains('"120000"'));
      expect(copied, isNot(contains('"transfer"')));
      expect(s.settlementReport().paid, 228000);
      await press(t, 'settlement-kind-true');
      await t.scrollUntilVisible(
        find.byKey(const Key('settlement-empty')),
        350,
        scrollable: vertical(),
      );
      expect(find.byKey(const Key('settlement-empty')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Detail links to original record and updates after refund approval',
    (t) async {
      final s = make();
      final id = s.settlementReport(onsite: false).rows.single.id;
      await pump(
        t,
        s,
        screen: SettlementDetailScreen(session: s, id: id, fee: 300),
      );
      final b = s.managedBookings.singleWhere((b) => b.id == id);
      s.login(DemoSession.phone, DemoSession.password);
      s.requestCancellation(b, 'Cannot attend');
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      s.reviewCancellation(b, approve: true);
      await t.pumpAndSettle();
      expect(find.text('5.238đ'), findsOneWidget);
      await press(t, 'settlement-open-record');
      expect(find.text('Hồ sơ $id'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Player role switch hides staff summary and detail', (t) async {
    final s = make();
    await pump(t, s);
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('settlement-export')), findsNothing);
    await pump(
      t,
      s,
      screen: SettlementDetailScreen(session: s, id: 'NVH0003', fee: 300),
    );
    expect(find.text('Không có quyền truy cập.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Management entry opens the live report', (t) async {
    final s = make();
    await pump(t, s, screen: ManagementScreen(session: s));
    await press(t, 'management-settlement');
    expect(find.byType(SettlementScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Empty ledger disables copy; clipboard failure offers retry', (
    t,
  ) async {
    final s = make(payments: false);
    await pump(t, s);
    expect(
      t
          .widget<IconButton>(find.byKey(const Key('settlement-export')))
          .onPressed,
      isNull,
    );
    final paid = make();
    await pump(t, paid);
    failCopy = true;
    await press(t, 'settlement-export');
    expect(find.text('Không thể sao chép. Thử lại.'), findsOneWidget);
    failCopy = false;
    await press(t, 'settlement-export');
    expect(copied, isNotNull);
    expect(t.takeException(), isNull);
  });
  for (final size in [(402.0, 1.0), (320.0, 2.0)]) {
    for (final view in ['summary', 'detail', 'empty']) {
      testWidgets('Settlement $view fits ${size.$1} text ${size.$2}', (
        t,
      ) async {
        final s = make(payments: view != 'empty');
        Widget? screen;
        if (view == 'detail') {
          screen = SettlementDetailScreen(
            session: s,
            id: s.settlementReport().rows.first.id,
            fee: 300,
          );
        }
        final key = await pump(
          t,
          s,
          width: size.$1,
          scale: size.$2,
          screen: screen,
        );
        await captureHome(
          key,
          'settlement-$view-${size.$2 == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 10; i++) {
          await t.drag(vertical(), const Offset(0, -350));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'settlement-$view-bottom-${size.$2 == 1 ? 'normal' : 'large'}',
          t,
        );
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
    }
  }
}
