import '../booking/demo_booking.dart';

class DemoCourtBlock {
  const DemoCourtBlock({
    required this.id,
    required this.court,
    required this.start,
    required this.hours,
    required this.reason,
    this.facilityId = '',
    this.courtCount = 3,
    this.openHour = 6,
    this.closeHour = 22,
    this.eventId = '',
  });
  final String id;
  final int court, hours;
  final DateTime start;
  final String reason;
  final String facilityId;
  final String eventId;
  final int courtCount, openHour, closeHour;
  DateTime get end => start.add(Duration(hours: hours));
  Map<String, Object?> toJson() => {
    'id': id,
    'court': court,
    'start': start.toIso8601String(),
    'hours': hours,
    'reason': reason,
    'facilityId': facilityId,
    'courtCount': courtCount,
    'openHour': openHour,
    'closeHour': closeHour,
    'eventId': eventId,
  };
  factory DemoCourtBlock.fromJson(Map<String, dynamic> j) {
    final b = DemoCourtBlock(
      id: j['id'] as String,
      court: j['court'] as int,
      start: DateTime.parse(j['start'] as String).toLocal(),
      hours: j['hours'] as int,
      reason: j['reason'] as String,
      facilityId: (j['facilityId'] ?? '') as String,
      courtCount: (j['courtCount'] ?? 3) as int,
      openHour: (j['openHour'] ?? 6) as int,
      closeHour: (j['closeHour'] ?? 22) as int,
      eventId: (j['eventId'] ?? '') as String,
    );
    if ((b.eventId.isNotEmpty &&
            (b.facilityId.isNotEmpty ||
                !RegExp(
                  r'^(HD\d{4,}|social-evening|social-morning|tournament-doubles)$',
                ).hasMatch(b.eventId))) ||
        !RegExp(r'^KB\d{4,}$').hasMatch(b.id) ||
        b.court < 1 ||
        b.courtCount < 1 ||
        b.courtCount > 20 ||
        b.court > b.courtCount ||
        b.openHour < 0 ||
        b.closeHour > 24 ||
        b.openHour >= b.closeHour ||
        (b.facilityId.isEmpty &&
            (b.courtCount != 3 || b.openHour != 6 || b.closeHour != 22)) ||
        (b.facilityId.isNotEmpty &&
            !RegExp(r'^CS\d{4,}$').hasMatch(b.facilityId)) ||
        b.hours < 1 ||
        b.hours > (b.facilityId.isEmpty ? 16 : 24) ||
        b.start.isUtc ||
        b.start != bookingDay(b.start).add(Duration(hours: b.start.hour)) ||
        b.start.hour < b.openHour ||
        b.start.hour + b.hours > b.closeHour ||
        b.reason.trim().length < 5 ||
        b.reason.length > 300) {
      throw const FormatException('Invalid court block');
    }
    return b;
  }
}
