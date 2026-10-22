import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final date = DateTime(2026, 10, 6, 10);
  DemoSession open({TestSessionStore? store, DateTime Function()? clock}) {
    final s = DemoSession(now: clock ?? () => date, store: store);
    addTearDown(s.dispose);
    return s;
  }

  DemoParticipation join(DemoSession s, {int quantity = 1, DemoEvent? event}) {
    final e = event ?? demoEvents.first;
    return s.joinEvent(
      eventId: e.id,
      start: e.start(date),
      quantity: quantity,
      contact: 'Test User',
      contactPhone: '0912345678',
      team: e.kind == DemoEventKind.tournament ? 'Demo team' : '',
      partner: e.kind == DemoEventKind.tournament ? 'Partner' : '',
    );
  }

  test(
    'Guests cannot join; invalid quantities and fields cannot consume seats',
    () {
      final s = open();
      expect(() => join(s), throwsStateError);
      s.login(DemoSession.phone, DemoSession.password);
      for (final q in [0, 3, -1]) {
        expect(() => join(s, quantity: q), throwsStateError);
      }
      expect(
        () => s.joinEvent(
          eventId: 'missing',
          start: date,
          quantity: 1,
          contact: 'User',
          contactPhone: '0912345678',
        ),
        throwsStateError,
      );
      expect(
        () => s.joinEvent(
          eventId: demoEvents.first.id,
          start: demoEvents.first.start(date),
          quantity: 1,
          contact: 'a' * 61,
          contactPhone: '0912345678',
        ),
        throwsStateError,
      );
      expect(s.participations, isEmpty);
      expect(
        s.eventSeats(demoEvents.first.id, demoEvents.first.start(date)),
        12,
      );
    },
  );
  test(
    'Duplicate registration is rejected; cancellation restores seats only once',
    () {
      final s = open()..login(DemoSession.phone, DemoSession.password);
      final p = join(s, quantity: 2);
      expect(p.total, 120000);
      expect(() => join(s), throwsStateError);
      expect(s.eventSeats(p.eventId, p.start), 10);
      expect(s.cancelParticipation(p), isTrue);
      expect(s.cancelParticipation(p), isFalse);
      expect(s.eventSeats(p.eventId, p.start), 12);
      expect(join(s).id, 'VE0002');
    },
  );
  test('Capacity is shared across accounts and histories remain isolated', () {
    final s = open();
    for (var i = 0; i < 6; i++) {
      s.register('User $i', 'user$i@example.com', 'Test1234');
      join(s, quantity: 2);
      expect(s.participations.length, 1);
    }
    s.register('Extra', 'extra@example.com', 'Test1234');
    expect(() => join(s), throwsStateError);
    expect(s.participations, isEmpty);
    s.login('user0@example.com', 'Test1234');
    final first = s.participations.single;
    s.login('user1@example.com', 'Test1234');
    expect(s.cancelParticipation(first), isFalse);
    expect(s.demoCheckIn(first), isFalse);
  });
  test('Tournament requires one team and both team and partner names', () {
    final s = open()..login(DemoSession.phone, DemoSession.password);
    final e = demoEvents.last;
    expect(() => join(s, event: e, quantity: 2), throwsStateError);
    expect(
      () => s.joinEvent(
        eventId: e.id,
        start: e.start(date),
        quantity: 1,
        contact: 'User',
        contactPhone: '0912345678',
      ),
      throwsStateError,
    );
    final p = join(s, event: e);
    expect(p.total, 150000);
    expect(p.partner, 'Partner');
    expect(s.eventSeats(e.id, p.start), 7);
  });
  test('Check-in boundaries and cancellation policy are enforced', () {
    var now = date;
    final s = open(clock: () => now)
      ..login(DemoSession.phone, DemoSession.password);
    final p = join(s);
    final other = join(s, event: demoEvents.last);
    expect(s.demoCheckIn(p), isFalse);
    now = p.start.subtract(const Duration(minutes: 30));
    expect(s.demoCheckIn(p), isTrue);
    expect(s.demoCheckIn(p), isFalse);
    expect(s.cancelParticipation(p), isFalse);
    now = other.event.end(other.start);
    expect(s.demoCheckIn(other), isFalse);
    expect(s.cancelParticipation(other), isFalse);
  });
  test('Stale occurrence rejected and schedule boundaries are exact', () {
    var now = date;
    final s = open(clock: () => now)
      ..login(DemoSession.phone, DemoSession.password);
    now = date.add(const Duration(days: 1));
    expect(() => join(s), throwsStateError);
    final start = demoEvents.first.start(date);
    final end = demoEvents.first.end(start);
    expect(
      scheduleState(start, end, start.subtract(const Duration(seconds: 1))),
      'Sắp tới',
    );
    expect(scheduleState(start, end, start), 'Đang diễn ra');
    expect(scheduleState(start, end, end), 'Đã kết thúc');
  });
  test(
    'Registrations, check-in and empty optional phone survive restart',
    () async {
      var now = date;
      final store = TestSessionStore();
      final s = open(store: store, clock: () => now);
      await s.initialize();
      s.register('Email user', 'email@example.com', 'Test1234');
      s.updateContactPhone('0912345678');
      s.clearContactPhone();
      final p = join(s);
      now = p.start;
      s.demoCheckIn(p);
      expect(await s.flush(), isTrue);
      final restored = open(store: store, clock: () => now);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      expect(restored.contactPhone, '');
      expect(restored.participations.single.checkedIn, isTrue);
      expect(restored.participations.single.id, p.id);
    },
  );
  test('Old snapshots without participations remain readable', () async {
    final store = TestSessionStore();
    final s = open(store: store);
    await s.initialize();
    s.login(DemoSession.phone, DemoSession.password);
    await s.flush();
    final data = jsonDecode(store.value!) as Map<String, dynamic>;
    data.remove('participations');
    store.value = jsonEncode(data);
    final restored = open(store: store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(restored.participations, isEmpty);
    expect(restored.bookings.length, 2);
  });
  for (final corrupt in [
    'owner',
    'duplicate',
    'quantity',
    'capacity',
    'status',
  ]) {
    test(
      'Malformed participation $corrupt fails restore without overwriting store',
      () async {
        final store = TestSessionStore();
        final s = open(store: store);
        await s.initialize();
        s.login(DemoSession.phone, DemoSession.password);
        join(s);
        await s.flush();
        final data = jsonDecode(store.value!) as Map<String, dynamic>;
        final entries = data['participations'] as List<dynamic>;
        final p = entries.first as Map<String, dynamic>;
        switch (corrupt) {
          case 'owner':
            p['owner'] = 'unknown@example.com';
          case 'duplicate':
            entries.add(Map<String, dynamic>.from(p));
          case 'quantity':
            p['quantity'] = 0;
          case 'status':
            p['cancelled'] = true;
            p['checkedIn'] = true;
          case 'capacity':
            for (var i = 0; i < 12; i++) {
              (data['users'] as List).add({
                'name': 'User $i',
                'identifier': 'u$i@example.com',
                'password': 'Test1234',
              });
              entries.add({
                ...p,
                'id': 'VE${(i + 2).toString().padLeft(4, '0')}',
                'owner': 'u$i@example.com',
              });
            }
        }
        store.value = jsonEncode(data);
        final original = store.value;
        final restored = open(store: store);
        await restored.initialize();
        expect(restored.loadFailed, isTrue);
        expect(restored.initialized, isFalse);
        expect(store.value, original);
      },
    );
  }
  test('Retry failed save does not duplicate registration', () async {
    final store = TestSessionStore();
    final s = open(store: store);
    await s.initialize();
    s.login(DemoSession.phone, DemoSession.password);
    await s.flush();
    store.failWrite = true;
    join(s);
    expect(await s.flush(), isFalse);
    store.failWrite = false;
    await s.retrySave();
    expect(s.participations.length, 1);
    final restored = open(store: store);
    await restored.initialize();
    expect(restored.participations.length, 1);
  });
}
