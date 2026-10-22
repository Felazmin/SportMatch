import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/play_groups_screen.dart';
import 'package:test_do_an/screens/community_screen.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';

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
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Owner creates/submits; Admin queue approves; player joins approved group',
    (t) async {
      final s = open();
      await pump(t, PlayGroupsScreen(session: s));
      await press(t, 'play-group-add');
      await t.enterText(
        find.byKey(const Key('play-group-name')),
        'Nhóm cuối tuần',
      );
      await t.enterText(
        find.byKey(const Key('play-group-description')),
        'Giao lưu cầu lông vào cuối tuần',
      );
      await press(t, 'play-group-save');
      await press(t, 'play-group-NC0001');
      await press(t, 'play-group-action-pending');
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(s.managedPlayGroups.single.state, 'pending');
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await pump(t, ApprovalCenterScreen(session: s));
      await press(t, 'approval-group-NC0001');
      await press(t, 'play-group-action-approved');
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(s.publicGroups['NC0001'], 'Nhóm cuối tuần');
      s.login(DemoSession.phone, DemoSession.password);
      await pump(t, CommunityScreen(session: s));
      await press(t, 'community-mode-1');
      await press(t, 'group-join-NC0001');
      expect(s.joinedGroups.contains('NC0001'), isTrue);
      await press(t, 'group-posts-NC0001');
      await press(t, 'community-compose');
      expect(find.byType(PostFormScreen), findsOneWidget);
      expect(find.text('Nhóm cuối tuần'), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('post-message')),
        'Giao lưu cuối tuần nhé',
      );
      await press(t, 'post-submit');
      expect(s.posts.single.groupId, 'NC0001');
      expect(find.text('Giao lưu cuối tuần nhé'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Role change while approving cannot mutate', (t) async {
    final s = open();
    final g = s.savePlayGroup(
      name: 'Nhóm cuối tuần',
      sport: 'badminton',
      description: 'Playing together this weekend',
    );
    s.transitionPlayGroup(g.id, 'pending', 0);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(t, PlayGroupDetailScreen(session: s, id: g.id));
    await press(t, 'play-group-action-approved');
    s.login(DemoSession.phone, DemoSession.password);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    expect(s.managedPlayGroups.single.state, 'pending');
    expect(t.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Manager approves requested membership at $scale', (t) async {
      final s = open();
      await pump(t, PlayGroupFormScreen(session: s), scale: scale);
      await t.enterText(
        find.byKey(const Key('play-group-name')),
        'Nhóm cần duyệt',
      );
      await t.enterText(
        find.byKey(const Key('play-group-description')),
        'Cùng chơi cầu lông cuối tuần.',
      );
      await press(t, 'play-group-member-approval');
      await press(t, 'play-group-save');
      final g = s.managedPlayGroups.single;
      expect(g.requiresApproval, true);
      s.transitionPlayGroup(g.id, 'pending', 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionPlayGroup(g.id, 'approved', 1);
      s.login(DemoSession.phone, DemoSession.password);
      await pump(t, CommunityScreen(session: s), scale: scale);
      await press(t, 'community-mode-1');
      await press(t, 'group-join-${g.id}');
      expect(s.joinedGroups.contains(g.id), false);
      expect(find.text('Rút yêu cầu'), findsOneWidget);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      final key = await pump(
        t,
        PlayGroupDetailScreen(session: s, id: g.id),
        scale: scale,
      );
      await press(t, 'group-member-approve-${DemoSession.phone}');
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(s.groupRequests(g.id).single.state, 'approved');
      await captureHome(key, 'group-members-$scale', t);
      expect(t.takeException(), isNull);
      s.login(DemoSession.phone, DemoSession.password);
      expect(s.joinedGroups.contains(g.id), true);
    });
  }
  testWidgets(
    'Approved long group board fits and suspension resets selection',
    (t) async {
      final s = open();
      final g = s.savePlayGroup(
        name: 'Nhóm cầu lông giao lưu thân thiện vào mỗi cuối tuần',
        sport: 'badminton',
        description: 'A community group for weekend badminton',
      );
      s.transitionPlayGroup(g.id, 'pending', 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionPlayGroup(g.id, 'approved', 1);
      s.login(DemoSession.phone, DemoSession.password);
      final key = await pump(t, CommunityScreen(session: s), scale: 2);
      await press(t, 'community-mode-1');
      await press(t, 'group-posts-${g.id}');
      expect(t.takeException(), isNull);
      expect(find.text(g.name), findsOneWidget);
      await captureHome(key, 'play-group-board-large', t);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionPlayGroup(
        g.id,
        'suspended',
        2,
        note: 'Check community rules',
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-group-public')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    for (final view in ['list', 'form', 'detail']) {
      testWidgets('Group $view fits scale $scale', (t) async {
        final s = open();
        final g = s.savePlayGroup(
          name: 'Nhóm cầu lông cuối tuần',
          sport: 'badminton',
          description:
              'Giao lưu cầu lông, tôn trọng thành viên và chia sẻ chi phí sân.',
        );
        s.transitionPlayGroup(g.id, 'pending', 0);
        s.loginStaff(
          DemoRole.admin,
          DemoSession.adminEmail,
          DemoSession.password,
        );
        s.transitionPlayGroup(
          g.id,
          'rejected',
          1,
          note: 'Bổ sung lịch sinh hoạt và nội quy nhóm.',
        );
        s.loginStaff(
          DemoRole.owner,
          DemoSession.ownerEmail,
          DemoSession.password,
        );
        final current = s.managedPlayGroups.single;
        final screen = switch (view) {
          'list' => PlayGroupsScreen(session: s),
          'form' => PlayGroupFormScreen(session: s, group: current),
          _ => PlayGroupDetailScreen(session: s, id: g.id),
        };
        final key = await pump(t, screen, scale: scale);
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'play-group-$view-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 4; i++) {
          await t.drag(find.byType(ListView), const Offset(0, -250));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
      });
    }
  }
}
