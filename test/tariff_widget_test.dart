import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_operations.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/operations_screen.dart';
import 'package:test_do_an/screens/booking_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession make() {
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 8));
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    addTearDown(s.dispose);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s, {
    double width = 402,
    double scale = 1,
    Widget? screen,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MyApp());
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen ?? OperationsScreen(session: s),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.vertical,
            )
            .last,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Owner adds tariff, admin approves, player confirmation shows each hour',
    (t) async {
      final s = make();
      await pump(t, s);
      await press(t, 'court-edit');
      await press(t, 'tariff-add');
      await t.enterText(find.byKey(const Key('tariff-rate')), '180000');
      await press(t, 'tariff-save');
      await press(t, 'court-submit');
      expect(s.courtRate(1, DateTime(2026, 10, 8, 11)), 120000);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await t.pumpAndSettle();
      await press(t, 'court-approve');
      await press(t, 'finance-confirm');
      expect(s.courtRate(1, DateTime(2026, 10, 8, 11)), 180000);
      s.login(DemoSession.phone, DemoSession.password);
      await pump(
        t,
        s,
        screen: BookingConfirmScreen(
          session: s,
          court: 1,
          start: DateTime(2026, 10, 8, 11),
          hours: 2,
        ),
      );
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('180.000đ / giờ'), findsOneWidget);
      expect(find.text('120.000đ / giờ'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Invalid price stays in editor; overlap does not add duplicate; delete removes tariff',
    (t) async {
      final s = make();
      await pump(t, s);
      await press(t, 'court-edit');
      await press(t, 'tariff-add');
      await t.enterText(find.byKey(const Key('tariff-rate')), '9000');
      await press(t, 'tariff-save');
      expect(find.byKey(const Key('tariff-rate')), findsOneWidget);
      await t.enterText(find.byKey(const Key('tariff-rate')), '180000');
      await press(t, 'tariff-save');
      await press(t, 'tariff-add');
      await press(t, 'tariff-save');
      expect(find.byKey(const Key('tariff-delete-0')), findsOneWidget);
      expect(find.byKey(const Key('tariff-delete-1')), findsNothing);
      await press(t, 'tariff-delete-0');
      await press(t, 'court-submit');
      expect(s.draftCourts!.tariffs, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Owner enters surcharge and expiry; approved quote expires at next day',
    (t) async {
      final s = make();
      await pump(t, s);
      await press(t, 'court-edit');
      await press(t, 'tariff-add');
      await t.enterText(find.byKey(const Key('tariff-surcharge')), '10000');
      await press(t, 'tariff-until');
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await press(t, 'tariff-save');
      await press(t, 'court-submit');
      expect(
        s.draftCourts!.tariffs.single.effectiveUntil,
        DateTime(2026, 10, 7),
      );
      expect(s.draftCourts!.tariffs.single.surcharge, 10000);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.reviewCourtSettings(approve: true);
      expect(s.courtRate(1, DateTime(2026, 10, 7, 11)), 130000);
      expect(s.courtRate(1, DateTime(2026, 10, 8, 11)), 120000);
      expect(t.takeException(), isNull);
    },
  );
  for (final size in [(402.0, 1.0), (320.0, 2.0)]) {
    for (final view in ['editor', 'published', 'quote']) {
      testWidgets('Tariff $view fits ${size.$1} at ${size.$2}', (t) async {
        final s = make();
        s.submitCourtSettings(
          CourtSettings(
            rates: [120000, 120000, 120000],
            enabled: [true, true, true],
            tariffs: [
              CourtTariff(
                court: 1,
                weekend: false,
                fromHour: 6,
                toHour: 12,
                rate: 180000,
                effectiveFrom: DateTime(2026, 10, 7),
              ),
            ],
          ),
        );
        s.loginStaff(
          DemoRole.admin,
          DemoSession.adminEmail,
          DemoSession.password,
        );
        s.reviewCourtSettings(approve: true);
        s.loginStaff(
          DemoRole.owner,
          DemoSession.ownerEmail,
          DemoSession.password,
        );
        Widget? screen;
        if (view == 'quote') {
          s.login(DemoSession.phone, DemoSession.password);
          screen = BookingConfirmScreen(
            session: s,
            court: 1,
            start: DateTime(2026, 10, 8, 11),
            hours: 2,
          );
        }
        final key = await pump(
          t,
          s,
          width: size.$1,
          scale: size.$2,
          screen: screen,
        );
        if (view == 'editor') {
          await press(t, 'court-edit');
          await press(t, 'tariff-add');
        }
        await captureHome(
          key,
          'tariff-$view-${size.$2 == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 6; i++) {
          await t.drag(
            find
                .byWidgetPredicate(
                  (w) => w is Scrollable && w.axis == Axis.vertical,
                )
                .last,
            const Offset(0, -250),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
    }
  }
}
