part of 'demo_session.dart';

extension DemoRegistrationSession on DemoSession {
  DemoRegistration beginDemoRegistration(
    String name,
    String identifier,
    String secret,
  ) {
    _requireReady();
    final id = DemoSession.normalize(identifier);
    if (name.trim().isEmpty ||
        name.trim().length > 60 ||
        secret.length < 8 ||
        secret.length > 128 ||
        !(RegExp(r'^0[35789]\d{8}$').hasMatch(id) ||
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(id))) {
      throw StateError('Kiểm tra tên, thông tin liên hệ và mật khẩu.');
    }
    if (id == DemoSession.phone ||
        id == DemoSession.email ||
        _registered.containsKey(id)) {
      throw StateError('Số điện thoại hoặc email này đã được đăng ký.');
    }
    _registrationDraft = (name: name.trim(), identifier: id, password: secret);
    return _registration = DemoRegistration(identifier: id, issued: now);
  }

  void _requireRegistration(
    DemoRegistration challenge, {
    bool requireUnexpired = true,
  }) {
    _requireReady();
    if (!identical(challenge, _registration) ||
        challenge.consumed ||
        _registrationDraft == null) {
      throw StateError('Yêu cầu không còn hiệu lực. Quay lại đăng ký.');
    }
    if (requireUnexpired && !now.isBefore(challenge.expires)) {
      throw StateError('Mã OTP đã hết hạn. Hãy tạo mã mới.');
    }
  }

  DemoRegistration resendDemoRegistration(DemoRegistration challenge) {
    _requireRegistration(challenge, requireUnexpired: false);
    if (now.isBefore(challenge.resendAt)) {
      throw StateError('Chờ đủ 60 giây trước khi tạo lại mã.');
    }
    return _registration = DemoRegistration(
      identifier: challenge.identifier,
      issued: now,
    );
  }

  void completeDemoRegistration(DemoRegistration challenge, String code) {
    _requireRegistration(challenge);
    if (challenge.attempts >= 5) {
      throw StateError('Đã nhập sai 5 lần. Hãy tạo mã mới.');
    }
    if (code.trim() != DemoRegistration.code) {
      challenge.attempts++;
      throw StateError(
        'Mã OTP không đúng. Còn ${5 - challenge.attempts} lần thử.',
      );
    }
    final draft = _registrationDraft!;
    if (!register(draft.name, draft.identifier, draft.password)) {
      throw StateError('Tài khoản đã được đăng ký. Quay lại đăng nhập.');
    }
    challenge.consumed = true;
    _registrationDraft = null;
  }

  void cancelDemoRegistration(DemoRegistration challenge) {
    if (identical(challenge, _registration)) {
      _registration = null;
      _registrationDraft = null;
    }
  }
}
