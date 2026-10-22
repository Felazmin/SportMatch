import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final date = DateTime(2026, 10, 6, 10);
  final proof = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  DemoSession open({TestSessionStore? store, DateTime Function()? clock}) {
    final s = DemoSession(store: store, now: clock ?? () => date);
    addTearDown(s.dispose);
    return s;
  }

  DemoBooking reserve(DemoSession s) => s.reserve(
    court: 2,
    start: DateTime(2026, 10, 7, 12),
    hours: 1,
    contact: 'User',
    contactPhone: DemoSession.phone,
  );
  void buyer(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);
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
  void submit(DemoSession s, DemoBooking b) {
    s.startTransfer(b);
    s.saveProofDraft(b, proof);
    s.submitProof(b, 'DEMO-${b.id}');
  }

  test(
    'Staff requires dedicated login; normal registration cannot grant a role',
    () {
      final s = open();
      expect(s.login(DemoSession.ownerEmail, DemoSession.password), isFalse);
      expect(
        s.loginStaff(
          DemoRole.owner,
          DemoSession.adminEmail,
          DemoSession.password,
        ),
        isFalse,
      );
      expect(
        s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, 'wrong'),
        isFalse,
      );
      s.register('Ordinary user', DemoSession.ownerEmail, DemoSession.password);
      expect(s.role, DemoRole.player);
      expect(() => s.managedBookings, throwsStateError);
      owner(s);
      expect(s.role, DemoRole.owner);
      expect(s.displayIdentifier, DemoSession.ownerEmail);
      expect(() => s.managedUsers, throwsStateError);
      expect(() => reserve(s), throwsStateError);
      admin(s);
      expect(s.managedUsers.length, 2);
    },
  );
  test(
    'Payment review requires staff and owner can only access own invoice',
    () {
      final s = open();
      buyer(s);
      final b = reserve(s);
      submit(s, b);
      expect(() => s.reviewPayment(b, approve: true), throwsStateError);
      s.register('Other', 'other@example.com', 'Test1234');
      expect(() => s.paymentFor(b), throwsStateError);
      expect(() => s.submitProof(b, 'DEMO'), throwsStateError);
      owner(s);
      s.reviewPayment(b, approve: true);
      expect(s.paymentFor(b)!.state, DemoPaymentState.approved);
      expect(() => s.reviewPayment(b, approve: true), throwsStateError);
    },
  );
  test('Rejected evidence can be resubmitted before deadline; pending review does not expire', () {
    var now = date;
    final s = open(clock: () => now);
    buyer(s);
    final b = reserve(s);
    submit(s, b);
    owner(s);
    s.reviewPayment(b, approve: false, note: 'Ảnh chưa rõ thông tin');
    buyer(s);
    expect(s.paymentFor(b)!.state, DemoPaymentState.rejected);
    s.saveProofDraft(b, proof);
    s.submitProof(b, 'NEW-DEMO');
    now = date.add(const Duration(hours: 2));
    expect(s.paymentFor(b)!.expired(now), isFalse);
    owner(s);
    s.reviewPayment(b, approve: true);
    expect(s.paymentFor(b)!.state, DemoPaymentState.approved);
  });
  test(
    'Expiry rejects late submissions, new attempt obtains a new deadline',
    () {
      var now = date;
      final s = open(clock: () => now);
      buyer(s);
      final b = reserve(s);
      final first = s.startTransfer(b);
      s.saveProofDraft(b, proof);
      now = first.deadline;
      expect(() => s.submitProof(b, 'DEMO'), throwsStateError);
      expect(first.expired(now), isTrue);
      final second = s.startTransfer(b);
      expect(second.deadline.isAfter(first.deadline), isTrue);
      expect(second.draft, '');
    },
  );
  test('Cancellation pending/rejected retains slot; paid approval queues refund once', () {
    final s = open();
    buyer(s);
    final b = reserve(s);
    submit(s, b);
    owner(s);
    s.reviewPayment(b, approve: true);
    buyer(s);
    expect(s.cancel(b), isFalse);
    s.requestCancellation(b, 'Không tham gia được');
    expect(s.available(2, b.start, 1), isFalse);
    expect(() => s.requestCancellation(b, 'Again please'), throwsStateError);
    owner(s);
    s.reviewCancellation(b, approve: false, note: 'Cần xác nhận lại lý do');
    buyer(s);
    expect(b.cancelled, isFalse);
    s.requestCancellation(b, 'Tôi không đến được');
    owner(s);
    s.reviewCancellation(b, approve: true);
    expect(b.cancelled, isTrue);
    expect(s.available(2, b.start, 1), isTrue);
    expect(s.paymentFor(b)!.refund, DemoRefundState.pending);
    s.recordDemoRefund(b);
    expect(s.paymentFor(b)!.refund, DemoRefundState.recorded);
    expect(() => s.recordDemoRefund(b), throwsStateError);
  });
  test(
    'Unpaid cancellation has no invented refund; late approval rejected',
    () {
      var now = date;
      final s = open(clock: () => now);
      buyer(s);
      final b = reserve(s);
      s.startTransfer(b);
      s.requestCancellation(b, 'Không đến được');
      owner(s);
      now = b.start;
      expect(() => s.reviewCancellation(b, approve: true), throwsStateError);
      s.reviewCancellation(b, approve: false, note: 'Lịch đã bắt đầu');
      expect(b.cancelled, isFalse);
    },
  );
  test(
    'Empty, invalid or oversized images and short reference do not submit',
    () {
      final s = open();
      buyer(s);
      final b = reserve(s);
      s.startTransfer(b);
      expect(() => s.saveProofDraft(b, Uint8List(0)), throwsFormatException);
      expect(
        () => s.saveProofDraft(b, Uint8List(maxProofBytes + 1)),
        throwsFormatException,
      );
      expect(
        () => s.saveProofDraft(b, Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      expect(() => s.submitProof(b, 'DEMO'), throwsStateError);
      s.saveProofDraft(b, proof);
      expect(() => s.submitProof(b, 'a'), throwsStateError);
      expect(s.paymentFor(b)!.state, DemoPaymentState.awaitingProof);
    },
  );
  test(
    'Disputes link bookings; owner responds, only admin records resolution',
    () {
      final s = open();
      buyer(s);
      final b = reserve(s);
      final d = s.createDispute(
        b,
        'Lịch đặt',
        'Cần hỗ trợ lịch đặt thử nghiệm',
      );
      expect(
        () => s.createDispute(b, 'Duplicate', 'Another dispute body'),
        throwsStateError,
      );
      expect(() => s.respondToDispute(d, 'Player response'), throwsStateError);
      s.register('Other', 'other@example.com', 'Test1234');
      expect(s.disputes, isEmpty);
      expect(
        () => s.createDispute(b, 'Other', 'Other account content'),
        throwsStateError,
      );
      owner(s);
      s.respondToDispute(d, 'Chủ sân đã kiểm tra lịch đặt');
      expect(
        () => s.respondToDispute(d, 'Không đủ quyền', resolve: true),
        throwsStateError,
      );
      admin(s);
      s.respondToDispute(d, 'Đã xử lý trên dữ liệu demo', resolve: true);
      expect(
        () => s.respondToDispute(d, 'Cannot reopen case'),
        throwsStateError,
      );
      buyer(s);
      expect(s.disputes.single.resolution, isNotEmpty);
    },
  );
  test('Staff credential/profile, payment proof, draft target and dispute survive restart', () async {
    final store = TestSessionStore();
    final s = open(store: store);
    await s.initialize();
    buyer(s);
    final b = reserve(s);
    submit(s, b);
    s.createDispute(b, 'Test', 'Nội dung khiếu nại demo');
    owner(s);
    s.reviewPayment(b, approve: true);
    s.updateName('Chủ sân mới');
    expect(s.changePassword(DemoSession.password, 'Owner12345'), isTrue);
    await s.flush();
    final restored = open(store: store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(restored.role, DemoRole.owner);
    expect(restored.user!.name, 'Chủ sân mới');
    expect(restored.managedBookings.length, 3);
    expect(
      restored
          .paymentFor(
            restored.managedBookings.singleWhere((item) => item.id == b.id),
          )!
          .proof,
      encodeProof(proof),
    );
    expect(restored.disputes.length, 1);
    expect(
      restored.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      ),
      isFalse,
    );
    expect(
      restored.loginStaff(DemoRole.owner, DemoSession.ownerEmail, 'Owner12345'),
      isTrue,
    );
  });
  test('Proof picker target and draft persisted separately from submitted evidence', () async {
    final store = TestSessionStore();
    final s = open(store: store);
    await s.initialize();
    buyer(s);
    final b = reserve(s);
    s.startTransfer(b);
    s.setProofPickerTarget(b);
    await s.flush();
    final next = open(store: store);
    await next.initialize();
    expect(next.proofPickerBooking!.id, b.id);
    next.saveProofDraft(next.proofPickerBooking!, proof);
    expect(next.proofPickerBooking, isNull);
    await next.flush();
    final third = open(store: store);
    await third.initialize();
    final p = third.paymentFor(
      third.bookings.singleWhere((item) => item.id == b.id),
    )!;
    expect(p.draft, isNotEmpty);
    expect(p.proof, '');
    expect(p.state, DemoPaymentState.awaitingProof);
  });
  for (final corruption in [
    'staff',
    'target',
    'refund',
    'duplicate',
    'dispute',
  ]) {
    test(
      'Invalid $corruption snapshot fails atomically without overwriting',
      () async {
        final store = TestSessionStore();
        final s = open(store: store);
        await s.initialize();
        buyer(s);
        final b = reserve(s);
        submit(s, b);
        s.createDispute(b, 'Test', 'Test complaint content');
        await s.flush();
        final data = jsonDecode(store.value!) as Map<String, dynamic>;
        final p = (data['payments'] as List).first as Map<String, dynamic>;
        switch (corruption) {
          case 'staff':
            data['staff'] = {
              'unknown': {'name': 'Admin', 'password': 'Demo1234'},
            };
          case 'target':
            p['bookingId'] = 'NVH9999';
          case 'refund':
            p['refund'] = 'recorded';
          case 'duplicate':
            (data['payments'] as List).add(Map<String, dynamic>.from(p));
          case 'dispute':
            ((data['disputes'] as List).first
                    as Map<String, dynamic>)['owner'] =
                'unknown@example.com';
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
  test(
    'Previous snapshots load with no finance data and safe staff defaults',
    () async {
      final store = TestSessionStore();
      final s = open(store: store);
      await s.initialize();
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      for (final key in [
        'staff',
        'payments',
        'disputes',
        'proofPickerTarget',
      ]) {
        data.remove(key);
      }
      store.value = jsonEncode(data);
      final restored = open(store: store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      expect(
        restored.loginStaff(
          DemoRole.owner,
          DemoSession.ownerEmail,
          DemoSession.password,
        ),
        isTrue,
      );
      expect(restored.managedBookings.length, 2);
    },
  );
}
