import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/customer_checkout_screen.dart';
import 'package:test_do_an/screens/customer_account_views.dart';
import 'package:test_do_an/screens/finance_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late Uint8List proof;
  setUp(() => now = DateTime(2026, 10, 10, 6, 35));
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
    final bytes = await rootBundle.load('assets/figma/c0697.png');
    proof = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  });
  const destination = DemoRefundDestination.bank(
    bank: 'Vietcombank',
    account: '01234567890',
    holder: 'NGUYEN MINH ANH',
  );
  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  Future<(DemoSession, DemoBooking)> setup({
    bool paid = true,
    TestSessionStore? store,
  }) async {
    final s = DemoSession(store: store, now: () => now);
    addTearDown(s.dispose);
    await s.initialize();
    player(s);
    final b = s.reserve(
      court: 2,
      start: DateTime(2026, 10, 10, 9),
      hours: 1,
      contact: 'Nguyễn Minh Anh',
      contactPhone: DemoSession.phone,
    );
    s.startTransfer(b, checkout: true);
    if (paid) {
      s.saveProofDraft(b, proof);
      s.saveStudentDraft(b, proof);
      s.submitProof(b, b.id);
      owner(s);
      s.reviewPayment(b, approve: true);
      player(s);
    }
    await s.flush();
    return (s, b);
  }

  void request(
    DemoSession s,
    DemoBooking b, {
    DemoRefundDestination? target = destination,
  }) => s.requestCancellation(
    b,
    'Có việc đột xuất',
    destination: target,
    acceptFee: true,
  );
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
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
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
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t, {bool bank = true}) async {
    await t.drag(find.byType(ListView).first, const Offset(0, 5000));
    await t.pumpAndSettle();
    await press(t, 'cancellation-reason');
    await t.enterText(
      find.byKey(const Key('cancellation-reason')),
      'Có việc đột xuất không thể tới sân',
    );
    if (bank) {
      await press(t, 'cancellation-account');
      await t.enterText(
        find.byKey(const Key('cancellation-account')),
        '0123 4567 890',
      );
    }
    await press(t, 'cancellation-consent');
  }

  test('Checkout has a strict inclusive two-hour cutoff; quote and fee validation are atomic', () async {
    final (s, b) = await setup();
    final p = s.paymentFor(b)!;
    expect(s.bookingCancellationDeadline(b), DateTime(2026, 10, 10, 7));
    expect(s.estimatedBookingRefund(b), 114000);
    expect(
      () => s.requestCancellation(b, 'Có việc đột xuất'),
      throwsStateError,
    );
    expect(p.cancellation, DemoCancellationState.none);
    expect(
      () => s.requestCancellation(
        b,
        'Có việc đột xuất',
        destination: destination,
      ),
      throwsStateError,
    );
    expect(
      () => s.requestCancellation(
        b,
        'Có việc đột xuất',
        destination: destination,
        acceptFee: true,
        quotedRefund: 95000,
      ),
      throwsStateError,
    );
    now = DateTime(2026, 10, 10, 7, 0, 0, 1);
    expect(s.canRequestBookingCancellation(b), isFalse);
    expect(() => request(s, b), throwsStateError);
    expect(p.cancellation, DemoCancellationState.none);
    now = DateTime(2026, 10, 10, 7);
    request(s, b);
    expect(p.cancellation, DemoCancellationState.requested);
    expect(p.cancellationEstimate, 114000);
    expect(b.cancelled, isFalse);
    now = DateTime(2026, 10, 10, 8);
    owner(s);
    s.reviewCancellation(b, approve: true);
    expect(b.cancelled, isTrue);
    expect(p.refundAmount, 114000);
    expect(p.refund, DemoRefundState.pending);
  });
  test('Refund destination and messages persist, legacy snapshots load, invalid destination is rejected', () async {
    final store = TestSessionStore();
    final (s, b) = await setup(store: store);
    expect(
      () => request(
        s,
        b,
        target: const DemoRefundDestination.bank(
          bank: 'V',
          account: 'abc',
          holder: 'A',
        ),
      ),
      throwsFormatException,
    );
    expect(s.paymentFor(b)!.cancellation, DemoCancellationState.none);
    request(s, b, target: DemoRefundDestination.qr(encodeProof(proof)));
    s.sendBookingMessage(b, 'Nhờ chủ sân kiểm tra giúp');
    await s.flush();
    final restored = DemoSession(store: store, now: () => now);
    addTearDown(restored.dispose);
    await restored.initialize();
    final p = restored.paymentFor(
      restored.bookings.singleWhere((e) => e.id == b.id),
    )!;
    expect(p.refundDestination!.qr, encodeProof(proof));
    expect(p.customerMessages.single.text, 'Nhờ chủ sân kiểm tra giúp');
    final old = Map<String, dynamic>.from(p.toJson())
      ..remove('refundDestination')
      ..remove('cancellationEstimate')
      ..remove('customerMessages');
    expect(DemoPayment.fromJson(old).refundDestination, isNull);
    final bad = jsonDecode(store.value!) as Map<String, dynamic>;
    (bad['payments'] as List).first['cancellationEstimate'] = 9999999;
    final invalidStore = TestSessionStore()..value = jsonEncode(bad);
    final invalid = DemoSession(store: invalidStore, now: () => now);
    addTearDown(invalid.dispose);
    await invalid.initialize();
    expect(invalid.loadFailed, isTrue);
  });
  test('Unconfirmed payments have no refund and legacy policy still allows late cancellation', () async {
    final (s, b) = await setup(paid: false);
    expect(s.estimatedBookingRefund(b), 0);
    request(s, b, target: null);
    expect(s.paymentFor(b)!.cancellationEstimate, 0);
    final legacy = s.reserve(
      court: 3,
      start: b.start,
      hours: 1,
      contact: 'Test',
      contactPhone: DemoSession.phone,
    );
    s.startTransfer(legacy);
    now = DateTime(2026, 10, 10, 8);
    expect(s.canRequestBookingCancellation(legacy), isTrue);
    s.requestCancellation(legacy, 'Thay đổi lịch học');
  });
  for (final large in [false, true]) {
    for (var kind = 0; kind < 3; kind++) {
      final index = kind;
      testWidgets('Cancellation screen $index fits large=$large', (t) async {
        final (s, b) = await setup();
        if (index == 1) request(s, b);
        if (index == 2) now = DateTime(2026, 10, 10, 8);
        final key = await open(
          t,
          CustomerCancellationScreen(session: s, booking: b),
          large: large,
        );
        expect(t.takeException(), isNull);
        expect(find.text(b.venueName), findsOneWidget);
        await captureHome(
          key,
          'cancellation-$index-${large ? 'large' : 'normal'}',
          t,
        );
        for (var i = 0; i < 9; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -400));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'cancellation-$index-bottom-${large ? 'large' : 'normal'}',
          t,
        );
      });
    }
  }
  testWidgets('Bank request submits, persists details and opens history', (
    t,
  ) async {
    final (s, b) = await setup();
    await open(t, CustomerCheckoutDetailScreen(session: s, booking: b));
    await press(t, 'payment-request-cancel');
    expect(find.byType(CustomerCancellationScreen), findsOneWidget);
    await press(t, 'cancellation-submit');
    expect(s.paymentFor(b)!.cancellation, DemoCancellationState.none);
    await fill(t);
    await press(t, 'cancellation-submit');
    expect(find.text('Đang chờ chủ sân phản hồi'), findsOneWidget);
    expect(s.paymentFor(b)!.refundDestination!.account, '01234567890');
    expect(b.cancelled, isFalse);
    expect(s.paymentFor(b)!.refund, DemoRefundState.none);
    await press(t, 'cancellation-history');
    expect(find.byType(CustomerBookingsScreen), findsOneWidget);
  });
  testWidgets('QR mode requires an image and sends it to the owner review', (
    t,
  ) async {
    final (s, b) = await setup();
    await open(
      t,
      CustomerCancellationScreen(
        session: s,
        booking: b,
        pickImage: () async => proof,
      ),
    );
    await fill(t, bank: false);
    await press(t, 'cancellation-mode-qr');
    await press(t, 'cancellation-submit');
    expect(s.paymentFor(b)!.cancellation, DemoCancellationState.none);
    await press(t, 'cancellation-pick-qr');
    await press(t, 'cancellation-submit');
    expect(s.paymentFor(b)!.refundDestination!.qr, encodeProof(proof));
    owner(s);
    await t.pumpWidget(
      MaterialApp(
        home: PaymentScreen(session: s, booking: b),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('QR nhận hoàn tiền do khách gửi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('QR nhận hoàn tiền do khách gửi'), findsOneWidget);
  });
  testWidgets(
    'Crossing deadline blocks form and contacting owner does not cancel booking',
    (t) async {
      final (s, b) = await setup();
      await open(t, CustomerCancellationScreen(session: s, booking: b));
      now = DateTime(2026, 10, 10, 8);
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('cancellation-submit')), findsNothing);
      await press(t, 'cancellation-contact');
      await t.enterText(
        find.byKey(const Key('finance-reason')),
        'Nhờ chủ sân hỗ trợ lịch đặt',
      );
      await press(t, 'finance-text-confirm');
      expect(
        s.paymentFor(b)!.customerMessages.single.text,
        'Nhờ chủ sân hỗ trợ lịch đặt',
      );
      expect(s.paymentFor(b)!.cancellation, DemoCancellationState.none);
      expect(b.cancelled, isFalse);
    },
  );
  testWidgets(
    'Failed disk write stays visibly unsaved and retry preserves a single request',
    (t) async {
      final store = TestSessionStore();
      final (s, b) = await setup(store: store);
      await open(t, CustomerCancellationScreen(session: s, booking: b));
      await fill(t);
      store.failWrite = true;
      await press(t, 'cancellation-submit');
      expect(s.saveFailed, isTrue);
      final requested = s.paymentFor(b)!.cancellationRequestedAt;
      store.failWrite = false;
      await press(t, 'cancellation-retry-save');
      expect(s.saveFailed, isFalse);
      expect(s.paymentFor(b)!.cancellationRequestedAt, requested);
    },
  );
  testWidgets(
    'Actor change during QR selection cannot attach another account image',
    (t) async {
      final (s, b) = await setup();
      final gate = Completer<Uint8List?>();
      await open(
        t,
        CustomerCancellationScreen(
          session: s,
          booking: b,
          pickImage: () => gate.future,
        ),
      );
      await press(t, 'cancellation-mode-qr');
      final picker = find.byKey(const Key('cancellation-pick-qr'));
      await t.ensureVisible(picker);
      await t.pumpAndSettle();
      await t.tap(picker);
      await t.pump();
      s.register('Other player', 'other@example.com', 'Test1234');
      gate.complete(proof);
      await t.pumpAndSettle();
      expect(find.text('Không có quyền truy cập lịch này.'), findsOneWidget);
      player(s);
      expect(s.paymentFor(b)!.refundDestination, isNull);
    },
  );
  testWidgets(
    'Rejection permits a new request, approval does not claim a completed refund',
    (t) async {
      final (s, b) = await setup();
      request(s, b);
      owner(s);
      s.reviewCancellation(b, approve: false, note: 'Cần bổ sung lý do');
      player(s);
      await open(t, CustomerCancellationScreen(session: s, booking: b));
      final retry = find.text('Mở lại yêu cầu hủy');
      await t.scrollUntilVisible(
        retry,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(retry);
      await t.pumpAndSettle();
      await t.tap(retry);
      await t.pumpAndSettle();
      await fill(t);
      await press(t, 'cancellation-submit');
      owner(s);
      s.reviewCancellation(b, approve: true);
      player(s);
      await t.pumpAndSettle();
      expect(find.text('Hoàn tiền chưa hoàn tất'), findsOneWidget);
      owner(s);
      s.recordDemoRefund(b);
      player(s);
      await t.pumpAndSettle();
      expect(find.text('Đã ghi nhận hoàn tiền demo'), findsOneWidget);
    },
  );
}
