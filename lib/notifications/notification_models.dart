class InboxNotice {
  const InboxNotice({
    required this.id,
    required this.owner,
    required this.bookingId,
    required this.kind,
    required this.title,
    required this.body,
    required this.created,
    this.scheduled,
    this.readAt,
  });
  final int id;
  final String owner, bookingId, kind, title, body;
  final DateTime created;
  final DateTime? scheduled, readAt;
  bool due(DateTime now) => scheduled == null || !scheduled!.isAfter(now);
  factory InboxNotice.fromMap(Map<String, Object?> m) => InboxNotice(
    id: m['id'] as int,
    owner: m['owner'] as String,
    bookingId: m['bookingId'] as String,
    kind: m['kind'] as String,
    title: m['title'] as String,
    body: m['body'] as String,
    created: _date(m['created'] as int),
    scheduled: m['scheduled'] == null ? null : _date(m['scheduled'] as int),
    readAt: m['readAt'] == null ? null : _date(m['readAt'] as int),
  );
  static DateTime _date(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
}

class ReminderPreferences {
  const ReminderPreferences({this.enabled = false, this.minutes = 60});
  final bool enabled;
  final int minutes;
  static const leadTimes = [1, 15, 30, 60];
}

class BookingNoticeState {
  const BookingNoticeState({
    required this.id,
    required this.venue,
    required this.court,
    required this.start,
    required this.hours,
    required this.revision,
    required this.confirmed,
    required this.cancelled,
    required this.suppressed,
  });
  final String id, venue;
  final int court, hours, revision;
  final DateTime start;
  final bool confirmed, cancelled, suppressed;
  String get fingerprint =>
      '${start.millisecondsSinceEpoch}:$court:$hours:$revision';
}
