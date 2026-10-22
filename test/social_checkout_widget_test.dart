import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/screens/customer_social_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 10, 10));
  setUpAll(() async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  DemoSession open() {
    final s = DemoSession(now: () => now)
      ..login(DemoSession.phone, DemoSession.password);
    addTearDown(s.dispose);
    return s;
  }

  DemoParticipation buy(DemoSession s) => s.joinEvent(
    eventId: demoEvents.first.id,
    start: demoEvents.first.start(now),
    quantity: 1,
    contact: 'Minh Phát',
    contactPhone: DemoSession.phone,
    socialCheckout: true,
  );
  Future<void> show(WidgetTester t, Widget screen) async {
    t.view.physicalSize = const Size(402, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Inter'),
        home: screen,
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'Booking method selects social; quantity two shows offer and form',
    (t) async {
      final s = open();
      await show(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showBookingMethod(context, s, 'cong-thuong', () {}),
              child: const Text('Đặt sân'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Đặt sân'));
      await t.pumpAndSettle();
      await t.tap(find.text('Mua vé social'));
      await t.pumpAndSettle();
      expect(find.text('Sự kiện tại sân'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Mua vé').first,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        t.element(find.text('Mua vé').first),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Mua vé').first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('social-plus')));
      await t.pumpAndSettle();
      expect(find.text('2 vé'), findsOneWidget);
      expect(
        find.text('Giảm 10% khi mua 2 vé trong cùng đơn.'),
        findsOneWidget,
      );
      await t.tap(find.text('Tiếp theo'));
      await t.pumpAndSettle();
      expect(find.text('Thông tin đặt vé · 2/3'), findsOneWidget);
      await t.tap(find.byKey(const Key('social-continue')));
      await t.pumpAndSettle();
      expect(s.participations, isEmpty);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('social-terms')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        t.element(find.byKey(const Key('social-terms'))),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('social-terms')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('social-continue')));
      await t.pumpAndSettle();
      expect(s.participations.single.quantity, 2);
      expect(find.text('Thanh toán · 3/3'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Upload and complete goes to history pending confirmation, not paid',
    (t) async {
      final s = open();
      final ticket = buy(s);
      await show(
        t,
        SocialCheckoutPaymentScreen(
          session: s,
          ticket: ticket,
          pickImage: () async => base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
        ),
      );
      await t.scrollUntilVisible(find.byKey(const Key('social-upload')), 200);
      await Scrollable.ensureVisible(
        t.element(find.byKey(const Key('social-upload'))),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('social-upload')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('social-complete')));
      await t.pumpAndSettle();
      expect(find.text('Vé social đã mua'), findsOneWidget);
      expect(s.workflowPayment(ticket.id)!.state, DemoPaymentState.pending);
      expect(ticket.cancelled, isFalse);
      expect(find.text('Chờ xác nhận thanh toán'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Expired modal cancels and returns capacity without reviving payment',
    (t) async {
      final s = open();
      final ticket = buy(s);
      await show(t, SocialCheckoutPaymentScreen(session: s, ticket: ticket));
      now = now.add(const Duration(minutes: 15));
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.text('Đã hết thời gian thanh toán'), findsOneWidget);
      expect(ticket.cancelled, isTrue);
      expect(s.eventSeats(ticket.eventId, ticket.start), ticket.event.capacity);
      await t.tap(find.text('Chọn mua vé mới'));
      await t.pumpAndSettle();
      expect(find.text('Vé social'), findsOneWidget);
      expect(s.participations.length, 1);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Foreign user cannot view payment or ticket details', (t) async {
    final s = open();
    final ticket = buy(s);
    s.register('Tấn Đạt', 'dat@example.com', 'Test1234');
    await show(t, SocialTicketDetailScreen(session: s, ticket: ticket));
    expect(
      find.text('Không thể truy cập vé của tài khoản khác.'),
      findsOneWidget,
    );
    expect(find.text('Minh Phát'), findsNothing);
    await show(t, SocialCheckoutPaymentScreen(session: s, ticket: ticket));
    expect(
      find.text('Vui lòng đăng nhập đúng tài khoản đã đặt vé.'),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [320.0, 402.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Social screens fit width $width and text scale $scale', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 879);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final s = open();
        final ticket = buy(s);
        final screens = <String, Widget>{
          'events': SocialVenueEventsScreen(session: s),
          'detail': SocialEventDetailScreen(
            session: s,
            event: ticket.event,
            start: ticket.start,
          ),
          'form': SocialCheckoutConfirmScreen(
            session: s,
            event: ticket.event,
            start: ticket.start,
            quantity: 2,
          ),
          'payment': SocialCheckoutPaymentScreen(session: s, ticket: ticket),
          'history': SocialTicketsScreen(session: s),
          'ticket': SocialTicketDetailScreen(session: s, ticket: ticket),
        };
        for (final screen in screens.entries) {
          final key = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                theme: ThemeData(fontFamily: 'Inter'),
                home: screen.value,
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: screen.key);
          await captureHome(
            key,
            'social_${screen.key}_${width.toInt()}_$scale',
            t,
          );
          final scrollable = find.byType(Scrollable).first;
          for (var i = 0; i < 6; i++) {
            await t.drag(scrollable, const Offset(0, -400));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: screen.key);
          }
          await t.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }
}
