import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_cashflow.dart';
import '../demo/demo_finance.dart';
import '../demo/demo_settlement.dart';

String adminReportRegion(String city) => switch (city.trim()) {
  'TP.HCM' ||
  'TP. HCM' ||
  'Hồ Chí Minh' ||
  'TP. Hồ Chí Minh' => 'TP. Hồ Chí Minh',
  _ => city.trim(),
};

class AdminReportData {
  AdminReportData._({
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.sport,
    required this.region,
    required this.cashflow,
    required this.totalBookings,
    required this.confirmed,
    required this.cancelled,
    required this.bySport,
    required this.byRegion,
    required this.newUsers,
    required this.totalUsers,
    required this.undatedUsers,
    required this.returningUsers,
    required this.bookingUsers,
    required this.refundRequests,
    required this.pendingRefundCount,
    required this.pendingRefundAmount,
    required this.cancellationReasons,
    required this.undatedRefunds,
  });

  factory AdminReportData.fromSession(
    DemoSession s, {
    required DateTime from,
    required DateTime to,
    String? sport,
    String? region,
  }) {
    // systemOverview enforces Admin access before any report data is read.
    final overview = s.systemOverview(from: from, to: to);
    final first = bookingDay(from), last = bookingDay(to);
    bool inside(DateTime date) =>
        !bookingDay(date).isBefore(first) && !bookingDay(date).isAfter(last);
    final facilities = {
      for (final f in s.managedFacilities) f.id: f.published ?? f.draft,
    };
    final bookings = s.managedBookings;
    final meta = <String, ({String sport, String region})>{
      for (final b in bookings)
        b.id: (
          sport: b.sport,
          region: b.facilityId.isEmpty
              ? 'TP. Hồ Chí Minh'
              : adminReportRegion(
                  facilities[b.facilityId]?.city ?? 'Chưa xác định',
                ),
        ),
      for (final p in s.managedParticipations)
        p.id: (sport: 'Môn khác', region: 'Chưa xác định'),
    };
    bool matches(String id) =>
        meta.containsKey(id) &&
        (sport == null || meta[id]!.sport == sport) &&
        (region == null || meta[id]!.region == region);
    final entries = overview.cashflow.entries
        .where((e) => matches(e.id))
        .toList();
    final selected = bookings
        .where((b) => inside(b.start) && matches(b.id))
        .toList();
    final active = selected.where((b) => !b.cancelled).toList();
    final sports = <String, int>{}, regions = <String, int>{};
    for (final b in active) {
      sports.update(b.sport, (n) => n + 1, ifAbsent: () => 1);
      regions.update(meta[b.id]!.region, (n) => n + 1, ifAbsent: () => 1);
    }
    final owners = active.map((b) => b.owner).toSet();
    final returning = owners
        .where(
          (owner) => bookings.any(
            (b) =>
                !b.cancelled &&
                b.owner == owner &&
                matches(b.id) &&
                bookingDay(b.start).isBefore(first),
          ),
        )
        .length;
    var pendingCount = 0,
        pendingAmount = 0,
        requestCount = 0,
        undatedRefunds = 0;
    final reasons = <String, int>{};
    for (final record in s.managedAttendance.where((r) => matches(r.id))) {
      final p = s.workflowPayment(record.id);
      if (p == null) continue;
      if (p.refund != DemoRefundState.none &&
          p.cancellationRequestedAt == null) {
        undatedRefunds++;
      }
      if (p.cancellationRequestedAt == null ||
          !inside(p.cancellationRequestedAt!)) {
        continue;
      }
      if (p.cancellationReason.trim().isNotEmpty) {
        reasons.update(
          p.cancellationReason.trim(),
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }
      if (p.state == DemoPaymentState.approved &&
          p.cancellation != DemoCancellationState.none) {
        requestCount++;
      }
      if (p.refund == DemoRefundState.pending) {
        pendingCount++;
        pendingAmount += refundForReport(p, record.total);
      }
    }
    final users = s.managedUsers;
    final growth = <DateTime, int>{};
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      growth[d] = 0;
    }
    for (final u in users.where(
      (u) => u.registeredAt != null && inside(u.registeredAt!),
    )) {
      growth.update(bookingDay(u.registeredAt!), (n) => n + 1);
    }
    return AdminReportData._(
      from: first,
      to: last,
      generatedAt: s.now,
      sport: sport,
      region: region,
      cashflow: DemoCashflowReport(
        entries: entries,
        from: first,
        to: last,
        pendingRefund: pendingAmount,
        undatedPayments: s.managedAttendance
            .where(
              (r) =>
                  matches(r.id) &&
                  s.workflowPayment(r.id)?.state == DemoPaymentState.approved &&
                  s.workflowPayment(r.id)?.receivedAt == null,
            )
            .length,
      ),
      totalBookings: selected.length,
      confirmed: active
          .where((b) => s.paymentFor(b)?.state == DemoPaymentState.approved)
          .length,
      cancelled: selected.where((b) => b.cancelled).length,
      bySport: Map.unmodifiable(sports),
      byRegion: Map.unmodifiable(regions),
      newUsers: Map.unmodifiable(growth),
      totalUsers: users.length,
      undatedUsers: users.where((u) => u.registeredAt == null).length,
      returningUsers: returning,
      bookingUsers: owners.length,
      refundRequests: requestCount,
      pendingRefundCount: pendingCount,
      pendingRefundAmount: pendingAmount,
      cancellationReasons: Map.unmodifiable(reasons),
      undatedRefunds: undatedRefunds,
    );
  }

  final DateTime from, to, generatedAt;
  final String? sport, region;
  final DemoCashflowReport cashflow;
  final int totalBookings, confirmed, cancelled;
  final Map<String, int> bySport, byRegion, cancellationReasons;
  final Map<DateTime, int> newUsers;
  final int totalUsers, undatedUsers, returningUsers, bookingUsers;
  final int refundRequests,
      pendingRefundCount,
      pendingRefundAmount,
      undatedRefunds;
  int get unconfirmed => totalBookings - confirmed - cancelled;
  int get newUserCount => newUsers.values.fold(0, (sum, n) => sum + n);
  int get recordedRefundCount => cashflow.entries.where((e) => e.refund).length;
  String get scope =>
      '${sport ?? 'Tất cả môn'} · ${region ?? 'Tất cả khu vực'}';
  String percent(int n, int total) =>
      total == 0 ? '0%' : '${(100 * n / total).toStringAsFixed(1)}%';

  List<List<Object>> rows() => [
    ['Báo cáo hệ thống', bookingDate(from), bookingDate(to)],
    ['Phạm vi', scope],
    ['Thời điểm', generatedAt.toIso8601String()],
    ['Giá trị giao dịch', cashflow.received],
    ['Hoàn trong kỳ', cashflow.refunded],
    ['Sau hoàn tiền', cashflow.balance],
    ['Phí nền tảng thực thu', 'Chưa có dữ liệu'],
    ['Tổng lượt đặt', totalBookings],
    ['Đã xác nhận', confirmed],
    ['Đã hủy', cancelled],
    ['Chưa xác nhận', unconfirmed],
    ['Yêu cầu hoàn theo ngày yêu cầu', refundRequests],
    ['Đã hoàn theo ngày ghi nhận', recordedRefundCount, cashflow.refunded],
    ['Chờ hoàn theo ngày yêu cầu', pendingRefundCount, pendingRefundAmount],
    for (final e in cancellationReasons.entries) ['Lý do hủy', e.key, e.value],
    for (final e in bySport.entries) ['Đặt sân theo môn', e.key, e.value],
    for (final e in byRegion.entries)
      ['Đặt sân theo khu vực hiện tại', e.key, e.value],
    ['Người dùng mới toàn hệ thống', newUserCount],
    ['Tài khoản chưa có ngày đăng ký', undatedUsers],
    ['Tổng tài khoản hiện tại', totalUsers],
    ['Khách quay lại / Khách đặt trong kỳ', returningUsers, bookingUsers],
    for (final e in newUsers.entries)
      ['Người dùng mới theo ngày', bookingDate(e.key), e.value],
    for (final e in cashflow.daily().entries)
      ['Giá trị giao dịch theo ngày', bookingDate(e.key), e.value],
  ];

  String csv() {
    String cell(Object value) {
      var text = '$value';
      if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    return '\uFEFF${rows().map((row) => row.map(cell).join(',')).join('\r\n')}';
  }
}
