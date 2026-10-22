import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/demo/admin_report_data.dart';
import 'package:test_do_an/reports/admin_report_export.dart';
import 'package:test_do_an/screens/admin_system_report_screen.dart';

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
  DemoSession admin() {
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 8));
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    addTearDown(s.dispose);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s, {
    double width = 402,
    double scale = 1,
    Future<void> Function(AdminReportFile)? onExport,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: AdminSystemReportScreen(session: s, onExport: onExport),
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
      maxScrolls: 80,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final layout in [(402.0, 1.0), (320.0, 2.0)]) {
    testWidgets('Figma report sections fit ${layout.$1}/${layout.$2}', (
      t,
    ) async {
      final s = admin();
      s.confirmVenuePayment(s.managedBookings.first);
      final boundary = await pump(t, s, width: layout.$1, scale: layout.$2);
      expect(find.text('28/09/2026 – 04/10/2026'), findsOneWidget);
      expect(t.takeException(), isNull);
      await captureHome(
        boundary,
        'admin-report-figma-${layout.$1}-${layout.$2}',
        t,
      );
      await t.tap(find.byKey(const Key('system-report-period-30')));
      await t.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await t.drag(
          find.byKey(const Key('system-report-list')),
          const Offset(0, -220),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (i == 3 || i == 8) {
          await captureHome(
            boundary,
            'admin-report-middle-$i-${layout.$1}-${layout.$2}',
            t,
          );
        }
      }
      expect(find.text('Tăng trưởng người dùng'), findsOneWidget);
      await captureHome(
        boundary,
        'admin-report-bottom-${layout.$1}-${layout.$2}',
        t,
      );
    });
  }
  testWidgets('Scope filters change totals and CSV uses the selected scope', (
    t,
  ) async {
    final s = admin();
    s.confirmVenuePayment(s.managedBookings.first);
    AdminReportFile? output;
    await pump(t, s, onExport: (file) async => output = file);
    await t.tap(find.byKey(const Key('system-report-period-30')));
    await t.pumpAndSettle();
    expect(
      find.text(bookingMoney(s.managedBookings.first.total)),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('system-report-sport')));
    await t.pumpAndSettle();
    await t.tap(find.text('Pickleball').last);
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('system-report-received'))).data,
      bookingMoney(0),
    );
    await press(t, 'system-report-export');
    await t.tap(find.byKey(const Key('system-report-export-csv')));
    await t.pumpAndSettle();
    expect(output!.name, endsWith('.csv'));
    expect(utf8.decode(output!.bytes), contains('Pickleball'));
    expect(utf8.decode(output!.bytes), contains('"Giá trị giao dịch","0"'));
    expect(t.takeException(), isNull);
  });
  testWidgets('Region scope and reset use actual region options', (t) async {
    final s = admin();
    s.confirmVenuePayment(s.managedBookings.first);
    await pump(t, s);
    await t.tap(find.byKey(const Key('system-report-period-30')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('system-report-region')));
    await t.pumpAndSettle();
    await t.tap(find.text('Chưa xác định').last);
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('system-report-received'))).data,
      bookingMoney(0),
    );
    await t.tap(find.byKey(const Key('system-report-reset-scope')));
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('system-report-received'))).data,
      bookingMoney(s.managedBookings.first.total),
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('Report tab retains Admin navigation and returns to overview', (
    t,
  ) async {
    final s = admin();
    final boundary = GlobalKey();
    t.view.physicalSize = const Size(402, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MyApp(session: s),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('admin-nav-3')));
    await t.pumpAndSettle();
    expect(find.byType(AdminSystemReportScreen), findsOneWidget);
    for (final title in [
      'Tổng quan',
      'Quản lý',
      'Duyệt',
      'Báo cáo',
      'Tài khoản',
    ]) {
      expect(find.text(title), findsWidgets);
    }
    await captureHome(boundary, 'admin-report-tab-with-navigation', t);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Export errors recover and busy export cannot duplicate', (
    t,
  ) async {
    final s = admin();
    var calls = 0;
    final pending = Completer<void>();
    await pump(
      t,
      s,
      onExport: (_) {
        calls++;
        return pending.future;
      },
    );
    await press(t, 'system-report-export');
    await t.tap(find.byKey(const Key('system-report-export-csv')));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('system-report-export')))
          .onPressed,
      isNull,
    );
    pending.completeError(StateError('Share failed'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('system-report-export-error')), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('system-report-export')))
          .onPressed,
      isNotNull,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('Account change while choosing export prevents data release', (
    t,
  ) async {
    final s = admin();
    var exports = 0;
    await pump(
      t,
      s,
      onExport: (_) async {
        exports++;
      },
    );
    await press(t, 'system-report-export');
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('system-report-export-csv')));
    await t.pumpAndSettle();
    expect(exports, 0);
    expect(find.text('Chỉ Admin được xem báo cáo hệ thống.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  test('PDF contains a real document with embedded Vietnamese font', () async {
    final s = admin();
    final data = AdminReportData.fromSession(
      s,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 9),
    );
    final file = await createAdminReportFile(data, pdf: true);
    expect(file.mimeType, 'application/pdf');
    expect(latin1.decode(file.bytes.take(5).toList()), '%PDF-');
    expect(file.bytes.length, greaterThan(5000));
    if (const bool.fromEnvironment('SCREENSHOT')) {
      await Directory('build/previews').create(recursive: true);
      await File('build/previews/admin-report-export.pdf')
          .writeAsBytes(file.bytes);
    }
  });
}
