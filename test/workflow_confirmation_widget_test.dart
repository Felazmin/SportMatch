import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/screens/finance_screen.dart';
import 'package:test_do_an/screens/workflow_screen.dart';

import 'multi_facility_test.dart' show sampleFacilityProof;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  void staff(DemoSession s, DemoRole role) => s.loginStaff(
    role,
    role == DemoRole.admin ? DemoSession.adminEmail : DemoSession.ownerEmail,
    DemoSession.password,
  );

  String submit(DemoSession s, bool ticket) {
    s.login(DemoSession.phone, DemoSession.password);
    final bytes = base64Decode(sampleFacilityProof);
    if (ticket) {
      final p = s.joinEvent(
        eventId: demoEvents.first.id,
        start: demoEvents.first.start(s.now),
        quantity: 1,
        contact: 'Test Player',
        contactPhone: DemoSession.phone,
      );
      s.startTicketTransfer(p);
      s.saveTicketProof(p, bytes);
      s.submitTicketProof(p, 'TEST-TICKET');
      return p.id;
    }
    final b = s.bookings.first;
    s.startTransfer(b);
    s.saveProofDraft(b, bytes);
    s.submitProof(b, 'TEST-BOOKING');
    return b.id;
  }

  Future<void> press(WidgetTester t, String key) async {
    final target = find.byKey(Key(key));
    await t.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester t,
    DemoSession s,
    String id,
    bool ticket,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: ticket
            ? WorkflowDetailScreen(session: s, id: id)
            : PaymentScreen(
                session: s,
                booking: s.managedBookings.singleWhere((b) => b.id == id),
              ),
      ),
    );
    await t.pumpAndSettle();
  }

  for (final ticket in [false, true]) {
    for (final reject in [false, true]) {
      testWidgets(
        'Payment ticket=$ticket reject=$reject cannot run after manager changes',
        (t) async {
          final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
          addTearDown(s.dispose);
          final id = submit(s, ticket);
          staff(s, DemoRole.owner);
          await pump(t, s, id, ticket);
          await press(
            t,
            '${ticket ? 'ticket' : 'payment'}-${reject ? 'reject' : 'approve'}',
          );
          if (reject) {
            await t.enterText(
              find.byKey(const Key('finance-reason')),
              'Proof needs correction',
            );
          }
          staff(s, DemoRole.admin);
          await t.pumpAndSettle();
          await t.tap(
            find.byKey(
              Key(reject ? 'finance-text-confirm' : 'finance-confirm'),
            ),
          );
          await t.pumpAndSettle();
          expect(s.workflowPayment(id)!.state, DemoPaymentState.pending);
          expect(
            find.text('Tài khoản đã thay đổi. Mở lại hồ sơ.'),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Payment ticket=$ticket failed approval save retries without duplicate receipt',
      (t) async {
        final store = TestSessionStore();
        final s = DemoSession(
          store: store,
          now: () => DateTime(2026, 10, 9, 10),
        );
        addTearDown(s.dispose);
        await s.initialize();
        final id = submit(s, ticket);
        staff(s, DemoRole.owner);
        expect(await s.flush(), isTrue);
        await pump(t, s, id, ticket);
        await press(t, '${ticket ? 'ticket' : 'payment'}-approve');
        store.failWrite = true;
        await t.tap(find.byKey(const Key('finance-confirm')));
        await t.pumpAndSettle();
        expect(s.workflowPayment(id)!.state, DemoPaymentState.approved);
        expect(
          find.text('Chưa lưu được vào thiết bị. Hãy thử lưu lại.'),
          findsOneWidget,
        );
        final received = s.workflowPayment(id)!.receivedAt;
        store.failWrite = false;
        final retry = find.byKey(const Key('finance-retry-save'));
        await t.scrollUntilVisible(
          retry,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.ensureVisible(retry);
        await t.pumpAndSettle();
        await t.tap(retry);
        await t.pumpAndSettle();
        expect(s.saveFailed, isFalse);
        final restored = DemoSession(
          store: store,
          now: () => DateTime(2026, 10, 9, 10),
        );
        addTearDown(restored.dispose);
        await restored.initialize();
        staff(restored, DemoRole.owner);
        expect(restored.workflowPayment(id)!.state, DemoPaymentState.approved);
        expect(restored.workflowPayment(id)!.receivedAt, received);
        expect(
          restored
              .cashflowReport(from: s.now, to: s.now)
              .entries
              .where((e) => e.id == id && !e.refund),
          hasLength(1),
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('Check-in confirmation cannot move to a different manager', (
    t,
  ) async {
    var clock = DateTime(2026, 10, 9, 10);
    final s = DemoSession(now: () => clock);
    addTearDown(s.dispose);
    staff(s, DemoRole.owner);
    final b = s.managedBookings.first;
    s.confirmVenuePayment(b);
    clock = b.start;
    await t.pumpWidget(
      MaterialApp(
        home: WorkflowDetailScreen(session: s, id: b.id),
      ),
    );
    await t.pumpAndSettle();
    await press(t, 'attendance-checkin');
    staff(s, DemoRole.admin);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.workflowRecord(b.id).attendance, DemoAttendance.pending);
    expect(find.text('Tài khoản đã thay đổi. Mở lại hồ sơ.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Attendance filters separate checked-in and cancelled records', (
    t,
  ) async {
    var clock = DateTime(2026, 10, 9, 10);
    final s = DemoSession(now: () => clock);
    addTearDown(s.dispose);
    staff(s, DemoRole.owner);
    final first = s.managedBookings.first;
    final second = s.managedBookings.last;
    s.login(DemoSession.phone, DemoSession.password);
    s.startTransfer(second);
    s.requestCancellation(second, 'Cannot attend this booking');
    staff(s, DemoRole.owner);
    s.reviewCancellation(second, approve: true);
    s.confirmVenuePayment(first);
    clock = first.start;
    s.setAttendance(first.id, DemoAttendance.checkedIn);
    await t.pumpWidget(MaterialApp(home: AttendanceScreen(session: s)));
    await t.pumpAndSettle();
    await press(t, 'attendance-filter-checkedIn');
    expect(find.byKey(Key('attendance-${first.id}')), findsOneWidget);
    expect(find.byKey(Key('attendance-${second.id}')), findsNothing);
    await press(t, 'attendance-filter-cancelled');
    expect(find.byKey(Key('attendance-${first.id}')), findsNothing);
    expect(find.byKey(Key('attendance-${second.id}')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
