import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/screens/play_groups_screen.dart';
import 'package:test_do_an/screens/community_screen.dart';
import 'package:test_do_an/main.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'home_accessibility_test.dart' show captureHome;

import 'group_removal_test.dart' show approvedMemberGroup, player;

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
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    return s;
  }

  Future<void> begin(
    WidgetTester t,
    DemoSession s,
    String id, {
    double scale = 1,
    GlobalKey? capture,
  }) async {
    await t.pumpWidget(const MyApp());
    await t.pumpAndSettle();
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    await t.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: PlayGroupDetailScreen(session: s, id: id),
        ),
      ),
    );
    final button = find.byKey(const Key('group-member-remove-0901234567'));
    if (button.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('finance-reason')),
      'Vi phạm nội quy nhóm',
    );
    await t.tap(find.byKey(const Key('finance-text-confirm')));
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Reason and confirmation revoke membership at $scale', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 879);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = open(), id = approvedMemberGroup(s);
      final capture = GlobalKey();
      await begin(t, s, id, scale: scale, capture: capture);
      await captureHome(capture, 'group-member-removal-$scale', t);
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(s.groupRequests(id).single.state, 'removed');
      expect(
        find.byKey(const Key('group-member-remove-0901234567')),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Account change during confirmation cannot revoke', (t) async {
    final s = open(), id = approvedMemberGroup(s);
    await begin(t, s, id);
    player(s);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.joinedGroups.contains(id), isTrue);
    expect(t.takeException(), isNull);
  });
  testWidgets('Failed removal save retries without repeating member revision', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    await s.initialize();
    final id = approvedMemberGroup(s);
    await s.flush();
    await begin(t, s, id);
    store.failWrite = true;
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.saveFailed, isTrue);
    expect(s.groupRequests(id).single.revision, 2);
    store.failWrite = false;
    await t.ensureVisible(find.byKey(const Key('finance-retry-save')));
    await t.tap(find.byKey(const Key('finance-retry-save')));
    await t.pumpAndSettle();
    expect(s.saveFailed, isFalse);
    expect(s.groupRequests(id).single.revision, 2);
  });
  testWidgets('Player sees removal reason and can request review again', (
    t,
  ) async {
    final s = open(), id = approvedMemberGroup(s);
    s.removeGroupMember(
      id,
      DemoSession.phone,
      1,
      reason: 'Vi phạm nội quy nhóm',
    );
    player(s);
    await t.pumpWidget(MaterialApp(home: CommunityScreen(session: s)));
    await t.tap(find.text('Nhóm chơi'));
    await t.pumpAndSettle();
    final notice = find.byKey(Key('group-removal-notice-$id'));
    if (notice.evaluate().isEmpty) await t.scrollUntilVisible(notice, 200);
    await t.ensureVisible(notice);
    expect(
      find.text('Đã thu hồi tư cách: Vi phạm nội quy nhóm'),
      findsOneWidget,
    );
    final join = find.byKey(Key('group-join-$id'));
    await t.ensureVisible(join);
    await t.tap(join);
    await t.pumpAndSettle();
    expect(s.ownGroupRequest(id)!.state, 'pending');
    expect(notice, findsNothing);
  });
}
