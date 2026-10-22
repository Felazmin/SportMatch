enum DemoShiftState { scheduled, checkedIn, completed, absent, cancelled }

class DemoShift {
  const DemoShift({
    required this.id,
    required this.employeeId,
    required this.start,
    required this.hours,
    this.state = DemoShiftState.scheduled,
    this.reason = '',
    this.revision = 0,
  });
  final String id, employeeId, reason;
  final DateTime start;
  final int hours, revision;
  final DemoShiftState state;
  DateTime get end => start.add(Duration(hours: hours));
  String get label => switch (state) {
    DemoShiftState.scheduled => 'Chưa vào ca',
    DemoShiftState.checkedIn => 'Đã vào ca',
    DemoShiftState.completed => 'Hoàn thành',
    DemoShiftState.absent => 'Vắng mặt',
    DemoShiftState.cancelled => 'Đã hủy ca',
  };
  Map<String, Object?> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'start': start.toIso8601String(),
    'hours': hours,
    'state': state.name,
    'reason': reason,
    'revision': revision,
  };
  factory DemoShift.fromJson(Map<String, dynamic> j) {
    final s = DemoShift(
      id: j['id'] as String,
      employeeId: j['employeeId'] as String,
      start: DateTime.parse(j['start'] as String).toLocal(),
      hours: j['hours'] as int,
      state: DemoShiftState.values.byName(j['state'] as String),
      reason: j['reason'] as String,
      revision: j['revision'] as int,
    );
    if (!RegExp(r'^CA\d{4,}$').hasMatch(s.id) ||
        !RegExp(r'^NS\d{4,}$').hasMatch(s.employeeId) ||
        s.hours < 1 ||
        s.hours > 12 ||
        s.start.hour < 6 ||
        s.end.hour > 22 ||
        s.start.day != s.end.day ||
        s.start.minute != 0 ||
        s.start.second != 0 ||
        s.start.millisecond != 0 ||
        s.start.microsecond != 0 ||
        s.revision < 0 ||
        s.revision !=
            (s.state == DemoShiftState.scheduled
                ? 0
                : s.state == DemoShiftState.completed
                ? 2
                : 1) ||
        (s.state == DemoShiftState.cancelled
            ? s.reason.trim().length < 5 || s.reason.length > 300
            : s.reason.isNotEmpty)) {
      throw const FormatException('Invalid employee shift');
    }
    return s;
  }
}
