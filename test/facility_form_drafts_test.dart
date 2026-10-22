import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';

import 'multi_facility_test.dart' show publishTestFacility;
import 'persistence_test.dart' show TestSessionStore;

FacilityFormDraft partial({DemoFacility? facility, String name = 'A'}) =>
    FacilityFormDraft(
      fields: {
        'name': name,
        'address': '',
        'city': '',
        'district': '',
        'phone': '',
        'ownerName': '',
        'courtCount': '',
        'baseRate': '',
        'description': '',
        'cancelPolicy': '',
      },
      facilityId: facility?.id ?? '',
      revision: facility?.revision ?? 0,
      sport: 'Pickleball',
      openHour: 22,
      closeHour: 6,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  test(
    'Failed local save retains partial input and retry writes it once',
    () async {
      final store = TestSessionStore(), persisted = open(TestSessionStore());
      await persisted.initialize();
      owner(persisted);
      final target = open(store);
      await target.initialize();
      owner(target);
      await target.flush();
      store.failWrite = true;
      target.saveFacilityFormDraft(partial(name: 'Retry'));
      expect(await target.flush(), isFalse);
      expect(target.facilityFormDraft()!.fields['name'], 'Retry');
      store.failWrite = false;
      await target.retrySave();
      final restored = open(store);
      await restored.initialize();
      owner(restored);
      expect(restored.facilityFormDraft()!.fields['name'], 'Retry');
      expect(restored.managedFacilities, isEmpty);
    },
  );
  test(
    'Incomplete input survives restart without creating a public facility',
    () async {
      final store = TestSessionStore(), s = open();
      owner(s);
      expect(() => s.saveFacilityFormDraft(partial()), returnsNormally);
      expect(s.facilityFormDraft()!.fields['name'], 'A');
      expect(s.publicFacilities, isEmpty);
      final persisted = open(store);
      await persisted.initialize();
      owner(persisted);
      persisted.saveFacilityFormDraft(partial());
      expect(await persisted.flush(), isTrue);
      final restored = open(store);
      await restored.initialize();
      owner(restored);
      expect(restored.facilityFormDraft()!.fields['address'], '');
      expect(restored.facilityFormDraft()!.openHour, 22);
      expect(restored.managedFacilities, isEmpty);
      expect(
        () => restored.facilityFormDraft()!.fields['name'] = 'Mutated',
        throwsUnsupportedError,
      );
    },
  );
  test('Player and admin cannot read, save or discard owner partial input', () {
    final s = open();
    owner(s);
    s.saveFacilityFormDraft(partial());
    for (final role in [DemoRole.player, DemoRole.admin]) {
      if (role == DemoRole.player) {
        s.login(DemoSession.phone, DemoSession.password);
      } else {
        s.loginStaff(role, DemoSession.adminEmail, DemoSession.password);
      }
      expect(() => s.facilityFormDraft(), throwsStateError);
      expect(() => s.saveFacilityFormDraft(partial()), throwsStateError);
      expect(() => s.discardFacilityFormDraft(), throwsStateError);
    }
  });
  test('Partial edits do not modify published data and stale forms cannot overwrite', () {
    final s = open(), f = publishTestFacility(open());
    // Use the facility registered in this session for all ownership checks.
    final own = publishTestFacility(s);
    owner(s);
    final draft = partial(facility: own);
    s.saveFacilityFormDraft(draft, facility: own);
    expect(own.published!.name, isNot('A'));
    s.saveFacility(own.draft, facility: own, expectedRevision: own.revision);
    expect(s.facilityFormDraft(own), isNull);
    expect(
      () => s.saveFacilityFormDraft(draft, facility: own),
      throwsStateError,
    );
    expect(
      () => s.saveFacilityFormDraft(partial(facility: f), facility: f),
      throwsStateError,
    );
  });
  test(
    'Submission hides obsolete partial input and discard persists',
    () async {
      final store = TestSessionStore(), s = open(TestSessionStore());
      await s.initialize();
      final f = publishTestFacility(s);
      owner(s);
      s.saveFacilityFormDraft(partial(facility: f), facility: f);
      s.saveFacility(f.draft, facility: f);
      s.submitFacility(f);
      expect(s.facilityFormDraft(f), isNull);
      expect(
        () => s.saveFacilityFormDraft(partial(facility: f), facility: f),
        throwsStateError,
      );
      final other = open(store);
      await other.initialize();
      owner(other);
      other.saveFacilityFormDraft(partial());
      other.discardFacilityFormDraft();
      expect(await other.flush(), isTrue);
      final restored = open(store);
      await restored.initialize();
      owner(restored);
      expect(restored.facilityFormDraft(), isNull);
    },
  );
  test('Malformed partial snapshot is rejected atomically; old snapshots stay compatible', () async {
    final store = TestSessionStore(), s = open();
    owner(s);
    expect(() => partial(name: 'x' * 101), throwsFormatException);
    final persisted = open(store);
    await persisted.initialize();
    owner(persisted);
    persisted.saveFacilityFormDraft(partial());
    await persisted.flush();
    final data = jsonDecode(store.value!) as Map<String, dynamic>;
    (data['facilityFormDrafts'] as List).add(
      (data['facilityFormDrafts'] as List).first,
    );
    store.value = jsonEncode(data);
    final invalid = open(store);
    await invalid.initialize();
    expect(invalid.loadFailed, isTrue);
    data.remove('facilityFormDrafts');
    store.value = jsonEncode(data);
    final legacy = open(store);
    await legacy.initialize();
    owner(legacy);
    expect(legacy.facilityFormDraft(), isNull);
  });
}
