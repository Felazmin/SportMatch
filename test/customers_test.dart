import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/customers_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';
import 'package:test_do_an/screens/workflow_screen.dart';
import 'package:test_do_an/screens/calendar_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 7, 10);
  DemoSession open() {
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  test('Customer directory excludes accounts without venue records and denies players', () {
    final s = open();
    expect(() => s.venueCustomers, throwsStateError);
    s.register('Other', 'other@example.com', 'Test1234');
    expect(() => s.customerRecords(DemoSession.phone), throwsStateError);
    owner(s);
    expect(s.venueCustomers.map((c) => c.id), [DemoSession.phone]);
    expect(() => s.customerRecords('other@example.com'), throwsStateError);
    expect(() => s.venueCustomers.clear(), throwsUnsupportedError);
  });
  test('Ticket-only customer is included; histories remain scoped', () {
    final s = open();
    s.register('Other', 'other@example.com', 'Test1234');
    final p = s.joinEvent(
      eventId: demoEvents.first.id,
      start: demoEvents.first.start(now),
      quantity: 1,
      contact: 'Another Customer',
      contactPhone: '0909876543',
    );
    owner(s);
    final other = s.venueCustomers.singleWhere((c) => c.id == p.owner);
    expect(other.phone, '0909876543');
    expect(other.count, 1);
    expect(s.customerRecords(p.owner).single.id, p.id);
    expect(
      s.customerRecords(DemoSession.phone).any((r) => r.id == p.id),
      isFalse,
    );
    expect(() => s.customerRecords(p.owner).clear(), throwsUnsupportedError);
  });
  test('Confirmed customer total uses paid ledger not unpaid reservations', () {
    final s = open();
    owner(s);
    final b = s.managedBookings.first;
    expect(s.venueCustomers.single.paid, 0);
    s.confirmVenuePayment(b);
    expect(s.venueCustomers.single.paid, b.total);
    expect(s.venueCustomers.single.count, 2);
  });
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
    double scale = 1,
  }) async {
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
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Search/filter/profile and linked workflow navigate', (t) async {
    final s = open();
    owner(s);
    await pump(t, CustomersScreen(session: s));
    await t.enterText(find.byKey(const Key('customers-search')), 'no match');
    await t.pumpAndSettle();
    expect(find.text('Không có khách hàng phù hợp.'), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('customers-search')),
      DemoSession.phone,
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('customers-returning')));
    await t.pumpAndSettle();
    await press(t, 'customer-${DemoSession.phone}');
    expect(find.byType(CustomerDetailScreen), findsOneWidget);
    await press(t, 'customer-record-NVH0002');
    expect(find.byType(WorkflowDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Role switch removes customer record details', (t) async {
    final s = open();
    owner(s);
    await pump(t, CustomerDetailScreen(session: s, id: DemoSession.phone));
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('customer-record-NVH0002')), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('New and returning filters use actual customer records', (
    t,
  ) async {
    final s = open();
    s.register('Khách Mới', 'new@example.com', 'Test1234');
    s.joinEvent(
      eventId: demoEvents.first.id,
      start: demoEvents.first.start(now),
      quantity: 1,
      contact: 'Khách Mới',
      contactPhone: '0909876543',
    );
    owner(s);
    await pump(t, CustomersScreen(session: s));
    expect(find.byKey(const Key('customer-new@example.com')), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    await t.tap(find.byKey(const Key('customers-new')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('customer-new@example.com')), findsOneWidget);
    expect(
      find.byKey(const Key('customer-${DemoSession.phone}')),
      findsNothing,
    );
    await t.tap(find.byKey(const Key('customers-returning')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('customer-new@example.com')), findsNothing);
    expect(
      find.byKey(const Key('customer-${DemoSession.phone}')),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('customers-all')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('customers-search')), 'khach moi');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('customer-new@example.com')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Customer header creates a booking and bottom tabs navigate home',
    (t) async {
      final s = open();
      owner(s);
      await pump(t, const SizedBox());
      await t.pumpWidget(MyApp(session: s));
      await t.pumpAndSettle();
      await press(t, 'owner-action-customers');
      expect(find.byType(CustomersScreen), findsOneWidget);
      await t.tap(find.byKey(const Key('customers-create-booking')));
      await t.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('customers-nav-2')));
      await t.pumpAndSettle();
      expect(find.byType(CustomersScreen), findsNothing);
      expect(find.text('Quản lý trận đấu'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Management entry opens customers', (t) async {
    final s = open();
    owner(s);
    await pump(t, ManagementScreen(session: s));
    await press(t, 'management-customers');
    expect(find.byType(CustomersScreen), findsOneWidget);
  });
  for (final scale in [1.0, 2.0]) {
    for (final view in ['list', 'detail']) {
      testWidgets('Customers $view fits $scale', (t) async {
        final s = open();
        owner(s);
        final key = await pump(
          t,
          view == 'list'
              ? CustomersScreen(session: s)
              : CustomerDetailScreen(session: s, id: DemoSession.phone),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'customers-$view-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 5; i++) {
          await t.drag(find.byType(ListView), const Offset(0, -250));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'customers-$view-bottom-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
      });
    }
  }
}
