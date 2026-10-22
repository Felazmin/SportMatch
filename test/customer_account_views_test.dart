import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/customer_account_views.dart';
import 'package:test_do_an/screens/booking_screen.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession session() {
    final s = DemoSession(now: () => DateTime(2026, 10, 10, 8));
    s.login(DemoSession.phone, DemoSession.password);
    addTearDown(s.dispose);
    return s;
  }

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
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final large in [false, true]) {
    for (var kind = 0; kind < 3; kind++) {
      final index = kind;
      testWidgets('Customer account view $index fits large=$large', (t) async {
        final s = session();
        s.toggleFavorite(demoVenueId);
        s.savePaymentMethod('Visa', '8829');
        s.savePaymentMethod('Mastercard', '4012');
        s.savePaymentMethod('MoMo', '4567');
        final screen = [
          CustomerFavoritesScreen(session: s),
          CustomerPaymentMethodsScreen(session: s),
          CustomerBookingsScreen(session: s),
        ][index];
        final key = await open(t, screen, large: large);
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'customer-account-$index-${large ? 'large' : 'normal'}',
          t,
        );
        await t.drag(find.byType(ListView).first, const Offset(0, -500));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'customer-account-$index-bottom-${large ? 'large' : 'normal'}',
          t,
        );
      });
    }
  }
  testWidgets('Customer account menu opens all three screens', (t) async {
    final s = session();
    await t.pumpWidget(MyApp(session: s));
    await t.pumpAndSettle();
    await press(t, 'home-nav-4');
    for (final entry in [
      ('Sân yêu thích', CustomerFavoritesScreen),
      ('Phương thức thanh toán', CustomerPaymentMethodsScreen),
      ('Lịch đặt sân', CustomerBookingsScreen),
    ]) {
      final target = find.text(entry.$1).last;
      await t.ensureVisible(target);
      await t.pumpAndSettle();
      await t.tap(target);
      await t.pumpAndSettle();
      expect(find.byType(entry.$2), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
    }
    expect(t.takeException(), isNull);
  });
  testWidgets('Favorite removal updates actual list without duplicate venue', (
    t,
  ) async {
    final s = session();
    s.toggleFavorite(demoVenueId);
    await open(t, CustomerFavoritesScreen(session: s));
    expect(find.byKey(Key('saved-venue-$demoVenueId')), findsOneWidget);
    s.toggleFavorite(demoVenueId);
    await t.pumpAndSettle();
    expect(find.byKey(Key('saved-venue-$demoVenueId')), findsNothing);
    expect(find.text('Bạn chưa lưu sân yêu thích.'), findsOneWidget);
  });
  testWidgets(
    'Add card validates 4 digits and detail supports default and delete',
    (t) async {
      final s = session();
      await open(t, CustomerPaymentMethodsScreen(session: s));
      await press(t, 'payment-add-card');
      await press(t, 'payment-save-method');
      expect(find.text('Nhập đúng 4 chữ số.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('payment-last4')), '8829');
      await press(t, 'payment-save-method');
      expect(s.savedPaymentMethods.single.last4, '8829');
      expect(s.savedPaymentMethods.single.isDefault, isTrue);
      s.savePaymentMethod('MoMo', '4567');
      await t.pumpAndSettle();
      await press(t, 'payment-method-MoMo-4567');
      await t.tap(find.text('Đặt mặc định'));
      await t.pumpAndSettle();
      expect(
        s.savedPaymentMethods.singleWhere((m) => m.isDefault).provider,
        'MoMo',
      );
      await press(t, 'payment-method-MoMo-4567');
      await t.tap(find.text('Xóa phương thức'));
      await t.pumpAndSettle();
      expect(s.savedPaymentMethods.single.provider, 'Visa');
      expect(s.savedPaymentMethods.single.isDefault, isTrue);
    },
  );
  testWidgets('Booking date filter, detail and confirmed cancellation', (
    t,
  ) async {
    final s = session();
    final b = s.bookings.first;
    await open(t, CustomerBookingsScreen(session: s));
    await press(t, 'customer-booking-day-10');
    expect(find.text('Không có lịch đặt phù hợp.'), findsOneWidget);
    await press(t, 'customer-booking-day-10');
    await press(t, 'customer-booking-detail-${b.id}');
    expect(find.byType(BookingDetailScreen), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, 'customer-booking-cancel-${b.id}');
    await t.tap(find.text('Giữ lịch'));
    await t.pumpAndSettle();
    expect(b.cancelled, isFalse);
    await press(t, 'customer-booking-cancel-${b.id}');
    await t.tap(find.text('Hủy lịch'));
    await t.pumpAndSettle();
    expect(b.cancelled, isTrue);
  });
  testWidgets('Change request preserves booking and records support ticket', (
    t,
  ) async {
    final s = session();
    final b = s.bookings.first;
    final start = b.start;
    await open(t, CustomerBookingsScreen(session: s));
    await press(t, 'customer-booking-change-${b.id}');
    await press(t, 'customer-booking-send-change');
    expect(find.text('Nhập tối thiểu 10 ký tự.'), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('customer-booking-change-message')),
      'Xin đổi sang ngày 12 lúc 10 giờ.',
    );
    await press(t, 'customer-booking-send-change');
    expect(s.tickets.single.subject, 'Đổi lịch ${b.id}');
    expect(b.start, start);
    expect(b.cancelled, isFalse);
  });
  testWidgets('Account change prevents saving a pending payment dialog', (
    t,
  ) async {
    final s = session();
    await open(t, CustomerPaymentMethodsScreen(session: s));
    await press(t, 'payment-add-card');
    await t.enterText(find.byKey(const Key('payment-last4')), '8829');
    s.logout();
    await t.pumpAndSettle();
    await press(t, 'payment-save-method');
    expect(s.savedPaymentMethods, isEmpty);
    expect(
      find.text('Vui lòng đăng nhập tài khoản khách hàng.'),
      findsOneWidget,
    );
  });
  test(
    'Methods persist with masked metadata only and legacy data loads',
    () async {
      final store = TestSessionStore();
      final s = DemoSession(store: store, now: () => DateTime(2026, 10, 10));
      addTearDown(s.dispose);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      s.savePaymentMethod('Visa', '8829');
      await s.flush();
      final raw = await store.read();
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      final method =
          (data['paymentMethods'][DemoSession.phone] as List).single as Map;
      expect(method.keys.toSet(), {'provider', 'last4', 'default'});
      final loaded = DemoSession(store: store);
      addTearDown(loaded.dispose);
      await loaded.initialize();
      loaded.login(DemoSession.phone, DemoSession.password);
      expect(loaded.savedPaymentMethods.single.last4, '8829');
      data.remove('paymentMethods');
      await store.write(jsonEncode(data));
      final legacy = DemoSession(store: store);
      addTearDown(legacy.dispose);
      await legacy.initialize();
      legacy.login(DemoSession.phone, DemoSession.password);
      expect(legacy.loadFailed, isFalse);
      expect(legacy.savedPaymentMethods, isEmpty);
    },
  );
  test('Methods reject invalid, duplicate, over-limit and staff writes', () {
    final s = session();
    expect(
      () => s.savePaymentMethod('Visa', '12345678'),
      throwsFormatException,
    );
    s.savePaymentMethod('Visa', '8829');
    expect(() => s.savePaymentMethod('Visa', '8829'), throwsStateError);
    s.savePaymentMethod('MoMo', '4567');
    expect(() => s.savePaymentMethod('MoMo', '1111'), throwsStateError);
    s.savePaymentMethod('Visa', '1111');
    s.savePaymentMethod('Visa', '2222');
    s.savePaymentMethod('Visa', '3333');
    expect(() => s.savePaymentMethod('Visa', '4444'), throwsStateError);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    expect(s.savedPaymentMethods, isEmpty);
    expect(() => s.savePaymentMethod('Visa', '5555'), throwsStateError);
  });
}
