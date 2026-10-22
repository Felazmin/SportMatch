import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/demo/demo_operations.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/admin_account_screen.dart';
import 'package:test_do_an/screens/admin_facility_review_screen.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';
import 'package:test_do_an/screens/facilities_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  late String photo;
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
    final data = await rootBundle.load('assets/figma/c0697.png');
    photo = encodeProof(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  });
  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  DemoSession open({TestSessionStore? store}) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    return s;
  }

  DemoFacility pending(DemoSession s, [String name = 'Sân Cầu Lông K99']) {
    owner(s);
    final f = s.saveFacility(
      FacilityProfile(
        name: name,
        sport: 'Cầu lông',
        address: '96 Chế Lan Viên',
        city: 'TP.HCM',
        district: 'Tân Phú',
        phone: DemoSession.phone,
        ownerName: 'Nguyễn Văn Hùng',
        courtCount: 6,
        openHour: 6,
        closeHour: 23,
        baseRate: 110000,
        photo: photo,
        legalProof: photo,
        amenities: {'Bãi xe', 'Nước uống', 'Wi-Fi'},
        description: 'Sân trong nhà, hệ thống chiếu sáng đạt chuẩn.',
        cancelPolicy: 'Hủy trước ít nhất 2 giờ: phí 5%.',
      ),
    );
    s.submitFacility(f);
    admin(s);
    return f;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    Widget page, {
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
          home: page,
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final image in t.widgetList<Image>(find.byType(Image))) {
      await t.runAsync(
        () =>
            precacheImage(image.image, t.element(find.byType(ListView).first)),
      );
    }
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.scrollUntilVisible(
      f,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    for (var screen = 0; screen < 3; screen++) {
      testWidgets('Admin reference screen $screen fits $scale', (t) async {
        final s = open();
        final actual = pending(s);
        s.reviewFacility(actual, approve: false, note: 'Bổ sung giấy tờ cơ sở');
        final next = pending(s, 'Sân chờ duyệt tiếp theo');
        final page = screen == 0
            ? AdminAccountScreen(session: s)
            : screen == 1
            ? ApprovalCenterScreen(session: s)
            : AdminFacilityReviewScreen(session: s, facility: next);
        final key = await pump(t, page, scale: scale);
        expect(t.takeException(), isNull);
        await captureHome(key, 'admin-review-$screen-$scale', t);
        for (var i = 0; i < 35; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -320));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(key, 'admin-review-$screen-bottom-$scale', t);
      });
    }
  }
  for (final decision in ['approved', 'supplement', 'rejected']) {
    testWidgets('Facility $decision is confirmed and audited', (t) async {
      final s = open(), f = pending(s);
      await pump(t, AdminFacilityReviewScreen(session: s, facility: f));
      await t.scrollUntilVisible(
        find.byKey(const Key('facility-review-reason')),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(
        find.byKey(const Key('facility-review-reason')),
        'Đã đối chiếu hồ sơ và giấy tờ',
      );
      await press(
        t,
        decision == 'approved'
            ? 'facility-approve'
            : decision == 'supplement'
            ? 'facility-reject'
            : 'facility-decline',
      );
      expect(f.state, 'pending');
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(f.reviewDecision, decision);
      expect(f.published != null, decision == 'approved');
      final entry = s.operationAudit.first;
      expect(entry.subject, f.id);
      expect(entry.decision, decision);
      expect(entry.note, 'Đã đối chiếu hồ sơ và giấy tờ');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Reason required; cancelling confirmation does not mutate', (
    t,
  ) async {
    final s = open(), f = pending(s);
    await pump(t, AdminFacilityReviewScreen(session: s, facility: f));
    await press(t, 'facility-decline');
    expect(find.byKey(const Key('facility-error')), findsOneWidget);
    expect(find.byKey(const Key('finance-confirm')), findsNothing);
    await press(t, 'facility-approve');
    await t.tap(find.text('Quay lại').last);
    await t.pumpAndSettle();
    expect(f.state, 'pending');
    expect(f.published, isNull);
  });
  testWidgets('Changing revision or actor during preview prevents decision', (
    t,
  ) async {
    final s = open(), f = pending(s);
    await pump(t, AdminFacilityReviewScreen(session: s, facility: f));
    await press(t, 'facility-approve');
    owner(s);
    s.updatePendingFacility(f.draft, facility: f, expectedRevision: f.revision);
    admin(s);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(f.state, 'pending');
    expect(find.byKey(const Key('facility-error')), findsOneWidget);
    await press(t, 'facility-approve');
    s.logout();
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(f.state, 'pending');
    expect(find.text('Chỉ Admin được truy cập hồ sơ này.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Queue ages, pagination, search and facility route', (t) async {
    final s = open();
    for (var i = 0; i < 7; i++) {
      final f = pending(s, 'Cơ sở $i');
      f.updated = s.now.subtract(Duration(hours: 12 * i));
    }
    await pump(t, ApprovalCenterScreen(session: s));
    await press(t, 'approval-age-1');
    expect(find.textContaining('Đang hiển thị 3 / 3 yêu cầu'), findsOneWidget);
    await press(t, 'approval-age-0');
    await press(t, 'approval-more');
    await t.scrollUntilVisible(
      find.textContaining('Đang hiển thị 7 / 7 yêu cầu'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Đang hiển thị 7 / 7 yêu cầu'), findsOneWidget);
    await t.scrollUntilVisible(
      find.byKey(const Key('approval-search')),
      -350,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.byKey(const Key('approval-search')));
    await t.enterText(find.byKey(const Key('approval-search')), 'CS0007');
    await t.pumpAndSettle();
    await press(t, 'approval-facility-CS0007');
    expect(find.byType(AdminFacilityReviewScreen), findsOneWidget);
    expect(find.byType(FacilityDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Audit export respects search, escaping and real decisions', (
    t,
  ) async {
    final s = open(), f = pending(s);
    s.reviewFacility(
      f,
      approve: false,
      reject: true,
      note: '=Không đủ giấy tờ',
    );
    Uint8List? bytes;
    await pump(
      t,
      AdminAccountScreen(
        session: s,
        onExport: (value) async {
          bytes = value;
        },
      ),
    );
    await t.enterText(find.byKey(const Key('admin-audit-search')), '=Không đủ');
    await t.pumpAndSettle();
    await press(t, 'admin-audit-export');
    final text = utf8.decode(bytes!.sublist(3));
    expect(text, contains("'=Không đủ giấy tờ"));
    expect(text, contains(f.id));
    expect(text, contains('Đã từ chối'));
    expect(text, isNot(contains('Lưu nháp')));
  });
  testWidgets('Admin account root route is distinct and protected', (t) async {
    final s = open();
    admin(s);
    await t.pumpWidget(MyApp(session: s));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('admin-nav-4')));
    await t.pumpAndSettle();
    expect(find.byType(AdminAccountScreen), findsOneWidget);
    expect(find.text('Nhật ký & cài đặt'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Notification changes require password and are audited', (
    t,
  ) async {
    final s = open();
    admin(s);
    await pump(t, AdminAccountScreen(session: s));
    await press(t, 'admin-account-tab-1');
    await press(t, 'admin-notify-requests');
    await t.enterText(find.byKey(const Key('admin-confirm-password')), 'wrong');
    await t.tap(find.text('Xác nhận').last);
    await t.pumpAndSettle();
    expect(s.adminNotificationPreferences.requests, isTrue);
    await press(t, 'admin-notify-requests');
    await t.enterText(
      find.byKey(const Key('admin-confirm-password')),
      DemoSession.password,
    );
    await t.tap(find.text('Xác nhận').last);
    await t.pumpAndSettle();
    expect(s.adminNotificationPreferences.requests, isFalse);
    expect(s.operationAudit.first.action, contains('tùy chọn thông báo'));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Password change verifies old password and logs without secrets',
    (t) async {
      final s = open();
      admin(s);
      await pump(t, AdminPasswordScreen(session: s));
      await t.enterText(
        find.byKey(const Key('admin-password-current')),
        DemoSession.password,
      );
      await t.enterText(
        find.byKey(const Key('admin-password-next')),
        'AdminNext123',
      );
      await t.enterText(
        find.byKey(const Key('admin-password-confirm')),
        'AdminNext123',
      );
      await press(t, 'admin-password-save');
      expect(find.text('Đã đổi mật khẩu.'), findsOneWidget);
      expect(s.operationAudit.first.action, 'Đổi mật khẩu quản trị');
      expect(
        s.operationAudit.first.toJson().toString(),
        isNot(contains('AdminNext123')),
      );
      s.logout();
      expect(
        s.loginStaff(
          DemoRole.admin,
          DemoSession.adminEmail,
          DemoSession.password,
        ),
        isFalse,
      );
      expect(
        s.loginStaff(DemoRole.admin, DemoSession.adminEmail, 'AdminNext123'),
        isTrue,
      );
    },
  );
  testWidgets(
    'Export failure leaves retry available and role change hides audit',
    (t) async {
      final s = open(), f = pending(s);
      s.reviewFacility(f, approve: true);
      var calls = 0;
      await pump(
        t,
        AdminAccountScreen(
          session: s,
          onExport: (_) async {
            calls++;
            throw StateError('share unavailable');
          },
        ),
      );
      await press(t, 'admin-audit-export');
      expect(calls, 1);
      await press(t, 'admin-audit-export');
      expect(calls, 2);
      owner(s);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('admin-audit-export')), findsNothing);
      expect(find.text('Chỉ Admin được truy cập.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  test(
    'Decisions, structured audit and preferences survive restoration',
    () async {
      final store = TestSessionStore(), s = open(store: store);
      await s.initialize();
      final f = pending(s);
      expect(
        () => s.updateAdminNotifications(
          password: 'wrong',
          requests: false,
          overdue: false,
          weekly: false,
        ),
        throwsStateError,
      );
      s.updateAdminNotifications(
        password: DemoSession.password,
        requests: false,
        overdue: true,
        weekly: false,
      );
      s.reviewFacility(
        f,
        approve: false,
        reject: true,
        note: 'Thiếu giấy tờ cơ sở',
      );
      await s.flush();
      final restored = open(store: store);
      await restored.initialize();
      admin(restored);
      expect(restored.managedFacilities.single.reviewDecision, 'rejected');
      expect(restored.managedFacilities.single.label, 'Bị từ chối');
      expect(restored.operationAudit.first.note, 'Thiếu giấy tờ cơ sở');
      expect(restored.adminNotificationPreferences, (
        requests: false,
        overdue: true,
        weekly: false,
      ));
      owner(restored);
      expect(() => restored.adminNotificationPreferences, throwsStateError);
      restored.submitFacility(restored.managedFacilities.single);
      expect(restored.managedFacilities.single.reviewDecision, '');
    },
  );
  test('Legacy audit and facility records remain readable', () {
    final s = open(), f = pending(s);
    final json = f.toJson()..remove('reviewDecision');
    expect(DemoFacility.fromJson(json).reviewDecision, '');
    final audit = DemoAuditEntry.fromJson({
      'actor': '__admin__',
      'action': 'Duyệt hồ sơ cũ',
      'created': s.now.toIso8601String(),
    });
    expect(audit.note, '');
    expect(audit.decision, '');
  });
}
