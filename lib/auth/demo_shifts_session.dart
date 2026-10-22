part of 'demo_session.dart';

extension DemoShiftsSession on DemoSession {
  List<DemoShift> get employeeShifts {
    _requireManager();
    return List.unmodifiable(
      [..._shifts]..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  DemoEmployee shiftEmployee(String id) {
    _requireManager();
    final e = employees.where((e) => e.id == id).firstOrNull;
    if (e == null) throw StateError('Nhân viên không tồn tại.');
    return e;
  }

  DemoShift scheduleEmployeeShift(
    String employeeId,
    DateTime start,
    int hours,
  ) {
    final e = shiftEmployee(employeeId);
    if (!e.active ||
        !start.isAfter(now) ||
        bookingDay(start)
            .isAfter(bookingDay(now).add(const Duration(days: 30)))) {
      throw StateError(
        'Chọn nhân viên đang làm và ca tương lai trong 30 ngày.',
      );
    }
    if (_shifts.length >= 500) throw StateError('Tối đa 500 ca làm demo.');
    final shift = DemoShift(
      id: 'CA${_nextShift.toString().padLeft(4, '0')}',
      employeeId: employeeId,
      start: start,
      hours: hours,
    );
    try {
      DemoShift.fromJson(shift.toJson());
    } on FormatException {
      throw StateError('Ca làm cần 1–12 giờ nguyên, trong khoảng 06:00–22:00.');
    }
    if (_shifts.any(
      (s) =>
          s.employeeId == employeeId &&
          s.state != DemoShiftState.cancelled &&
          start.isBefore(s.end) &&
          shift.end.isAfter(s.start),
    )) {
      throw StateError('Nhân viên đã có ca trùng thời gian.');
    }
    _shifts.add(shift);
    _nextShift++;
    _recordOperation('Phân ca ${shift.id} / $employeeId');
    return shift;
  }

  void setEmployeeShiftState(
    String id,
    DemoShiftState next, {
    required int expectedRevision,
    String reason = '',
  }) {
    _requireManager();
    final index = _shifts.indexWhere((s) => s.id == id);
    if (index < 0) throw StateError('Ca làm không tồn tại.');
    final old = _shifts[index];
    final e = shiftEmployee(old.employeeId);
    if (old.revision != expectedRevision) {
      throw StateError('Ca đã thay đổi. Mở lại hồ sơ.');
    }
    final allowed = switch (next) {
      DemoShiftState.checkedIn =>
        old.state == DemoShiftState.scheduled &&
            e.active &&
            !now.isBefore(old.start.subtract(const Duration(minutes: 15))) &&
            now.isBefore(old.end),
      DemoShiftState.completed =>
        old.state == DemoShiftState.checkedIn && !now.isBefore(old.end),
      DemoShiftState.absent =>
        old.state == DemoShiftState.scheduled && !now.isBefore(old.end),
      DemoShiftState.cancelled =>
        old.state == DemoShiftState.scheduled &&
            now.isBefore(old.start) &&
            reason.trim().length >= 5 &&
            reason.trim().length <= 300,
      DemoShiftState.scheduled => false,
    };
    if (!allowed) {
      throw StateError('Thời gian, nhân viên hoặc trạng thái ca chưa hợp lệ.');
    }
    _shifts[index] = DemoShift(
      id: old.id,
      employeeId: old.employeeId,
      start: old.start,
      hours: old.hours,
      state: next,
      reason: next == DemoShiftState.cancelled ? reason.trim() : '',
      revision: old.revision + 1,
    );
    _recordOperation(
      '${_shifts[index].label} ${old.id} / ${old.employeeId}${next == DemoShiftState.cancelled ? ': ${reason.trim()}' : ''}',
    );
  }
}
