import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/demo/demo_payout.dart';
import 'package:test_do_an/venues/osm_venue_catalog.dart';
import 'package:test_do_an/venues/venue_catalog.dart';

import 'multi_facility_test.dart' show sampleFacilityProof;
import 'persistence_test.dart' show TestSessionStore;
import 'venue_claims_test.dart'
    show
        claimVenueId,
        loginClaimOwner,
        loginClaimAdmin,
        submitTestClaim,
        reviewTestClaim;

const activationBank = DemoBankAccount(
  bank: 'Ngân hàng mô phỏng',
  holder: 'NGUYEN VAN HUNG',
  number: '0000000000',
  revision: 1,
);

FacilityProfile activationProfile({
  bool bank = true,
  String sport = 'Pickleball',
  int rate = 160000,
}) => FacilityProfile(
  name: 'Pickleball 426',
  sport: sport,
  address: '16/15 Bình Lợi',
  city: 'TP. Hồ Chí Minh',
  district: 'Bình Lợi Trung',
  phone: DemoSession.phone,
  ownerName: 'Nguyễn Văn Hùng',
  courtCount: 2,
  openHour: 6,
  closeHour: 22,
  baseRate: rate,
  photo: sampleFacilityProof,
  legalProof: sampleFacilityProof,
  receivingAccount: bank ? activationBank : null,
);

void approveActivationClaim(DemoSession s) {
  loginClaimOwner(s);
  submitTestClaim(s);
  loginClaimAdmin(s);
  reviewTestClaim(s);
  loginClaimOwner(s);
}

DemoFacility createActivationFacility(DemoSession s, {bool bank = true}) =>
    s.saveFacility(
      activationProfile(bank: bank),
      sourceVenueId: claimVenueId,
      expectedClaimRevision: 2,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<VenueSummary> catalog;
  setUpAll(() async => catalog = await loadOsmVenues());
  Future<DemoSession> open([TestSessionStore? store]) async {
    final s = DemoSession(
      store: store ?? TestSessionStore(),
      venueCatalogLoader: () async => catalog,
      now: () => DateTime(2026, 10, 20, 10),
    );
    addTearDown(s.dispose);
    await s.initialize();
    return s;
  }

  final start = DateTime(2026, 10, 21, 9);

  test(
    'Only approved owners may create a linked operational profile, once',
    () async {
      final s = await open();
      expect(() => createActivationFacility(s), throwsStateError);
      loginClaimOwner(s);
      expect(() => createActivationFacility(s), throwsStateError);
      submitTestClaim(s);
      expect(() => createActivationFacility(s), throwsStateError);
      loginClaimAdmin(s);
      reviewTestClaim(s);
      expect(() => createActivationFacility(s), throwsStateError);
      loginClaimOwner(s);
      expect(
        () => s.saveFacility(
          activationProfile(),
          sourceVenueId: claimVenueId,
          expectedClaimRevision: 1,
        ),
        throwsStateError,
      );
      expect(
        () => s.saveFacility(
          activationProfile(sport: 'Bóng đá'),
          sourceVenueId: claimVenueId,
          expectedClaimRevision: 2,
        ),
        throwsStateError,
      );
      expect(s.managedFacilities, isEmpty);
      final f = createActivationFacility(s);
      expect(s.claimedFacility(claimVenueId), same(f));
      expect(() => createActivationFacility(s), throwsStateError);
      expect(s.managedFacilities.length, 1);
      expect(
        s.currentVenues.singleWhere((v) => v.id == claimVenueId).bookingEnabled,
        isFalse,
      );
    },
  );

  test(
    'Publishing requires receiving account and an explicit second review',
    () async {
      final s = await open();
      approveActivationClaim(s);
      final f = createActivationFacility(s, bank: false);
      expect(() => s.submitFacility(f), throwsStateError);
      expect(f.state, 'draft');
      s.saveFacility(
        activationProfile(),
        facility: f,
        expectedRevision: f.revision,
      );
      s.submitFacility(f);
      expect(
        s.currentVenues.singleWhere((v) => v.id == claimVenueId).bookingEnabled,
        isFalse,
      );
      expect(() => s.reviewFacility(f, approve: true), throwsStateError);
      loginClaimAdmin(s);
      expect(
        () => s.reviewFacility(f, approve: true, expectedRevision: 0),
        throwsStateError,
      );
      s.reviewFacility(f, approve: true, expectedRevision: f.revision);
      expect(
        s.currentVenues.singleWhere((v) => v.id == claimVenueId).bookingEnabled,
        isTrue,
      );
    },
  );

  test(
    'Publishing preserves one map point and favorite identity, uses owner rate',
    () async {
      final s = await open();
      s.login(DemoSession.phone, DemoSession.password);
      s.toggleFavorite(claimVenueId);
      approveActivationClaim(s);
      final f = createActivationFacility(s);
      s.submitFacility(f);
      loginClaimAdmin(s);
      s.reviewFacility(f, approve: true);
      s.login(DemoSession.phone, DemoSession.password);
      final v = s.currentVenues.singleWhere((v) => v.id == claimVenueId);
      final source = catalog.singleWhere((v) => v.id == claimVenueId);
      expect(s.currentVenues.length, catalog.length + 1);
      expect(s.currentVenues.where((v) => v.id == f.id), isEmpty);
      expect(v.latitude, source.latitude);
      expect(v.longitude, source.longitude);
      expect(v.sourceUrl, source.sourceUrl);
      expect(v.priceReference, isNull);
      expect(v.bookingId, f.id);
      expect(v.price, 160000);
      expect(s.favoriteVenueIds, contains(claimVenueId));
      final b = s.reserve(
        facilityId: v.bookingId,
        court: 1,
        start: start,
        hours: 1,
        contact: 'Minh Phát',
        contactPhone: DemoSession.phone,
        quotedRate: 160000,
      );
      expect(b.venueName, 'Pickleball 426');
      expect(b.receivingAccount!.number, '0000000000');
      expect(b.total, 160000);
      expect(s.available(1, start, 1, facilityId: f.id), isFalse);
      expect(s.available(2, start, 1, facilityId: f.id), isTrue);
    },
  );

  test(
    'Suspension blocks reservations and old booking retains its bank and price',
    () async {
      final s = await open();
      approveActivationClaim(s);
      final f = createActivationFacility(s);
      s.submitFacility(f);
      loginClaimAdmin(s);
      s.reviewFacility(f, approve: true);
      s.login(DemoSession.phone, DemoSession.password);
      final b = s.reserve(
        facilityId: f.id,
        court: 1,
        start: start,
        hours: 1,
        contact: 'Tấn Đạt',
        contactPhone: DemoSession.phone,
      );
      loginClaimOwner(s);
      final changed = FacilityProfile.fromJson({
        ...activationProfile(rate: 200000).toJson(),
        'receivingAccount': {
          ...activationBank.toJson(),
          'number': '1111111111',
          'revision': 2,
        },
      });
      s.saveFacility(changed, facility: f, expectedRevision: f.revision);
      s.submitFacility(f);
      expect(
        s.currentVenues.singleWhere((v) => v.id == claimVenueId).price,
        160000,
      );
      loginClaimAdmin(s);
      s.reviewFacility(f, approve: true);
      expect(
        s.currentVenues.singleWhere((v) => v.id == claimVenueId).price,
        200000,
      );
      s.suspendFacility(f, true);
      s.login(DemoSession.phone, DemoSession.password);
      expect(
        s.currentVenues.singleWhere((v) => v.id == claimVenueId).bookingEnabled,
        isFalse,
      );
      expect(s.available(2, start, 1, facilityId: f.id), isFalse);
      expect(b.total, 160000);
      expect(b.receivingAccount!.number, '0000000000');
      expect(s.startTransfer(b).bookingId, b.id);
    },
  );

  test(
    'Linked profiles and booking account snapshots survive device reload',
    () async {
      final store = TestSessionStore();
      final s = await open(store);
      approveActivationClaim(s);
      final f = createActivationFacility(s);
      s.submitFacility(f);
      loginClaimAdmin(s);
      s.reviewFacility(f, approve: true);
      s.login(DemoSession.phone, DemoSession.password);
      final b = s.reserve(
        facilityId: f.id,
        court: 1,
        start: start,
        hours: 1,
        contact: 'Minh Phát',
        contactPhone: DemoSession.phone,
      );
      expect(await s.flush(), isTrue);
      final restored = await open(store);
      expect(restored.loadFailed, isFalse);
      expect(
        restored.currentVenues
            .singleWhere((v) => v.id == claimVenueId)
            .bookingId,
        f.id,
      );
      expect(
        restored.bookings
            .singleWhere((v) => v.id == b.id)
            .receivingAccount!
            .number,
        '0000000000',
      );
      loginClaimOwner(restored);
      expect(
        restored.claimedFacility(claimVenueId)!.sourceVenueId,
        claimVenueId,
      );
    },
  );

  test('Restore rejects broken claim links and missing published receiving accounts', () async {
    final store = TestSessionStore();
    final s = await open(store);
    approveActivationClaim(s);
    final f = createActivationFacility(s);
    s.submitFacility(f);
    loginClaimAdmin(s);
    s.reviewFacility(f, approve: true);
    expect(await s.flush(), isTrue);
    final original = store.value!;
    for (final mode in ['claim', 'account', 'duplicate']) {
      final j = jsonDecode(original) as Map<String, dynamic>;
      final row = (j['facilities'] as List).single as Map<String, dynamic>;
      if (mode == 'claim') row['sourceVenueId'] = 'osm-way-112337549';
      if (mode == 'account') {
        (row['published'] as Map)['receivingAccount'] = null;
      }
      if (mode == 'duplicate') {
        (j['facilities'] as List).add({...row, 'id': 'CS0002'});
        j['nextFacility'] = 3;
      }
      final restored = await open(TestSessionStore()..value = jsonEncode(j));
      expect(restored.loadFailed, isTrue, reason: mode);
      expect(restored.initialized, isFalse);
    }
  });
}
