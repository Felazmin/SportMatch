import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';

import 'persistence_test.dart' show TestSessionStore;

String publishedRosterGroup(DemoSession s, {bool approval = false}) {
  s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
  final g = s.savePlayGroup(
    name: 'Nhóm quản lý thành viên',
    sport: 'badminton',
    description: 'Giao lưu cầu lông cuối tuần.',
    requiresApproval: approval,
  );
  s.transitionPlayGroup(g.id, 'pending', g.revision);
  s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
  s.transitionPlayGroup(g.id, 'approved', 1);
  return g.id;
}

void main() {
  DemoSession open({TestSessionStore? store}) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);

  test(
    'Immediate membership roster is scoped, immutable and updates on leave',
    () {
      final s = open();
      final id = publishedRosterGroup(s);
      expect(s.groupMembers(id), isEmpty);
      player(s);
      s.updateName('Nguyễn Minh Phát');
      s.toggleGroup(id);
      expect(() => s.groupMembers(id), throwsStateError);
      owner(s);
      final snapshot = s.groupMembers(id);
      expect(snapshot.single.name, 'Nguyễn Minh Phát');
      expect(() => snapshot.clear(), throwsUnsupportedError);
      expect(() => s.groupMembers('unknown'), throwsStateError);
      player(s);
      s.toggleGroup(id);
      owner(s);
      expect(s.groupMembers(id), isEmpty);
      expect(snapshot, hasLength(1));
    },
  );

  test('Approval roster includes approved members only, not requests or revoked members', () {
    final s = open();
    final id = publishedRosterGroup(s, approval: true);
    player(s);
    s.toggleGroup(id);
    owner(s);
    expect(s.groupRequests(id), hasLength(1));
    expect(s.groupMembers(id), isEmpty);
    s.reviewGroupRequest(id, DemoSession.phone, 0, approve: true);
    expect(s.groupMembers(id).single.identifier, DemoSession.phone);
    s.removeGroupMember(
      id,
      DemoSession.phone,
      1,
      reason: 'Vi phạm nội quy nhóm',
    );
    expect(s.groupMembers(id), isEmpty);
    expect(s.groupRequests(id).single.state, 'removed');
  });

  test(
    'Roster survives reload and suspended groups keep historical membership',
    () async {
      final store = TestSessionStore();
      final s = open(store: store);
      await s.initialize();
      final id = publishedRosterGroup(s);
      player(s);
      s.toggleGroup(id);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionPlayGroup(
        id,
        'suspended',
        2,
        note: 'Tạm ngưng hoạt động nhóm',
      );
      expect(await s.flush(), isTrue);
      final restored = open(store: store);
      await restored.initialize();
      owner(restored);
      expect(restored.groupMembers(id).single.identifier, DemoSession.phone);
      expect(restored.publicGroups.containsKey(id), isFalse);
      restored.logout();
      expect(() => restored.groupMembers(id), throwsStateError);
    },
  );
}
