import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';

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
      name: 'Nhóm cần duyệt',
      sport: 'badminton',
      description: 'Cùng chơi cầu lông cuối tuần.',
      requiresApproval: true,
    );
    s.transitionPlayGroup(g.id, 'pending', 0);
    admin(s);
    s.transitionPlayGroup(g.id, 'approved', 1);
    return g.id;
  }

  test(
    'Membership remains pending until manager approval; stale replay fails',
    () {
      final s = open();
      final id = group(s);
      player(s);
      s.toggleGroup(id);
      expect(s.ownGroupRequest(id)!.state, 'pending');
      expect(s.joinedGroups.contains(id), false);
      expect(() => s.createPost(id, 'Hello'), throwsStateError);
      expect(() => s.groupRequests(id), throwsStateError);
      expect(
        () => s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true),
        throwsStateError,
      );
      owner(s);
      expect(s.groupRequests(id).length, 1);
      expect(() => s.groupRequests(id).clear(), throwsUnsupportedError);
      s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true);
      expect(
        () => s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true),
        throwsStateError,
      );
      player(s);
      expect(s.joinedGroups.contains(id), true);
      s.createPost(id, 'Hello');
      s.toggleGroup(id);
      expect(s.joinedGroups.contains(id), false);
      expect(s.ownGroupRequest(id)!.state, 'withdrawn');
      s.toggleGroup(id);
      expect(s.ownGroupRequest(id)!.state, 'pending');
      expect(s.ownGroupRequest(id)!.revision, 3);
    },
  );
  test('Withdrawal/rejection/reapplication keep revision and reason rules', () {
    final s = open();
    final id = group(s);
    player(s);
    s.toggleGroup(id);
    s.toggleGroup(id);
    owner(s);
    expect(
      () => s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true),
      throwsStateError,
    );
    player(s);
    s.toggleGroup(id);
    owner(s);
    expect(
      () => s.reviewGroupRequest(
        id,
        DemoSession.phone,
        2,
        approve: false,
        note: 'no',
      ),
      throwsStateError,
    );
    s.reviewGroupRequest(
      id,
      DemoSession.phone,
      2,
      approve: false,
      note: 'Cần bổ sung thông tin',
    );
    player(s);
    expect(s.ownGroupRequest(id)!.note, 'Cần bổ sung thông tin');
    s.toggleGroup(id);
    expect(s.ownGroupRequest(id)!.revision, 4);
    expect(s.ownGroupRequest(id)!.note, '');
  });
  test(
    'Suspension blocks membership reviews but preserves request history',
    () {
      final s = open();
      final id = group(s);
      player(s);
      s.toggleGroup(id);
      admin(s);
      s.transitionPlayGroup(id, 'suspended', 2, note: 'Tạm kiểm tra thông tin');
      expect(
        () => s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true),
        throwsStateError,
      );
      player(s);
      expect(() => s.toggleGroup(id), throwsStateError);
      admin(s);
      s.transitionPlayGroup(id, 'approved', 3);
      s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true);
      player(s);
      expect(s.joinedGroups.contains(id), true);
    },
  );
  test(
    'Failed save retries and approved membership survives restart',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final id = group(s);
      player(s);
      s.toggleGroup(id);
      owner(s);
      store.failWrite = true;
      s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true);
      expect(await s.flush(), false);
      store.failWrite = false;
      s.retrySave();
      expect(await s.flush(), true);
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, false);
      expect(restored.groupRequests(id).single.state, 'approved');
      player(restored);
      expect(restored.joinedGroups.contains(id), true);
    },
  );
  for (final corruption in [
    'duplicate',
    'unknownMember',
    'missingMembership',
  ]) {
    test('Rejects $corruption atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final id = group(s);
      player(s);
      s.toggleGroup(id);
      owner(s);
      s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true);
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      final requests = j['groupRequests'] as List;
      if (corruption == 'duplicate') {
        requests.add(Map<String, dynamic>.from(requests.first));
      }
      if (corruption == 'unknownMember') requests.first['member'] = 'unknown';
      if (corruption == 'missingMembership') j['groups'] = {};
      store.value = jsonEncode(j);
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, true);
      expect(restored.user, isNull);
    });
  }
}
