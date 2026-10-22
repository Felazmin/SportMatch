import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/screens/activities_screen.dart';
import 'package:test_do_an/screens/court_types_screen.dart';
import 'package:test_do_an/screens/play_groups_screen.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
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

  String draft(DemoSession s, String kind) {
    owner(s);
    if (kind == 'group') {
      final g = s.savePlayGroup(
        name: 'Nhóm cuối tuần',
        sport: 'badminton',
        description: 'Giao lưu cầu lông cuối tuần',
      );
      s.transitionPlayGroup(g.id, 'pending', g.revision);
      return g.id;
    }
    if (kind == 'activity') {
      final a = s.saveActivity(
        title: 'Giao lưu cuối tuần',
        kind: DemoEventKind.social,
        start: DateTime(2026, 10, 11, 18),
        durationMinutes: 120,
        capacity: 12,
        fee: 65000,
        description: 'Chơi cầu lông và giao lưu thân thiện.',
      );
      s.transitionActivity(a.id, 'pending', a.revision);
      return a.id;
    }
    final c = s.saveCourtType(
      name: 'Sân cuối tuần',
      sport: 'Cầu lông',
      description: 'Sân cầu lông trong nhà',
    );
    s.transitionCourtType(c.id, 'pending', c.revision);
    return c.id;
  }

  ({String state, int revision}) current(DemoSession s, String kind) {
    if (kind == 'group') {
      final g = s.managedPlayGroups.single;
      return (state: g.state, revision: g.revision);
    }
    if (kind == 'activity') {
      final a = s.managedActivities.single;
      return (state: a.state, revision: a.revision);
    }
    final c = s.managedCourtTypes.last;
    return (state: c.state, revision: c.revision);
  }

  Future<void> begin(
    WidgetTester t,
    DemoSession s,
    String kind,
    String id,
  ) async {
    final screen = kind == 'group'
        ? PlayGroupDetailScreen(session: s, id: id)
        : kind == 'activity'
        ? ActivityDetailScreen(session: s, id: id)
        : CourtTypesScreen(session: s);
    await t.pumpWidget(MaterialApp(home: screen));
    await t.pumpAndSettle();
    final key = kind == 'group'
        ? 'play-group-action-approved'
        : kind == 'activity'
        ? 'activity-action-approved'
        : 'court-type-approved-$id';
    final button = find.byKey(Key(key));
    await t.scrollUntilVisible(
      button,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester t, String kind) async {
    await t.tap(
      find.byKey(
        Key(kind == 'court' ? 'court-type-confirm' : 'finance-confirm'),
      ),
    );
    await t.pumpAndSettle();
  }

  for (final kind in ['group', 'activity', 'court']) {
    testWidgets('$kind confirmation rejects changed account', (t) async {
      final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
      addTearDown(s.dispose);
      final id = draft(s, kind);
      admin(s);
      await begin(t, s, kind, id);
      owner(s);
      await t.pumpAndSettle();
      await confirm(t, kind);
      expect(current(s, kind), (state: 'pending', revision: 1));
      expect(find.text('Tài khoản đã thay đổi. Mở lại hồ sơ.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('$kind failed save retries without a second approval', (
      t,
    ) async {
      final store = TestSessionStore();
      final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
      addTearDown(s.dispose);
      await s.initialize();
      final id = draft(s, kind);
      admin(s);
      expect(await s.flush(), isTrue);
      await begin(t, s, kind, id);
      store.failWrite = true;
      await confirm(t, kind);
      expect(current(s, kind), (state: 'approved', revision: 2));
      expect(
        find.text('Chưa lưu được vào thiết bị. Hãy thử lưu lại.'),
        findsOneWidget,
      );
      store.failWrite = false;
      final retry = find.byKey(const Key('finance-retry-save'));
      await t.scrollUntilVisible(
        retry,
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(retry);
      await t.pumpAndSettle();
      await t.tap(retry);
      await t.pumpAndSettle();
      expect(s.saveFailed, isFalse);
      expect(current(s, kind), (state: 'approved', revision: 2));
      final reloaded = DemoSession(
        store: store,
        now: () => DateTime(2026, 10, 9, 10),
      );
      addTearDown(reloaded.dispose);
      await reloaded.initialize();
      admin(reloaded);
      expect(current(reloaded, kind), (state: 'approved', revision: 2));
      expect(t.takeException(), isNull);
    });
  }
}
