import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 8, 10));
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
  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  String group(DemoSession s) {
    owner(s);
    final g = s.savePlayGroup(
      name: 'Nhóm liên kết',
      sport: 'badminton',
      description: 'Cùng chơi cuối tuần tại sân.',
      requiresApproval: true,
    );
    s.transitionPlayGroup(g.id, 'pending', 0);
    admin(s);
    s.transitionPlayGroup(g.id, 'approved', 1);
    owner(s);
    return g.id;
  }

  String activity(DemoSession s, String groupId) => s
      .saveActivity(
        title: 'Lịch chơi của nhóm',
        kind: DemoEventKind.social,
        start: DateTime(2026, 10, 10, 18),
        durationMinutes: 120,
        capacity: 12,
        fee: 60000,
        description: 'Giao lưu thân thiện cuối tuần.',
        groupId: groupId,
      )
      .id;
  void join(DemoSession s, String id) => s.joinEvent(
    eventId: id,
    start: DateTime(2026, 10, 10, 18),
    quantity: 1,
    contact: 'Minh Phat',
    contactPhone: DemoSession.phone,
  );
  test(
    'Registration requires actual approved membership; linked catalog is live',
    () {
      final s = open();
      final g = group(s);
      final id = activity(s, g);
      s.transitionActivity(id, 'pending', 0);
      admin(s);
      s.transitionActivity(id, 'approved', 1);
      player(s);
      expect(s.eventsForGroup(g).single.id, id);
      expect(s.eventGroupName(id), 'Nhóm liên kết');
      expect(() => join(s, id), throwsStateError);
      s.toggleGroup(g);
      expect(() => join(s, id), throwsStateError);
      owner(s);
      s.reviewGroupRequest(g, DemoSession.phone, 0, approve: true);
      player(s);
      join(s, id);
      expect(s.participations.single.total, 60000);
      admin(s);
      s.transitionPlayGroup(g, 'suspended', 2, note: 'Tạm kiểm tra nhóm');
      expect(s.eventsForGroup(g), isEmpty);
      player(s);
      expect(s.participations.single.eventId, id);
    },
  );
  test('Unknown or suspended groups cannot be authored/approved', () {
    final s = open();
    final g = group(s);
    expect(() => activity(s, 'NC9999'), throwsStateError);
    final id = activity(s, g);
    s.transitionActivity(id, 'pending', 0);
    admin(s);
    s.transitionPlayGroup(g, 'suspended', 2, note: 'Tạm kiểm tra nhóm');
    expect(() => s.transitionActivity(id, 'approved', 1), throwsStateError);
    owner(s);
    expect(() => activity(s, g), throwsStateError);
  });
  test('Links and existing tickets restore through group suspension', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    final g = group(s);
    final id = activity(s, g);
    s.transitionActivity(id, 'pending', 0);
    admin(s);
    s.transitionActivity(id, 'approved', 1);
    player(s);
    s.toggleGroup(g);
    owner(s);
    s.reviewGroupRequest(g, DemoSession.phone, 0, approve: true);
    player(s);
    join(s, id);
    admin(s);
    s.transitionPlayGroup(g, 'suspended', 2, note: 'Tạm kiểm tra nhóm');
    await s.flush();
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, false);
    expect(restored.managedActivities.single.groupId, g);
    expect(restored.eventsForGroup(g), isEmpty);
    player(restored);
    expect(restored.participations.single.total, 60000);
  });
  test('Unknown persisted group link rejects snapshot atomically', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    activity(s, group(s));
    await s.flush();
    final j = jsonDecode(store.value!) as Map<String, dynamic>;
    j['activities'][0]['groupId'] = 'NC9999';
    store.value = jsonEncode(j);
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, true);
    expect(restored.user, isNull);
  });
}
