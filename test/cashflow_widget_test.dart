import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/cashflow_screen.dart';
import 'package:test_do_an/screens/settlement_screen.dart';
import 'package:test_do_an/screens/finance_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'multi_facility_test.dart' show sampleFacilityProof, publishTestFacility;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession open() {
    final s = DemoSession(now: () => DateTime(2026, 10, 8, 10));
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  void receipts(DemoSession s) {
    final f = publishTestFacility(s);
    s.login(DemoSession.phone, DemoSession.password);
    final primary = s.reserve(
      court: 2,
      start: DateTime(2026, 10, 9, 12),
      hours: 1,
      contact: 'Guest',
      contactPhone: DemoSession.phone,
    );
    final other = s.reserve(
      facilityId: f.id,
      court: 7,
      start: DateTime(2026, 10, 9, 12),
      hours: 1,
      contact: 'Guest',
      contactPhone: DemoSession.phone,
    );
    s.startTransfer(primary);
    s.saveProofDraft(primary, base64Decode(sampleFacilityProof));
    s.submitProof(primary, 'TEST-001');
    owner(s);
    s.reviewPayment(primary, approve: true);
    s.confirmVenuePayment(other);
  }

  Future<GlobalKey> pump(WidgetTester t, Widget screen, double scale) async {
    t.view.physicalSize = Size(scale == 1 ? 402 : 320, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
    await t.pumpAndSettle();
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> reach(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Cashflow values, chart and venue filter fit $scale', (
      t,
    ) async {
      final s = open();
      receipts(s);
      final key = await pump(t, CashflowScreen(session: s), scale);
      expect(
        t.widget<Text>(find.byKey(const Key('cashflow-received'))).data,
        '270.000đ',
      );
      await reach(t, find.byType(CashflowChart));
      await captureHome(key, 'cashflow-chart-$scale', t);
      expect(find.byType(CashflowChart), findsOneWidget);
      expect(t.takeException(), isNull);
      await reach(t, find.byKey(const Key('cashflow-channel-true')));
      await t.tap(find.byKey(const Key('cashflow-channel-true')));
      await t.pumpAndSettle();
      await reach(t, find.byKey(const Key('cashflow-received')));
      expect(
        t.widget<Text>(find.byKey(const Key('cashflow-received'))).data,
        '150.000đ',
      );
      final field = find.byType(DropdownButtonFormField<String>);
      await reach(t, field);
      await t.tap(field);
      await t.pumpAndSettle();
      await t.tap(find.text('Sân chính').last);
      await t.pumpAndSettle();
      await reach(t, find.byKey(const Key('cashflow-received')));
      expect(
        t.widget<Text>(find.byKey(const Key('cashflow-received'))).data,
        '0đ',
      );
      expect(t.takeException(), isNull);
    });
    testWidgets('Empty report and long date chart remain stable at $scale', (
      t,
    ) async {
      final s = open();
      owner(s);
      await pump(t, CashflowScreen(session: s), scale);
      await t.tap(find.byKey(const Key('cashflow-days-30')));
      await t.pumpAndSettle();
      await reach(t, find.byType(CashflowChart));
      expect(t.takeException(), isNull);
      await reach(t, find.byKey(const Key('cashflow-empty')));
      expect(find.byKey(const Key('cashflow-empty')), findsOneWidget);
    });
  }
  testWidgets('Player cannot open financial reports', (t) async {
    final s = open();
    s.login(DemoSession.phone, DemoSession.password);
    await pump(t, CashflowScreen(session: s), 1);
    expect(find.text('Chưa có quyền truy cập.'), findsOneWidget);
    expect(find.byType(CashflowChart), findsNothing);
  });
  testWidgets('Settlement toolbar opens actual cashflow report', (t) async {
    final s = open();
    owner(s);
    await pump(t, SettlementScreen(session: s), 1);
    await t.tap(find.byKey(const Key('settlement-cashflow')));
    await t.pumpAndSettle();
    expect(find.byType(CashflowScreen), findsOneWidget);
  });
  testWidgets(
    'Manager chooses received date before confirming booking payment',
    (t) async {
      final s = open();
      s.login(DemoSession.phone, DemoSession.password);
      final b = s.reserve(
        court: 2,
        start: DateTime(2026, 10, 9, 12),
        hours: 1,
        contact: 'Guest',
        contactPhone: DemoSession.phone,
      );
      final bytes = await rootBundle.load('assets/figma/c0697.png');
      s.startTransfer(b);
      s.saveProofDraft(
        b,
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      s.submitProof(b, 'TEST-DATE');
      owner(s);
      await pump(t, PaymentScreen(session: s, booking: b), 1);
      await reach(t, find.byKey(const Key('payment-received-date')));
      await t.tap(find.byKey(const Key('payment-received-date')));
      await t.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await t.tap(find.text('7').last);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await reach(t, find.byKey(const Key('payment-approve')));
      await t.tap(find.byKey(const Key('payment-approve')));
      await t.pumpAndSettle();
      await t.tap(find.text('Xác nhận').last);
      await t.pumpAndSettle();
      expect(s.paymentFor(b)!.receivedAt, DateTime(2026, 10, 7));
      await t.pumpWidget(const SizedBox());
    },
  );
}
