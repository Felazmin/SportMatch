part of 'demo_session.dart';

extension DemoManagement on DemoSession {
  CancellationPolicy get primaryCancellationPolicy {
    _requireReady();
    return _primaryCancellationPolicy;
  }

  int get primaryCancellationRevision {
    _requireReady();
    return _primaryCancellationRevision;
  }

  void setPrimaryCancellationPolicy(
    CancellationPolicy policy, {
    required int expectedRevision,
    required String password,
  }) {
    _requireAdmin();
    if (_primaryCancellationRevision != expectedRevision) {
      throw StateError('Chính sách đã thay đổi. Mở lại màn hình.');
    }
    _verifyAdminConfirmation(password);
    _primaryCancellationPolicy = policy;
    _primaryCancellationRevision++;
    _recordOperation(
      'Cập nhật chính sách hủy sân chính v$_primaryCancellationRevision',
    );
  }

  DemoRole get role => user?.role ?? DemoRole.player;
  String get displayIdentifier => role == DemoRole.owner
      ? DemoSession.ownerEmail
      : role == DemoRole.admin
      ? DemoSession.adminEmail
      : user?.identifier ?? '';
  void _requireManager() {
    _requireReady();
    if (user == null || role == DemoRole.player) {
      throw StateError('Chỉ Chủ sân hoặc Admin được thực hiện.');
    }
  }

  List<DemoBooking> get managedBookings {
    _requireManager();
    return List.unmodifiable(
      [..._bookings]..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  List<DemoUser> get managedUsers {
    _requireManager();
    if (role != DemoRole.admin) {
      throw StateError('Chỉ Admin được xem danh sách tài khoản.');
    }
    return List.unmodifiable([
      _demoUser,
      ..._registered.values.map((r) => r.user),
    ]);
  }

  DemoPayment? paymentFor(DemoBooking booking) {
    _requireReady();
    if (user == null ||
        !_bookings.contains(booking) ||
        (role == DemoRole.player && booking.owner != user!.identifier)) {
      throw StateError('Không có quyền xem thanh toán.');
    }
    return _payments[booking.id];
  }

  void _requireBookingOwner(DemoBooking booking) {
    _requireReady();
    if (user == null ||
        role != DemoRole.player ||
        !_bookings.contains(booking) ||
        booking.owner != user!.identifier) {
      throw StateError('Vui lòng đăng nhập đúng tài khoản đặt sân.');
    }
  }

  DemoPayment startTransfer(
    DemoBooking booking, {
    bool checkout = false,
    String customerNote = '',
  }) {
    _requireBookingOwner(booking);
    if (customerNote.trim().length > 300) {
      throw StateError('Ghi chú tối đa 300 ký tự.');
    }
    if (booking.cancelled || !booking.start.isAfter(now)) {
      throw StateError('Lịch không còn khả dụng.');
    }
    final old = _payments[booking.id];
    if (old != null &&
        (!old.expired(now) ||
            old.cancellation == DemoCancellationState.requested)) {
      return old;
    }
    final useCheckout = checkout || (old?.checkout ?? false);
    final limit = now.add(Duration(minutes: useCheckout ? 15 : 30));
    final p =
        DemoPayment(
            bookingId: booking.id,
            deadline: limit.isBefore(booking.start) ? limit : booking.start,
          )
          ..checkout = useCheckout
          ..customerNote = old?.customerNote ?? customerNote.trim();
    _payments[booking.id] = p;
    _changed();
    return p;
  }

  void setProofPickerTarget(DemoBooking booking) {
    _requireBookingOwner(booking);
    final p = _payments[booking.id];
    if (p == null ||
        booking.cancelled ||
        p.expired(now) ||
        p.state == DemoPaymentState.pending ||
        p.state == DemoPaymentState.approved ||
        p.cancellation == DemoCancellationState.requested) {
      throw StateError('Chưa thể chọn minh chứng ở trạng thái này.');
    }
    _proofPickerTarget = booking.id;
    _changed();
  }

  DemoBooking? get proofPickerBooking => _bookings
      .where((b) => b.id == _proofPickerTarget && b.owner == user?.identifier)
      .firstOrNull;
  void clearProofPickerTarget() {
    _requireReady();
    _proofPickerTarget = null;
    _changed();
  }

  void saveProofDraft(DemoBooking booking, Uint8List bytes) {
    _requireBookingOwner(booking);
    final p = paymentFor(booking);
    if (p == null ||
        p.expired(now) ||
        booking.cancelled ||
        p.state == DemoPaymentState.pending ||
        p.state == DemoPaymentState.approved ||
        p.cancellation == DemoCancellationState.requested) {
      throw StateError('Không thể gắn minh chứng.');
    }
    p.draft = encodeProof(bytes);
    _proofPickerTarget = null;
    _changed();
  }

  void saveStudentDraft(DemoBooking booking, Uint8List bytes) {
    _requireBookingOwner(booking);
    final p = paymentFor(booking);
    if (p == null ||
        !p.checkout ||
        p.expired(now) ||
        booking.cancelled ||
        !booking.start.isAfter(now) ||
        p.cancellation == DemoCancellationState.requested ||
        (p.state != DemoPaymentState.awaitingProof &&
            p.state != DemoPaymentState.rejected)) {
      throw StateError('Không thể gắn thẻ học sinh / sinh viên.');
    }
    p.studentDraft = encodeProof(bytes);
    _changed();
  }

  void submitProof(DemoBooking booking, String reference) {
    _requireBookingOwner(booking);
    final p = paymentFor(booking);
    if (p == null ||
        booking.cancelled ||
        p.expired(now) ||
        p.cancellation == DemoCancellationState.requested ||
        (p.state != DemoPaymentState.awaitingProof &&
            p.state != DemoPaymentState.rejected) ||
        p.draft.isEmpty ||
        (p.checkout && p.studentDraft.isEmpty) ||
        reference.trim().length < 3 ||
        reference.trim().length > 80) {
      throw StateError('Kiểm tra ảnh, mã tham chiếu và thời hạn gửi.');
    }
    p.proof = p.draft;
    p.draft = '';
    if (p.checkout) {
      p.studentProof = p.studentDraft;
      p.studentDraft = '';
    }
    p.reference = reference.trim();
    p.state = DemoPaymentState.pending;
    p.reviewNote = '';
    _changed();
  }

  void reviewPayment(
    DemoBooking booking, {
    required bool approve,
    String note = '',
    DateTime? receivedAt,
  }) {
    _requireManager();
    final p = paymentFor(booking);
    if (p == null ||
        p.state != DemoPaymentState.pending ||
        booking.cancelled ||
        p.cancellation == DemoCancellationState.requested ||
        (!approve && (note.trim().length < 5 || note.trim().length > 300))) {
      throw StateError('Không thể xử lý minh chứng ở trạng thái này.');
    }
    if (receivedAt != null &&
        (!approve || receivedAt.isAfter(now) || receivedAt.year < 2020)) {
      throw StateError('Ngày ghi nhận phải từ năm 2020 đến hiện tại.');
    }
    p.receivedAt = approve ? receivedAt ?? now : null;
    p.state = approve ? DemoPaymentState.approved : DemoPaymentState.rejected;
    p.reviewNote = approve ? '' : note.trim();
    _recordOperation(
      '${approve ? 'Duyệt' : 'Từ chối'} minh chứng ${booking.id}',
    );
  }

  int bookingCancellationMinimumHours(DemoBooking booking) {
    final minimum = booking.cancellationPolicy.minimumHours;
    return paymentFor(booking)?.checkout == true && minimum < 2 ? 2 : minimum;
  }

  DateTime bookingCancellationDeadline(DemoBooking booking) => booking.start
      .subtract(Duration(hours: bookingCancellationMinimumHours(booking)));

  bool canRequestBookingCancellation(DemoBooking booking) {
    final p = paymentFor(booking);
    return p != null &&
        !booking.cancelled &&
        booking.start.isAfter(now) &&
        booking.attendance == DemoAttendance.pending &&
        !now.isAfter(bookingCancellationDeadline(booking)) &&
        p.cancellation != DemoCancellationState.requested;
  }

  int estimatedBookingRefund(DemoBooking booking, {DateTime? requestedAt}) =>
      paymentFor(booking)?.state != DemoPaymentState.approved
      ? 0
      : booking.cancellationPolicy.refundAmount(
          booking.total,
          booking.start,
          requestedAt ?? now,
        );

  void sendBookingMessage(DemoBooking booking, String text) {
    _requireBookingOwner(booking);
    final p = paymentFor(booking);
    if (p == null ||
        text.trim().length < 5 ||
        text.trim().length > 500 ||
        p.customerMessages.length >= 20) {
      throw StateError(
        'Tin nhắn cần 5–500 ký tự; tối đa 20 tin cho một lịch đặt.',
      );
    }
    p.customerMessages = List.unmodifiable([
      ...p.customerMessages,
      DemoBookingMessage(text.trim(), now),
    ]);
    _recordOperation('Khách nhắn chủ sân về lịch ${booking.id}');
  }

  void requestCancellation(
    DemoBooking booking,
    String reason, {
    DemoRefundDestination? destination,
    bool acceptFee = false,
    int? quotedRefund,
  }) {
    _requireBookingOwner(booking);
    final p = paymentFor(booking);
    if (p == null ||
        booking.cancelled ||
        booking.attendance != DemoAttendance.pending ||
        !canRequestBookingCancellation(booking) ||
        p.cancellation == DemoCancellationState.requested ||
        reason.trim().length < 5 ||
        reason.trim().length > 300) {
      throw StateError('Kiểm tra lý do và thời gian yêu cầu hủy.');
    }
    final estimate = estimatedBookingRefund(booking);
    if (quotedRefund != null && quotedRefund != estimate) {
      throw StateError(
        'Số tiền dự kiến đã thay đổi. Mở lại yêu cầu hủy để xác nhận.',
      );
    }
    if (p.checkout &&
        p.state == DemoPaymentState.approved &&
        estimate > 0 &&
        destination == null) {
      throw StateError('Chọn thông tin nhận hoàn tiền.');
    }
    if (p.checkout &&
        p.state == DemoPaymentState.approved &&
        estimate < booking.total &&
        !acceptFee) {
      throw StateError('Xác nhận phí hủy trước khi gửi.');
    }
    destination?.validate();
    p.cancellation = DemoCancellationState.requested;
    p.cancellationReason = reason.trim();
    p.cancellationRequestedAt = now;
    p.cancellationNote = '';
    p.refundDestination = destination;
    p.cancellationEstimate = estimate;
    _recordOperation('Yêu cầu hủy ${booking.id}');
  }

  void reviewCancellation(
    DemoBooking booking, {
    required bool approve,
    String note = '',
  }) {
    _requireManager();
    final p = paymentFor(booking);
    if (p == null ||
        p.cancellation != DemoCancellationState.requested ||
        booking.cancelled ||
        booking.attendance != DemoAttendance.pending ||
        (approve && !booking.start.isAfter(now)) ||
        (!approve && (note.trim().length < 5 || note.trim().length > 300))) {
      throw StateError('Không thể xử lý yêu cầu hủy.');
    }
    p.cancellation = approve
        ? DemoCancellationState.accepted
        : DemoCancellationState.rejected;
    p.cancellationNote = approve ? '' : note.trim();
    if (approve) {
      booking.cancelled = true;
      if (p.state == DemoPaymentState.approved) {
        p.refund = DemoRefundState.pending;
        p.refundAmount = booking.cancellationPolicy.refundAmount(
          booking.total,
          booking.start,
          p.cancellationRequestedAt ?? now,
        );
      }
    }
    _recordOperation('${approve ? 'Duyệt' : 'Từ chối'} hủy ${booking.id}');
  }

  void recordDemoRefund(DemoBooking booking) {
    _requireManager();
    final p = paymentFor(booking);
    if (p == null ||
        p.refund != DemoRefundState.pending ||
        !booking.cancelled) {
      throw StateError('Không có khoản hoàn chờ ghi nhận.');
    }
    p.refund = DemoRefundState.recorded;
    p.refundRecordedAt = now;
    _recordOperation('Ghi nhận hoàn demo ${booking.id}');
  }

  List<DemoDispute> get disputes => List.unmodifiable(
    _disputes
        .where(
          (d) =>
              user != null &&
              (role != DemoRole.player || d.owner == user!.identifier),
        )
        .toList()
      ..sort((a, b) => b.created.compareTo(a.created)),
  );
  DemoDispute createDispute(
    DemoBooking booking,
    String subject,
    String message,
  ) {
    _requireBookingOwner(booking);
    if (disputes.any(
      (d) => d.bookingId == booking.id && d.resolution.isEmpty,
    )) {
      throw StateError('Đã có khiếu nại đang xử lý cho lịch này.');
    }
    final d = DemoDispute(
      id: 'KN${(_disputes.length + 1).toString().padLeft(4, '0')}',
      owner: user!.identifier,
      bookingId: booking.id,
      subject: subject.trim(),
      message: message.trim(),
      created: now,
    );
    try {
      DemoDispute.fromJson(d.toJson());
    } on FormatException {
      throw StateError('Tiêu đề tối đa 80 ký tự, nội dung 10–1.000 ký tự.');
    }
    _disputes.add(d);
    _changed();
    return d;
  }

  void respondToDispute(
    DemoDispute dispute,
    String text, {
    bool resolve = false,
  }) {
    _requireManager();
    if (!_disputes.contains(dispute) ||
        dispute.resolution.isNotEmpty ||
        (resolve && role != DemoRole.admin) ||
        text.trim().length < 10 ||
        text.trim().length > 1000) {
      throw StateError('Không có quyền xử lý hoặc nội dung chưa hợp lệ.');
    }
    if (resolve) {
      dispute.resolution = text.trim();
    } else {
      dispute.response = text.trim();
    }
    _changed();
  }
}
