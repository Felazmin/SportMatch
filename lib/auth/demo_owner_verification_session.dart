part of 'demo_session.dart';

extension DemoOwnerVerificationSession on DemoSession {
  DemoOwnerVerification? get ownerVerification {
    _requireManager();
    return _ownerVerification;
  }

  void submitOwnerVerification({
    required String name,
    required String phone,
    required String proof,
    required int expectedRevision,
  }) {
    _requireManager();
    final old = _ownerVerification;
    if (role != DemoRole.owner ||
        (old?.revision ?? 0) != expectedRevision ||
        (old != null && old.state != 'rejected')) {
      throw StateError('Hồ sơ đã thay đổi hoặc không thể gửi lại.');
    }
    final next = DemoOwnerVerification(
      name: name.trim(),
      phone: DemoSession.normalize(phone),
      proof: proof,
      state: 'pending',
      created: old?.created ?? now,
      updated: now,
      revision: expectedRevision + 1,
    );
    try {
      DemoOwnerVerification.fromJson(next.toJson());
    } on FormatException {
      throw StateError('Kiểm tra tên, số điện thoại và ảnh hồ sơ.');
    }
    _ownerVerification = next;
    _recordOperation('Gửi hồ sơ xác minh Chủ sân');
  }

  void reviewOwnerVerification({
    required bool approve,
    bool reject = false,
    required int expectedRevision,
    required String password,
    String note = '',
  }) {
    _requireAdmin();
    if (approve && reject) {
      throw StateError('Quyết định không hợp lệ.');
    }
    final old = _ownerVerification;
    if (old == null ||
        old.revision != expectedRevision ||
        (old.state != 'pending' && !(old.state == 'verified' && !approve))) {
      throw StateError('Hồ sơ đã thay đổi.');
    }
    final next = DemoOwnerVerification(
      name: old.name,
      phone: old.phone,
      proof: old.proof,
      state: approve ? 'verified' : 'rejected',
      created: old.created,
      updated: now,
      revision: old.revision + 1,
      note: approve ? '' : note.trim(),
      reviewDecision: approve
          ? 'approved'
          : reject
          ? 'rejected'
          : 'supplement',
    );
    try {
      DemoOwnerVerification.fromJson(next.toJson());
    } on FormatException {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    _verifyAdminConfirmation(password);
    _ownerVerification = next;
    _recordOperation(
      '${next.label} Chủ sân ${next.name}',
      subject: '__owner__',
      decision: next.reviewDecision,
      note: next.note,
    );
  }

  void _verifyAdminConfirmation(String password) {
    _requireAdmin();
    if (_accessLockedUntil?.isAfter(now) ?? false) {
      throw StateError('Xác nhận tạm khóa. Thử lại sau 60 giây.');
    }
    if (_accessLockedUntil != null) {
      _accessLockedUntil = null;
      _accessFailures = 0;
    }
    if (_staff[user!.identifier]!.password != password) {
      if (++_accessFailures >= 5) {
        _accessLockedUntil = now.add(const Duration(minutes: 1));
      }
      throw StateError('Mật khẩu Admin không đúng hoặc xác nhận tạm khóa.');
    }
    _accessFailures = 0;
  }
}
