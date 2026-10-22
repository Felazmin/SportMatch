import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_venue_claim.dart';
import 'package:test_do_an/venues/osm_venue_catalog.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'multi_facility_test.dart' show sampleFacilityProof;
import 'persistence_test.dart' show TestSessionStore;

const claimVenueId = 'osm-way-1350606729';
void loginClaimOwner(DemoSession s) =>
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
void loginClaimAdmin(DemoSession s) =>
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
void submitTestClaim(
  DemoSession s, {
  int revision = 0,
  String proof = sampleFacilityProof,
  String venueId = claimVenueId,
  String phone = DemoSession.phone,
  String explanation = 'Tôi là người đại diện được ủy quyền quản lý cơ sở này.',
}) => s.submitVenueClaim(
  venueId: venueId,
  contact: 'Nguyễn Văn Hùng',
  phone: phone,
  explanation: explanation,
  proof: proof,
  expectedRevision: revision,
);
void reviewTestClaim(
  DemoSession s, {
  int revision = 1,
  bool approve = true,
  String password = DemoSession.password,
  String note = '',
}) => s.reviewVenueClaim(
  '__owner__:$claimVenueId',
  approve: approve,
  expectedRevision: revision,
  password: password,
  note: note,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<VenueSummary> venues;
  setUpAll(() async => venues = await loadOsmVenues());
  Future<DemoSession> open([TestSessionStore? store]) async {
    final s = DemoSession(
      store: store ?? TestSessionStore(),
      venueCatalogLoader: () async => venues,
      now: () => DateTime(2026, 10, 19, 12),
    );
    addTearDown(s.dispose);
    await s.initialize();
    return s;
  }

  test('Only owners submit evidence and only Admin reviews; approval does not publish', () async {
    final s = await open();
    expect(() => submitTestClaim(s), throwsStateError);
    expect(() => s.venueClaims, throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => submitTestClaim(s), throwsStateError);
    loginClaimOwner(s);
    submitTestClaim(s);
    expect(s.ownVenueClaim(claimVenueId)!.state, 'pending');
    expect(() => reviewTestClaim(s), throwsStateError);
    loginClaimAdmin(s);
    expect(() => submitTestClaim(s), throwsStateError);
    expect(() => reviewTestClaim(s, password: 'wrong'), throwsStateError);
    expect(s.venueClaims.single.state, 'pending');
    reviewTestClaim(s);
    expect(s.venueClaims.single.state, 'approved');
    expect(s.venueClaims.single.reviewer, '__admin__');
    expect(() => reviewTestClaim(s, revision: 2), throwsStateError);
    loginClaimOwner(s);
    expect(s.ownVenueClaim(claimVenueId)!.revision, 2);
    expect(() => submitTestClaim(s, revision: 2), throwsStateError);
    final venue = s.currentVenues.singleWhere((v) => v.id == claimVenueId);
    expect(venue.bookingEnabled, isFalse);
    expect(s.managedFacilities, isEmpty);
    expect(s.currentVenues.length, 130);
    expect(() => s.venueClaims.clear(), throwsUnsupportedError);
    s.logout();
    expect(() => s.venueClaims, throwsStateError);
  });

  test('Duplicate/stale requests, unknown venues and invalid evidence are rejected', () async {
    final s = await open();
    loginClaimOwner(s);
    for (final attempt in <void Function()>[
      () => submitTestClaim(s, proof: ''),
      () => submitTestClaim(s, phone: '123'),
      () => submitTestClaim(s, explanation: 'Ngắn'),
      () => submitTestClaim(s, venueId: demoVenueId),
      () => submitTestClaim(s, venueId: 'osm-way-999999999999'),
      () => submitTestClaim(s, revision: 5),
    ]) {
      expect(attempt, throwsStateError);
      expect(s.venueClaims, isEmpty);
    }
    submitTestClaim(s);
    expect(() => submitTestClaim(s), throwsStateError);
    expect(() => submitTestClaim(s, revision: 1), throwsStateError);
    expect(
      () => s.withdrawVenueClaim(claimVenueId, expectedRevision: 0),
      throwsStateError,
    );
    loginClaimAdmin(s);
    expect(() => reviewTestClaim(s, revision: 0), throwsStateError);
    expect(
      () => reviewTestClaim(s, approve: false, note: 'no'),
      throwsStateError,
    );
    expect(s.venueClaims.single.revision, 1);
  });

  test('Reject, resubmit, withdraw and resubmit preserve evidence and revision checks', () async {
    final s = await open();
    loginClaimOwner(s);
    submitTestClaim(s);
    loginClaimAdmin(s);
    reviewTestClaim(s, approve: false, note: 'Cần ảnh giấy ủy quyền rõ nét.');
    loginClaimOwner(s);
    expect(s.venueClaims.single.note, contains('ủy quyền'));
    submitTestClaim(s, revision: 2);
    expect(s.venueClaims.single.note, isEmpty);
    expect(s.venueClaims.single.state, 'pending');
    s.withdrawVenueClaim(claimVenueId, expectedRevision: 3);
    expect(s.venueClaims.single.state, 'withdrawn');
    loginClaimAdmin(s);
    expect(() => reviewTestClaim(s, revision: 3), throwsStateError);
    loginClaimOwner(s);
    submitTestClaim(s, revision: 4);
    expect(s.venueClaims.single.revision, 5);
    expect(s.venueClaims.single.proof, sampleFacilityProof);
    loginClaimAdmin(s);
    reviewTestClaim(s, revision: 5);
    loginClaimOwner(s);
    expect(
      () => s.withdrawVenueClaim(claimVenueId, expectedRevision: 6),
      throwsStateError,
    );
  });

  test('Five wrong Admin passwords lock confirmation', () async {
    final s = await open();
    loginClaimOwner(s);
    submitTestClaim(s);
    loginClaimAdmin(s);
    for (var i = 0; i < 5; i++) {
      expect(() => reviewTestClaim(s, password: 'wrong'), throwsStateError);
    }
    expect(() => reviewTestClaim(s), throwsStateError);
    expect(s.venueClaims.single.state, 'pending');
  });

  test('Approved claims and documents restore after save retry without catalog dependency', () async {
    final store = TestSessionStore();
    final s = await open(store);
    loginClaimOwner(s);
    submitTestClaim(s);
    loginClaimAdmin(s);
    reviewTestClaim(s);
    store.failWrite = true;
    expect(await s.flush(), isFalse);
    expect(s.saveFailed, isTrue);
    store.failWrite = false;
    await s.retrySave();
    expect(await s.flush(), isTrue);
    final restored = DemoSession(
      store: store,
      now: () => DateTime(2026, 10, 19, 12),
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    loginClaimOwner(restored);
    expect(restored.venueClaims.single.state, 'approved');
    expect(restored.venueClaims.single.proof, sampleFacilityProof);
    expect(restored.venueClaims.single.venueName, 'Pickleball 426');
  });

  test('Corrupt or duplicate claims fail restoration atomically', () async {
    final store = TestSessionStore();
    final s = await open(store);
    loginClaimOwner(s);
    submitTestClaim(s);
    await s.flush();
    final original = store.value!;
    for (final corrupt in ['duplicate', 'owner', 'reviewer', 'proof']) {
      final data = jsonDecode(original) as Map<String, dynamic>;
      final row = (data['venueClaims'] as List).single as Map<String, dynamic>;
      if (corrupt == 'duplicate') (data['venueClaims'] as List).add({...row});
      if (corrupt == 'owner') row['owner'] = DemoSession.phone;
      if (corrupt == 'reviewer') {
        row['state'] = 'approved';
        row['revision'] = 2;
        row['reviewer'] = '__owner__';
      }
      if (corrupt == 'proof') row['proof'] = 'invalid';
      final bad = TestSessionStore()..value = jsonEncode(data);
      final restored = await open(bad);
      expect(restored.loadFailed, isTrue);
      expect(restored.initialized, isFalse);
      expect(bad.value, jsonEncode(data));
    }
    final legacy = jsonDecode(original) as Map<String, dynamic>;
    legacy.remove('venueClaims');
    final restored = await open(TestSessionStore()..value = jsonEncode(legacy));
    expect(restored.loadFailed, isFalse);
    loginClaimOwner(restored);
    expect(restored.venueClaims, isEmpty);
  });

  test('Malformed state and timestamps reject the document model', () async {
    final s = await open();
    loginClaimOwner(s);
    submitTestClaim(s);
    final row = s.venueClaims.single.toJson();
    for (final delta in [
      {'state': 'unknown'},
      {'updated': '2010-01-01'},
      {'latitude': 91},
      {'state': 'approved', 'reviewer': ''},
    ]) {
      expect(
        () => DemoVenueClaim.fromJson({...row, ...delta}),
        throwsFormatException,
      );
    }
  });
}
