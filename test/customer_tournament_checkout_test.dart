import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/screens/customer_tournament_checkout_screen.dart';
import 'package:test_do_an/main.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'home_accessibility_test.dart' show captureHome;

void main() {
  final now = DateTime(2026, 10, 10, 8);
  final event = demoEvents.last;
  const details = DemoTournamentRegistration(
    birthYear: 1995,
    email: 'bao@example.com',
    level: '3.5',
    accepted: true,
  );
  DemoSession session([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void buyer(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);
  DemoParticipation ticket(DemoSession s, {bool metadata = true}) =>
      s.joinEvent(
        eventId: event.id,
        start: event.start(now),
        quantity: 1,
        contact: 'Nguyễn Quốc Bảo',
        contactPhone: DemoSession.phone,
        team: 'Đội thử nghiệm',
        partner: 'Minh Thư',
        registration: metadata ? details : null,
      );
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  for (final method in ['qr', 'wallet', 'bank']) {
    test(
      'Persist $method receipt, retry idempotently, preserve refund workflow',
      () async {
        final store = TestSessionStore(), s = session();
        buyer(s);
        final p = ticket(s),
            payment = s.payTournamentDemo(s.participations.single, method);
        expect(payment.state, DemoPaymentState.approved);
        expect(identical(payment, s.payTournamentDemo(p, method)), isTrue);
        expect(
          DemoPayment.fromJson(Map<String, dynamic>.from(payment.toJson()))
              .gatewayMethod,
          method,
        );
        // Round-trip the entire encrypted-store payload through the session loader.
        final persisted = session(store);
        await persisted.initialize();
        buyer(persisted);
        final savedTicket = ticket(persisted);
        persisted.payTournamentDemo(savedTicket, method);
        expect(await persisted.flush(), isTrue);
        final restored = session(store);
        await restored.initialize();
        expect(restored.loadFailed, isFalse);
        expect(
          restored.participations.single.registration!.email,
          details.email,
        );
        expect(
          restored.workflowPayment(savedTicket.id)!.simulatedGateway,
          isTrue,
        );
        restored.requestTicketCancellation(
          restored.participations.single,
          'Không thể tham dự',
        );
        restored.loginStaff(
          DemoRole.owner,
          DemoSession.ownerEmail,
          DemoSession.password,
        );
        restored.reviewTicketCancellation(
          restored.managedParticipations.single,
          approve: true,
        );
        expect(
          restored.workflowPayment(savedTicket.id)!.refundAmount,
          event.fee,
        );
        expect(await restored.flush(), isTrue);
        final refunded = session(store);
        await refunded.initialize();
        expect(refunded.loadFailed, isFalse);
      },
    );
  }
  test('No bypass for manual proof, legacy registration or another actor', () {
    final s = session();
    buyer(s);
    final p = ticket(s);
    s.startTicketTransfer(p);
    expect(() => s.payTournamentDemo(p, 'qr'), throwsStateError);
    s.register('Khác', 'other@example.com', 'Test1234');
    expect(() => s.payTournamentDemo(p, 'qr'), throwsStateError);
    final legacy = session();
    buyer(legacy);
    expect(
      () => legacy.payTournamentDemo(ticket(legacy, metadata: false), 'qr'),
      throwsStateError,
    );
  });
  test(
    'Reject malformed metadata and receipt without mutating registrations',
    () {
      final s = session();
      buyer(s);
      expect(
        () => s.joinEvent(
          eventId: event.id,
          start: event.start(now),
          quantity: 1,
          contact: 'Test',
          contactPhone: DemoSession.phone,
          team: 'Test team',
          partner: 'Test partner',
          registration: const DemoTournamentRegistration(
            birthYear: 2099,
            email: 'x@example.com',
            level: '3.5',
            accepted: true,
          ),
        ),
        throwsStateError,
      );
      expect(s.participations, isEmpty);
      final p = ticket(s),
          payment = s.payTournamentDemo(s.participations.single, 'qr');
      final json = Map<String, dynamic>.from(payment.toJson())
        ..['gatewayMethod'] = 'invalid';
      expect(() => DemoPayment.fromJson(json), throwsFormatException);
      expect(() => s.payTournamentDemo(p, 'invalid'), throwsStateError);
    },
  );
  test('Legacy snapshots remain valid without new optional fields', () {
    final s = session();
    buyer(s);
    final p = ticket(s, metadata: false);
    final json = Map<String, dynamic>.from(p.toJson())..remove('registration');
    expect(DemoParticipation.fromJson(json).registration, isNull);
    final payment = s.startTicketTransfer(p);
    final old = Map<String, dynamic>.from(payment.toJson())
      ..remove('simulatedGateway')
      ..remove('gatewayMethod');
    expect(DemoPayment.fromJson(old).simulatedGateway, isFalse);
  });
  test(
    'Cancelled occurrence and elapsed start cannot receive demo payment',
    () {
      var clock = now;
      final s = DemoSession(now: () => clock);
      addTearDown(s.dispose);
      buyer(s);
      final p = ticket(s);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      s.cancelEventOccurrence(p.eventId, p.start, 'Không đủ điều kiện tổ chức');
      buyer(s);
      expect(() => s.payTournamentDemo(p, 'qr'), throwsStateError);
      final second = DemoSession(now: () => clock);
      addTearDown(second.dispose);
      buyer(second);
      final late = ticket(second);
      clock = late.start;
      expect(() => second.payTournamentDemo(late, 'qr'), throwsStateError);
    },
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
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        350,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t) async {
    for (final e in {
      'tournament-year': '1995',
      'tournament-email': 'bao@example.com',
      'event-team': 'Đội thử nghiệm',
      'event-partner': 'Minh Thư',
    }.entries) {
      final f = find.byKey(Key(e.key));
      if (f.evaluate().isEmpty) {
        await t.scrollUntilVisible(
          f,
          300,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await t.ensureVisible(f);
      await t.enterText(f, e.value);
      await t.pumpAndSettle();
    }
    await press(t, 'tournament-terms');
  }

  testWidgets('Changed actor cannot submit another user registration form', (
    t,
  ) async {
    final s = session();
    buyer(s);
    await open(
      t,
      CustomerTournamentRegistrationScreen(
        session: s,
        event: event,
        start: event.start(now),
      ),
    );
    await fill(t);
    s.register('Người khác', 'other@example.com', 'Test1234');
    await press(t, 'event-submit');
    expect(s.participations, isEmpty);
    expect(find.byType(CustomerTournamentRegistrationScreen), findsOneWidget);
  });
  testWidgets('Full registration, payment and saved success receipt', (
    t,
  ) async {
    final s = session();
    buyer(s);
    await open(
      t,
      CustomerTournamentRegistrationScreen(
        session: s,
        event: event,
        start: event.start(now),
      ),
    );
    await press(t, 'event-submit');
    expect(s.participations, isEmpty);
    await t.drag(find.byType(ListView), const Offset(0, 5000));
    await t.pumpAndSettle();
    await fill(t);
    await press(t, 'event-submit');
    expect(find.byType(CustomerTournamentPaymentScreen), findsOneWidget);
    expect(s.participations.single.registration!.birthYear, 1995);
    await press(t, 'tournament-method-wallet');
    await press(t, 'tournament-pay');
    expect(find.byType(CustomerTournamentSuccessScreen), findsOneWidget);
    expect(find.text('Thanh toán thành công!'), findsOneWidget);
    expect(
      s.workflowPayment(s.participations.single.id)!.gatewayMethod,
      'wallet',
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('Failed registration save retries once without a duplicate', (
    t,
  ) async {
    final store = TestSessionStore(), s = session(store);
    await s.initialize();
    buyer(s);
    await s.flush();
    store.failWrite = true;
    await open(
      t,
      CustomerTournamentRegistrationScreen(
        session: s,
        event: event,
        start: event.start(now),
      ),
    );
    await fill(t);
    await press(t, 'event-submit');
    expect(find.byType(CustomerTournamentRegistrationScreen), findsOneWidget);
    expect(s.participations.length, 1);
    store.failWrite = false;
    await press(t, 'event-submit');
    expect(find.byType(CustomerTournamentPaymentScreen), findsOneWidget);
    expect(s.participations.length, 1);
  });
  testWidgets('Failed payment save does not display success until persisted', (
    t,
  ) async {
    final store = TestSessionStore(), s = session(store);
    await s.initialize();
    buyer(s);
    final p = ticket(s);
    await s.flush();
    store.failWrite = true;
    await open(
      t,
      CustomerTournamentPaymentScreen(session: s, participation: p),
    );
    await press(t, 'tournament-pay');
    expect(find.byType(CustomerTournamentPaymentScreen), findsOneWidget);
    expect(s.saveFailed, isTrue);
    store.failWrite = false;
    await press(t, 'tournament-pay');
    expect(find.byType(CustomerTournamentSuccessScreen), findsOneWidget);
    expect(s.participations.length, 1);
    expect(jsonDecode(store.value!), isA<Map>());
  });
  for (final large in [false, true]) {
    for (var step = 0; step < 3; step++) {
      testWidgets('Responsive tournament step $step large=$large', (t) async {
        final s = session();
        buyer(s);
        final p = step == 0 ? null : ticket(s);
        if (step == 2) s.payTournamentDemo(p!, 'qr');
        await s.flush();
        final screen = step == 0
            ? CustomerTournamentRegistrationScreen(
                session: s,
                event: event,
                start: event.start(now),
              )
            : step == 1
            ? CustomerTournamentPaymentScreen(session: s, participation: p!)
            : CustomerTournamentSuccessScreen(session: s, participation: p!);
        final key = await open(t, screen, large: large);
        await captureHome(
          key,
          'tournament-checkout-$step-${large ? 'large' : 'normal'}',
          t,
        );
        for (var n = 0; n < 12; n++) {
          await t.drag(find.byType(ListView), const Offset(0, -300));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'tournament-checkout-$step-bottom-${large ? 'large' : 'normal'}',
          t,
        );
      });
    }
  }
}
