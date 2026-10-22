import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'multi_facility_test.dart' show sampleFacilityProof;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 8, 10));
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(store: store, now: () => now);
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
  void submit(
    DemoSession s, {
    int revision = 0,
    String proof = sampleFacilityProof,
  }) => s.submitOwnerVerification(
    name: 'Nguyễn Minh Phát',
    phone: DemoSession.phone,
    proof: proof,
    expectedRevision: revision,
  );
  void review(
    DemoSession s, {
    bool approve = true,
    int revision = 1,
    String password = DemoSession.password,
    String note = '',
  }) => s.reviewOwnerVerification(
    approve: approve,
    expectedRevision: revision,
    password: password,
    note: note,
  );
  test(
    'Owner submits; only Admin verifies with password; stale/replay guarded',
    () {
      final s = open();
      expect(() => s.ownerVerification, throwsStateError);
      owner(s);
      submit(s);
      expect(s.ownerVerification!.state, 'pending');
      expect(() => submit(s, revision: 1), throwsStateError);
      expect(() => review(s), throwsStateError);
      admin(s);
      expect(() => review(s, password: 'wrong'), throwsStateError);
      review(s);
      expect(s.ownerVerification!.state, 'verified');
      expect(() => review(s), throwsStateError);
      s.login(DemoSession.phone, DemoSession.password);
      expect(() => s.ownerVerification, throwsStateError);
      expect(() => review(s), throwsStateError);
    },
  );
  test('Required evidence and reason validation do not change records', () {
    final s = open();
    owner(s);
    expect(() => submit(s, proof: ''), throwsStateError);
    expect(s.ownerVerification, isNull);
    submit(s);
    admin(s);
    expect(() => review(s, approve: false, note: 'no'), throwsStateError);
    expect(s.ownerVerification!.state, 'pending');
    review(s, approve: false, note: 'Cần ảnh rõ hơn');
    owner(s);
    expect(s.ownerVerification!.note, 'Cần ảnh rõ hơn');
    submit(s, revision: 2);
    expect(s.ownerVerification!.revision, 3);
    expect(s.ownerVerification!.note, '');
    admin(s);
    review(s, revision: 3);
    review(s, approve: false, revision: 4, note: 'Kiểm tra hồ sơ bổ sung');
    expect(s.ownerVerification!.state, 'rejected');
  });
  test('Five wrong confirmations lock for 60 seconds including logout', () {
    final s = open();
    owner(s);
    submit(s);
    admin(s);
    for (var i = 0; i < 5; i++) {
      expect(() => review(s, password: 'wrong'), throwsStateError);
    }
    s.logout();
    admin(s);
    expect(() => review(s), throwsStateError);
    now = now.add(const Duration(seconds: 60));
    review(s);
    expect(s.ownerVerification!.state, 'verified');
  });
  test('Failed save retries; evidence and review restore', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    owner(s);
    submit(s);
    admin(s);
    store.failWrite = true;
    review(s);
    expect(await s.flush(), false);
    store.failWrite = false;
    s.retrySave();
    expect(await s.flush(), true);
    final next = open(store);
    await next.initialize();
    expect(next.loadFailed, false);
    expect(next.ownerVerification!.proof, sampleFacilityProof);
    expect(next.ownerVerification!.state, 'verified');
  });
  test(
    'Legacy store without verification restores with no legal assertion',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      j.remove('ownerVerification');
      store.value = jsonEncode(j);
      final next = open(store);
      await next.initialize();
      expect(next.loadFailed, false);
      expect(next.ownerVerification, isNull);
    },
  );
  for (final field in ['state', 'revision', 'proof']) {
    test('Corrupt $field fails atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      submit(s);
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      j['ownerVerification'][field] = field == 'revision' ? -1 : 'invalid';
      store.value = jsonEncode(j);
      final next = open(store);
      await next.initialize();
      expect(next.loadFailed, true);
      expect(next.user, isNull);
    });
  }
}
