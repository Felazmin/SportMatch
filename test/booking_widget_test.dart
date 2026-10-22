import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/booking_screen.dart';
import 'package:test_do_an/screens/customer_checkout_screen.dart';

import 'auth_widget_test.dart' show setUpApp, submit;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'Guest booking preserves selection after login and requests cancellation',
    (tester) async {
      await setUpApp(tester, width: 320);
      await tester.ensureVisible(find.text('Đặt sân ngay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt sân ngay'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'venue-book');
      await tester.tap(find.text('Đặt lịch theo sân'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'booking-day-1');
      await tester.tap(find.text('2 giờ'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'booking-hour-12');
      await tapKey(tester, 'booking-continue');
      await tester.enterText(
        find.byKey(const Key('auth-identifier')),
        DemoSession.phone,
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        DemoSession.password,
      );
      await submit(tester);
      expect(find.byKey(const Key('booking-name')), findsOneWidget);
      expect(find.text('240.000đ'), findsWidgets);
      expect(find.text('12:00 – 14:00'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('checkout-terms')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapKey(tester, 'checkout-terms');
      await tapKey(tester, 'booking-confirm');
      expect(find.byType(CustomerCheckoutPaymentScreen), findsOneWidget);
      expect(find.byKey(const Key('checkout-countdown')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Chi tiết lịch đặt'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Chi tiết lịch đặt'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('payment-request-cancel')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tapKey(tester, 'payment-request-cancel');
      await tester.enterText(
        find.byKey(const Key('cancellation-reason')),
        'Thay đổi kế hoạch',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('cancellation-consent')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapKey(tester, 'cancellation-consent');
      await tester.scrollUntilVisible(
        find.byKey(const Key('cancellation-submit')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapKey(tester, 'cancellation-submit');
      expect(find.text('Đang chờ chủ sân phản hồi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Contact validation and keyboard work on narrow screen', (
    tester,
  ) async {
    final session = DemoSession(now: () => DateTime(2026, 10, 3, 10));
    session.register('Test', 'test@example.com', 'Test1234');
    addTearDown(session.dispose);
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: BookingConfirmScreen(
          session: session,
          court: 2,
          start: DateTime(2026, 10, 4, 12),
          hours: 1,
        ),
      ),
    );
    await tapKey(tester, 'booking-confirm');
    expect(find.text('Nhập số điện thoại hợp lệ'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('booking-phone')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('booking-phone')),
      '0912345678',
    );
    await tapKey(tester, 'booking-confirm');
    expect(session.bookings.length, 1);
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('SCREENSHOT')) {
    for (final width in [402.0, 320.0]) {
      for (final screen in [
        'venue',
        'schedule',
        'confirm',
        'success',
        'history',
        'detail',
      ]) {
        testWidgets('Capture $screen $width', (tester) async {
          await setUpApp(tester, width: width);
          final theme = Theme.of(tester.element(find.byType(Scaffold).first));
          final session = DemoSession(now: () => DateTime(2026, 10, 3, 10));
          session.login(DemoSession.phone, DemoSession.password);
          final booking = session.reserve(
            court: 2,
            start: DateTime(2026, 10, 4, 12),
            hours: 2,
            contact: 'Văn Hùng',
            contactPhone: DemoSession.phone,
          );
          final capture = GlobalKey();
          final Widget page = switch (screen) {
            'venue' => VenueDetailScreen(session: session),
            'schedule' => BookingScheduleScreen(session: session),
            'confirm' => BookingConfirmScreen(
              session: session,
              court: 1,
              start: DateTime(2026, 10, 4, 12),
              hours: 2,
            ),
            'success' => BookingSuccessScreen(
              session: session,
              booking: booking,
            ),
            'history' => BookingsScreen(session: session),
            _ => BookingDetailScreen(session: session, booking: booking),
          };
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (screen == 'schedule') {
            await tapKey(tester, 'booking-day-1');
            await tapKey(tester, 'booking-hour-12');
          }
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/previews').create(recursive: true);
            await File('build/previews/${screen}_${width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox());
          session.dispose();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
