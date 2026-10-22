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
import 'package:test_do_an/screens/booking_screen.dart';
import 'package:test_do_an/screens/facility_booking_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;
import 'multi_facility_test.dart' show publishTestFacility;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List proof;
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 10, 8));
  setUpAll(() async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
    final data = await rootBundle.load('assets/figma/c0697.png');
    proof = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  DemoSession session({TestSessionStore? store}) {
    final s = DemoSession(store: store, now: () => now);
    if (store == null) s.login(DemoSession.phone, DemoSession.password);
    addTearDown(s.dispose);
    return s;
  }

  DemoBooking reserve(DemoSession s) => s.reserve(
    court: 2,
    start: DateTime(2026, 10, 11, 12),
    hours: 1,
    contact: 'Nguyễn Minh Anh',
    contactPhone: DemoSession.phone,
  );
  Future<GlobalKey> open(
    WidgetTester t,
    Widget page, {
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
          home: page,
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  void send(DemoSession s, DemoBooking b) {
    s.saveProofDraft(b, proof);
    s.saveStudentDraft(b, proof);
    s.submitProof(b, b.id);
  }

  test(
    'Checkout requires both documents; pending never expires and round trips',
    () async {
      final store = TestSessionStore();
      final s = session(store: store);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      final b = reserve(s);
      final p = s.startTransfer(
        b,
        checkout: true,
        customerNote: 'Thuê thêm vợt',
      );
      expect(p.deadline.difference(now), const Duration(minutes: 15));
      s.saveProofDraft(b, proof);
      expect(() => s.submitProof(b, b.id), throwsStateError);
      expect(p.state, DemoPaymentState.awaitingProof);
      s.saveStudentDraft(b, proof);
      s.submitProof(b, b.id);
      now = now.add(const Duration(minutes: 20));
      expect(p.expired(now), isFalse);
      expect(b.cancelled, isFalse);
      expect(s.startTransfer(b), same(p));
      expect(await s.flush(), isTrue);
      final restored = DemoSession(store: store, now: () => now);
      addTearDown(restored.dispose);
      await restored.initialize();
      final saved = restored.paymentFor(
        restored.bookings.singleWhere((e) => e.id == b.id),
      )!;
      expect(saved.state, DemoPaymentState.pending);
      expect(saved.studentProof, encodeProof(proof));
      expect(saved.customerNote, 'Thuê thêm vợt');
      final legacy = Map<String, dynamic>.from(p.toJson())
        ..remove('checkout')
        ..remove('studentProof')
        ..remove('studentDraft')
        ..remove('customerNote');
      expect(DemoPayment.fromJson(legacy).checkout, isFalse);
      final bad = Map<String, dynamic>.from(p.toJson())
        ..['studentProof'] = 'bad-image';
      expect(() => DemoPayment.fromJson(bad), throwsFormatException);
      expect(jsonDecode(store.value!)['payments'], isNotEmpty);
    },
  );
  test(
    'Expired checkout rejects upload and can start a new bounded session',
    () {
      final s = session(), b = reserve(s);
      final p = s.startTransfer(b, checkout: true, customerNote: 'Ghi chú');
      now = p.deadline;
      expect(() => s.saveStudentDraft(b, proof), throwsStateError);
      expect(() => s.submitProof(b, b.id), throwsStateError);
      final retry = s.startTransfer(b);
      expect(retry.deadline.difference(now), const Duration(minutes: 15));
      expect(retry.checkout, isTrue);
      expect(retry.customerNote, 'Ghi chú');
      expect(b.cancelled, isFalse);
      now = b.start;
      expect(() => s.startTransfer(b), throwsStateError);
    },
  );
  for (final large in [false, true]) {
    for (var kind = 0; kind < 4; kind++) {
      final index = kind;
      testWidgets('Checkout screen $index fits large=$large', (t) async {
        final s = session(), b = reserve(s);
        s.startTransfer(b, checkout: true);
        if (index >= 2) send(s, b);
        final page = <Widget>[
          CustomerCheckoutConfirmScreen(
            session: s,
            court: 3,
            start: b.start,
            hours: 1,
          ),
          CustomerCheckoutPaymentScreen(session: s, booking: b),
          CustomerCheckoutHistoryScreen(session: s, booking: b),
          CustomerCheckoutDetailScreen(session: s, booking: b),
        ][index];
        final key = await open(t, page, large: large);
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'checkout-$index-${large ? 'large' : 'normal'}',
          t,
        );
        for (var i = 0; i < 9; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -400));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'checkout-$index-bottom-${large ? 'large' : 'normal'}',
          t,
        );
      });
    }
  }
  testWidgets('Terms, documents, submit, history, details, cancellation', (
    t,
  ) async {
    final s = session();
    await open(
      t,
      CustomerCheckoutConfirmScreen(
        session: s,
        court: 2,
        start: DateTime(2026, 10, 11, 12),
        hours: 1,
      ),
    );
    await press(t, 'booking-confirm');
    expect(s.bookings.length, 2);
    await press(t, 'checkout-terms');
    await press(t, 'booking-confirm');
    expect(find.byType(CustomerCheckoutPaymentScreen), findsOneWidget);
    final b = s.bookings.singleWhere((b) => s.paymentFor(b)?.checkout == true);
    expect(find.text('15:00'), findsOneWidget);
    await press(t, 'payment-submit-proof');
    expect(s.paymentFor(b)!.state, DemoPaymentState.awaitingProof);
    await t.pumpWidget(
      MaterialApp(
        home: CustomerCheckoutPaymentScreen(
          session: s,
          booking: b,
          pickImage: () async => proof,
        ),
      ),
    );
    await t.pumpAndSettle();
    await press(t, 'payment-pick-proof');
    await press(t, 'checkout-pick-student');
    await press(t, 'payment-submit-proof');
    expect(find.byType(CustomerCheckoutHistoryScreen), findsOneWidget);
    expect(s.paymentFor(b)!.state, DemoPaymentState.pending);
    await press(t, 'checkout-booking-detail');
    expect(find.byType(CustomerCheckoutDetailScreen), findsOneWidget);
    await press(t, 'payment-request-cancel');
    await t.enterText(
      find.byKey(const Key('cancellation-reason')),
      'Thay đổi lịch học',
    );
    await press(t, 'cancellation-consent');
    await press(t, 'cancellation-submit');
    expect(s.paymentFor(b)!.cancellation, DemoCancellationState.requested);
    expect(b.cancelled, isFalse);
  });
  testWidgets(
    'Timeout shows modal; retry resets countdown; sent proofs do not timeout',
    (t) async {
      final s = session(), b = reserve(s);
      final p = s.startTransfer(b, checkout: true);
      final key = await open(
        t,
        CustomerCheckoutPaymentScreen(session: s, booking: b),
      );
      now = p.deadline;
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('checkout-timeout-retry')), findsOneWidget);
      await captureHome(key, 'checkout-timeout', t);
      await press(t, 'checkout-timeout-retry');
      expect(find.text('15:00'), findsOneWidget);
      send(s, b);
      now = now.add(const Duration(minutes: 20));
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('checkout-timeout-retry')), findsNothing);
      expect(s.paymentFor(b)!.state, DemoPaymentState.pending);
      expect(b.cancelled, isFalse);
    },
  );
  testWidgets(
    'Failed submit save stays on payment and retry submits only once',
    (t) async {
      final store = TestSessionStore();
      final s = session(store: store);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      final b = reserve(s);
      s.startTransfer(b, checkout: true);
      s.saveProofDraft(b, proof);
      s.saveStudentDraft(b, proof);
      await s.flush();
      await open(t, CustomerCheckoutPaymentScreen(session: s, booking: b));
      store.failWrite = true;
      await press(t, 'payment-submit-proof');
      expect(find.byType(CustomerCheckoutHistoryScreen), findsNothing);
      expect(s.paymentFor(b)!.state, DemoPaymentState.pending);
      store.failWrite = false;
      await press(t, 'payment-submit-proof');
      expect(find.byType(CustomerCheckoutHistoryScreen), findsOneWidget);
      expect(s.bookings.length, 3);
    },
  );
  testWidgets('Account switch during image selection cannot attach it', (
    t,
  ) async {
    final s = session(), b = reserve(s);
    s.startTransfer(b, checkout: true);
    final gate = Completer<Uint8List?>();
    await open(
      t,
      CustomerCheckoutPaymentScreen(
        session: s,
        booking: b,
        pickImage: () => gate.future,
      ),
    );
    final f = find.byKey(const Key('checkout-pick-student'));
    await t.scrollUntilVisible(
      f,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pump();
    s.register('Other player', 'other@example.com', 'Test1234');
    gate.complete(proof);
    await t.pumpAndSettle();
    expect(find.text('Không có quyền truy cập lịch này.'), findsOneWidget);
    s.login(DemoSession.phone, DemoSession.password);
    expect(s.paymentFor(b)!.studentDraft, isEmpty);
  });
  testWidgets('Schedule and facility entry both open the shared checkout', (
    t,
  ) async {
    final s = session();
    await open(t, BookingScheduleScreen(session: s));
    await press(t, 'booking-day-1');
    await press(t, 'booking-hour-12');
    await press(t, 'booking-continue');
    expect(find.byType(CustomerCheckoutConfirmScreen), findsOneWidget);
    publishTestFacility(s);
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpWidget(
      MaterialApp(
        home: FacilityBookingScreen(session: s, id: 'CS0001'),
      ),
    );
    await t.pumpAndSettle();
    await press(t, 'facility-book-submit');
    expect(find.byType(CustomerCheckoutConfirmScreen), findsOneWidget);
  });
}
