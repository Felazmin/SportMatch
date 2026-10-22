import '../booking/demo_booking.dart';
import 'demo_finance.dart';

class DemoSettlementRow {
  const DemoSettlementRow({
    required this.id,
    required this.title,
    required this.date,
    required this.gross,
    required this.discount,
    required this.paid,
    required this.pendingRefund,
    required this.recordedRefund,
    required this.onsite,
    required this.held,
  });
  final String id, title;
  final DateTime date;
  final int gross, discount, paid, pendingRefund, recordedRefund;
  final bool onsite, held;
  int get retained => paid - pendingRefund - recordedRefund;
  int get cashBalance => paid - recordedRefund;
  int fee(int basisPoints) => onsite ? 0 : retained * basisPoints ~/ 10000;
  int net(int basisPoints) => retained - fee(basisPoints);
}

class DemoSettlementReport {
  DemoSettlementReport(
    Iterable<DemoSettlementRow> rows, {
    this.basisPoints = 300,
  }) : rows = List.unmodifiable(rows) {
    if (basisPoints < 0 ||
        basisPoints > 1000 ||
        this.rows.map((r) => r.id).toSet().length != this.rows.length ||
        this.rows.any(
          (r) =>
              r.gross < 0 ||
              r.discount < 0 ||
              r.gross - r.discount != r.paid ||
              r.pendingRefund < 0 ||
              r.recordedRefund < 0 ||
              r.pendingRefund + r.recordedRefund > r.paid,
        )) {
      throw const FormatException('Invalid settlement report');
    }
  }
  final List<DemoSettlementRow> rows;
  final int basisPoints;
  int sum(int Function(DemoSettlementRow) value) =>
      rows.fold(0, (a, b) => a + value(b));
  int get gross => sum((r) => r.gross);
  int get discount => sum((r) => r.discount);
  int get paid => sum((r) => r.paid);
  int get pendingRefund => sum((r) => r.pendingRefund);
  int get recordedRefund => sum((r) => r.recordedRefund);
  int get retained => sum((r) => r.retained);
  int get fees => sum((r) => r.fee(basisPoints));
  int get net => sum((r) => r.net(basisPoints));
  int get onsite => sum((r) => r.onsite ? r.retained : 0);
  int get held => sum((r) => r.held ? r.net(basisPoints) : 0);
  Map<DateTime, int> get dailyNet {
    final days = <DateTime, int>{};
    for (final r in rows) {
      final d = bookingDay(r.date);
      days[d] = (days[d] ?? 0) + r.net(basisPoints);
    }
    return Map.unmodifiable(days);
  }

  String csv() {
    String cell(Object value) {
      var s = value.toString();
      if (RegExp(r'^\s*[=+@-]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    return [
      [
        'id',
        'service_date',
        'title',
        'channel',
        'gross',
        'discount',
        'confirmed',
        'refund_pending',
        'refund_recorded',
        'fee_demo',
        'net_estimate',
        'review_hold',
        'fee_basis_points',
      ],
      for (final r in rows)
        [
          r.id,
          bookingDay(r.date).toIso8601String().substring(0, 10),
          r.title,
          r.onsite ? 'onsite' : 'transfer',
          r.gross,
          r.discount,
          r.paid,
          r.pendingRefund,
          r.recordedRefund,
          r.fee(basisPoints),
          r.net(basisPoints),
          r.held ? 'yes' : 'no',
          basisPoints,
        ],
    ].map((row) => row.map(cell).join(',')).join('\r\n');
  }
}

int refundForReport(DemoPayment p, int total) =>
    p.refund == DemoRefundState.none ? 0 : p.refundAmount ?? total;
