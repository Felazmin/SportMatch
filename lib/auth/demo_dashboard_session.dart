part of 'demo_session.dart';

typedef DemoDayOverview = ({
  DateTime day,
  int capacity,
  int reserved,
  int blocked,
  int confirmedValue,
  List<DemoBooking> bookings,
});

extension DemoDashboardSession on DemoSession {
  DemoSystemOverview systemOverview({
    required DateTime from,
    required DateTime to,
  }) {
    _requireAdmin();
    final cashflow = cashflowReport(from: from, to: to);
    final records = managedAttendance.where((r) {
      final day = bookingDay(r.start);
      return !day.isBefore(cashflow.from) && !day.isAfter(cashflow.to);
    }).toList();
    final users = managedUsers;
    final pendingPayments = _payments.values.where(
      (p) =>
          p.state == DemoPaymentState.pending &&
          p.cancellation != DemoCancellationState.requested &&
          p.cancellation != DemoCancellationState.accepted,
    );
    return (
      cashflow: cashflow,
      players: users.length,
      owners: _staff.values.where((a) => a.user.role == DemoRole.owner).length,
      verifiedOwners: _ownerVerification?.state == 'verified' ? 1 : 0,
      blockedPlayers: users
          .where((u) => _operations.blocked.contains(u.identifier))
          .length,
      publicFacilities:
          1 +
          _facilities.where((f) => f.published != null && !f.suspended).length,
      pendingFacilities: _facilities.where((f) => f.state == 'pending').length,
      publicGroups: publicGroups.length,
      pendingGroups: _playGroups.where((g) => g.state == 'pending').length,
      pendingActivities: _activities.where((a) => a.state == 'pending').length,
      bookings: records
          .where((r) => !r.id.startsWith('VE') && !r.cancelled)
          .length,
      tickets: records
          .where((r) => r.id.startsWith('VE') && !r.cancelled)
          .length,
      cancelled: records.where((r) => r.cancelled).length,
      pendingProofs: pendingPayments.length,
      pendingCancellations: _payments.values
          .where((p) => p.cancellation == DemoCancellationState.requested)
          .length,
      openDisputes: _disputes.where((d) => d.closedAt == null).length,
    );
  }

  DemoDayOverview dayOverview(DateTime date, {String facilityId = ''}) {
    _requireManager();
    final facility = facilityId.isEmpty
        ? null
        : managedFacilities
              .where((f) => f.id == facilityId && f.published != null)
              .firstOrNull;
    if (facilityId.isNotEmpty && facility == null) {
      throw StateError('Không có cơ sở được quản lý.');
    }
    final profile = facility?.published;
    final day = bookingDay(date);
    if (date.isUtc ||
        day.isBefore(bookingDay(now)) ||
        day.isAfter(bookingDay(now).add(const Duration(days: 6)))) {
      throw StateError('Chọn ngày trong 7 ngày hiện tại.');
    }
    final records =
        _bookings
            .where(
              (b) =>
                  b.facilityId == facilityId &&
                  !b.cancelled &&
                  bookingDay(b.start) == day,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    var capacity = 0, reserved = 0, blocked = 0;
    // Count the same hourly cells as the calendar, not payment or visit counts.
    for (var court = 1; court <= (profile?.courtCount ?? 3); court++) {
      if ((profile == null && !_operations.published.enabled[court - 1]) ||
          (facility?.suspended ?? false)) {
        continue;
      }
      for (
        var hour = profile?.openHour ?? 6;
        hour < (profile?.closeHour ?? 22);
        hour++
      ) {
        capacity++;
        final start = day.add(Duration(hours: hour));
        final end = start.add(const Duration(hours: 1));
        if (records.any(
          (b) =>
              b.court == court && b.start.isBefore(end) && b.end.isAfter(start),
        )) {
          reserved++;
        } else if (_courtBlocks.any(
          (b) =>
              b.facilityId == facilityId &&
              b.court == court &&
              b.start.isBefore(end) &&
              b.end.isAfter(start),
        )) {
          blocked++;
        }
      }
    }
    return (
      day: day,
      capacity: capacity,
      reserved: reserved,
      blocked: blocked,
      confirmedValue: records
          .where((b) => _payments[b.id]?.state == DemoPaymentState.approved)
          .fold<int>(0, (sum, b) => sum + b.total),
      bookings: List.unmodifiable(records),
    );
  }

  DemoDayOverview allFacilitiesOverview(DateTime date) {
    _requireManager();
    final days = [
      dayOverview(date),
      for (final f in managedFacilities.where((f) => f.published != null))
        dayOverview(date, facilityId: f.id),
    ];
    return (
      day: bookingDay(date),
      capacity: days.fold<int>(0, (sum, d) => sum + d.capacity),
      reserved: days.fold<int>(0, (sum, d) => sum + d.reserved),
      blocked: days.fold<int>(0, (sum, d) => sum + d.blocked),
      confirmedValue: days.fold<int>(0, (sum, d) => sum + d.confirmedValue),
      bookings: List.unmodifiable(
        days.expand((d) => d.bookings).toList()
          ..sort((a, b) => a.start.compareTo(b.start)),
      ),
    );
  }
}

typedef DemoSystemOverview = ({
  DemoCashflowReport cashflow,
  int players,
  int owners,
  int verifiedOwners,
  int blockedPlayers,
  int publicFacilities,
  int pendingFacilities,
  int publicGroups,
  int pendingGroups,
  int pendingActivities,
  int bookings,
  int tickets,
  int cancelled,
  int pendingProofs,
  int pendingCancellations,
  int openDisputes,
});
