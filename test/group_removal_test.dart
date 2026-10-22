import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';

import 'persistence_test.dart' show TestSessionStore;

void owner(DemoSession s) =>
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
void player(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);
String approvedMemberGroup(DemoSession s) {
  owner(s);
  final g = s.savePlayGroup(
    name: 'Nhóm cuối tuần',
    sport: 'badminton',
    description: 'Cùng chơi cầu lông cuối tuần.',
    requiresApproval: true,
  );
  s.transitionPlayGroup(g.id, 'pending', 0);
  s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
  s.transitionPlayGroup(g.id, 'approved', 1);
  player(s);
  s.toggleGroup(g.id);
  owner(s);
  s.reviewGroupRequest(g.id, DemoSession.phone, 0, approve: true);
  return g.id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    return s;
  }

  void remove(
    DemoSession s,
    String id, {
    int revision = 1,
    String reason = 'Vi phạm nội quy nhóm',
  }) => s.removeGroupMember(id, DemoSession.phone, revision, reason: reason);
  test('Removal revokes posting; existing posts stay and reapplication requires review', () {
    final s = open(), id = approvedMemberGroup(s);
    player(s);
    final post = s.createPost(id, 'Bài viết đã đăng');
    owner(s);
    remove(s, id);
    expect(s.groupRequests(id).single.state, 'removed');
    expect(s.groupRequests(id).single.revision, 2);
    player(s);
    expect(s.joinedGroups.contains(id), isFalse);
    expect(s.posts.any((p) => p.id == post.id), isTrue);
    expect(() => s.createPost(id, 'Bài mới'), throwsStateError);
    expect(s.ownGroupRequest(id)!.note, 'Vi phạm nội quy nhóm');
    s.toggleGroup(id);
    expect(s.ownGroupRequest(id)!.state, 'pending');
    expect(s.ownGroupRequest(id)!.note, isEmpty);
    expect(s.joinedGroups.contains(id), isFalse);
    owner(s);
    s.reviewGroupRequest(id, DemoSession.phone, 3, approve: true);
    player(s);
    expect(s.joinedGroups.contains(id), isTrue);
  });
  test(
    'Role, stale revision, invalid reason and repeat removal reject atomically',
    () {
      final s = open(), id = approvedMemberGroup(s);
      player(s);
      expect(() => remove(s, id), throwsStateError);
      owner(s);
      expect(() => remove(s, id, revision: 0), throwsStateError);
      expect(() => remove(s, id, reason: 'No'), throwsStateError);
      expect(s.groupRequests(id).single.state, 'approved');
      remove(s, id);
      expect(() => remove(s, id, revision: 2), throwsStateError);
    },
  );
  test('Suspended approved group still allows reasoned removal', () {
    final s = open(), id = approvedMemberGroup(s);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.transitionPlayGroup(id, 'suspended', 2, note: 'Tạm ngưng nhóm');
    remove(s, id);
    expect(s.groupRequests(id).single.state, 'removed');
  });
  test('Existing linked tickets are retained without automatic cancellation/refunds', () {
    final s = open(), id = approvedMemberGroup(s);
    final at = DateTime(2026, 10, 11, 18);
    final a = s.saveActivity(
      title: 'Lịch chơi nhóm',
      kind: DemoEventKind.social,
      start: at,
      durationMinutes: 120,
      capacity: 12,
      fee: 60000,
      description: 'Giao lưu cầu lông cuối tuần tại sân.',
      groupId: id,
    );
    s.transitionActivity(a.id, 'pending', 0);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.transitionActivity(a.id, 'approved', 1);
    player(s);
    final ticket = s.joinEvent(
      eventId: a.id,
      start: at,
      quantity: 1,
      contact: 'Test Player',
      contactPhone: DemoSession.phone,
    );
    owner(s);
    remove(s, id);
    player(s);
    expect(ticket.cancelled, isFalse);
    expect(s.workflowRecord(ticket.id).total, 60000);
    expect(s.workflowPayment(ticket.id), isNull);
    expect(
      () => s.joinEvent(
        eventId: a.id,
        start: at,
        quantity: 1,
        contact: 'Test Player',
        contactPhone: DemoSession.phone,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'reason',
          contains('Tham gia nhóm'),
        ),
      ),
    );
  });
  test(
    'Removal persists; incompatible active membership fails atomic restore',
    () async {
      final store = TestSessionStore();
      final persisted = open(store);
      await persisted.initialize();
      final id = approvedMemberGroup(persisted);
      remove(persisted, id);
      expect(await persisted.flush(), isTrue);
      final restored = open(store);
      await restored.initialize();
      player(restored);
      expect(restored.ownGroupRequest(id)!.state, 'removed');
      expect(restored.joinedGroups.contains(id), isFalse);
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      (data['groups'] as Map)[DemoSession.phone] = [id];
      final bad = open(TestSessionStore()..value = jsonEncode(data));
      await bad.initialize();
      expect(bad.loadFailed, isTrue);
      expect(bad.user, isNull);
    },
  );
}
