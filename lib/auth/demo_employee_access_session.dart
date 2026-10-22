part of 'demo_session.dart';

extension DemoEmployeeAccessSession on DemoSession {
  DemoEmployee? get activeEmployee {
    _requireReady();
    if (user != null ||
        _activeEmployeeId == null ||
        !(_employeeAccess[_activeEmployeeId]?.permissions.isNotEmpty ??
            false)) {
      return null;
    }
    return _operations.employees
        .where((e) => e.id == _activeEmployeeId && e.active)
        .firstOrNull;
  }

  DemoEmployeeAccess? employeeAccess(String id) {
    _requireManager();
    shiftEmployee(id);
    return _employeeAccess[id];
  }

  void configureEmployeeAccess(
    String id,
    Set<String> permissions,
    String secret, {
    required int expectedRevision,
    required String managerPassword,
    Set<String>? facilityIds,
  }) {
    _requireManager();
    final e = shiftEmployee(id);
    if (!e.active ||
        _staff[user!.identifier]?.password != managerPassword ||
        (_employeeAccess[id]?.revision ?? 0) != expectedRevision) {
      throw StateError(
        'Kiểm tra mật khẩu quản lý, trạng thái nhân viên và phiên bản quyền.',
      );
    }
    final old = _employeeAccess[id];
    final access = DemoEmployeeAccess(
      password: secret.isEmpty ? old?.password ?? '' : secret,
      permissions: permissions,
      revision: expectedRevision + 1,
      facilityIds: facilityIds ?? old?.facilityIds ?? {'*'},
    );
    try {
      DemoEmployeeAccess.fromJson(access.toJson());
    } on FormatException {
      throw StateError(
        'Mật khẩu cần 8–128 ký tự; quyền thao tác cần kèm quyền xem lịch.',
      );
    }
    if (access.facilityIds.any(
      (id) =>
          !['*', ''].contains(id) &&
          !_facilities.any((f) => f.id == id && f.published != null),
    )) {
      throw StateError('Chọn cơ sở đã được duyệt.');
    }
    _employeeAccess[id] = access;
    _recordOperation('Cập nhật quyền $id: ${permissions.join(', ')}');
  }

  bool loginEmployee(String identifier, String secret) {
    _requireReady();
    if (_employeeLoginLockedUntil?.isAfter(now) ?? false) return false;
    final normalized = DemoSession.normalize(identifier);
    final e = _operations.employees
        .where(
          (e) =>
              e.active &&
              (e.id.toLowerCase() == identifier.trim().toLowerCase() ||
                  e.phone == normalized),
        )
        .firstOrNull;
    if (e == null ||
        _employeeAccess[e.id]?.password != secret ||
        _employeeAccess[e.id]!.permissions.isEmpty) {
      if (++_employeeLoginFailures >= 5) {
        _employeeLoginLockedUntil = now.add(const Duration(minutes: 1));
        _employeeLoginFailures = 0;
      }
      return false;
    }
    _employeeLoginFailures = 0;
    _employeeLoginLockedUntil = null;
    user = null;
    _activeEmployeeId = e.id;
    _proofPickerTarget = null;
    _changed();
    return true;
  }

  bool employeeCan(String permission) =>
      activeEmployee != null &&
      (_employeeAccess[_activeEmployeeId]?.permissions.contains(permission) ??
          false);
  void _requireEmployee(String permission) {
    if (!employeeCan(permission)) {
      throw StateError('Quyền đã thay đổi hoặc tài khoản bị ngừng.');
    }
  }

  List<DemoShift> get ownEmployeeShifts {
    final e = activeEmployee;
    if (e == null) throw StateError('Cần đăng nhập nhân viên.');
    return List.unmodifiable(_shifts.where((s) => s.employeeId == e.id));
  }

  List<DemoWorkflowRecord> get employeeSchedule {
    _requireEmployee('schedule');
    final scope = _employeeAccess[_activeEmployeeId]!.facilityIds;
    final first = bookingDay(now),
        last = bookingDay(now).add(const Duration(days: 7));
    return List.unmodifiable(
      [
        for (final id in [
          ..._bookings.map((b) => b.id),
          ..._participations.map((p) => p.id),
        ])
          if (!_rawWorkflowRecord(id).start.isBefore(first) &&
              _rawWorkflowRecord(id).start.isBefore(last) &&
              (scope.contains('*') ||
                  scope.contains(
                    _bookings
                            .where((b) => b.id == id)
                            .firstOrNull
                            ?.facilityId ??
                        '',
                  )))
            _rawWorkflowRecord(id),
      ]..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  DemoWorkflowRecord _employeeRecord(String id) {
    return employeeSchedule.where((r) => r.id == id).firstOrNull ??
        (throw StateError('Hồ sơ ngoài lịch được giao.'));
  }

  bool employeeRecordPaid(String id) {
    _employeeRecord(id);
    return _payments[id]?.state == DemoPaymentState.approved;
  }

  void employeeSetAttendance(
    String id,
    DemoAttendance next,
    DemoAttendance expected,
  ) {
    _requireEmployee('attendance');
    final r = _employeeRecord(id);
    if (r.attendance != expected) throw StateError('Điểm danh đã thay đổi.');
    _applyAttendance(id, next);
  }

  void employeeConfirmPayment(String id) {
    _requireEmployee('onsite');
    _employeeRecord(id);
    final b = _bookings.where((b) => b.id == id).firstOrNull;
    if (b == null) throw StateError('Chỉ hỗ trợ thu lịch đặt sân.');
    _applyVenuePayment(b);
  }
}
