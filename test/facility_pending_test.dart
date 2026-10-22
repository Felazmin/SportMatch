import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/facilities_screen.dart';
import 'package:test_do_an/screens/facility_pending_screen.dart';
import 'package:test_do_an/screens/owner_facility_edit_list_screen.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

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
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  FacilityProfile profile([String name = 'Sân Cầu Lông K99']) =>
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
      );
  test('Pending updates stay pending, private and survive restart', () async {
    final store = TestSessionStore(), s = open(store);
    await s.initialize();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    final revision = f.revision;
    s.updatePendingFacility(
      profile('K99 đã bổ sung'),
      facility: f,
      expectedRevision: revision,
    );
    expect(f.state, 'pending');
    expect(f.revision, revision + 1);
    expect(s.managedFacilities.length, 1);
    expect(s.publicFacilities, isEmpty);
    await s.flush();
    final restored = open(store);
    await restored.initialize();
    owner(restored);
    expect(restored.managedFacilities.single.state, 'pending');
    expect(restored.managedFacilities.single.draft.name, 'K99 đã bổ sung');
  });
  test('Stale owner and admin revisions cannot overwrite pending updates', () {
    final s = open();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    final old = f.revision;
    s.updatePendingFacility(
      profile('K99 mới'),
      facility: f,
      expectedRevision: old,
    );
    expect(
      () => s.updatePendingFacility(
        profile('Ghi đè'),
        facility: f,
        expectedRevision: old,
      ),
      throwsStateError,
    );
    admin(s);
    expect(
      () => s.reviewFacility(f, approve: true, expectedRevision: old),
      throwsStateError,
    );
    expect(
      () => s.updatePendingFacility(
        profile('Admin sửa'),
        facility: f,
        expectedRevision: f.revision,
      ),
      throwsStateError,
    );
    s.reviewFacility(f, approve: true, expectedRevision: f.revision);
    owner(s);
    expect(
      () => s.updatePendingFacility(
        profile('Đã duyệt sửa lại'),
        facility: f,
        expectedRevision: f.revision,
      ),
      throwsStateError,
    );
    expect(f.draft.name, 'K99 mới');
  });
  test('Pending edits preserve live profile until admin approves revision', () {
    final s = open();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    admin(s);
    s.reviewFacility(f, approve: true);
    owner(s);
    s.saveFacility(
      profile('Bản sửa lần 1'),
      facility: f,
      expectedRevision: f.revision,
    );
    s.submitFacility(f);
    s.updatePendingFacility(
      profile('Bản sửa lần 2'),
      facility: f,
      expectedRevision: f.revision,
    );
    expect(s.publicFacilities.single.profile.name, 'Sân Cầu Lông K99');
    admin(s);
    s.reviewFacility(f, approve: true, expectedRevision: f.revision);
    expect(s.publicFacilities.single.profile.name, 'Bản sửa lần 2');
  });
  test('Missing proof and player role cannot mutate pending application', () {
    final s = open();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    final old = f.revision;
    final incomplete = FacilityProfile.fromJson({
      ...profile().toJson(),
      'legalProof': '',
    });
    expect(
      () => s.updatePendingFacility(
        incomplete,
        facility: f,
        expectedRevision: old,
      ),
      throwsStateError,
    );
    expect(f.revision, old);
    s.login(DemoSession.phone, DemoSession.password);
    expect(
      () => s.updatePendingFacility(
        profile(),
        facility: f,
        expectedRevision: old,
      ),
      throwsStateError,
    );
    expect(f.revision, old);
  });
  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
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
    for (final e in find.byType(Image).evaluate().toList()) {
      await t.runAsync(() => precacheImage((e.widget as Image).image, e));
    }
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(
      f,
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Pending screen edits, saves once, and cancel discards input', (
    t,
  ) async {
    final s = open();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    await pump(t, FacilityDetailScreen(session: s, facility: f));
    expect(find.byType(FacilityPendingScreen), findsOneWidget);
    await press(t, find.byKey(const Key('facility-edit')));
    expect(find.text('Chỉnh sửa sân'), findsOneWidget);
    expect(find.byKey(const Key('facility-submit-application')), findsNothing);
    await t.enterText(
      find.byKey(const Key('facility-field-name')),
      'K99 đã cập nhật',
    );
    await press(t, find.byKey(const Key('facility-save-pending')));
    expect(f.draft.name, 'K99 đã cập nhật');
    expect(f.state, 'pending');
    expect(s.managedFacilities.length, 1);
    expect(s.publicFacilities, isEmpty);
    await press(t, find.byKey(const Key('facility-edit')));
    await t.enterText(
      find.byKey(const Key('facility-field-name')),
      'Không lưu thay đổi',
    );
    await press(t, find.byKey(const Key('facility-cancel-changes')));
    expect(f.draft.name, 'K99 đã cập nhật');
    expect(find.byType(FacilityFormScreen), findsNothing);
    expect(t.takeException(), isNull);
  });
  test('Primary profile uses approval and persistence without duplicate venue or booking inventory', () async {
    final store = TestSessionStore(), s = open(store);
    await s.initialize();
    owner(s);
    final oldName = s.currentVenues.single.name,
        oldPrice = s.currentVenues.single.price;
    final f = s.ensurePrimaryFacilityProfile(photo);
    expect(identical(f, s.ensurePrimaryFacilityProfile(photo)), isTrue);
    expect(s.managedFacilities, isEmpty);
    final edited = FacilityProfile.fromJson({
      ...f.draft.toJson(),
      'name': 'Sân chính cập nhật',
      'legalProof': photo,
    });
    s.saveFacility(edited, facility: f, expectedRevision: f.revision);
    s.submitFacility(f);
    expect(s.currentVenues.single.name, oldName);
    expect(s.ownerEditableFacilities.single.id, 'CS0000');
    expect(s.publicFacilities, isEmpty);
    await s.flush();
    final restored = open(store);
    await restored.initialize();
    owner(restored);
    expect(restored.loadFailed, isFalse);
    final saved = restored.ownerEditableFacilities.single;
    expect(saved.state, 'pending');
    expect(restored.currentVenues.single.name, oldName);
    admin(restored);
    expect(restored.managedFacilities.single.id, 'CS0000');
    restored.reviewFacility(
      saved,
      approve: true,
      expectedRevision: saved.revision,
    );
    expect(restored.currentVenues.single.id, demoVenueId);
    expect(restored.currentVenues.single.name, 'Sân chính cập nhật');
    expect(restored.currentVenues.single.price, oldPrice);
    expect(restored.publicFacilities, isEmpty);
    await restored.flush();
    final approved = open(store);
    await approved.initialize();
    owner(approved);
    expect(approved.loadFailed, isFalse);
    expect(approved.currentVenues.single.name, 'Sân chính cập nhật');
    final added = approved.saveFacility(profile());
    expect(added.id, 'CS0001');
  });
  test(
    'Primary profile rejects player access and structural court changes',
    () {
      final s = open();
      owner(s);
      final f = s.ensurePrimaryFacilityProfile(photo);
      final invalid = FacilityProfile.fromJson({
        ...f.draft.toJson(),
        'courtCount': 6,
      });
      expect(
        () =>
            s.saveFacility(invalid, facility: f, expectedRevision: f.revision),
        throwsStateError,
      );
      expect(f.draft.courtCount, 3);
      s.login(DemoSession.phone, DemoSession.password);
      expect(() => s.ensurePrimaryFacilityProfile(photo), throwsStateError);
      expect(() => s.ownerEditableFacilities, throwsStateError);
    },
  );
  testWidgets(
    'Edit list opens the selected existing pending profile and never creates a duplicate',
    (t) async {
      final s = open();
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      await pump(t, OwnerFacilityEditListScreen(session: s));
      expect(find.byType(FacilityFormScreen), findsNothing);
      await press(t, find.byKey(Key('owner-edit-facility-${f.id}')));
      final form = t.widget<FacilityFormScreen>(
        find.byType(FacilityFormScreen),
      );
      expect(form.facility, same(f));
      expect(form.editProfile, isTrue);
      await t.enterText(
        find.byKey(const Key('facility-field-name')),
        'K99 đổi tên',
      );
      await press(t, find.byKey(const Key('facility-save-pending')));
      expect(f.state, 'pending');
      expect(f.draft.name, 'K99 đổi tên');
      expect(s.managedFacilities.length, 1);
    },
  );
  testWidgets(
    'Primary appears and opens prefilled form; cancel does not modify it',
    (t) async {
      final s = open();
      owner(s);
      await pump(t, OwnerFacilityEditListScreen(session: s));
      await press(t, find.byKey(const Key('owner-edit-facility-CS0000')));
      final f = s.ownerEditableFacilities.single;
      expect(
        t.widget<FacilityFormScreen>(find.byType(FacilityFormScreen)).facility,
        same(f),
      );
      await t.enterText(
        find.byKey(const Key('facility-field-name')),
        'Không lưu',
      );
      await press(t, find.byKey(const Key('facility-cancel-changes')));
      expect(find.byType(OwnerFacilityEditListScreen), findsOneWidget);
      expect(f.draft.name, isNot('Không lưu'));
    },
  );
  testWidgets(
    'Approved edit submits revision while retaining published profile',
    (t) async {
      final s = open();
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      admin(s);
      s.reviewFacility(f, approve: true);
      owner(s);
      await pump(
        t,
        FacilityFormScreen(session: s, facility: f, editProfile: true),
      );
      await t.enterText(
        find.byKey(const Key('facility-field-name')),
        'Bản cập nhật K99',
      );
      await press(t, find.byKey(const Key('facility-save-pending')));
      expect(f.state, 'pending');
      expect(f.draft.name, 'Bản cập nhật K99');
      expect(f.published!.name, 'Sân Cầu Lông K99');
      expect(s.publicFacilities.single.profile.name, 'Sân Cầu Lông K99');
    },
  );
  for (final layout in [(402.0, 1.0), (320.0, 2.0)]) {
    testWidgets('Edit list fits ${layout.$1}/${layout.$2}', (t) async {
      final s = open();
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      final key = await pump(
        t,
        OwnerFacilityEditListScreen(session: s),
        width: layout.$1,
        scale: layout.$2,
      );
      await captureHome(
        key,
        'owner-edit-list-${layout.$1.toInt()}-${layout.$2}',
        t,
      );
      await press(t, find.byKey(Key('owner-edit-facility-${f.id}')));
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'Dashboard pending destination handles empty and multiple applications',
    (t) async {
      final s = open();
      owner(s);
      await pump(t, OwnerPendingFacilitiesScreen(session: s));
      expect(find.text('Chưa có hồ sơ sân đang chờ duyệt.'), findsOneWidget);
      final first = s.saveFacility(profile());
      s.submitFacility(first);
      await t.pumpAndSettle();
      expect(find.byType(FacilityPendingScreen), findsOneWidget);
      final second = s.saveFacility(profile('Sân thứ hai'));
      s.submitFacility(second);
      await t.pumpAndSettle();
      expect(
        find.byKey(Key('owner-pending-facility-${first.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('owner-pending-facility-${second.id}')),
        findsOneWidget,
      );
      await press(t, find.byKey(Key('owner-pending-facility-${second.id}')));
      expect(
        t
            .widget<FacilityPendingScreen>(find.byType(FacilityPendingScreen))
            .facility
            .id,
        second.id,
      );
      s.login(DemoSession.phone, DemoSession.password);
      await t.pumpAndSettle();
      expect(find.text('Chưa có quyền truy cập.'), findsOneWidget);
      expect(find.byKey(const Key('facility-edit')), findsNothing);
    },
  );
  testWidgets(
    'Submission display preserves minutes instead of rounding to hour',
    (t) async {
      final s = DemoSession(now: () => DateTime(2026, 10, 10, 8, 47));
      addTearDown(s.dispose);
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      await pump(t, FacilityPendingScreen(session: s, facility: f));
      expect(find.textContaining('08:47'), findsNWidgets(2));
      expect(find.textContaining('08:00'), findsNothing);
    },
  );
  testWidgets(
    'Failed edit save stays visible, can retry persistence and reopen latest pending revision',
    (t) async {
      final store = TestSessionStore(), s = open(store);
      await s.initialize();
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      await s.flush();
      final revision = f.revision;
      store.failWrite = true;
      await pump(t, FacilityFormScreen(session: s, facility: f));
      await t.enterText(
        find.byKey(const Key('facility-field-name')),
        'K99 sửa hồ sơ',
      );
      await press(t, find.byKey(const Key('facility-save-pending')));
      expect(find.byType(FacilityFormScreen), findsOneWidget);
      expect(s.saveFailed, isTrue);
      expect(f.revision, revision + 1);
      expect(f.state, 'pending');
      expect(s.publicFacilities, isEmpty);
      store.failWrite = false;
      await t.drag(find.byType(ListView).first, const Offset(0, 5000));
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('finance-retry-save')));
      expect(s.saveFailed, isFalse);
      expect(f.revision, revision + 1);
      final restored = open(store);
      await restored.initialize();
      owner(restored);
      expect(restored.managedFacilities.single.draft.name, 'K99 sửa hồ sơ');
      expect(restored.managedFacilities.single.state, 'pending');
    },
  );
  testWidgets('Admin approval while form is open disables stale save', (
    t,
  ) async {
    final s = open();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    await pump(t, FacilityFormScreen(session: s, facility: f));
    admin(s);
    s.reviewFacility(f, approve: true, expectedRevision: f.revision);
    owner(s);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('facility-save-pending')),
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('facility-save-pending')))
          .onPressed,
      isNull,
    );
    expect(f.state, 'approved');
    expect(t.takeException(), isNull);
  });
  for (final layout in [(402.0, 1.0), (320.0, 2.0)]) {
    for (final view in ['pending', 'edit']) {
      testWidgets('$view fits ${layout.$1}/${layout.$2}', (t) async {
        final s = open();
        owner(s);
        final f = s.saveFacility(profile());
        s.submitFacility(f);
        final key = await pump(
          t,
          view == 'pending'
              ? FacilityDetailScreen(session: s, facility: f)
              : FacilityFormScreen(session: s, facility: f),
          width: layout.$1,
          scale: layout.$2,
        );
        await captureHome(
          key,
          'facility-$view-${layout.$1.toInt()}-${layout.$2}',
          t,
        );
        expect(t.takeException(), isNull);
        for (var i = 0; i < 9; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -280));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'facility-$view-bottom-${layout.$1.toInt()}-${layout.$2}',
          t,
        );
      });
    }
  }
}
