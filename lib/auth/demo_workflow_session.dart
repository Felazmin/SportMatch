part of 'demo_session.dart';

typedef DemoWorkflowRecord = ({
  String id,
  String owner,
  String title,
  DateTime start,
  DateTime end,
  int total,
  bool cancelled,
  DemoAttendance attendance,
});

extension DemoWorkflowSession on DemoSession {
  DemoWorkflowRecord workflowRecord(String id) {
    final r = _rawWorkflowRecord(id);
    if (user == null ||
        (role == DemoRole.player && r.owner != user!.identifier)) {
      throw StateError('Không có quyền truy cập hồ sơ.');
    }
    return r;
  }

  DemoWorkflowRecord _rawWorkflowRecord(String id) {
    _requireReady();
    final b = _bookings.where((b) => b.id == id).firstOrNull;
    final p = _participations.where((p) => p.id == id).firstOrNull;
    final owner = b?.owner ?? p?.owner;
    if (owner == null) {
      throw StateError('Không có quyền truy cập hồ sơ.');
    }
    return (
      id: id,
      owner: owner,
      title: b == null ? p!.event.title : '${b.venueName} · Sân ${b.court}',
      start: b?.start ?? p!.start,
      end: b?.end ?? p!.event.end(p.start),
      total: b?.total ?? p!.total,
      cancelled: b?.cancelled ?? p!.cancelled,
      attendance: b?.attendance ?? p!.attendance,
    );
  }

  List<DemoWorkflowRecord> get managedAttendance {
    _requireManager();
    return [
      ..._bookings.map((b) => workflowRecord(b.id)),
      ..._participations.map((p) => workflowRecord(p.id)),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  List<DemoParticipation> get managedParticipations {
    _requireManager();
    return List.unmodifiable(_participations);
  }

  DemoPayment? workflowPayment(String id) {
    workflowRecord(id);
    return _payments[id];
  }

  List<DemoAuditEntry> workflowHistory(String id) {
    workflowRecord(id);
    final pattern = RegExp(r'\b' + RegExp.escape(id) + r'\b');
    return List.unmodifiable(
      _operations.audit.reversed.where(
        (entry) => pattern.hasMatch(entry.action),
      ),
    );
  }

  void _requireTicketOwner(DemoParticipation p) {
    final r = workflowRecord(p.id);
    if (!_participations.contains(p) ||
        role != DemoRole.player ||
        r.owner != user!.identifier) {
      throw StateError('Vui lòng dùng tài khoản đăng ký vé.');
    }
  }

  DemoPayment startTicketTransfer(DemoParticipation ticket) {
    _requireTicketOwner(ticket);
    expireSocialTickets();
    if (ticket.cancelled ||
        !(ticket.socialCheckout ? ticket.event.end(ticket.start) : ticket.start)
            .isAfter(now) ||
        ticket.attendance != DemoAttendance.pending) {
      throw StateError('Vé không còn khả dụng.');
    }
    final old = _payments[ticket.id];
    if (ticket.socialCheckout &&
        old != null &&
        old.expired(now) &&
        old.state != DemoPaymentState.rejected) {
      throw StateError('Đơn vé social đã hết hạn. Vui lòng chọn mua vé mới.');
    }
    if (old != null &&
        (!old.expired(now) ||
            old.cancellation == DemoCancellationState.requested)) {
      return old;
    }
    final deadline = now.add(
      Duration(minutes: ticket.socialCheckout ? 15 : 30),
    );
    final cutoff = ticket.socialCheckout
        ? ticket.event.end(ticket.start)
        : ticket.start;
    final p = ticket.socialCheckout && old?.state == DemoPaymentState.rejected
        ? DemoPayment.fromJson(
            Map<String, dynamic>.from(old!.toJson())
              ..['deadline'] = (deadline.isBefore(cutoff) ? deadline : cutoff)
                  .toIso8601String(),
          )
        : DemoPayment(
            bookingId: ticket.id,
            deadline: deadline.isBefore(cutoff) ? deadline : cutoff,
          );
    _payments[ticket.id] = p;
    _recordOperation('Mở chuyển khoản vé ${ticket.id}');
    return p;
  }

  DemoPayment payTournamentDemo(DemoParticipation ticket, String method) {
    _requireTicketOwner(ticket);
    if (ticket.cancelled ||
        ticket.event.kind != DemoEventKind.tournament ||
        ticket.registration == null ||
        !['qr', 'wallet', 'bank'].contains(method)) {
      throw StateError('Đăng ký không khả dụng cho thanh toán giải đấu demo.');
    }
    final old = _payments[ticket.id];
    if (old?.simulatedGateway == true &&
        old?.state == DemoPaymentState.approved) {
      return old!;
    }
    if (!ticket.start.isAfter(now) ||
        ticket.attendance != DemoAttendance.pending ||
        eventCancellation(ticket.eventId, ticket.start) != null ||
        old != null ||
        !eventOccurrenceExists(ticket.eventId, ticket.start)) {
      throw StateError(
        'Lịch hoặc trạng thái thanh toán đã thay đổi. Mở lại đăng ký.',
      );
    }
    final payment = DemoPayment(bookingId: ticket.id, deadline: ticket.start)
      ..simulatedGateway = true
      ..gatewayMethod = method
      ..state = DemoPaymentState.approved
      ..receivedAt = now
      ..reference = 'DEMO-${ticket.id}';
    _payments[ticket.id] = payment;
    _recordOperation('Thanh toán mô phỏng giải đấu ${ticket.id} · $method');
    return payment;
  }

  DemoPayment _editableTicket(DemoParticipation ticket) {
    _requireTicketOwner(ticket);
    final p = _payments[ticket.id];
    if (p == null ||
        ticket.cancelled ||
        !(ticket.socialCheckout ? ticket.event.end(ticket.start) : ticket.start)
            .isAfter(now) ||
        p.expired(now) ||
        p.cancellation == DemoCancellationState.requested ||
        (p.state != DemoPaymentState.awaitingProof &&
            p.state != DemoPaymentState.rejected)) {
      throw StateError('Vé chưa thể gửi minh chứng ở trạng thái này.');
    }
    return p;
  }

  void saveTicketProof(DemoParticipation ticket, Uint8List bytes) {
    _editableTicket(ticket).draft = encodeProof(bytes);
    _changed();
  }

  void submitTicketProof(DemoParticipation ticket, String reference) {
    final p = _editableTicket(ticket);
    if (p.draft.isEmpty ||
        reference.trim().length < 3 ||
        reference.trim().length > 80) {
      throw StateError('Chọn ảnh và nhập mã tham chiếu 3–80 ký tự.');
    }
    p.proof = p.draft;
    p.draft = '';
    p.reference = reference.trim();
    p.reviewNote = '';
    p.state = DemoPaymentState.pending;
    _recordOperation('Gửi minh chứng vé ${ticket.id}');
  }

  void reviewTicketPayment(
    DemoParticipation ticket, {
    required bool approve,
    String note = '',
    DateTime? receivedAt,
  }) {
    _requireManager();
    final r = workflowRecord(ticket.id);
    final p = _payments[ticket.id];
    if (!_participations.contains(ticket) ||
        r.cancelled ||
        p == null ||
        p.state != DemoPaymentState.pending ||
        p.cancellation == DemoCancellationState.requested ||
        (!approve && (note.trim().length < 5 || note.trim().length > 300))) {
      throw StateError('Không thể xử lý minh chứng vé.');
    }
    if (receivedAt != null &&
        (!approve || receivedAt.isAfter(now) || receivedAt.year < 2020)) {
      throw StateError('Ngày ghi nhận phải từ năm 2020 đến hiện tại.');
    }
    p.receivedAt = approve ? receivedAt ?? now : null;
    p.state = approve ? DemoPaymentState.approved : DemoPaymentState.rejected;
    p.reviewNote = approve ? '' : note.trim();
    _recordOperation(
      '${approve ? 'Duyệt' : 'Từ chối'} minh chứng ${ticket.id}',
    );
  }

  void requestTicketCancellation(DemoParticipation ticket, String reason) {
    _requireTicketOwner(ticket);
    expireSocialTickets();
    final p = _payments[ticket.id];
    if (p == null ||
        ticket.cancelled ||
        ticket.attendance != DemoAttendance.pending ||
        ticket.start.difference(now) < const Duration(hours: 24) ||
        p.cancellation == DemoCancellationState.requested ||
        reason.trim().length < 5 ||
        reason.trim().length > 300) {
      throw StateError(
        'Cần yêu cầu trước ít nhất 24 giờ, chưa check-in và nhập lý do hợp lệ.',
      );
    }
    p.cancellation = DemoCancellationState.requested;
    p.cancellationReason = reason.trim();
    p.cancellationRequestedAt = now;
    p.cancellationNote = '';
    _recordOperation('Yêu cầu hủy vé ${ticket.id}');
  }

  void reviewTicketCancellation(
    DemoParticipation ticket, {
    required bool approve,
    String note = '',
  }) {
    _requireManager();
    workflowRecord(ticket.id);
    final p = _payments[ticket.id];
    if (!_participations.contains(ticket) ||
        p == null ||
        ticket.cancelled ||
        ticket.attendance != DemoAttendance.pending ||
        p.cancellation != DemoCancellationState.requested ||
        (approve && !ticket.start.isAfter(now)) ||
        (!approve && (note.trim().length < 5 || note.trim().length > 300))) {
      throw StateError('Yêu cầu hủy không còn khả dụng.');
    }
    p.cancellation = approve
        ? DemoCancellationState.accepted
        : DemoCancellationState.rejected;
    p.cancellationNote = approve ? '' : note.trim();
    if (approve) {
      ticket.cancelled = true;
      if (p.state == DemoPaymentState.approved) {
        p.refund = DemoRefundState.pending;
        p.refundAmount = ticket.total;
      }
    }
    _recordOperation('${approve ? 'Duyệt' : 'Từ chối'} hủy ${ticket.id}');
  }

  void recordWorkflowRefund(String id, String reference, Uint8List proof) {
    _requireManager();
    final r = workflowRecord(id);
    final p = _payments[id];
    if (p == null ||
        !r.cancelled ||
        p.refund != DemoRefundState.pending ||
        reference.trim().length < 3 ||
        reference.trim().length > 80) {
      throw StateError('Khoản hoàn hoặc mã tham chiếu chưa hợp lệ.');
    }
    final encoded = encodeProof(proof);
    p.refundProof = encoded;
    p.refundReference = reference.trim();
    p.refundAmount ??= r.total;
    p.refund = DemoRefundState.recorded;
    p.refundRecordedAt = now;
    _recordOperation('Ghi nhận hoàn demo $id: ${p.refundAmount}');
  }

  String attendanceLabel(DemoAttendance value) => switch (value) {
    DemoAttendance.pending => 'Chưa check-in',
    DemoAttendance.checkedIn => 'Đã check-in',
    DemoAttendance.absent => 'Vắng mặt',
    DemoAttendance.completed => 'Đã hoàn thành',
  };

  DemoWorkflowRecord checkAttendanceCode(String input) {
    _requireManager();
    var id = input.trim();
    final uri = Uri.tryParse(id);
    if (uri != null && uri.scheme == 'nvh-demo') {
      if (uri.host != 'ticket' || uri.queryParameters['version'] != '1') {
        throw StateError('QR demo không hợp lệ.');
      }
      id = uri.queryParameters['id'] ?? '';
      final p = _participations.where((p) => p.id == id).firstOrNull;
      if (p == null || input.trim() != p.qrPayload) {
        throw StateError('QR không khớp với vé trên thiết bị.');
      }
    }
    return workflowRecord(id);
  }

  void setAttendance(String id, DemoAttendance next) {
    _requireManager();
    _applyAttendance(id, next);
  }

  void _applyAttendance(String id, DemoAttendance next) {
    final r = _rawWorkflowRecord(id);
    final p = _payments[id];
    if (r.cancelled ||
        r.attendance == DemoAttendance.completed ||
        r.attendance == DemoAttendance.absent ||
        p == null ||
        p.state != DemoPaymentState.approved ||
        p.cancellation == DemoCancellationState.requested) {
      throw StateError('Lịch phải được xác nhận thanh toán và không chờ hủy.');
    }
    final allowed = switch (next) {
      DemoAttendance.checkedIn =>
        r.attendance == DemoAttendance.pending &&
            !now.isBefore(r.start.subtract(const Duration(minutes: 30))) &&
            now.isBefore(r.end),
      DemoAttendance.absent =>
        r.attendance == DemoAttendance.pending && !now.isBefore(r.end),
      DemoAttendance.completed =>
        r.attendance == DemoAttendance.checkedIn && !now.isBefore(r.end),
      DemoAttendance.pending => false,
    };
    if (!allowed) {
      throw StateError('Thời gian hoặc trạng thái điểm danh không hợp lệ.');
    }
    final b = _bookings.where((b) => b.id == id).firstOrNull;
    if (b != null) {
      b.attendance = next;
    } else {
      final ticket = _participations.firstWhere((p) => p.id == id);
      ticket.attendance = next;
      ticket.checkedIn =
          next == DemoAttendance.checkedIn || next == DemoAttendance.completed;
    }
    _recordOperation('${attendanceLabel(next)} $id');
  }

  DemoDispute createTicketDispute(
    DemoParticipation ticket,
    String subject,
    String message,
  ) {
    _requireTicketOwner(ticket);
    if (_disputes.any(
      (d) => d.bookingId == ticket.id && d.resolution.isEmpty,
    )) {
      throw StateError('Vé đã có khiếu nại đang xử lý.');
    }
    final d = DemoDispute(
      id: 'KN${(_disputes.length + 1).toString().padLeft(4, '0')}',
      owner: ticket.owner,
      bookingId: ticket.id,
      subject: subject.trim(),
      message: message.trim(),
      created: now,
    );
    try {
      DemoDispute.fromJson(d.toJson());
    } on FormatException {
      throw StateError('Kiểm tra tiêu đề và nội dung 10–1.000 ký tự.');
    }
    _disputes.add(d);
    _changed();
    return d;
  }

  void attachDisputeEvidence(DemoDispute d, Uint8List bytes) {
    if (!disputes.contains(d) ||
        d.resolution.isNotEmpty ||
        role != DemoRole.player ||
        d.owner != user?.identifier) {
      throw StateError('Không thể bổ sung bằng chứng.');
    }
    d.evidence = encodeProof(bytes);
    _changed();
  }

  void decideDispute(
    DemoDispute d,
    DemoDisputeDecision decision,
    String explanation,
  ) {
    _requireAdmin();
    if (!_disputes.contains(d) ||
        d.resolution.isNotEmpty ||
        explanation.trim().length < 10 ||
        explanation.trim().length > 1000) {
      throw StateError('Quyết định hoặc nội dung chưa hợp lệ.');
    }
    final r = workflowRecord(d.bookingId);
    final p = _payments[r.id];
    if (decision == DemoDisputeDecision.refund) {
      if (p == null ||
          p.state != DemoPaymentState.approved ||
          p.refund == DemoRefundState.recorded ||
          r.attendance != DemoAttendance.pending) {
        throw StateError('Hồ sơ không đủ điều kiện hoàn tiền demo.');
      }
      final b = _bookings.where((b) => b.id == r.id).firstOrNull;
      if (b != null) {
        b.cancelled = true;
      } else {
        _participations.firstWhere((p) => p.id == r.id).cancelled = true;
      }
      p.cancellation = DemoCancellationState.accepted;
      if (p.cancellationReason.isEmpty) {
        p.cancellationReason = 'Theo quyết định khiếu nại ${d.id}';
      }
      p.refundAmount = r.total * (b != null ? 95 : 100) ~/ 100;
      p.refund = DemoRefundState.pending;
    }
    d.decision = decision;
    d.resolution = explanation.trim();
    _recordOperation('Quyết định ${d.id} / ${r.id}: ${decision.name}');
  }

  bool disputeReadyToClose(DemoDispute d) {
    if (!disputes.contains(d)) {
      throw StateError('Không có quyền xem khiếu nại này.');
    }
    if (d.closedAt != null || d.resolution.isEmpty || d.decision == null) {
      return false;
    }
    if (d.decision == DemoDisputeDecision.uphold) return true;
    final p = workflowPayment(d.bookingId);
    return p != null &&
        p.refund == DemoRefundState.recorded &&
        p.refundRecordedAt != null &&
        !p.refundRecordedAt!.isAfter(now) &&
        p.refundReference.isNotEmpty &&
        p.refundProof.isNotEmpty;
  }

  void closeDispute(DemoDispute d) {
    _requireAdmin();
    if (!disputeReadyToClose(d) || now.isBefore(d.created)) {
      throw StateError('Hồ sơ chưa đủ điều kiện đóng hoặc đã được đóng.');
    }
    d.closedAt = now;
    _recordOperation('Đóng khiếu nại ${d.id} / ${d.bookingId}');
  }
}
