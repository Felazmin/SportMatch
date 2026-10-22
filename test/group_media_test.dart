import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_play_groups.dart';

import 'multi_facility_test.dart' show sampleFacilityProof;
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
  test('Group cover survives submit, rejection, correction, approval and suspension', () {
    final s = open();
    owner(s);
    var g = s.savePlayGroup(
      name: 'Test cover group',
      sport: 'badminton',
      description: 'A local test cover group',
      photo: sampleFacilityProof,
    );
    expect(s.publicPlayGroup(g.id), isNull);
    s.transitionPlayGroup(g.id, 'pending', g.revision);
    admin(s);
    s.transitionPlayGroup(
      g.id,
      'rejected',
      1,
      note: 'Needs clearer description',
    );
    owner(s);
    g = s.savePlayGroup(
      id: g.id,
      expectedRevision: 2,
      name: g.name,
      sport: g.sport,
      description: 'Corrected description for group',
    );
    expect(g.photo, sampleFacilityProof);
    s.transitionPlayGroup(g.id, 'pending', g.revision);
    admin(s);
    s.transitionPlayGroup(g.id, 'approved', 4);
    expect(s.publicPlayGroup(g.id)!.photo, sampleFacilityProof);
    s.transitionPlayGroup(
      g.id,
      'suspended',
      5,
      note: 'Group is temporarily suspended',
    );
    expect(s.publicPlayGroup(g.id), isNull);
  });
  test('Invalid group photo is rejected before creating a record; old JSON migrates', () {
    final s = open();
    owner(s);
    expect(
      () => s.savePlayGroup(
        name: 'Test cover group',
        sport: 'badminton',
        description: 'A local test cover group',
        photo: 'invalid photo',
      ),
      throwsStateError,
    );
    expect(s.managedPlayGroups, isEmpty);
    final g = s.savePlayGroup(
      name: 'Test cover group',
      sport: 'badminton',
      description: 'A local test cover group',
    );
    final data = g.toJson()..remove('photo');
    expect(DemoPlayGroup.fromJson(data).photo, '');
  });
  test(
    'Group cover is persisted and can be explicitly removed before submission',
    () async {
      final store = TestSessionStore(), s = open(store);
      await s.initialize();
      owner(s);
      final g = s.savePlayGroup(
        name: 'Test cover group',
        sport: 'badminton',
        description: 'A local test cover group',
        photo: sampleFacilityProof,
      );
      await s.flush();
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      owner(restored);
      expect(restored.managedPlayGroups.single.photo, sampleFacilityProof);
      restored.savePlayGroup(
        id: g.id,
        expectedRevision: 0,
        name: g.name,
        sport: g.sport,
        description: g.description,
        photo: '',
      );
      expect(restored.managedPlayGroups.single.photo, '');
    },
  );
}
