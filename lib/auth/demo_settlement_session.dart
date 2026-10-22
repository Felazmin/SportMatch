part of 'demo_session.dart';

extension DemoSettlementSession on DemoSession {
  DemoCashflowReport cashflowReport({
    required DateTime from,
    required DateTime to,
    String facilityId = '*',
    bool? onsite,
    bool? tickets,
  }) {
    _requireManager();
    final first = bookingDay(from), last = bookingDay(to);
    if (first.isAfter(last) ||
        last.difference(first).inDays > 365 ||
        ![
          '*',
          '',
          'EVENTS',
          ...managedFacilities.map((f) => f.id),
        ].contains(facilityId)) {
      throw ArgumentError('Invalid cashflow filters');
    }
    final entries = <DemoCashflowEntry>[];
    var pendingRefund = 0, undatedPayments = 0;
    bool inside(DateTime d) =>
        !bookingDay(d).isBefore(first) && !bookingDay(d).isAfter(last);
    for (final r in managedAttendance) {
      final p = _payments[r.id];
      if (p == null ||
          p.state != DemoPaymentState.approved ||
          (onsite != null && p.atVenue != onsite) ||
          (tickets != null && r.id.startsWith('VE') != tickets)) {
        continue;
      }
      final b = _bookings.where((b) => b.id == r.id).firstOrNull;
      final venue = b?.facilityId ?? 'EVENTS';
      if (facilityId != '*' && venue != facilityId) continue;
      if (p.refund == DemoRefundState.pending) {
        pendingRefund += refundForReport(p, r.total);
      }
      if (p.receivedAt == null) {
        undatedPayments++;
      } else if (inside(p.receivedAt!)) {
        entries.add(
          DemoCashflowEntry(
            id: r.id,
            title: r.title,
            facilityId: venue,
            date: p.receivedAt!,
            amount: r.total,
            refund: false,
            onsite: p.atVenue,
          ),
        );
      }
      if (p.refund == DemoRefundState.recorded &&
          p.refundRecordedAt != null &&
          inside(p.refundRecordedAt!)) {
        entries.add(
          DemoCashflowEntry(
            id: r.id,
            title: r.title,
            facilityId: venue,
            date: p.refundRecordedAt!,
            amount: refundForReport(p, r.total),
            refund: true,
            onsite: p.atVenue,
          ),
        );
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return DemoCashflowReport(
      entries: entries,
      from: first,
      to: last,
      pendingRefund: pendingRefund,
      undatedPayments: undatedPayments,
    );
  }

  DemoSettlementReport settlementReport({
    DateTime? from,
    DateTime? to,
    int basisPoints = 300,
    bool? onsite,
    bool? tickets,
  }) {
    _requireManager();
    if ((from == null) != (to == null) ||
        (from != null && bookingDay(from).isAfter(bookingDay(to!)))) {
      throw ArgumentError('Invalid service date range');
    }
    final rows = <DemoSettlementRow>[];
    for (final record in managedAttendance) {
      final p = _payments[record.id];
      if (p == null ||
          p.state != DemoPaymentState.approved ||
          (onsite != null && p.atVenue != onsite) ||
          (tickets != null && record.id.startsWith('VE') != tickets) ||
          (from != null &&
              (bookingDay(record.start).isBefore(bookingDay(from)) ||
                  bookingDay(record.start).isAfter(bookingDay(to!))))) {
        continue;
      }
      final booking = _bookings.where((b) => b.id == record.id).firstOrNull;
      final refund = refundForReport(p, record.total);
      rows.add(
        DemoSettlementRow(
          id: record.id,
          title: record.title,
          date: record.start,
          gross: booking?.subtotal ?? record.total,
          discount: booking?.discount ?? 0,
          paid: record.total,
          pendingRefund: p.refund == DemoRefundState.pending ? refund : 0,
          recordedRefund: p.refund == DemoRefundState.recorded ? refund : 0,
          onsite: p.atVenue,
          held:
              p.cancellation == DemoCancellationState.requested ||
              _disputes.any(
                (d) => d.bookingId == record.id && d.resolution.isEmpty,
              ),
        ),
      );
    }
    return DemoSettlementReport(rows, basisPoints: basisPoints);
  }
}
