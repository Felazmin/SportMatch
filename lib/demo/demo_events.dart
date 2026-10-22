import '../booking/demo_booking.dart';
import 'demo_finance.dart';

enum DemoEventKind { social, tournament }

class DemoEventCancellation {
  const DemoEventCancellation({
    required this.eventId,
    required this.start,
    required this.created,
    required this.actor,
    required this.reason,
  });
  final String eventId, actor, reason;
  final DateTime start, created;
  String get key => '$eventId:${start.toIso8601String()}';
  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'start': start.toIso8601String(),
    'created': created.toIso8601String(),
    'actor': actor,
    'reason': reason,
  };
  factory DemoEventCancellation.fromJson(Map<String, dynamic> j) {
    final c = DemoEventCancellation(
      eventId: j['eventId'] as String,
      start: DateTime.parse(j['start'] as String),
      created: DateTime.parse(j['created'] as String),
      actor: j['actor'] as String,
      reason: j['reason'] as String,
    );
    final event = demoEvents.where((e) => e.id == c.eventId).firstOrNull;
    if (event == null ||
        c.start.isUtc ||
        c.created.isUtc ||
        c.start.year < 2020 ||
        c.start.year > 2100 ||
        c.start != bookingDay(c.start).add(Duration(hours: event.hour)) ||
        !c.created.isBefore(c.start) ||
        !['__owner__', '__admin__'].contains(c.actor) ||
        c.reason != c.reason.trim() ||
        c.reason.length < 5 ||
        c.reason.length > 300) {
      throw const FormatException('Invalid event cancellation');
    }
    return c;
  }
}

class DemoEvent {
  const DemoEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.hour,
    required this.durationMinutes,
    required this.capacity,
    required this.fee,
    required this.description,
    this.scheduledStart,
  });
  final String id;
  final String title;
  final DemoEventKind kind;
  final int hour;
  final int durationMinutes;
  final int capacity;
  final int fee;
  final String description;
  final DateTime? scheduledStart;
  DateTime start(DateTime now) =>
      scheduledStart ?? bookingDay(now).add(Duration(days: 2, hours: hour));
  DateTime end(DateTime start) => start.add(Duration(minutes: durationMinutes));
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'hour': hour,
    'durationMinutes': durationMinutes,
    'capacity': capacity,
    'fee': fee,
    'description': description,
    'scheduledStart': scheduledStart?.toIso8601String(),
  };
  factory DemoEvent.fromJson(Map<String, dynamic> j) {
    final e = DemoEvent(
      id: j['id'] as String,
      title: j['title'] as String,
      kind: DemoEventKind.values.byName(j['kind'] as String),
      hour: j['hour'] as int,
      durationMinutes: j['durationMinutes'] as int,
      capacity: j['capacity'] as int,
      fee: j['fee'] as int,
      description: j['description'] as String,
      scheduledStart: DateTime.parse(j['scheduledStart'] as String).toLocal(),
    );
    final start = e.scheduledStart!;
    if (!RegExp(r'^HD\d{4,}$').hasMatch(e.id) ||
        int.parse(e.id.substring(2)) < 1 ||
        e.title.trim() != e.title ||
        e.title.length < 3 ||
        e.title.length > 100 ||
        e.description.trim() != e.description ||
        e.description.length < 10 ||
        e.description.length > 1000 ||
        start != bookingDay(start).add(Duration(hours: e.hour)) ||
        e.hour < 6 ||
        e.durationMinutes < 60 ||
        e.durationMinutes > 240 ||
        e.durationMinutes % 60 != 0 ||
        e.hour + e.durationMinutes ~/ 60 > 22 ||
        e.capacity < 1 ||
        e.capacity > (e.kind == DemoEventKind.social ? 64 : 32) ||
        e.fee < 10000 ||
        e.fee > 1000000 ||
        e.fee % 1000 != 0) {
      throw const FormatException('Invalid activity definition');
    }
    return e;
  }
}

const demoEvents = [
  DemoEvent(
    id: 'social-evening',
    title: 'Giao lưu cầu lông buổi tối',
    kind: DemoEventKind.social,
    hour: 18,
    durationMinutes: 120,
    capacity: 12,
    fee: 60000,
    description: 'Đánh đôi luân phiên, phù hợp người chơi cơ bản và trung cấp. Chi phí gồm sân và cầu; mang theo vợt và giày thể thao.',
  ),
  DemoEvent(
    id: 'social-morning',
    title: 'Giao lưu cầu lông buổi sáng',
    kind: DemoEventKind.social,
    hour: 8,
    durationMinutes: 120,
    capacity: 8,
    fee: 50000,
    description: 'Buổi chơi dành cho người mới và người chơi phong trào. Chia đội tại sân, tối đa hai vé cho mỗi tài khoản.',
  ),
  DemoEvent(
    id: 'tournament-doubles',
    title: 'Giải cầu lông đôi phong trào',
    kind: DemoEventKind.tournament,
    hour: 14,
    durationMinutes: 240,
    capacity: 8,
    fee: 150000,
    description: 'Thi đấu đôi, đăng ký theo đội hai người. Vòng bảng tính điểm, hai đội đứng đầu mỗi bảng vào vòng loại trực tiếp. Lịch thi đấu chi tiết sẽ do ban tổ chức công bố.',
  ),
];

DemoEvent eventById(String id) => demoEvents.firstWhere((e) => e.id == id);

String scheduleState(DateTime start, DateTime end, DateTime now) =>
    now.isBefore(start)
    ? 'Sắp tới'
    : now.isBefore(end)
    ? 'Đang diễn ra'
    : 'Đã kết thúc';

class DemoTournamentRegistration {
  const DemoTournamentRegistration({
    required this.birthYear,
    required this.email,
    required this.level,
    required this.accepted,
  });
  final int birthYear;
  final String email, level;
  final bool accepted;
  void validate() {
    if (birthYear < 1900 ||
        birthYear > 2100 ||
        email.length > 120 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        !['3.0', '3.5', '4.0'].contains(level) ||
        !accepted) {
      throw const FormatException(
        'Kiểm tra năm sinh, email, trình độ và điều khoản.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'birthYear': birthYear,
    'email': email,
    'level': level,
    'accepted': accepted,
  };
  factory DemoTournamentRegistration.fromJson(Map<String, dynamic> data) {
    final details = DemoTournamentRegistration(
      birthYear: data['birthYear'] as int,
      email: data['email'] as String,
      level: data['level'] as String,
      accepted: data['accepted'] as bool,
    );
    details.validate();
    return details;
  }
}

class DemoParticipation {
  DemoParticipation({
    required this.id,
    required this.owner,
    required this.eventId,
    required this.start,
    required this.quantity,
    required this.contact,
    required this.phone,
    this.team = '',
    this.partner = '',
    this.eventSnapshot,
    this.registration,
    this.socialCheckout = false,
    this.note = '',
  });
  final String id;
  final String owner;
  final String eventId;
  final DateTime start;
  final int quantity;
  final String contact;
  final String phone;
  final String team;
  final String partner;
  bool cancelled = false;
  bool checkedIn = false;
  DemoAttendance attendance = DemoAttendance.pending;
  final DemoEvent? eventSnapshot;
  final DemoTournamentRegistration? registration;
  final bool socialCheckout;
  final String note;
  DemoEvent get event => eventSnapshot ?? eventById(eventId);
  String get qrPayload => Uri(
    scheme: 'nvh-demo',
    host: 'ticket',
    queryParameters: {
      'version': '1',
      'id': id,
      'event': eventId,
      'start': start.toIso8601String(),
    },
  ).toString();
  int get discount =>
      socialCheckout && quantity == 2 ? quantity * event.fee ~/ 10 : 0;
  int get total => quantity * event.fee - discount;
  String state(DateTime now) => cancelled
      ? 'Đã hủy'
      : attendance == DemoAttendance.absent
      ? 'Vắng mặt'
      : attendance == DemoAttendance.completed
      ? 'Đã hoàn thành'
      : checkedIn
      ? 'Đã check-in'
      : scheduleState(start, event.end(start), now);
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'eventId': eventId,
    'start': start.toIso8601String(),
    'quantity': quantity,
    'contact': contact,
    'phone': phone,
    'team': team,
    'partner': partner,
    'registration': registration?.toJson(),
    'socialCheckout': socialCheckout,
    'note': note,
    if (eventSnapshot != null) 'eventSnapshot': eventSnapshot!.toJson(),
    'cancelled': cancelled,
    'checkedIn': checkedIn,
    'attendance': attendance.name,
  };
  factory DemoParticipation.fromJson(Map<String, dynamic> data) {
    final p =
        DemoParticipation(
            id: data['id'] as String,
            owner: data['owner'] as String,
            eventId: data['eventId'] as String,
            start: DateTime.parse(data['start'] as String).toLocal(),
            quantity: data['quantity'] as int,
            contact: data['contact'] as String,
            phone: data['phone'] as String,
            team: data['team'] as String,
            partner: data['partner'] as String,
            socialCheckout: (data['socialCheckout'] ?? false) as bool,
            note: (data['note'] ?? '') as String,
            registration: data['registration'] == null
                ? null
                : DemoTournamentRegistration.fromJson(
                    data['registration'] as Map<String, dynamic>,
                  ),
            eventSnapshot: data['eventSnapshot'] == null
                ? null
                : DemoEvent.fromJson(
                    data['eventSnapshot'] as Map<String, dynamic>,
                  ),
          )
          ..cancelled = data['cancelled'] as bool
          ..checkedIn = data['checkedIn'] as bool;
    p.attendance = DemoAttendance.values.byName(
      (data['attendance'] ?? (p.checkedIn ? 'checkedIn' : 'pending')) as String,
    );
    if ((p.socialCheckout && p.event.kind != DemoEventKind.social) ||
        p.note.length > 300 ||
        (p.note.isNotEmpty && !p.socialCheckout) ||
        (p.registration != null && p.event.kind != DemoEventKind.tournament) ||
        !RegExp(r'^VE\d{4,}$').hasMatch(p.id) ||
        (p.eventSnapshot == null
            ? !demoEvents.any((e) => e.id == p.eventId)
            : p.eventSnapshot!.id != p.eventId ||
                  p.start != p.eventSnapshot!.scheduledStart) ||
        p.quantity < 1 ||
        p.quantity > 2 ||
        p.contact.trim().isEmpty ||
        p.contact.length > 60 ||
        !RegExp(r'^0[35789]\d{8}$').hasMatch(p.phone) ||
        p.start != bookingDay(p.start).add(Duration(hours: p.event.hour)) ||
        (p.cancelled &&
            (p.checkedIn || p.attendance != DemoAttendance.pending)) ||
        (p.checkedIn !=
            (p.attendance == DemoAttendance.checkedIn ||
                p.attendance == DemoAttendance.completed)) ||
        (p.event.kind == DemoEventKind.tournament &&
            (p.quantity != 1 ||
                p.team.trim().isEmpty ||
                p.team.length > 60 ||
                p.partner.trim().isEmpty ||
                p.partner.length > 60)) ||
        (p.event.kind == DemoEventKind.social &&
            (p.team.isNotEmpty || p.partner.isNotEmpty))) {
      throw const FormatException('Invalid participation');
    }
    return p;
  }
}
