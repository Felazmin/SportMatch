import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => DateTime(2026, 10, 8, 10), store: store);
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
  void draft(
    DemoSession s, {
    String name = 'Cầu lông PVC',
    String sport = 'Cầu lông',
  }) => s.saveCourtType(
    name: name,
    sport: sport,
    description: 'Mặt thảm PVC trong nhà',
  );
  void publish(DemoSession s) {
    owner(s);
    draft(s);
    s.transitionCourtType('LS0001', 'pending', 0);
    admin(s);
    s.transitionCourtType('LS0001', 'approved', 1);
  }

  FacilityProfile profile({String id = 'LS0001', String sport = 'Cầu lông'}) =>
      FacilityProfile(
        name: 'Cơ sở thử nghiệm',
        sport: sport,
        courtTypeId: id,
        address: '12 Đường thử nghiệm',
        city: 'TP.HCM',
        district: 'Tân Phú',
        phone: DemoSession.phone,
        ownerName: 'Chủ sân',
        courtCount: 3,
        openHour: 6,
        closeHour: 22,
        baseRate: 120000,
      );
  test('Permissions, pending approval and immutable registry', () {
    final s = open();
    expect(() => draft(s), throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.managedCourtTypes, throwsStateError);
    expect(() => draft(s), throwsStateError);
    admin(s);
    expect(() => draft(s), throwsStateError);
    owner(s);
    draft(s);
    expect(s.approvedCourtTypes, isEmpty);
    expect(
      () => s.transitionCourtType('LS0001', 'approved', 0),
      throwsStateError,
    );
    s.transitionCourtType('LS0001', 'pending', 0);
    admin(s);
    s.transitionCourtType('LS0001', 'approved', 1);
    expect(s.approvedCourtTypes.single.name, 'Cầu lông PVC');
    expect(() => s.approvedCourtTypes.clear(), throwsUnsupportedError);
  });
  test('Validation, normalized duplicates and ID stability', () {
    final s = open();
    owner(s);
    expect(() => draft(s, sport: 'Invalid'), throwsStateError);
    expect(() => draft(s, name: 'x'), throwsStateError);
    draft(s);
    expect(s.managedCourtTypes.single.id, 'LS0001');
    expect(() => draft(s, name: 'cau long pvc'), throwsStateError);
    draft(s, name: 'Bóng đá cỏ');
    expect(s.managedCourtTypes.last.id, 'LS0002');
  });
  test('Reject, revise, resubmit, suspend and reopen with stale guards', () {
    final s = open();
    owner(s);
    draft(s);
    s.transitionCourtType('LS0001', 'pending', 0);
    admin(s);
    expect(
      () => s.transitionCourtType('LS0001', 'rejected', 1, note: 'no'),
      throwsStateError,
    );
    s.transitionCourtType('LS0001', 'rejected', 1, note: 'Bổ sung đặc điểm');
    owner(s);
    s.saveCourtType(
      id: 'LS0001',
      expectedRevision: 2,
      name: 'Cầu lông PVC',
      sport: 'Cầu lông',
      description: 'Mặt thảm chống trượt',
    );
    s.transitionCourtType('LS0001', 'pending', 3);
    admin(s);
    expect(
      () => s.transitionCourtType('LS0001', 'approved', 1),
      throwsStateError,
    );
    s.transitionCourtType('LS0001', 'approved', 4);
    s.transitionCourtType(
      'LS0001',
      'suspended',
      5,
      note: 'Tạm kiểm tra chất lượng',
    );
    expect(s.approvedCourtTypes, isEmpty);
    s.transitionCourtType('LS0001', 'approved', 6);
    expect(s.approvedCourtTypes.single.note, isEmpty);
  });
  test('Facility links only approved matching sport; suspension retains old references', () {
    final s = open();
    owner(s);
    draft(s);
    expect(() => s.saveFacility(profile()), throwsStateError);
    s.transitionCourtType('LS0001', 'pending', 0);
    admin(s);
    s.transitionCourtType('LS0001', 'approved', 1);
    owner(s);
    expect(() => s.saveFacility(profile(sport: 'Bóng đá')), throwsStateError);
    final f = s.saveFacility(profile());
    admin(s);
    s.transitionCourtType(
      'LS0001',
      'suspended',
      2,
      note: 'Tạm kiểm tra chất lượng',
    );
    owner(s);
    expect(() => s.saveFacility(profile()), throwsStateError);
    s.saveFacility(profile(), facility: f, expectedRevision: f.revision);
    expect(f.draft.courtTypeId, 'LS0001');
  });
  test('Restart preserves types, links and revisions', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    publish(s);
    owner(s);
    s.saveFacility(profile());
    await s.flush();
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(restored.managedCourtTypes.single.revision, 2);
    expect(restored.managedFacilities.single.draft.courtTypeId, 'LS0001');
  });
  test('Legacy snapshot without type registry still loads', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    owner(s);
    s.saveFacility(profile(id: ''));
    await s.flush();
    final data = jsonDecode(store.value!) as Map<String, dynamic>;
    data.remove('courtTypes');
    data.remove('nextCourtType');
    (data['facilities'][0]['draft'] as Map).remove('courtTypeId');
    store.value = jsonEncode(data);
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(restored.managedCourtTypes, isEmpty);
  });
  test(
    'Save failure retries without duplicate types or audit entries',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      await s.flush();
      store.failWrite = true;
      draft(s);
      expect(await s.flush(), isFalse);
      store.failWrite = false;
      s.retrySave();
      expect(await s.flush(), isTrue);
      final restored = open(store);
      await restored.initialize();
      expect(restored.managedCourtTypes.length, 1);
      expect(restored.managedCourtTypes.single.id, 'LS0001');
    },
  );
  test('Draft names are not exposed through public lookup', () {
    final s = open();
    owner(s);
    draft(s);
    expect(s.courtTypeName('LS0001'), 'Cầu lông PVC');
    s.login(DemoSession.phone, DemoSession.password);
    expect(s.courtTypeName('LS0001'), isEmpty);
  });
  for (final invalid in ['counter', 'link', 'duplicate', 'sport']) {
    test('Corrupt $invalid fails atomic restore', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      publish(s);
      owner(s);
      s.saveFacility(profile());
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      switch (invalid) {
        case 'counter':
          data['nextCourtType'] = 1;
        case 'link':
          data['facilities'][0]['draft']['courtTypeId'] = 'LS9999';
        case 'duplicate':
          data['courtTypes'].add(data['courtTypes'][0]);
        case 'sport':
          data['courtTypes'][0]['sport'] = 'Bóng đá';
      }
      store.value = jsonEncode(data);
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isTrue);
      expect(restored.user, isNull);
    });
  }
}
