import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/auth_screen.dart';
import 'package:test_do_an/screens/booking_screen.dart';
import 'package:test_do_an/screens/finance_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List proof;
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
    final data = await rootBundle.load('assets/figma/c0697.png');
    proof = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });
  DemoSession session({TestSessionStore? store}) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 6, 10));
    addTearDown(s.dispose);
    return s;
  }

  DemoBooking reserve(DemoSession s) => s.reserve(
    court: 2,
    start: DateTime(2026, 10, 7, 12),
    hours: 1,
    contact: 'Test User',
    contactPhone: DemoSession.phone,
  );
  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  Future<GlobalKey> pump(
    WidgetTester t,
    Widget w, {
    double width = 402,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 879);
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

  Future<void> press(WidgetTester t, Finder f) async {
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

  Future<void> confirm(WidgetTester t) =>
      press(t, find.byKey(const Key('finance-confirm')));
  Future<void> reason(WidgetTester t, String text) async {
    await t.enterText(find.byKey(const Key('finance-reason')), text);
    await press(t, find.byKey(const Key('finance-text-confirm')));
  }

  testWidgets(
    'Player sends image; owner rejects and reviews resubmission; cancellation and refund',
    (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final b = reserve(s);
      final key = await pump(
        t,
        PaymentScreen(session: s, booking: b, pickImage: () async => proof),
      );
      await press(t, find.byKey(const Key('payment-start-transfer')));
      await captureHome(key, 'payment-transfer', t);
      await press(t, find.byKey(const Key('payment-pick-proof')));
      expect(s.paymentFor(b)!.draft, isNotEmpty);
      await t.enterText(find.byKey(const Key('payment-reference')), 'DEMO-REF');
      await press(t, find.byKey(const Key('payment-submit-proof')));
      expect(find.text('Chờ Chủ sân duyệt'), findsOneWidget);
      final imageFinder = find.byType(Image).first;
      await t.runAsync(
        () => precacheImage(
          t.widget<Image>(imageFinder).image,
          t.element(imageFinder),
        ),
      );
      await t.pumpAndSettle();
      expect(t.widget<RawImage>(find.byType(RawImage).first).image, isNotNull);
      await captureHome(key, 'payment-pending', t);
      owner(s);
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('payment-reject')));
      await reason(t, 'Ảnh chưa rõ thông tin');
      s.login(DemoSession.phone, DemoSession.password);
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('payment-pick-proof')));
      await press(t, find.byKey(const Key('payment-submit-proof')));
      owner(s);
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('payment-approve')));
      await confirm(t);
      expect(s.paymentFor(b)!.state, DemoPaymentState.approved);
      s.login(DemoSession.phone, DemoSession.password);
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('payment-request-cancel')));
      await reason(t, 'Không tham gia được');
      expect(b.cancelled, isFalse);
      owner(s);
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('payment-approve-cancel')));
      await confirm(t);
      expect(b.cancelled, isTrue);
      await press(t, find.byKey(const Key('payment-refund')));
      await press(t, find.byKey(const Key('refund-proof')));
      await t.enterText(
        find.byKey(const Key('refund-reference')),
        'REF-BOOKING',
      );
      await press(t, find.byKey(const Key('refund-record')));
      await confirm(t);
      expect(s.paymentFor(b)!.refund, DemoRefundState.recorded);
      await finish(t);
    },
  );
  testWidgets(
    'Picking cancellation and failure are handled without submitted evidence',
    (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final b = reserve(s);
      s.startTransfer(b);
      await pump(
        t,
        PaymentScreen(session: s, booking: b, pickImage: () async => null),
      );
      await press(t, find.byKey(const Key('payment-pick-proof')));
      expect(s.proofPickerBooking, isNull);
      expect(s.paymentFor(b)!.draft, '');
      await finish(t);
      await pump(
        t,
        PaymentScreen(
          session: s,
          booking: b,
          pickImage: () async => throw PlatformException(code: 'denied'),
        ),
      );
      await press(t, find.byKey(const Key('payment-pick-proof')));
      expect(find.byKey(const Key('payment-error')), findsOneWidget);
      expect(s.paymentFor(b)!.proof, '');
      await finish(t);
    },
  );
  testWidgets(
    'Failed save has retry without duplicate payment or proof submission',
    (t) async {
      final store = TestSessionStore();
      final s = session(store: store);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      final b = reserve(s);
      await s.flush();
      await pump(
        t,
        PaymentScreen(session: s, booking: b, pickImage: () async => proof),
      );
      await press(t, find.byKey(const Key('payment-start-transfer')));
      await press(t, find.byKey(const Key('payment-pick-proof')));
      await t.enterText(find.byKey(const Key('payment-reference')), 'DEMO-REF');
      store.failWrite = true;
      await press(t, find.byKey(const Key('payment-submit-proof')));
      expect(s.paymentFor(b)!.state, DemoPaymentState.pending);
      expect(find.byKey(const Key('finance-retry-save')), findsOneWidget);
      store.failWrite = false;
      await press(t, find.byKey(const Key('finance-retry-save')));
      expect(s.saveFailed, isFalse);
      expect(s.paymentFor(b)!.state, DemoPaymentState.pending);
      await finish(t);
    },
  );
  testWidgets(
    'Dedicated staff login returns to account with the correct workspace',
    (t) async {
      final s = session();
      await pump(t, AuthScreen(session: s));
      await press(t, find.byKey(const Key('auth-staff-login')));
      await t.enterText(
        find.byKey(const Key('staff-identifier')),
        DemoSession.ownerEmail,
      );
      await t.enterText(
        find.byKey(const Key('staff-password')),
        DemoSession.password,
      );
      await press(t, find.byKey(const Key('staff-submit')));
      expect(s.role, DemoRole.owner);
      await finish(t);
    },
  );
  testWidgets('Owner opens payment queue and admin records dispute outcome', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final b = reserve(s);
    s.startTransfer(b);
    s.saveProofDraft(b, proof);
    s.submitProof(b, 'DEMO-REF');
    final d = s.createDispute(
      b,
      'Lịch đặt',
      'Cần kiểm tra lịch đặt thử nghiệm',
    );
    owner(s);
    final key = await pump(t, ManagementScreen(session: s));
    await captureHome(key, 'owner-workspace', t);
    await press(t, find.byKey(const Key('management-payments')));
    await press(t, find.byKey(Key('management-booking-${b.id}')));
    expect(find.byType(PaymentScreen), findsOneWidget);
    await finish(t);
    await pump(t, DisputeDetailScreen(session: s, dispute: d));
    await press(t, find.byKey(const Key('dispute-respond')));
    await reason(t, 'Chủ sân đã kiểm tra dữ liệu');
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await t.pumpAndSettle();
    await press(t, find.byKey(const Key('dispute-resolve')));
    await reason(t, 'Khiếu nại đã xử lý trong demo');
    await press(t, find.byKey(const Key('finance-confirm')));
    expect(d.resolution, isNotEmpty);
    await finish(t);
  });
  for (final view in [
    'payment',
    'owner',
    'admin',
    'staff-login',
    'dispute',
    'dispute-form',
  ]) {
    testWidgets('$view fits 320px at 200 percent text', (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final b = reserve(s);
      s.startTransfer(b);
      final d = s.createDispute(
        b,
        'Lịch đặt thử nghiệm',
        'Cần kiểm tra khung giờ đã đăng ký',
      );
      if (view == 'owner') owner(s);
      if (view == 'admin') {
        s.loginStaff(
          DemoRole.admin,
          DemoSession.adminEmail,
          DemoSession.password,
        );
      }
      final w = switch (view) {
        'payment' => PaymentScreen(session: s, booking: b),
        'owner' || 'admin' => ManagementScreen(session: s),
        'staff-login' => StaffLoginScreen(session: s),
        'dispute' => DisputeDetailScreen(session: s, dispute: d),
        _ => DisputeFormScreen(session: s, booking: b),
      };
      final key = await pump(t, w, width: 320, scale: 2);
      await captureHome(key, 'finance-$view-large', t);
      await t.drag(find.byType(ListView).first, const Offset(0, -400));
      await t.pumpAndSettle();
      await finish(t);
    });
  }
  testWidgets('Ordinary users cannot open management or another invoice', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final b = reserve(s);
    s.register('Other', 'other@example.com', 'Test1234');
    await pump(t, PaymentScreen(session: s, booking: b));
    expect(find.text('Không có quyền truy cập lịch này.'), findsOneWidget);
    await finish(t);
    await pump(t, BookingDetailScreen(session: s, booking: b));
    expect(find.text('Không có quyền xem lịch đặt này.'), findsOneWidget);
    expect(find.byKey(const Key('booking-payment')), findsNothing);
    await finish(t);
    await pump(t, ManagementScreen(session: s));
    expect(find.text('Cần tài khoản Chủ sân hoặc Admin.'), findsOneWidget);
    await finish(t);
  });
}
