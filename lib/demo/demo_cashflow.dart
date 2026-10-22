import '../booking/demo_booking.dart';

class DemoCashflowEntry {
  const DemoCashflowEntry({
    required this.id,
    required this.title,
    required this.facilityId,
    required this.date,
    required this.amount,
    required this.refund,
    required this.onsite,
  });
  final String id, title, facilityId;
  final DateTime date;
  final int amount;
  final bool refund, onsite;
}

class DemoCashflowReport {
  DemoCashflowReport({
    required Iterable<DemoCashflowEntry> entries,
    required this.from,
    required this.to,
    required this.pendingRefund,
    required this.undatedPayments,
  }) : entries = List.unmodifiable(entries) {
    if (from != bookingDay(from) ||
        to != bookingDay(to) ||
        from.isAfter(to) ||
        to.difference(from).inDays > 365 ||
        pendingRefund < 0 ||
        undatedPayments < 0 ||
        this.entries.map((e) => '${e.id}:${e.refund}').toSet().length !=
            this.entries.length ||
        this.entries.any(
          (e) =>
              e.amount < 0 ||
              bookingDay(e.date).isBefore(from) ||
              bookingDay(e.date).isAfter(to),
        )) {
      throw const FormatException('Invalid cashflow report');
    }
  }
  final List<DemoCashflowEntry> entries;
  final DateTime from, to;
  final int pendingRefund, undatedPayments;
  int get received =>
      entries.where((e) => !e.refund).fold(0, (sum, e) => sum + e.amount);
  int get refunded =>
      entries.where((e) => e.refund).fold(0, (sum, e) => sum + e.amount);
  int get onsite => entries
      .where((e) => !e.refund && e.onsite)
      .fold(0, (sum, e) => sum + e.amount);
  int get balance => received - refunded;
  Map<DateTime, int> daily({bool refund = false}) {
    final result = <DateTime, int>{};
    for (
      var d = from;
      !d.isAfter(to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      result[d] = 0;
    }
    for (final e in entries.where((e) => e.refund == refund)) {
      final day = bookingDay(e.date);
      result[day] = result[day]! + e.amount;
    }
    return Map.unmodifiable(result);
  }

  Map<String, int> get byFacility {
    final result = <String, int>{};
    for (final e in entries.where((e) => !e.refund)) {
      result[e.facilityId] = (result[e.facilityId] ?? 0) + e.amount;
    }
    return Map.unmodifiable(result);
  }

  String csv() {
    String cell(Object value) {
      var text = '$value';
      if (RegExp(r'^\s*[=+@-]').hasMatch(text)) {
        text = "'$text";
      }
      return '"${text.replaceAll('"', '""')}"';
    }

    return [
      [
        'id',
        'recorded_date',
        'facility_id',
        'title',
        'kind',
        'channel',
        'amount',
      ],
      for (final e in entries)
        [
          e.id,
          e.date.toIso8601String(),
          e.facilityId,
          e.title,
          e.refund ? 'refund' : 'payment',
          e.onsite ? 'onsite' : 'transfer',
          e.amount,
        ],
    ].map((r) => r.map(cell).join(',')).join('\r\n');
  }
}
