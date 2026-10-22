import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/facilities_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String png;
  late Uint8List bytes;
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
    final data = await rootBundle.load('assets/figma/c0697.png');
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    png = encodeProof(bytes);
  });
  DemoSession make([TestSessionStore? store]) {
    final s = DemoSession(now: () => DateTime(2026, 10, 6, 10), store: store);
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
  FacilityProfile profile() => FacilityProfile(
    name: 'Cơ sở thử nghiệm',
    sport: 'Cầu lông',
    address: '12 Đường thử nghiệm',
    city: 'TP.HCM',
    district: 'Tân Phú',
    phone: DemoSession.phone,
    ownerName: 'Người đại diện riêng',
    courtCount: 3,
    openHour: 6,
    closeHour: 22,
    baseRate: 120000,
    description: 'Cơ sở thử nghiệm cho bản demo',
    photo: png,
    legalProof: png,
    amenities: {'Bãi xe', 'Nước uống'},
  );
  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
    double width = 402,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MyApp());
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 879),
            textScaler: TextScaler.linear(scale),
          ),
          child: RepaintBoundary(key: key, child: screen),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> visible(WidgetTester t, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable).first;
      t.state<ScrollableState>(scrollable).position.jumpTo(0);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        finder,
        350,
        scrollable: scrollable,
        maxScrolls: 40,
      );
    }
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await visible(t, f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> enter(WidgetTester t, String key, String text) async {
    final f = find.byKey(Key('facility-field-$key'));
    await visible(t, f);
    await t.pumpAndSettle();
    await t.enterText(f, text);
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    for (final element in find.byType(Image).evaluate().toList()) {
      final widget = element.widget as Image;
      await t.runAsync(() => precacheImage(widget.image, element));
    }
    await t.pumpAndSettle();
    await captureHome(key, name, t);
  }

  testWidgets(
    'Owner fills profile, picks images, saves draft, submits and admin approves',
    (t) async {
      final s = make();
      owner(s);
      await pump(
        t,
        FacilityFormScreen(session: s, pickImage: () async => bytes),
      );
      await enter(t, 'name', 'Cơ sở thử nghiệm');
      await enter(t, 'address', '12 Đường thử nghiệm');
      await enter(t, 'district', 'Tân Phú');
      await enter(t, 'phone', DemoSession.phone);
      await press(t, 'facility-photo');
      await press(t, 'facility-legal');
      await press(t, 'facility-save-draft');
      expect(s.managedFacilities.length, 1);
      await press(t, 'facility-submit');
      expect(s.managedFacilities.single.state, 'pending');
      admin(s);
      await t.pumpAndSettle();
      await press(t, 'facility-approve');
      await press(t, 'finance-confirm');
      expect(s.publicFacilities.length, 1);
      final key = await pump(
        t,
        FacilityDetailScreen(session: s, facility: s.managedFacilities.single),
      );
      await capture(t, key, 'facility-approval-complete');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Admin rejection displays reason and owner can reopen correction form',
    (t) async {
      final s = make();
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      admin(s);
      await pump(t, FacilityDetailScreen(session: s, facility: f));
      await visible(t, find.byKey(const Key('facility-review-reason')));
      await t.enterText(
        find.byKey(const Key('facility-review-reason')),
        'Bổ sung địa chỉ thử nghiệm',
      );
      await press(t, 'facility-reject');
      await press(t, 'finance-confirm');
      expect(f.state, 'rejected');
      await visible(t, find.text('Bổ sung địa chỉ thử nghiệm'));
      expect(find.text('Bổ sung địa chỉ thử nghiệm'), findsWidgets);
      owner(s);
      await t.pumpAndSettle();
      await press(t, 'facility-edit');
      expect(find.byType(FacilityFormScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Draft submit without attachments shows error and no public record',
    (t) async {
      final s = make();
      owner(s);
      final f = s.saveFacility(
        FacilityProfile.fromJson({
          ...profile().toJson(),
          'photo': '',
          'legalProof': '',
        }),
      );
      await pump(t, FacilityDetailScreen(session: s, facility: f));
      await press(t, 'facility-submit');
      expect(find.byKey(const Key('facility-error')), findsOneWidget);
      expect(f.state, 'draft');
      expect(s.publicFacilities, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Image selection cancellation and failure keep form alive', (
    t,
  ) async {
    final s = make();
    owner(s);
    await pump(t, FacilityFormScreen(session: s, pickImage: () async => null));
    await press(t, 'facility-photo');
    expect(find.byKey(const Key('facility-form-error')), findsNothing);
    await pump(
      t,
      FacilityFormScreen(
        key: const Key('pick-error'),
        session: s,
        pickImage: () async => throw StateError('gallery denied'),
      ),
    );
    await press(t, 'facility-photo');
    await visible(t, find.byKey(const Key('facility-form-error')));
    expect(
      find.text('Không chọn được ảnh PNG/JPEG tối đa 400KB.'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('Failed submit save retry does not duplicate facility', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = make(store);
    await s.initialize();
    owner(s);
    final f = s.saveFacility(profile());
    await s.flush();
    store.failWrite = true;
    await pump(t, FacilityDetailScreen(session: s, facility: f));
    await press(t, 'facility-submit');
    await visible(t, find.byKey(const Key('finance-retry-save')));
    expect(find.byKey(const Key('finance-retry-save')), findsOneWidget);
    store.failWrite = false;
    await press(t, 'finance-retry-save');
    expect(s.managedFacilities.length, 1);
    expect(s.managedFacilities.single.state, 'pending');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Public profile omits legal material and disappears on suspension',
    (t) async {
      final s = make();
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      admin(s);
      s.reviewFacility(f, approve: true);
      await pump(t, PublicFacilityScreen(session: s, id: f.id));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Ảnh giấy tờ mẫu'), findsNothing);
      expect(find.text('Người đại diện riêng'), findsNothing);
      s.suspendFacility(f, true);
      await t.pumpAndSettle();
      expect(
        find.text('Cơ sở chưa công bố hoặc đã tạm ngưng.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Management filters pending records and searches names', (
    t,
  ) async {
    final s = make();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    s.saveFacility(
      FacilityProfile.fromJson({...profile().toJson(), 'name': 'Cơ sở khác'}),
    );
    await pump(t, FacilitiesScreen(session: s));
    await press(t, 'owner-facilities-filter-2');
    expect(find.byKey(Key('facility-${f.id}')), findsOneWidget);
    expect(find.byKey(const Key('facility-CS0002')), findsNothing);
    await press(t, 'facility-search-toggle');
    await t.enterText(
      find.byKey(const Key('facility-search')),
      'không tồn tại',
    );
    await t.pumpAndSettle();
    expect(find.text('Chưa có sân phù hợp.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final view in [
    'owner-list',
    'admin-list',
    'form',
    'pending',
    'approved',
    'public',
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$view fits ${scale == 1 ? 402 : 320}px text scale $scale', (
        t,
      ) async {
        final s = make();
        owner(s);
        final f = s.saveFacility(profile());
        s.submitFacility(f);
        if (view == 'approved' || view == 'public') {
          admin(s);
          s.reviewFacility(f, approve: true);
          owner(s);
        }
        if (view == 'admin-list') admin(s);
        final screen = switch (view) {
          'form' => FacilityFormScreen(session: s),
          'pending' ||
          'approved' => FacilityDetailScreen(session: s, facility: f),
          'public' => PublicFacilityScreen(session: s, id: f.id),
          _ => FacilitiesScreen(session: s),
        };
        final key = await pump(
          t,
          screen,
          width: scale == 1 ? 402 : 320,
          scale: scale,
        );
        await capture(
          t,
          key,
          'facility-$view-${scale == 1 ? 'normal' : 'large'}',
        );
        await t.drag(find.byType(ListView).first, const Offset(0, -600));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('Player cannot open staff list, form or detail', (t) async {
    final s = make();
    owner(s);
    final f = s.saveFacility(profile());
    s.login(DemoSession.phone, DemoSession.password);
    for (final screen in [
      FacilitiesScreen(session: s),
      FacilityFormScreen(session: s),
      FacilityDetailScreen(session: s, facility: f),
    ]) {
      await pump(t, screen);
      expect(find.text('Chưa có quyền truy cập.'), findsOneWidget);
      expect(find.byKey(const Key('facility-submit')), findsNothing);
    }
    expect(t.takeException(), isNull);
  });
}
