import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/admin_management_screen.dart';
import 'package:test_do_an/screens/admin_facility_review_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  late String photo;
  DateTime now = DateTime(2026, 10, 9, 10);
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
    final bytes = await rootBundle.load('assets/figma/c0697.png');
    photo = encodeProof(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
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
  DemoSession fixture() {
    now = DateTime(2026, 10, 8, 10);
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    owner(s);
    final f = s.saveFacility(
      FacilityProfile(
        name: 'Sân Cầu Lông K99',
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
        amenities: {'Bãi xe', 'Wi-Fi'},
        description: 'Sân trong nhà, chiếu sáng đạt chuẩn.',
      ),
    );
    s.submitFacility(f);
    admin(s);
    s.reviewFacility(f, approve: true);
    owner(s);
    s.submitOwnerVerification(
      name: 'Nguyễn Văn Hùng',
      phone: DemoSession.phone,
      proof: photo,
      expectedRevision: 0,
    );
    final type = s.saveCourtType(
      name: 'Cầu lông mái che',
      sport: 'Cầu lông',
      description: 'Sân trong nhà có mái che, thảm PVC.',
    );
    s.transitionCourtType(type.id, 'pending', type.revision);
    final group = s.savePlayGroup(
      name: 'Hội Cầu Lông Bình Thạnh',
      sport: 'badminton',
      description: 'Cùng tập luyện và giao lưu cầu lông mỗi cuối tuần.',
      photo: photo,
    );
    s.transitionPlayGroup(group.id, 'pending', group.revision);
    final activity = s.saveActivity(
      title: 'Social Pickleball cuối tuần',
      kind: DemoEventKind.social,
      start: DateTime(2026, 10, 11, 18),
      durationMinutes: 120,
      capacity: 16,
      fee: 80000,
      description: 'Giao lưu trình độ cơ bản đến trung bình; hỗ trợ ghép đôi.',
    );
    s.transitionActivity(activity.id, 'pending', activity.revision);
    s.login(DemoSession.phone, DemoSession.password);
    final b = s.reserve(
      facilityId: f.id,
      court: 1,
      start: DateTime(2026, 10, 9, 9),
      hours: 1,
      contact: 'Khách thử',
      contactPhone: DemoSession.phone,
    );
    owner(s);
    s.confirmVenuePayment(b);
    now = b.start;
    s.setAttendance(b.id, DemoAttendance.checkedIn);
    now = b.end;
    s.setAttendance(b.id, DemoAttendance.completed);
    s.login(DemoSession.phone, DemoSession.password);
    s.submitVenueReview(
      b.id,
      2,
      'Sân sạch nhưng hôm mình đến đèn sân hơi tối.',
    );
    admin(s);
    return s;
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
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        key = GlobalKey();
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
    for (var kind = 0; kind < 7; kind++) {
      testWidgets('Admin management $kind fits $scale', (t) async {
        final s = fixture();
        final key = await pump(
          t,
          AdminManagementScreen(session: s, initialKind: kind),
          scale: scale,
        );
        expect(find.byKey(const Key('admin-management-kind')), findsOneWidget);
        expect(t.takeException(), isNull);
        await captureHome(key, 'admin-management-$kind-$scale', t);
        for (var i = 0; i < 8; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -300));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        final entry = adminManagementEntries(s, kind).last;
        final detail = await pump(
          t,
          AdminManagementDetailScreen(session: s, kind: kind, id: entry.id),
          scale: scale,
        );
        expect(
          find.byKey(const Key('admin-management-detail-state')),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await captureHome(detail, 'admin-management-detail-$kind-$scale', t);
        for (var i = 0; i < 20; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -300));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          detail,
          'admin-management-detail-$kind-bottom-$scale',
          t,
        );
      });
    }
  }
  testWidgets('Root tab dropdown selects all seven actual lists', (t) async {
    final s = fixture();
    await t.pumpWidget(MyApp(session: s));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('admin-nav-1')));
    await t.pumpAndSettle();
    expect(find.byType(AdminManagementScreen), findsOneWidget);
    for (var kind = 0; kind < 7; kind++) {
      await t.tap(find.byKey(const Key('admin-management-kind')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(adminManagementKinds[kind]).last);
      await t.tap(find.text(adminManagementKinds[kind]).last);
      await t.pumpAndSettle();
      expect(find.text(adminManagementKinds[kind]), findsWidgets);
      expect(t.takeException(), isNull);
    }
  });
  testWidgets('Search filters current kind and pending facility opens review', (
    t,
  ) async {
    final s = fixture(), f = s.managedFacilities.single;
    owner(s);
    s.saveFacility(f.draft, facility: f);
    s.submitFacility(f);
    admin(s);
    await pump(t, AdminManagementScreen(session: s));
    await t.enterText(
      find.byKey(const Key('admin-management-search')),
      'no match',
    );
    await t.pumpAndSettle();
    expect(find.text('Không có kết quả phù hợp.'), findsOneWidget);
    await t.enterText(find.byKey(const Key('admin-management-search')), f.id);
    await t.pumpAndSettle();
    await press(t, 'admin-management-entry-0-${f.id}');
    expect(find.byType(AdminFacilityReviewScreen), findsOneWidget);
  });
  for (final action in [
    (1, 'owner-approve'),
    (4, 'type-approve'),
    (5, 'activity-approve'),
    (6, 'group-approve'),
  ]) {
    testWidgets('Admin confirms ${action.$2} and logs decision', (t) async {
      final s = fixture(),
          entry = adminManagementEntries(fixture(), action.$1).first;
      await pump(
        t,
        AdminManagementDetailScreen(session: s, kind: action.$1, id: entry.id),
      );
      if (action.$1 == 1) {
        await t.scrollUntilVisible(
          find.byKey(const Key('admin-management-password')),
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(
          find.byKey(const Key('admin-management-password')),
          DemoSession.password,
        );
      }
      await press(t, 'admin-management-${action.$2}');
      expect(find.byKey(const Key('finance-confirm')), findsOneWidget);
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(
        adminManagementEntries(s, action.$1).first.state,
        action.$1 == 1 ? 'verified' : 'approved',
      );
      expect(s.operationAudit.first.decision, 'approved');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'Suspending facility needs reason, preserves bookings and audits',
    (t) async {
      final s = fixture(), f = s.managedFacilities.single;
      final count = s.managedBookings.length;
      await pump(t, AdminManagementDetailScreen(session: s, kind: 0, id: f.id));
      await press(t, 'admin-management-facility-access');
      expect(f.suspended, isFalse);
      expect(find.byKey(const Key('finance-confirm')), findsNothing);
      await t.enterText(
        find.byKey(const Key('admin-management-reason')),
        'Kiểm tra an toàn cơ sở',
      );
      await press(t, 'admin-management-facility-access');
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(f.suspended, isTrue);
      expect(s.managedBookings.length, count);
      expect(s.operationAudit.first.note, 'Kiểm tra an toàn cơ sở');
    },
  );
  testWidgets('Moderation keeps original text and can restore visibility', (
    t,
  ) async {
    final s = fixture(), review = s.managedReviews.single;
    await pump(
      t,
      AdminManagementDetailScreen(session: s, kind: 3, id: review.bookingId),
    );
    await t.scrollUntilVisible(
      find.byKey(const Key('admin-management-reason')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await t.enterText(
      find.byKey(const Key('admin-management-reason')),
      'Đã kiểm tra bằng chứng vi phạm',
    );
    await press(t, 'admin-management-review-moderate');
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.managedReviews.single.hidden, isTrue);
    expect(s.managedReviews.single.message, review.message);
    await press(t, 'admin-management-review-moderate');
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.managedReviews.single.hidden, isFalse);
    expect(s.managedReviews.single.stars, review.stars);
  });
  testWidgets('Role change removes all private management content', (t) async {
    final s = fixture();
    await pump(t, AdminManagementScreen(session: s));
    owner(s);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('admin-management-kind')), findsNothing);
    expect(find.text('Chỉ Admin được truy cập.'), findsOneWidget);
  });
  for (final kind in [4, 5, 6]) {
    testWidgets('Supplement decision for kind $kind remains distinct', (
      t,
    ) async {
      final s = fixture(),
          id = adminManagementEntries(fixture(), kind).first.id;
      await pump(
        t,
        AdminManagementDetailScreen(session: s, kind: kind, id: id),
      );
      await t.scrollUntilVisible(
        find.byKey(const Key('admin-management-reason')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(
        find.byKey(const Key('admin-management-reason')),
        'Vui lòng bổ sung thông tin hồ sơ',
      );
      await press(
        t,
        'admin-management-${kind == 4
            ? 'type'
            : kind == 5
            ? 'activity'
            : 'group'}-supplement',
      );
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(adminManagementEntries(s, kind).first.state, 'supplement');
      expect(s.operationAudit.first.decision, 'supplement');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Rejecting owner is distinct from requesting supplement', (
    t,
  ) async {
    final s = fixture();
    await pump(
      t,
      AdminManagementDetailScreen(session: s, kind: 1, id: '__owner__'),
    );
    await t.scrollUntilVisible(
      find.byKey(const Key('admin-management-reason')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await t.enterText(
      find.byKey(const Key('admin-management-reason')),
      'Hồ sơ không đáp ứng yêu cầu',
    );
    await t.enterText(
      find.byKey(const Key('admin-management-password')),
      DemoSession.password,
    );
    await press(t, 'admin-management-owner-reject');
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.ownerVerification!.label, 'Bị từ chối');
    expect(s.ownerVerification!.reviewDecision, 'rejected');
    expect(s.operationAudit.first.decision, 'rejected');
    expect(t.takeException(), isNull);
  });
}
