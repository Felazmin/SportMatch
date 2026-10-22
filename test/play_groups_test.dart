import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_play_groups.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 10), store: store);
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
  DemoPlayGroup draft(DemoSession s) => s.savePlayGroup(
    name: 'Nhóm cuối tuần',
    sport: 'badminton',
    description: 'Giao lưu cầu lông vào cuối tuần.',
  );
  test(
    'Only Owner authors, managers read private drafts, only Admin reviews',
    () {
      final s = open();
      expect(() => draft(s), throwsStateError);
      player(s);
      expect(() => draft(s), throwsStateError);
      expect(() => s.managedPlayGroups, throwsStateError);
      admin(s);
      expect(() => draft(s), throwsStateError);
      owner(s);
      final g = draft(s);
      expect(s.publicGroups.containsKey(g.id), isFalse);
      expect(
        () => s.transitionPlayGroup(g.id, 'approved', 0),
        throwsStateError,
      );
      s.transitionPlayGroup(g.id, 'pending', 0);
      expect(
        () => s.transitionPlayGroup(g.id, 'approved', 1),
        throwsStateError,
      );
      admin(s);
      s.transitionPlayGroup(g.id, 'approved', 1);
      expect(s.publicGroups[g.id], g.name);
      expect(() => s.managedPlayGroups.clear(), throwsUnsupportedError);
      expect(() => s.publicGroups.clear(), throwsUnsupportedError);
    },
  );
  test('Content validation and duplicate names fail without consuming IDs', () {
    final s = open();
    owner(s);
    for (final name in ['x', 'Cầu lông phong trào']) {
      expect(
        () => s.savePlayGroup(
          name: name,
          sport: 'badminton',
          description: 'A valid description',
        ),
        throwsStateError,
      );
    }
    expect(
      () => s.savePlayGroup(
        name: 'Valid name',
        sport: 'invalid',
        description: 'A valid description',
      ),
      throwsStateError,
    );
    final g = draft(s);
    expect(g.id, 'NC0001');
    expect(() => draft(s), throwsStateError);
    expect(s.managedPlayGroups.length, 1);
  });
  test('Rejected group can edit and resubmit; replay and stale forms fail', () {
    final s = open();
    owner(s);
    final g = draft(s);
    s.transitionPlayGroup(g.id, 'pending', 0);
    expect(
      () => s.savePlayGroup(
        id: g.id,
        expectedRevision: 1,
        name: g.name,
        sport: g.sport,
        description: g.description,
      ),
      throwsStateError,
    );
    admin(s);
    expect(
      () => s.transitionPlayGroup(g.id, 'rejected', 1, note: 'no'),
      throwsStateError,
    );
    s.transitionPlayGroup(g.id, 'rejected', 1, note: 'Please clarify rules');
    expect(() => s.transitionPlayGroup(g.id, 'approved', 1), throwsStateError);
    owner(s);
    final edit = s.savePlayGroup(
      id: g.id,
      expectedRevision: 2,
      name: g.name,
      sport: g.sport,
      description: 'Updated description and playing rules',
    );
    expect(edit.state, 'draft');
    expect(edit.note, '');
    expect(
      () => s.savePlayGroup(
        id: g.id,
        expectedRevision: 2,
        name: g.name,
        sport: g.sport,
        description: g.description,
      ),
      throwsStateError,
    );
    s.transitionPlayGroup(g.id, 'pending', edit.revision);
    admin(s);
    s.transitionPlayGroup(g.id, 'approved', 4);
    expect(s.publicGroups.containsKey(g.id), isTrue);
  });
  test('Suspension hides group/posts and denies joining/posting, reopening preserves history', () {
    final s = open();
    owner(s);
    final g = draft(s);
    s.transitionPlayGroup(g.id, 'pending', 0);
    admin(s);
    s.transitionPlayGroup(g.id, 'approved', 1);
    player(s);
    s.toggleGroup(g.id);
    final post = s.createPost(g.id, 'Playing this weekend');
    admin(s);
    s.transitionPlayGroup(g.id, 'suspended', 2, note: 'Temporary group review');
    player(s);
    expect(s.joinedGroups.contains(g.id), isFalse);
    expect(s.posts.contains(post), isFalse);
    expect(() => s.toggleGroup(g.id), throwsStateError);
    expect(() => s.createPost(g.id, 'New post'), throwsStateError);
    admin(s);
    s.transitionPlayGroup(g.id, 'approved', 3);
    player(s);
    expect(s.joinedGroups.contains(g.id), isTrue);
    expect(s.posts.contains(post), isTrue);
    s.toggleGroup(g.id);
    expect(() => s.createPost(g.id, 'New post'), throwsStateError);
  });
  test(
    'Snapshots preserve suspended history and retry without duplicate group',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      store.failWrite = true;
      final g = draft(s);
      expect(await s.flush(), isFalse);
      store.failWrite = false;
      await s.retrySave();
      s.transitionPlayGroup(g.id, 'pending', 0);
      admin(s);
      s.transitionPlayGroup(g.id, 'approved', 1);
      player(s);
      s.toggleGroup(g.id);
      s.createPost(g.id, 'Persistent group post');
      admin(s);
      s.transitionPlayGroup(g.id, 'suspended', 2, note: 'Checking group rules');
      await s.flush();
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isFalse);
      expect(r.managedPlayGroups.length, 1);
      r.transitionPlayGroup(g.id, 'approved', 3);
      player(r);
      expect(r.joinedGroups.contains(g.id), isTrue);
      expect(r.posts.single.message, 'Persistent group post');
    },
  );
  test('Legacy snapshots without registry keep seeded groups', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    owner(s);
    await s.flush();
    final data = jsonDecode(store.value!) as Map<String, dynamic>;
    data.remove('playGroups');
    data.remove('nextPlayGroup');
    store.value = jsonEncode(data);
    final r = open(store);
    await r.initialize();
    expect(r.loadFailed, isFalse);
    expect(r.managedPlayGroups, isEmpty);
    expect(r.publicGroups.length, 2);
  });
  for (final bad in [
    'owner',
    'state',
    'counter',
    'duplicate',
    'note',
    'membership',
  ]) {
    test('Corrupt $bad fails atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      draft(s);
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      final list = data['playGroups'] as List;
      final g = list.single as Map<String, dynamic>;
      switch (bad) {
        case 'owner':
          g['owner'] = DemoSession.phone;
        case 'state':
          g['state'] = 'approved';
        case 'counter':
          data['nextPlayGroup'] = 1;
        case 'duplicate':
          list.add({...g, 'id': 'NC0002'});
          data['nextPlayGroup'] = 3;
        case 'note':
          g['note'] = 'Unexpected note';
        case 'membership':
          data['groups'] = {
            DemoSession.phone: ['NC0001'],
          };
      }
      store.value = jsonEncode(data);
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(r.user, isNull);
    });
  }
}
