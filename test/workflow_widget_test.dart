import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/workflow_screen.dart';
import 'package:test_do_an/screens/finance_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late Uint8List proof;
  setUp(() => now = DateTime(2026, 10, 7, 10));
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
    final data = await rootBundle.load('assets/figma/07380.png');
    proof = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  DemoSession session() {
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    s.login(DemoSession.phone, DemoSession.password);
    return s;
  }

  void buyer(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);
  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  DemoParticipation ticket(DemoSession s) => s.joinEvent(
    eventId: demoEvents.first.id,
    start: demoEvents.first.start(now),
    quantity: 1,
    contact: 'Test User',
    contactPhone: DemoSession.phone,
  );
  void submit(DemoSession s, DemoParticipation p) {
    s.startTicketTransfer(p);
    s.saveTicketProof(p, proof);
    s.submitTicketProof(p, 'DEMO-TEST');
  }

  Future<GlobalKey> pump(WidgetTester t, Widget w, {double scale = 1}) async {
    t.view.physicalSize = Size(scale == 1 ? 402 : 320, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
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
          home: w,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
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

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'Ticket transfer gallery, submit, owner approval through same live screen',
    (t) async {
      final s = session();
      final p = ticket(s);
      await pump(
        t,
        WorkflowDetailScreen(
          session: s,
          id: p.id,
          pickImage: () async => proof,
        ),
      );
      await press(t, 'ticket-start');
      await press(t, 'ticket-proof');
      await t.enterText(
        find.byKey(const Key('workflow-reference')),
        'DEMO-001',
      );
      await press(t, 'ticket-submit');
      await press(t, 'finance-confirm');
      expect(s.workflowPayment(p.id)!.state, DemoPaymentState.pending);
      owner(s);
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView), const Offset(0, 900));
      await t.pumpAndSettle();
      await press(t, 'ticket-approve');
      await press(t, 'finance-confirm');
      expect(s.workflowPayment(p.id)!.state, DemoPaymentState.approved);
      await finish(t);
    },
  );
  testWidgets('Attendance lookup and check-in require confirmation', (t) async {
    final s = session();
    final p = ticket(s);
    submit(s, p);
    owner(s);
    s.reviewTicketPayment(p, approve: true);
    now = p.start;
    await pump(t, AttendanceScreen(session: s));
    await t.enterText(find.byKey(const Key('attendance-code')), p.qrPayload);
    await press(t, 'attendance-lookup');
    await press(t, 'attendance-checkin');
    expect(p.checkedIn, isFalse);
    await press(t, 'finance-confirm');
    expect(p.checkedIn, isTrue);
    await finish(t);
  });
  testWidgets('Refund gallery and reference records exactly once', (t) async {
    final s = session();
    final p = ticket(s);
    submit(s, p);
    owner(s);
    s.reviewTicketPayment(p, approve: true);
    buyer(s);
    s.requestTicketCancellation(p, 'Cannot attend');
    owner(s);
    s.reviewTicketCancellation(p, approve: true);
    await pump(
      t,
      WorkflowDetailScreen(session: s, id: p.id, pickImage: () async => proof),
    );
    await press(t, 'refund-proof');
    await t.enterText(find.byKey(const Key('refund-reference')), 'REF-UI');
    await press(t, 'refund-record');
    await press(t, 'finance-confirm');
    expect(s.workflowPayment(p.id)!.refundReference, 'REF-UI');
    expect(find.byKey(const Key('refund-record')), findsNothing);
    await finish(t);
  });
  for (final state in [
    'unpaid',
    'pending',
    'rejected',
    'refund',
    'recorded',
    'attendance',
    'dispute',
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$state workflow fits ${scale == 1 ? 402 : 320}px text $scale',
        (t) async {
          final s = session();
          final p = ticket(s);
          if (state != 'unpaid') submit(s, p);
          if ([
            'rejected',
            'refund',
            'recorded',
            'attendance',
          ].contains(state)) {
            owner(s);
            s.reviewTicketPayment(
              p,
              approve: state != 'rejected',
              note: 'Please select another sample image',
            );
            buyer(s);
          }
          if (state == 'refund' || state == 'recorded') {
            s.requestTicketCancellation(p, 'Cannot attend');
            owner(s);
            s.reviewTicketCancellation(p, approve: true);
            if (state == 'recorded') {
              s.recordWorkflowRefund(p.id, 'REF-SAMPLE', proof);
              buyer(s);
            }
          }
          if (state == 'attendance') owner(s);
          Widget w = WorkflowDetailScreen(session: s, id: p.id);
          if (state == 'attendance') w = AttendanceScreen(session: s);
          if (state == 'dispute') {
            final d = s.createTicketDispute(
              p,
              'Khiếu nại vé giao lưu',
              'Nhờ kiểm tra điều kiện hủy và chứng từ.',
            );
            s.attachDisputeEvidence(d, proof);
            s.loginStaff(
              DemoRole.admin,
              DemoSession.adminEmail,
              DemoSession.password,
            );
            w = DisputeDetailScreen(session: s, dispute: d);
          }
          final key = await pump(t, w, scale: scale);
          for (final element in find.byType(Image).evaluate()) {
            await t.runAsync(
              () => precacheImage((element.widget as Image).image, element),
            );
          }
          await t.pumpAndSettle();
          await captureHome(
            key,
            'workflow-$state-${scale == 1 ? 'normal' : 'large'}',
            t,
          );
          for (var i = 0; i < 6; i++) {
            await t.drag(find.byType(ListView).first, const Offset(0, -450));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          }
          await finish(t);
        },
      );
    }
  }
}
