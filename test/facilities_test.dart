import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  const png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
  final now = DateTime(2026, 10, 6, 10);
  DemoSession make([TestSessionStore? store]) {
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
  FacilityProfile profile({
    String name = 'Cơ sở thử nghiệm',
    bool attachments = true,
  }) => FacilityProfile(
    name: name,
    sport: 'Cầu lông',
    address: '12 Đường thử nghiệm',
    city: 'TP.HCM',
    district: 'Tân Phú',
    phone: DemoSession.phone,
    ownerName: 'Chủ sân',
    courtCount: 3,
    openHour: 6,
    closeHour: 22,
    baseRate: 120000,
    photo: attachments ? png : '',
    legalProof: attachments ? png : '',
    amenities: {'Bãi xe'},
  );
  test('Only owner creates, edits and submits; only admin reviews', () {
    final s = make();
    expect(() => s.saveFacility(profile()), throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.saveFacility(profile()), throwsStateError);
    owner(s);
    final f = s.saveFacility(profile());
    expect(f.id, 'CS0001');
    s.submitFacility(f);
    expect(() => s.reviewFacility(f, approve: true), throwsStateError);
    expect(() => s.saveFacility(profile(), facility: f), throwsStateError);
    admin(s);
    expect(() => s.saveFacility(profile()), throwsStateError);
    s.reviewFacility(f, approve: true);
    expect(s.publicFacilities.single.id, f.id);
    expect(f.state, 'approved');
  });
  test(
    'Gallery and legal samples are required to submit but not save draft',
    () {
      final s = make();
      owner(s);
      final f = s.saveFacility(profile(attachments: false));
      expect(() => s.submitFacility(f), throwsStateError);
      expect(f.state, 'draft');
      expect(s.publicFacilities, isEmpty);
    },
  );
  test('Reason validation, rejection, correction and resubmission', () {
    final s = make();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    admin(s);
    expect(
      () => s.reviewFacility(f, approve: false, note: 'No'),
      throwsStateError,
    );
    s.reviewFacility(f, approve: false, note: 'Bổ sung hồ sơ');
    expect(f.label, 'Cần bổ sung');
    owner(s);
    s.saveFacility(profile(name: 'Hồ sơ đã bổ sung'), facility: f);
    s.submitFacility(f);
    admin(s);
    s.reviewFacility(f, approve: true);
    expect(s.publicFacilities.single.profile.name, 'Hồ sơ đã bổ sung');
  });
  test('Editing and rejection keep the previous published profile', () {
    final s = make();
    owner(s);
    final f = s.saveFacility(profile());
    s.submitFacility(f);
    admin(s);
    s.reviewFacility(f, approve: true);
    owner(s);
    s.saveFacility(profile(name: 'Thông tin nháp mới'), facility: f);
    expect(s.publicFacilities.single.profile.name, 'Cơ sở thử nghiệm');
    s.submitFacility(f);
    admin(s);
    s.reviewFacility(f, approve: false, note: 'Kiểm tra thông tin');
    expect(s.publicFacilities.single.profile.name, 'Cơ sở thử nghiệm');
  });
  test(
    'Public view omits legal attachment and private representative name',
    () {
      final s = make();
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      admin(s);
      s.reviewFacility(f, approve: true);
      s.logout();
      final p = s.publicFacilities.single.profile;
      expect(p.legalProof, isEmpty);
      expect(p.ownerName, 'Chủ cơ sở');
      expect(p.photo, png);
      expect(() => s.managedFacilities, throwsStateError);
    },
  );
  test('Suspension hides public record and reopening restores it', () {
    final s = make();
    owner(s);
    final f = s.saveFacility(profile());
    expect(() => s.suspendFacility(f, true), throwsStateError);
    s.submitFacility(f);
    admin(s);
    s.reviewFacility(f, approve: true);
    s.suspendFacility(f, true);
    expect(s.publicFacilities, isEmpty);
    expect(f.label, 'Tạm ngưng');
    s.suspendFacility(f, false);
    expect(s.publicFacilities.length, 1);
  });
  test(
    'Foreign instance and stale revisions cannot mutate managed records',
    () {
      final s = make(), other = make();
      owner(s);
      owner(other);
      final f = other.saveFacility(profile());
      expect(() => s.submitFacility(f), throwsStateError);
      final own = s.saveFacility(profile());
      final revision = own.revision;
      s.saveFacility(profile(name: 'Đã sửa'), facility: own);
      expect(
        () => s.saveFacility(
          profile(),
          facility: own,
          expectedRevision: revision,
        ),
        throwsStateError,
      );
      s.submitFacility(own);
      admin(s);
      expect(
        () => s.reviewFacility(own, approve: true, expectedRevision: revision),
        throwsStateError,
      );
      expect(own.state, 'pending');
    },
  );
  test('Invalid numeric, contact, sports and image data fail validation', () {
    for (final patch in [
      {'courtCount': 0},
      {'courtCount': 21},
      {'openHour': 22, 'closeHour': 6},
      {'baseRate': 12345},
      {'phone': '123'},
      {'sport': 'unknown'},
      {'name': 'a'},
      {'photo': 'bad'},
    ]) {
      expect(
        () => FacilityProfile.fromJson({...profile().toJson(), ...patch}),
        throwsFormatException,
      );
    }
  });
  test(
    'Facilities, drafts, approved private attachments and IDs survive restart',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      owner(s);
      final f = s.saveFacility(profile());
      s.submitFacility(f);
      admin(s);
      s.reviewFacility(f, approve: true);
      owner(s);
      s.saveFacility(profile(name: 'Bản nháp mới'), facility: f);
      await s.flush();
      final r = make(store);
      await r.initialize();
      expect(r.loadFailed, isFalse);
      expect(r.managedFacilities.single.draft.name, 'Bản nháp mới');
      expect(r.managedFacilities.single.draft.legalProof, png);
      expect(r.publicFacilities.single.profile.name, 'Cơ sở thử nghiệm');
      expect(r.saveFacility(profile()).id, 'CS0002');
    },
  );
  test('Save retry does not duplicate records or journal entries', () async {
    final store = TestSessionStore();
    final s = make(store);
    await s.initialize();
    owner(s);
    await s.flush();
    store.failWrite = true;
    s.saveFacility(profile());
    expect(await s.flush(), isFalse);
    store.failWrite = false;
    await s.retrySave();
    final r = make(store);
    await r.initialize();
    expect(r.managedFacilities.length, 1);
    expect(r.operationAudit.length, 1);
  });
  test(
    'Old snapshots without facility fields migrate to empty registry',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      owner(s);
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      data.remove('facilities');
      data.remove('nextFacility');
      store.value = jsonEncode(data);
      final r = make(store);
      await r.initialize();
      expect(r.loadFailed, isFalse);
      expect(r.managedFacilities, isEmpty);
    },
  );
  for (final corrupt in [
    'id',
    'owner',
    'approved',
    'pending',
    'duplicate',
    'counter',
    'revision',
    'suspended',
  ]) {
    test('Corrupt $corrupt facility snapshot is rejected atomically', () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      owner(s);
      s.saveFacility(profile(attachments: false));
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      final list = data['facilities'] as List;
      final f = list.single as Map<String, dynamic>;
      switch (corrupt) {
        case 'id':
          f['id'] = 'bad';
        case 'owner':
          f['owner'] = DemoSession.phone;
        case 'approved':
          f['state'] = 'approved';
        case 'pending':
          f['state'] = 'pending';
        case 'duplicate':
          list.add(Map<String, dynamic>.from(f));
        case 'counter':
          data['nextFacility'] = 1;
        case 'revision':
          f['revision'] = 0;
        case 'suspended':
          f['suspended'] = true;
      }
      store.value = jsonEncode(data);
      final r = make(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(r.user, isNull);
      expect(r.publishedCourts.rates, [120000, 120000, 120000]);
    });
  }
}
