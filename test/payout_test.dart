import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'multi_facility_test.dart' show sampleFacilityProof;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 8, 10));
  DemoSession open([TestSessionStore? store]) {
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
  void bank(DemoSession s, {int revision = 0, String number = '0012345678'}) =>
      s.savePayoutAccount(
        'Ngân hàng demo',
        'NGUYEN MINH PHAT',
        number,
        expectedRevision: revision,
        password: DemoSession.password,
      );
  DemoBooking earnings(DemoSession s, {bool onsite = false}) {
    s.login(DemoSession.phone, DemoSession.password);
    final b = s.reserve(
      court: 2,
      start: DateTime(2026, 10, 9, 12),
      hours: 1,
      contact: 'Người thử',
      contactPhone: DemoSession.phone,
    );
    if (!onsite) {
      s.startTransfer(b);
      s.saveProofDraft(b, base64Decode(sampleFacilityProof));
      s.submitProof(b, 'BOOK-12345');
    }
    owner(s);
    if (onsite) {
      s.confirmVenuePayment(b);
    } else {
      s.reviewPayment(b, approve: true);
    }
    return b;
  }

  void ready(DemoSession s) {
    earnings(s);
    now = DateTime(2026, 10, 9, 13);
    bank(s);
  }

  String request(DemoSession s, int amount) => s
      .requestPayout(
        amount,
        expectedBalance: s.payoutBalance,
        expectedAccountRevision: s.payoutAccount!.revision,
        password: DemoSession.password,
      )
      .id;
  void record(DemoSession s, String id, {String reference = 'PAY-12345'}) =>
      s.reviewPayout(
        id,
        0,
        approve: true,
        password: DemoSession.password,
        reference: reference,
        proof: sampleFacilityProof,
      );
  test('Only ended transfer earnings fund requests; onsite/future payments excluded', () {
    final s = open();
    earnings(s);
    expect(s.payoutBalance, 0);
    now = DateTime(2026, 10, 9, 13);
    expect(s.payoutBalance, 116400);
    final other = open();
    now = DateTime(2026, 10, 8, 10);
    earnings(other, onsite: true);
    now = DateTime(2026, 10, 9, 13);
    expect(other.payoutBalance, 0);
  });
  test('Owner account confirmation, validation and role guards', () {
    final s = open();
    expect(() => s.payouts, throwsStateError);
    owner(s);
    expect(() => bank(s, number: 'abc'), throwsStateError);
    expect(s.payoutAccount, isNull);
    bank(s);
    expect(s.payoutAccount!.number, '0012345678');
    expect(() => bank(s), throwsStateError);
    admin(s);
    expect(() => bank(s, revision: 1), throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.payoutBalance, throwsStateError);
  });
  test('Requests reserve balance, overdraw/stale rejected, receipts immutable and no double recording', () {
    final s = open();
    ready(s);
    final id = request(s, 100000);
    expect(s.payoutBalance, 16400);
    expect(() => request(s, 20000), throwsStateError);
    expect(s.payouts.length, 1);
    bank(s, revision: 1, number: '9988776655');
    expect(s.payouts.single.account.number, '0012345678');
    expect(() => record(s, id), throwsStateError);
    admin(s);
    record(s, id);
    expect(s.payoutBalance, 16400);
    expect(s.payouts.single.state, 'recorded');
    expect(() => record(s, id), throwsStateError);
    expect(() => s.payouts.clear(), throwsUnsupportedError);
  });
  test(
    'Rejection releases balance; missing evidence/short reason rejected',
    () {
      final s = open();
      ready(s);
      final id = request(s, 100000);
      admin(s);
      expect(
        () => s.reviewPayout(
          id,
          0,
          approve: true,
          password: DemoSession.password,
          reference: 'REF-12345',
        ),
        throwsStateError,
      );
      expect(
        () => s.reviewPayout(
          id,
          0,
          approve: false,
          password: DemoSession.password,
          note: 'no',
        ),
        throwsStateError,
      );
      s.reviewPayout(
        id,
        0,
        approve: false,
        password: DemoSession.password,
        note: 'Chứng từ cần kiểm tra',
      );
      expect(s.payoutBalance, 116400);
      expect(s.payouts.single.state, 'rejected');
    },
  );
  test('New dispute holds earnings and blocks recording reserved payout', () {
    final s = open();
    final b = earnings(s);
    now = DateTime(2026, 10, 9, 13);
    bank(s);
    final id = request(s, 100000);
    s.login(DemoSession.phone, DemoSession.password);
    s.createDispute(
      b,
      'Kiểm tra thanh toán',
      'Đề nghị kiểm tra lại thanh toán.',
    );
    admin(s);
    expect(s.payoutBalance, -100000);
    expect(() => record(s, id), throwsStateError);
    s.reviewPayout(
      id,
      0,
      approve: false,
      password: DemoSession.password,
      note: 'Có tranh chấp đang xử lý',
    );
    expect(s.payoutBalance, 0);
  });
  test('Receipt reference duplicates cannot approve twice', () {
    final s = open();
    ready(s);
    final first = request(s, 40000), second = request(s, 40000);
    admin(s);
    record(s, first);
    expect(() => record(s, second), throwsStateError);
    record(s, second, reference: 'PAY-67890');
    expect(s.payoutBalance, 36400);
  });
  test('Save retry/restoration preserve bank snapshot and ledger', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    ready(s);
    final id = request(s, 100000);
    admin(s);
    store.failWrite = true;
    record(s, id);
    expect(await s.flush(), false);
    store.failWrite = false;
    s.retrySave();
    expect(await s.flush(), true);
    final next = open(store);
    await next.initialize();
    expect(next.loadFailed, false);
    expect(next.payoutBalance, 16400);
    expect(next.payouts.single.reference, 'PAY-12345');
    expect(next.payoutAccount!.number, '0012345678');
  });
  test('Admin password confirmation locks after five failures and expires', () {
    final s = open();
    ready(s);
    final id = request(s, 100000);
    admin(s);
    for (var i = 0; i < 5; i++) {
      expect(
        () => s.reviewPayout(
          id,
          0,
          approve: true,
          password: 'wrong',
          reference: 'PAY-12345',
          proof: sampleFacilityProof,
        ),
        throwsStateError,
      );
    }
    expect(() => record(s, id), throwsStateError);
    expect(s.payouts.single.state, 'pending');
    now = now.add(const Duration(seconds: 60));
    record(s, id);
    expect(s.payouts.single.state, 'recorded');
  });
  for (final field in ['amount', 'proof', 'nextPayout']) {
    test('Corrupt $field rejected atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      ready(s);
      final id = request(s, 100000);
      admin(s);
      record(s, id);
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      if (field == 'nextPayout') {
        j[field] = 1;
      } else {
        j['payouts'][0][field] = field == 'amount' ? -1 : 'invalid';
      }
      store.value = jsonEncode(j);
      final next = open(store);
      await next.initialize();
      expect(next.loadFailed, true);
      expect(next.user, isNull);
    });
  }
}
