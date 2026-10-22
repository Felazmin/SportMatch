import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/activities_screen.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';
import 'package:test_do_an/screens/events_screen.dart';
import 'package:test_do_an/screens/community_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession open() {
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 10));
    addTearDown(s.dispose);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    return s;
  }

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

  Future<void> press(WidgetTester t, String id) async {
    final f = find.byKey(Key(id));
    await t.scrollUntilVisible(
      f,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Owner creates/submits; Admin approves; player registers a local custom ticket',
    (t) async {
      final s = open();
      await pump(t, ActivitiesScreen(session: s));
      await press(t, 'activity-add');
      await t.enterText(
        find.byKey(const Key('activity-title')),
        'Giao lưu cuối tuần',
      );
      await t.enterText(
        find.byKey(const Key('activity-description')),
        'Chơi cầu lông và giao lưu tại sân',
      );
      await t.enterText(find.byKey(const Key('activity-fee')), '65000');
      await press(t, 'activity-save');
      await press(t, 'activity-HD0001');
      await press(t, 'activity-action-pending');
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await pump(t, ApprovalCenterScreen(session: s));
      await press(t, 'approval-activity-HD0001');
      await press(t, 'activity-action-approved');
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      s.login(DemoSession.phone, DemoSession.password);
      await pump(t, EventsScreen(session: s));
      await t.enterText(find.byKey(const Key('events-search')), 'cuoi tuan');
      await t.pumpAndSettle();
      await press(t, 'event-HD0001');
      await press(t, 'event-register');
      await press(t, 'event-submit');
      await t.tap(find.byKey(const Key('event-confirm')));
      await t.pumpAndSettle();
      expect(s.participations.single.eventId, 'HD0001');
      expect(s.participations.single.total, 65000);
      expect(find.text('Đăng ký thành công'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('Linked activity form and group event navigation at $scale', (
      t,
    ) async {
      final s = open();
      final g = s.savePlayGroup(
        name: 'Nhóm cuối tuần',
        sport: 'badminton',
        description: 'Chơi cầu lông cuối tuần tại sân.',
      );
      s.transitionPlayGroup(g.id, 'pending', 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionPlayGroup(g.id, 'approved', 1);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await pump(t, ActivityFormScreen(session: s), scale: scale);
      await t.enterText(
        find.byKey(const Key('activity-title')),
        'Lịch chơi của nhóm',
      );
      await t.enterText(
        find.byKey(const Key('activity-description')),
        'Giao lưu thân thiện cuối tuần.',
      );
      await press(t, 'activity-group');
      await t.tap(find.text(g.id).last);
      await t.pumpAndSettle();
      expect(find.text(g.name), findsOneWidget);
      await press(t, 'activity-save');
      final a = s.managedActivities.single;
      expect(a.groupId, g.id);
      s.transitionActivity(a.id, 'pending', 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionActivity(a.id, 'approved', 1);
      s.login(DemoSession.phone, DemoSession.password);
      s.toggleGroup(g.id);
      await pump(t, CommunityScreen(session: s), scale: scale);
      await press(t, 'community-mode-1');
      await press(t, 'group-event-${a.id}');
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('Nhóm: ${g.name}'), findsOneWidget);
      await press(t, 'event-register');
      await press(t, 'event-submit');
      await t.tap(find.byKey(const Key('event-confirm')));
      await t.pumpAndSettle();
      expect(s.participations.single.eventId, a.id);
      expect(t.takeException(), isNull);
    });
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('Whole activity cancellation via real confirmation at $scale', (
      t,
    ) async {
      final s = open();
      final a = s.saveActivity(
        title: 'Hoạt động bị hủy',
        kind: DemoEventKind.social,
        start: DateTime(2026, 10, 9, 18),
        durationMinutes: 120,
        capacity: 12,
        fee: 60000,
        description: 'Hoạt động thử nghiệm cuối tuần.',
      );
      s.transitionActivity(a.id, 'pending', 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionActivity(a.id, 'approved', 1);
      s.login(DemoSession.phone, DemoSession.password);
      final p = s.joinEvent(
        eventId: a.id,
        start: a.event.scheduledStart!,
        quantity: 1,
        contact: 'Người thử',
        contactPhone: DemoSession.phone,
      );
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      final key = await pump(
        t,
        ActivityDetailScreen(session: s, id: a.id),
        scale: scale,
      );
      await press(t, 'activity-cancel-all');
      await t.enterText(
        find.byKey(const Key('finance-reason')),
        'Không đủ người tham gia',
      );
      await t.tap(find.byKey(const Key('finance-text-confirm')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(s.managedActivities.single.state, 'cancelled');
      expect(p.cancelled, true);
      expect(find.byKey(const Key('activity-cancel-all')), findsNothing);
      await captureHome(key, 'activity-cancelled-$scale', t);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Role change during approval cannot mutate activity', (t) async {
    final s = open();
    final a = s.saveActivity(
      title: 'Giao lưu cuối tuần',
      kind: DemoEventKind.social,
      start: DateTime(2026, 10, 9, 18),
      durationMinutes: 120,
      capacity: 12,
      fee: 65000,
      description: 'A friendly badminton activity',
    );
    s.transitionActivity(a.id, 'pending', 0);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(t, ActivityDetailScreen(session: s, id: a.id));
    await press(t, 'activity-action-approved');
    s.login(DemoSession.phone, DemoSession.password);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    expect(s.managedActivities.single.state, 'pending');
    expect(t.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    for (final view in ['list', 'form', 'detail', 'public']) {
      testWidgets('Activity $view fits scale $scale', (t) async {
        final s = open();
        final a = s.saveActivity(
          title: 'Giao lưu cầu lông cuối tuần tại Công Thương',
          kind: DemoEventKind.social,
          start: DateTime(2026, 10, 9, 18),
          durationMinutes: 120,
          capacity: 12,
          fee: 65000,
          description: 'Giao lưu đánh đôi luân phiên, tôn trọng người chơi và chia sẻ chi phí sân.',
        );
        s.transitionActivity(a.id, 'pending', 0);
        s.loginStaff(
          DemoRole.admin,
          DemoSession.adminEmail,
          DemoSession.password,
        );
        s.transitionActivity(a.id, 'approved', 1);
        final current = s.managedActivities.single;
        s.loginStaff(
          DemoRole.owner,
          DemoSession.ownerEmail,
          DemoSession.password,
        );
        final screen = switch (view) {
          'list' => ActivitiesScreen(session: s),
          'form' => ActivityFormScreen(session: s),
          'detail' => ActivityDetailScreen(session: s, id: a.id),
          _ => EventDetailScreen(
            session: s,
            event: current.event,
            start: current.event.scheduledStart!,
          ),
        };
        final key = await pump(t, screen, scale: scale);
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'activity-$view-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 6; i++) {
          await t.drag(find.byType(ListView), const Offset(0, -250));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'activity-$view-${scale == 1 ? 'normal' : 'large'}-bottom',
          t,
        );
      });
    }
  }
}
