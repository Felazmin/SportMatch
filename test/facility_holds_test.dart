import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_calendar.dart';

import 'multi_facility_test.dart' show publishTestFacility;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  final now = DateTime(2026, 10, 8, 10), start = DateTime(2026, 10, 9, 5);
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void manager(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  test('Facility locks isolate inventories and primary dashboard', () {
    final s = open();
    publishTestFacility(s);
    publishTestFacility(s, name: 'Second facility');
    manager(s);
    final b = s.blockCourt(
      facilityId: 'CS0001',
      court: 8,
      start: start,
      hours: 2,
      reason: 'Maintenance test',
    );
    expect(b.courtCount, 8);
    expect(s.available(8, start, 1, facilityId: 'CS0001'), isFalse);
    expect(s.available(8, start, 1, facilityId: 'CS0002'), isTrue);
    expect(s.dayOverview(start).blocked, 0);
    expect(
      s.available(
        8,
        start.add(const Duration(hours: 2)),
        1,
        facilityId: 'CS0001',
      ),
      isTrue,
    );
    expect(
      () => s.blockCourt(
        facilityId: 'CS0001',
        court: 8,
        start: start,
        hours: 1,
        reason: 'Duplicate lock',
      ),
      throwsStateError,
    );
    s.unblockCourt(b);
    expect(s.available(8, start, 1, facilityId: 'CS0001'), isTrue);
  });
  test('Manual facility reservation keeps venue snapshot and blocks locks', () {
    final s = open();
    publishTestFacility(s);
    manager(s);
    final b = s.manualReservation(
      facilityId: 'CS0001',
      customer: DemoSession.phone,
      court: 8,
      start: start,
      hours: 2,
      contact: 'Test guest',
      contactPhone: DemoSession.phone,
      quotedRate: 150000,
      quotedRates: [150000, 150000],
    );
    expect(b.facilityId, 'CS0001');
    expect(b.venueCourtCount, 8);
    expect(b.venueOpenHour, 5);
    expect(b.total, 300000);
    expect(
      () => s.blockCourt(
        facilityId: 'CS0001',
        court: 8,
        start: start,
        hours: 1,
        reason: 'Maintenance test',
      ),
      throwsStateError,
    );
    expect(
      () => s.manualReservation(
        facilityId: 'CS0001',
        customer: DemoSession.phone,
        court: 7,
        start: start,
        hours: 1,
        contact: 'Test guest',
        contactPhone: DemoSession.phone,
        quotedRate: 120000,
      ),
      throwsStateError,
    );
  });
  test('Facility opening, court, reason, horizon and role guards reject without commits', () {
    final s = open();
    final f = publishTestFacility(s);
    manager(s);
    for (final args in [
      (9, start, 1),
      (1, start.subtract(const Duration(hours: 1)), 1),
      (1, DateTime(2026, 10, 9, 22), 2),
      (1, start.add(const Duration(minutes: 1)), 1),
      (1, start.add(const Duration(days: 7)), 1),
    ]) {
      expect(
        () => s.blockCourt(
          facilityId: f.id,
          court: args.$1,
          start: args.$2,
          hours: args.$3,
          reason: 'Maintenance test',
        ),
        throwsStateError,
      );
    }
    expect(
      () => s.blockCourt(
        facilityId: f.id,
        court: 1,
        start: start,
        hours: 1,
        reason: 'x',
      ),
      throwsStateError,
    );
    expect(s.courtBlocks, isEmpty);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.suspendFacility(f, true);
    expect(
      () => s.blockCourt(
        facilityId: f.id,
        court: 1,
        start: start,
        hours: 1,
        reason: 'Maintenance test',
      ),
      throwsStateError,
    );
    s.login(DemoSession.phone, DemoSession.password);
    expect(
      () => s.blockCourt(
        court: 2,
        start: start.add(const Duration(hours: 1)),
        hours: 1,
        reason: 'Maintenance test',
      ),
      throwsStateError,
    );
  });
  test('Primary legacy lock migration preserves contract', () {
    final b = DemoCourtBlock.fromJson({
      'id': 'KB0001',
      'court': 1,
      'start': DateTime(2026, 10, 9, 6).toIso8601String(),
      'hours': 1,
      'reason': 'Maintenance test',
    });
    expect(b.facilityId, '');
    expect(b.courtCount, 3);
    expect(b.closeHour, 22);
  });
  test(
    'Scoped locks persist and missing facility links reject atomically',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      publishTestFacility(s);
      manager(s);
      s.blockCourt(
        facilityId: 'CS0001',
        court: 8,
        start: start,
        hours: 2,
        reason: 'Maintenance test',
      );
      await s.flush();
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      manager(restored);
      expect(restored.courtBlocks.single.facilityId, 'CS0001');
      expect(restored.available(8, start, 1, facilityId: 'CS0001'), isFalse);
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      (data['courtBlocks'] as List).first['facilityId'] = 'CS9999';
      store.value = jsonEncode(data);
      final invalid = open(store);
      await invalid.initialize();
      expect(invalid.loadFailed, isTrue);
    },
  );
}
