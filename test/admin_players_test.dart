import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 7, 8));
  DemoSession make([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  void change(
    DemoSession s,
    bool blocked, {
    String id = DemoSession.phone,
    String secret = DemoSession.password,
    String reason = 'Demo access review',
    int? revision,
  }) => s.setPlayerBlocked(
    id,
    blocked,
    password: secret,
    reason: reason,
    expectedBlocked: !blocked,
    expectedRevision: revision ?? s.playerAccessRevision(id),
  );
  test(
    'Only Admin can read player detail/contact/history or change access',
    () {
      final s = make();
      player(s);
      expect(() => s.managedPlayer(DemoSession.phone), throwsStateError);
      expect(() => s.managedContactPhone(DemoSession.phone), throwsStateError);
      expect(() => s.playerRecords(DemoSession.phone), throwsStateError);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      expect(() => s.playerAccessDecision(DemoSession.phone), throwsStateError);
      expect(
        () => s.setPlayerBlocked(
          DemoSession.phone,
          true,
          password: DemoSession.password,
          reason: 'Test reason',
          expectedBlocked: false,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
    },
  );
  test('Unknown and staff identities cannot be treated as players', () {
    final s = make();
    admin(s);
    for (final id in ['__admin__', '__owner__', 'unknown@example.com']) {
      expect(() => s.managedPlayer(id), throwsStateError);
      expect(() => change(s, true, id: id), throwsStateError);
    }
  });
  test('Known profile and contact reflect latest account edits', () {
    final s = make();
    player(s);
    s.updateName('Đã sửa');
    s.updateContactPhone('0987654321');
    admin(s);
    expect(s.managedPlayer(DemoSession.phone).name, 'Đã sửa');
    expect(s.managedContactPhone(DemoSession.phone), '0987654321');
  });
  test('Player history is isolated and immutable', () {
    final s = make();
    admin(s);
    expect(s.playerRecords(DemoSession.phone).length, 2);
    s.register('Other', 'other@example.com', 'Test1234');
    admin(s);
    expect(s.playerRecords('other@example.com'), isEmpty);
    expect(
      () => s.playerRecords(DemoSession.phone).clear(),
      throwsUnsupportedError,
    );
  });
  test('Correct secret/reason lock both seed login aliases without deleting history', () {
    final s = make();
    admin(s);
    final before = s.playerRecords(DemoSession.phone);
    change(s, true);
    expect(
      s.playerAccessDecision(DemoSession.phone)!.reason,
      'Demo access review',
    );
    expect(s.playerAccessRevision(DemoSession.phone), 1);
    expect(s.playerRecords(DemoSession.phone).length, before.length);
    s.logout();
    expect(s.login(DemoSession.phone, DemoSession.password), isFalse);
    expect(s.login(DemoSession.email, DemoSession.password), isFalse);
    admin(s);
    change(s, false);
    expect(s.playerAccessRevision(DemoSession.phone), 2);
    expect(s.login(DemoSession.phone, DemoSession.password), isTrue);
  });
  test('Wrong password never mutates state, reason or audit', () {
    final s = make();
    admin(s);
    final n = s.operationAudit.length;
    expect(() => change(s, true, secret: 'wrong'), throwsStateError);
    expect(s.isBlocked(DemoSession.phone), isFalse);
    expect(s.playerAccessDecision(DemoSession.phone), isNull);
    expect(s.operationAudit.length, n);
  });
  test('Reason validation does not consume password attempts', () {
    final s = make();
    admin(s);
    for (var i = 0; i < 6; i++) {
      expect(
        () => change(s, true, secret: 'wrong', reason: 'bad'),
        throwsStateError,
      );
    }
    change(s, true);
    expect(s.isBlocked(DemoSession.phone), isTrue);
  });
  test('Five wrong attempts impose 60-second cooldown across logout/login', () {
    final s = make();
    admin(s);
    for (var i = 0; i < 5; i++) {
      expect(() => change(s, true, secret: 'wrong'), throwsStateError);
    }
    s.logout();
    admin(s);
    expect(() => change(s, true), throwsStateError);
    now = now.add(const Duration(seconds: 59));
    expect(() => change(s, true), throwsStateError);
    now = now.add(const Duration(seconds: 1));
    change(s, true);
    expect(s.isBlocked(DemoSession.phone), isTrue);
  });
  test('Changing Admin password invalidates the old confirmation password', () {
    final s = make();
    admin(s);
    expect(s.changePassword(DemoSession.password, 'NewDemo1234'), isTrue);
    expect(() => change(s, true), throwsStateError);
    change(s, true, secret: 'NewDemo1234');
    expect(s.isBlocked(DemoSession.phone), isTrue);
  });
  test('Replay and stale boolean state are rejected', () {
    final s = make();
    admin(s);
    change(s, true, revision: 0);
    expect(() => change(s, true, revision: 0), throwsStateError);
    expect(
      () => s.setPlayerBlocked(
        DemoSession.phone,
        false,
        password: DemoSession.password,
        reason: 'Test reason',
        expectedBlocked: false,
        expectedRevision: 1,
      ),
      throwsStateError,
    );
  });
  test(
    'Stale revision rejects even after lock/unlock returns to the old state',
    () {
      final s = make();
      admin(s);
      change(s, true);
      change(s, false);
      expect(() => change(s, true, revision: 0), throwsStateError);
      expect(s.playerAccessRevision(DemoSession.phone), 2);
    },
  );
  test(
    'Long identifier/reason cannot create an invalid oversized audit entry',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      final id = '${List.filled(380, 'a').join()}@example.com';
      s.register('Long', id, 'Test1234');
      admin(s);
      change(s, true, id: id, reason: List.filled(300, 'x').join());
      expect(s.operationAudit.last.action.length, lessThanOrEqualTo(400));
      await s.flush();
      final r = make(store);
      await r.initialize();
      expect(r.loadFailed, isFalse);
      expect(r.isBlocked(id), isTrue);
    },
  );
  test(
    'Restart restores reason/revision without persisting confirmation input',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      admin(s);
      change(s, true);
      await s.flush();
      final r = make(store);
      await r.initialize();
      expect(r.playerAccessRevision(DemoSession.phone), 1);
      expect(
        r.playerAccessDecision(DemoSession.phone)!.reason,
        'Demo access review',
      );
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      expect(
        data['operations']['accessDecisions'][DemoSession.phone].containsKey(
          'password',
        ),
        isFalse,
      );
    },
  );
  test(
    'Failed save retry does not duplicate the decision or revision',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      admin(s);
      store.failWrite = true;
      change(s, true);
      expect(await s.flush(), isFalse);
      store.failWrite = false;
      await s.retrySave();
      expect(s.playerAccessRevision(DemoSession.phone), 1);
      final r = make(store);
      await r.initialize();
      expect(r.playerAccessRevision(DemoSession.phone), 1);
    },
  );
  test(
    'Old snapshots without access decisions retain legacy blocked status',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      admin(s);
      change(s, true);
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      j['operations'].remove('accessDecisions');
      store.value = jsonEncode(j);
      final r = make(store);
      await r.initialize();
      expect(r.isBlocked(DemoSession.phone), isTrue);
      expect(r.playerAccessDecision(DemoSession.phone), isNull);
    },
  );
  for (final defect in ['reason', 'state', 'revision', 'owner']) {
    test('Corrupted access decision $defect fails atomically', () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      admin(s);
      change(s, true);
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>,
          decisions =
              j['operations']['accessDecisions'] as Map<String, dynamic>;
      final d = decisions[DemoSession.phone] as Map<String, dynamic>;
      if (defect == 'reason') d['reason'] = 'bad';
      if (defect == 'state') d['blocked'] = false;
      if (defect == 'revision') d['revision'] = 0;
      if (defect == 'owner') {
        decisions['__owner__'] = decisions.remove(DemoSession.phone);
      }
      store.value = jsonEncode(j);
      final r = make(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(r.user, isNull);
    });
  }
}
