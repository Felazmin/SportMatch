import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/booking_screen.dart';
import 'package:test_do_an/screens/demo_account_screens.dart';
import 'package:test_do_an/screens/venue_map_screen.dart';
import 'package:test_do_an/main.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  final now = DateTime(2026, 10, 3, 10);
  DemoSession session() {
    final result = DemoSession(now: () => now)
      ..login(DemoSession.phone, DemoSession.password);
    addTearDown(result.dispose);
    return result;
  }

  Future<GlobalKey> pump(
    WidgetTester tester,
    Widget screen, {
    double width = 320,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 879);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final capture = GlobalKey();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return capture;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Voucher selection changes invoice and committed booking total', (
    tester,
  ) async {
    final s = session();
    await pump(
      tester,
      BookingConfirmScreen(
        session: s,
        court: 2,
        start: DateTime(2026, 10, 4, 12),
        hours: 2,
      ),
    );
    await tap(tester, find.byKey(const Key('booking-voucher')));
    await tap(tester, find.byKey(const Key('voucher-DEMO30')));
    expect(find.text('-30.000đ'), findsOneWidget);
    expect(find.text('210.000đ'), findsOneWidget);
    await tap(tester, find.byKey(const Key('booking-confirm')));
    expect(find.text('Đặt sân thành công'), findsNWidgets(2));
    expect(s.bookings.firstWhere((b) => b.id == 'NVH0003').total, 210000);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Ineligible voucher disabled and choosing none clears discount', (
    tester,
  ) async {
    final s = session();
    await pump(
      tester,
      BookingConfirmScreen(
        session: s,
        court: 2,
        start: DateTime(2026, 10, 4, 12),
        hours: 1,
      ),
    );
    await tap(tester, find.byKey(const Key('booking-voucher')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('voucher-DEMO30')))
          .onPressed,
      isNull,
    );
    await tap(tester, find.byKey(const Key('voucher-DEMO10')));
    await tap(tester, find.byKey(const Key('booking-voucher')));
    await tap(tester, find.text('Không dùng ưu đãi'));
    expect(find.text('DEMO10'), findsNothing);
    expect(find.text('120.000đ'), findsOneWidget);
  });
  testWidgets('Settings validate current password and store contact phone', (
    tester,
  ) async {
    final s = session();
    await pump(tester, AccountSettingsScreen(session: s));
    await tester.enterText(
      find.byKey(const Key('settings-phone')),
      '0912345678',
    );
    await tester.enterText(
      find.byKey(const Key('settings-current')),
      'Wrong1234',
    );
    await tester.enterText(
      find.byKey(const Key('settings-next')),
      'Newpass123',
    );
    await tester.enterText(
      find.byKey(const Key('settings-confirm')),
      'Newpass123',
    );
    await tap(tester, find.byKey(const Key('settings-save')));
    expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('settings-current')),
      'Demo1234',
    );
    await tap(tester, find.byKey(const Key('settings-save')));
    expect(s.contactPhone, '0912345678');
    s.logout();
    expect(s.login(DemoSession.email, 'Newpass123'), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Academy registration and cancellation update my schedule', (
    tester,
  ) async {
    final s = session();
    await pump(tester, AcademyScreen(session: s));
    await tap(tester, find.byKey(const Key('course-basic')));
    await tap(tester, find.text('Đăng ký'));
    expect(s.enrollments.length, 1);
    expect(find.textContaining('Sắp tới · Chưa thanh toán'), findsOneWidget);
    await tap(tester, find.byKey(const Key('course-cancel-HL0001')));
    await tap(tester, find.text('Hủy buổi học').last);
    expect(s.enrollments.single.cancelled, isTrue);
    expect(find.textContaining('Đã hủy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Support validates content, saves local ticket and closes it', (
    tester,
  ) async {
    final s = session();
    await pump(tester, SupportScreen(session: s));
    await tap(tester, find.byKey(const Key('support-create')));
    await tap(tester, find.byKey(const Key('support-save')));
    expect(find.text('Nhập tiêu đề'), findsOneWidget);
    expect(find.text('Nhập ít nhất 10 ký tự'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('support-subject')),
      'Test hỗ trợ',
    );
    await tester.enterText(
      find.byKey(const Key('support-message')),
      'Nội dung hỗ trợ đủ độ dài.',
    );
    await tap(tester, find.byKey(const Key('support-save')));
    expect(s.tickets.length, 1);
    await tap(tester, find.text('Test hỗ trợ'));
    await tap(tester, find.byKey(const Key('ticket-close-HT0001')));
    expect(s.tickets.single.closed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Map search, copy, detail and launch failure are handled', (
    tester,
  ) async {
    final s = session();
    await pump(
      tester,
      Scaffold(body: VenueMapScreen(session: s, active: false)),
    );
    await tester.enterText(
      find.byKey(const Key('map-search')),
      'khong ton tai',
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy địa chỉ phù hợp.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('map-search')),
      'Nguyen Do Cung',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('map-copy')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã sao chép địa chỉ.'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('map-open')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Không mở được bản đồ. Bạn có thể sao chép địa chỉ để tìm kiếm.',
      ),
      findsOneWidget,
    );
    await tap(tester, find.byKey(const Key('customer-book-cong-thuong')));
    expect(find.text('Chi tiết sân'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 402.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Additional screens render at $width with text scale $scale',
        (tester) async {
          final s = session();
          final screens = <String, Widget>{
            'schedule': BookingScheduleScreen(session: s),
            'wallet': VoucherWalletScreen(session: s),
            'points': PointsScreen(session: s),
            'settings': AccountSettingsScreen(session: s),
            'academy': AcademyScreen(session: s),
            'support': SupportScreen(session: s),
            'map': Scaffold(body: VenueMapScreen(session: s, active: false)),
            'confirm': BookingConfirmScreen(
              session: s,
              court: 2,
              start: DateTime(2026, 10, 4, 12),
              hours: 1,
            ),
          };
          for (final entry in screens.entries) {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            final capture = await pump(
              tester,
              entry.value,
              width: width,
              scale: scale,
            );
            await captureHome(
              capture,
              '${entry.key}_complete_${width.toInt()}_$scale',
              tester,
            );
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
      testWidgets('Account is usable at $width with text scale $scale', (
        tester,
      ) async {
        final s = session();
        tester.view.physicalSize = Size(width, 879);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MyApp(session: s),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tài khoản').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await captureHome(
          capture,
          'account_complete_${width.toInt()}_$scale',
          tester,
        );
        await tap(tester, find.text('Ví ưu đãi'));
        expect(find.text('Ví ưu đãi'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byTooltip('Cài đặt tài khoản'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tap(tester, find.byTooltip('Cài đặt tài khoản'));
        expect(find.byKey(const Key('settings-save')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
