part of 'demo_session.dart';

extension DemoCalendarSession on DemoSession {
  List<DemoCourtBlock> get courtBlocks {
    _requireManager();
    return List.unmodifiable(_courtBlocks);
  }

  List<DemoUser> get calendarCustomers {
    _requireManager();
    return List.unmodifiable(
      [
        _demoUser,
        ..._registered.values.map((r) => r.user),
      ].where((u) => !_operations.blocked.contains(u.identifier)),
    );
  }

  bool _calendarRange(DateTime start, int hours) =>
      start.isAfter(now) &&
      !bookingDay(start).isBefore(bookingDay(now)) &&
      !bookingDay(start)
          .isAfter(bookingDay(now).add(const Duration(days: 6))) &&
      start == bookingDay(start).add(Duration(hours: start.hour)) &&
      hours >= 1 &&
      start.hour >= 6 &&
      start.hour + hours <= 22;

  DemoCourtBlock blockCourt({
    required int court,
    required DateTime start,
    required int hours,
    required String reason,
    String facilityId = '',
  }) {
    _requireManager();
    final profile = facilityId.isEmpty ? null : _bookableFacility(facilityId);
    if (facilityId.isNotEmpty && profile == null) {
      throw StateError('Cơ sở chưa công bố hoặc đang tạm ngưng.');
    }
    if (_courtBlocks.length >= 500 ||
        court < 1 ||
        court > (profile?.courtCount ?? 3) ||
        (profile == null
            ? !_calendarRange(start, hours)
            : start.isUtc ||
                  !start.isAfter(now) ||
                  bookingDay(start)
                      .isAfter(bookingDay(now).add(const Duration(days: 6))) ||
                  start != bookingDay(start).add(Duration(hours: start.hour)) ||
                  hours < 1 ||
                  start.hour < profile.openHour ||
                  start.hour + hours > profile.closeHour)) {
      throw StateError('Kiểm tra sân và khung giờ trong 7 ngày.');
    }
    final b = DemoCourtBlock(
      id: 'KB${_nextBlock.toString().padLeft(4, '0')}',
      court: court,
      start: start,
      hours: hours,
      reason: reason.trim(),
      facilityId: facilityId,
      courtCount: profile?.courtCount ?? 3,
      openHour: profile?.openHour ?? 6,
      closeHour: profile?.closeHour ?? 22,
    );
    try {
      DemoCourtBlock.fromJson(b.toJson());
    } on FormatException {
      throw StateError('Lý do khóa cần 5–300 ký tự.');
    }
    if (_bookings.any(
          (r) =>
              !r.cancelled &&
              r.facilityId == facilityId &&
              r.court == court &&
              start.isBefore(r.end) &&
              b.end.isAfter(r.start),
        ) ||
        _courtBlocks.any(
          (r) =>
              r.facilityId == facilityId &&
              r.court == court &&
              start.isBefore(r.end) &&
              b.end.isAfter(r.start),
        )) {
      throw StateError('Khung giờ đang có lịch hoặc đã khóa.');
    }
    _courtBlocks.add(b);
    _nextBlock++;
    _recordOperation(
      'Khóa Sân $court ${bookingDate(start)} ${bookingTime(start)} / ${b.id}',
    );
    return b;
  }

  void unblockCourt(DemoCourtBlock block) {
    _requireManager();
    if (block.eventId.isNotEmpty) {
      throw StateError(
        'Đổi sân trong hồ sơ hoạt động, không mở khóa riêng lẻ.',
      );
    }
    if (!_courtBlocks.contains(block)) {
      throw StateError('Khung khóa không còn tồn tại.');
    }
    _courtBlocks.remove(block);
    _recordOperation('Mở khóa ${block.id}');
  }

  DemoBooking manualReservation({
    required String customer,
    required int court,
    required DateTime start,
    required int hours,
    required String contact,
    required String contactPhone,
    required int quotedRate,
    List<int>? quotedRates,
    String facilityId = '',
  }) {
    _requireManager();
    final profile = facilityId.isEmpty ? null : _bookableFacility(facilityId);
    if (!calendarCustomers.any((u) => u.identifier == customer) ||
        !available(court, start, hours, facilityId: facilityId) ||
        quotedRate !=
            bookingRates(court, start, hours, facilityId: facilityId).first) {
      throw StateError('Khách hàng, giá hoặc khung giờ đã thay đổi.');
    }
    final rates = bookingRates(court, start, hours, facilityId: facilityId);
    if (quotedRates != null &&
        (quotedRates.length != rates.length ||
            Iterable.generate(rates.length)
                .any((i) => quotedRates[i] != rates[i]))) {
      throw StateError('Giá khung giờ đã thay đổi. Chọn lại lịch.');
    }
    final b = DemoBooking(
      id: 'NVH${(_bookings.length + 1).toString().padLeft(4, '0')}',
      owner: customer,
      facilityId: facilityId,
      venueName: profile?.name ?? DemoBooking.venue,
      venueAddress: profile == null
          ? DemoBooking.address
          : '${profile.address}, ${profile.district}, ${profile.city}',
      sport: profile?.sport ?? 'Cầu lông',
      venueCourtCount: profile?.courtCount ?? 3,
      venueOpenHour: profile?.openHour ?? 6,
      venueCloseHour: profile?.closeHour ?? 22,
      cancellationPolicy:
          profile?.cancellationPolicy ?? _primaryCancellationPolicy,
      court: court,
      start: start,
      hours: hours,
      contact: contact.trim(),
      phone: DemoSession.normalize(contactPhone),
      rate: quotedRate,
      hourlyRates: rates,
    );
    try {
      DemoBooking.fromJson(b.toJson());
    } on FormatException {
      throw StateError('Kiểm tra tên và số điện thoại liên hệ.');
    }
    if (b.contact.length > 60) throw StateError('Tên tối đa 60 ký tự.');
    _bookings.add(b);
    _recordOperation('Đặt thủ công ${b.id}');
    return b;
  }

  void rescheduleBooking(
    DemoBooking booking, {
    required int court,
    required DateTime start,
    required int expectedRevision,
  }) {
    _requireManager();
    final p = _payments[booking.id];
    if (!_bookings.contains(booking) ||
        booking.revision != expectedRevision ||
        booking.cancelled ||
        booking.attendance != DemoAttendance.pending ||
        !booking.start.isAfter(now) ||
        (p != null &&
            (p.state != DemoPaymentState.approved ||
                p.cancellation == DemoCancellationState.requested ||
                p.refund != DemoRefundState.none))) {
      throw StateError('Lịch đã thay đổi hoặc đang chờ xử lý thanh toán/hủy.');
    }
    if (court == booking.court && start == booking.start) {
      throw StateError('Chọn sân hoặc giờ mới.');
    }
    if (court > booking.venueCourtCount ||
        start.hour < booking.venueOpenHour ||
        start.hour + booking.hours > booking.venueCloseHour ||
        !_slotAvailable(
          court,
          start,
          booking.hours,
          facilityId: booking.facilityId,
          excluding: booking,
        )) {
      throw StateError('Khung giờ mới không còn khả dụng.');
    }
    final old =
        'Sân ${booking.court} ${bookingDate(booking.start)} ${bookingTime(booking.start)}';
    booking.court = court;
    booking.start = start;
    booking.revision++;
    _recordOperation(
      'Đổi lịch ${booking.id}: $old → Sân $court ${bookingDate(start)} ${bookingTime(start)}; giữ nguyên số tiền',
    );
  }

  void confirmVenuePayment(DemoBooking booking) {
    _requireManager();
    _applyVenuePayment(booking);
  }

  void _applyVenuePayment(DemoBooking booking) {
    if (!_bookings.contains(booking) ||
        booking.cancelled ||
        booking.attendance != DemoAttendance.pending ||
        !now.isBefore(booking.end) ||
        _payments.containsKey(booking.id)) {
      throw StateError('Lịch chưa thể xác nhận thanh toán tại sân.');
    }
    _payments[booking.id] =
        DemoPayment(bookingId: booking.id, deadline: booking.start)
          ..atVenue = true
          ..receivedAt = now
          ..state = DemoPaymentState.approved
          ..reference = 'ONSITE-${booking.id}';
    _recordOperation('Xác nhận thanh toán tại sân demo ${booking.id}');
  }
}
