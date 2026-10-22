import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/payout_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  late Uint8List bytes;
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
    final data = await rootBundle.load('assets/figma/c0697.png');
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  DemoSession ready() {
    var now = DateTime(2026, 10, 8, 10);
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    s.login(DemoSession.phone, DemoSession.password);
    final b = s.reserve(
      court: 2,
      start: DateTime(2026, 10, 9, 12),
      hours: 1,
      contact: 'Người thử',
      contactPhone: DemoSession.phone,
    );
    s.startTransfer(b);
    s.saveProofDraft(b, bytes);
    s.submitProof(b, 'BOOK-12345');
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.reviewPayment(b, approve: true);
    now = DateTime(2026, 10, 9, 13);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
    double scale = 1,
  }) async {
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

  Future<void> press(WidgetTester t, String id) async {
    final f = find.byKey(Key(id));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Owner bank/request and Admin receipt record through UI at $scale',
      (t) async {
        final s = ready();
        await pump(t, PayoutScreen(session: s), scale: scale);
        await press(t, 'payout-account-edit');
        await t.enterText(
          find.byKey(const Key('payout-bank')),
          'Ngân hàng demo',
        );
        await t.enterText(
          find.byKey(const Key('payout-holder')),
          'NGUYEN MINH PHAT',
        );
        await t.enterText(find.byKey(const Key('payout-number')), '0012345678');
        await t.enterText(
          find.byKey(const Key('payout-account-password')),
          DemoSession.password,
        );
        await press(t, 'payout-account-save');
        expect(s.payoutAccount!.number, '0012345678');
        await t.enterText(find.byKey(const Key('payout-amount')), '100000');
        await t.enterText(
          find.byKey(const Key('payout-password')),
          DemoSession.password,
        );
        await press(t, 'payout-request');
        await t.tap(find.byKey(const Key('finance-confirm')));
        await t.pumpAndSettle();
        expect(s.payoutBalance, 16400);
        final p = s.payouts.single;
        s.loginStaff(
          DemoRole.admin,
          DemoSession.adminEmail,
          DemoSession.password,
        );
        final key = await pump(
          t,
          PayoutDetailScreen(
            session: s,
            id: p.id,
            pickImage: () async => bytes,
          ),
          scale: scale,
        );
        await t.enterText(
          find.byKey(const Key('payout-reference')),
          'PAY-12345',
        );
        await press(t, 'payout-proof');
        await t.runAsync(
          () => precacheImage(
            t.widget<Image>(find.byType(Image)).image,
            t.element(find.byType(PayoutDetailScreen)),
          ),
        );
        await t.pumpAndSettle();
        expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        await t.enterText(
          find.byKey(const Key('payout-admin-password')),
          DemoSession.password,
        );
        await press(t, 'payout-record');
        await t.tap(find.byKey(const Key('finance-confirm')));
        await t.pumpAndSettle();
        expect(s.payouts.single.state, 'recorded');
        expect(find.text('Mã chứng từ: PAY-12345'), findsOneWidget);
        await t.runAsync(
          () => precacheImage(
            t.widget<Image>(find.byType(Image)).image,
            t.element(find.byType(PayoutDetailScreen)),
          ),
        );
        await t.pumpAndSettle();
        expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        await captureHome(key, 'payout-recorded-$scale', t);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('Role switch during review confirmation blocks recording', (
    t,
  ) async {
    final s = ready();
    s.savePayoutAccount(
      'Ngân hàng demo',
      'NGUYEN MINH PHAT',
      '0012345678',
      expectedRevision: 0,
      password: DemoSession.password,
    );
    final p = s.requestPayout(
      100000,
      expectedBalance: s.payoutBalance,
      expectedAccountRevision: 1,
      password: DemoSession.password,
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(
      t,
      PayoutDetailScreen(session: s, id: p.id, pickImage: () async => bytes),
    );
    await t.enterText(find.byKey(const Key('payout-reference')), 'PAY-12345');
    await press(t, 'payout-proof');
    await t.enterText(
      find.byKey(const Key('payout-admin-password')),
      DemoSession.password,
    );
    await press(t, 'payout-record');
    s.login(DemoSession.phone, DemoSession.password);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    expect(s.payouts.single.state, 'pending');
    expect(t.takeException(), isNull);
  });
  testWidgets('Management route opens ledger and player is denied', (t) async {
    final s = ready();
    await pump(t, ManagementScreen(session: s));
    await press(t, 'management-payouts');
    expect(find.byType(PayoutScreen), findsOneWidget);
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('payout-balance')), findsNothing);
    expect(t.takeException(), isNull);
  });
}
