part of 'demo_session.dart';

extension DemoSocialSession on DemoSession {
  bool _socialReservationExpired(DemoParticipation ticket) {
    final payment = _payments[ticket.id];
    return ticket.socialCheckout &&
        !ticket.cancelled &&
        ticket.attendance == DemoAttendance.pending &&
        payment != null &&
        payment.state == DemoPaymentState.awaitingProof &&
        payment.proof.isEmpty &&
        !now.isBefore(payment.deadline);
  }

  int expireSocialTickets() {
    if (!initialized) return 0;
    final expired = _participations.where(_socialReservationExpired).toList();
    for (final ticket in expired) {
      ticket.cancelled = true;
      final payment = _payments[ticket.id]!;
      payment.cancellation = DemoCancellationState.accepted;
      payment.cancellationReason = 'Tự hủy vé social do hết hạn gửi chứng từ.';
      payment.cancellationNote =
          'Đã trả chỗ; không có giao dịch hoàn tiền tự động.';
      _operations.audit.add(
        DemoAuditEntry(
          actor: '__system__',
          action:
              'Tự hủy vé social hết hạn ${ticket.id}; trả ${ticket.quantity} chỗ',
          created: now,
        ),
      );
      if (_operations.audit.length > 1000) _operations.audit.removeAt(0);
    }
    if (expired.isNotEmpty) _changed();
    return expired.length;
  }
}
