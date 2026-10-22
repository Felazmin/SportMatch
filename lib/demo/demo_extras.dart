import '../booking/demo_booking.dart';

class DemoVoucher {
  const DemoVoucher(
    this.code,
    this.title, {
    this.amount = 0,
    this.percent = 0,
    this.minimum = 0,
  });
  final String code;
  final String title;
  final int amount;
  final int percent;
  final int minimum;
  int discount(int subtotal) => subtotal < minimum
      ? 0
      : (percent > 0 ? subtotal * percent ~/ 100 : amount).clamp(0, subtotal);
}

const demoVouchers = [
  DemoVoucher('DEMO10', 'Giảm 10%', percent: 10),
  DemoVoucher('DEMO20', 'Giảm 20.000đ', amount: 20000, minimum: 120000),
  DemoVoucher('DEMO30', 'Giảm 30.000đ', amount: 30000, minimum: 240000),
];

class DemoCourse {
  const DemoCourse(
    this.id,
    this.title,
    this.level,
    this.description,
    this.hour,
  );
  final String id;
  final String title;
  final String level;
  final String description;
  final int hour;
  static const capacity = 12;
  static const fee = 180000;
  DateTime start(DateTime now) =>
      bookingDay(now).add(Duration(days: 2, hours: hour));
}

const demoCourses = [
  DemoCourse(
    'basic',
    'Cầu lông căn bản',
    'Mới bắt đầu',
    'Cầm vợt, di chuyển và phát cầu. Buổi trải nghiệm 90 phút.',
    8,
  ),
  DemoCourse(
    'advanced',
    'Kỹ thuật đánh đôi',
    'Trung cấp',
    'Phối hợp đồng đội, phòng thủ và tấn công. Buổi trải nghiệm 90 phút.',
    16,
  ),
];

class DemoEnrollment {
  DemoEnrollment({
    required this.id,
    required this.owner,
    required this.courseId,
    required this.start,
  });
  final String id;
  final String owner;
  final String courseId;
  final DateTime start;
  bool cancelled = false;
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'courseId': courseId,
    'start': start.toIso8601String(),
    'cancelled': cancelled,
  };
  factory DemoEnrollment.fromJson(Map<String, dynamic> data) {
    final result = DemoEnrollment(
      id: data['id'] as String,
      owner: data['owner'] as String,
      courseId: data['courseId'] as String,
      start: DateTime.parse(data['start'] as String).toLocal(),
    )..cancelled = data['cancelled'] as bool;
    if (!RegExp(r'^HL\d{4,}$').hasMatch(result.id) ||
        !demoCourses.any(
          (c) => c.id == result.courseId && c.hour == result.start.hour,
        ) ||
        result.start.minute != 0 ||
        result.start.second != 0 ||
        result.start.millisecond != 0 ||
        result.start.microsecond != 0) {
      throw const FormatException('Invalid enrollment');
    }
    return result;
  }
}

class DemoSupportTicket {
  DemoSupportTicket({
    required this.id,
    required this.owner,
    required this.subject,
    required this.message,
    required this.created,
  });
  final String id;
  final String owner;
  final String subject;
  final String message;
  final DateTime created;
  bool closed = false;
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'subject': subject,
    'message': message,
    'created': created.toIso8601String(),
    'closed': closed,
  };
  factory DemoSupportTicket.fromJson(Map<String, dynamic> data) {
    final result = DemoSupportTicket(
      id: data['id'] as String,
      owner: data['owner'] as String,
      subject: data['subject'] as String,
      message: data['message'] as String,
      created: DateTime.parse(data['created'] as String).toLocal(),
    )..closed = data['closed'] as bool;
    if (!RegExp(r'^HT\d{4,}$').hasMatch(result.id) ||
        result.subject.trim().isEmpty ||
        result.subject.length > 80 ||
        result.message.trim().length < 10 ||
        result.message.length > 1000) {
      throw const FormatException('Invalid ticket');
    }
    return result;
  }
}
