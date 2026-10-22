part of 'demo_session.dart';

extension DemoPayoutSession on DemoSession {
  DemoBankAccount? get payoutAccount {
    _requireManager();
    return _payoutAccount;
  }

  List<DemoPayout> get payouts {
    _requireManager();
    return List.unmodifiable(_payouts.reversed);
  }

  int get payoutBalance {
    _requireManager();
    final earned = settlementReport(onsite: false).rows
        .where((r) => !r.held && !_rawWorkflowRecord(r.id).end.isAfter(now))
        .fold<int>(0, (sum, r) => sum + r.net(300));
    return earned -
        _payouts
            .where((p) => p.state != 'rejected')
            .fold<int>(0, (sum, p) => sum + p.amount);
  }

  void savePayoutAccount(
    String bank,
    String holder,
    String number, {
    required int expectedRevision,
    required String password,
  }) {
    _requireManager();
    if (role != DemoRole.owner ||
        _staff[user!.identifier]!.password != password ||
        (_payoutAccount?.revision ?? 0) != expectedRevision) {
      throw StateError(
        'Kiểm tra tài khoản, mật khẩu Chủ sân và phiên bản hồ sơ.',
      );
    }
    final next = DemoBankAccount(
      bank: bank.trim(),
      holder: holder.trim(),
      number: number.trim(),
      revision: expectedRevision + 1,
    );
    try {
      DemoBankAccount.fromJson(next.toJson());
    } on FormatException {
      throw StateError(
        'Tên ngân hàng 3–80 ký tự, chủ tài khoản 3–60; số tài khoản 6–24 chữ số.',
      );
    }
    _payoutAccount = next;
    _recordOperation('Cập nhật tài khoản nhận tiền demo');
  }

  DemoPayout requestPayout(
    int amount, {
    required int expectedBalance,
    required int expectedAccountRevision,
    required String password,
  }) {
    _requireManager();
    if (role != DemoRole.owner ||
        _staff[user!.identifier]!.password != password ||
        _payoutAccount == null ||
        _payoutAccount!.revision != expectedAccountRevision ||
        payoutBalance != expectedBalance ||
        amount > payoutBalance ||
        _payouts.length >= 500) {
      throw StateError(
        'Số dư/tài khoản đã thay đổi hoặc không đủ điều kiện chi trả demo.',
      );
    }
    final p = DemoPayout(
      id: 'CT${_nextPayout.toString().padLeft(4, '0')}',
      amount: amount,
      account: _payoutAccount!,
      created: now,
      updated: now,
    );
    try {
      DemoPayout.fromJson(p.toJson());
    } on FormatException {
      throw StateError('Số tiền từ 1.000 đến 1 tỷ, bội số 1.000.');
    }
    _payouts.add(p);
    _nextPayout++;
    _recordOperation('Yêu cầu chi trả demo ${p.id}: ${p.amount}');
    return p;
  }

  void reviewPayout(
    String id,
    int expectedRevision, {
    required bool approve,
    required String password,
    String reference = '',
    String proof = '',
    String note = '',
  }) {
    _requireAdmin();
    final old = _payouts.where((p) => p.id == id).firstOrNull;
    if (old == null ||
        old.state != 'pending' ||
        old.revision != expectedRevision ||
        (approve &&
            (payoutBalance < 0 ||
                _payouts.any(
                  (p) =>
                      p.state == 'recorded' &&
                      p.reference.toLowerCase() ==
                          reference.trim().toLowerCase(),
                )))) {
      throw StateError(
        'Kiểm tra mật khẩu, trạng thái yêu cầu, số dư và mã chứng từ.',
      );
    }
    final next = DemoPayout(
      id: old.id,
      amount: old.amount,
      account: old.account,
      created: old.created,
      updated: now,
      revision: old.revision + 1,
      state: approve ? 'recorded' : 'rejected',
      reference: approve ? reference.trim() : '',
      proof: approve ? proof : '',
      note: approve ? '' : note.trim(),
    );
    try {
      DemoPayout.fromJson(next.toJson());
    } on FormatException {
      throw StateError(
        'Chọn ảnh/mã chứng từ 3–80 ký tự hoặc lý do từ chối 5–300 ký tự.',
      );
    }
    _verifyAdminConfirmation(password);
    _payouts[_payouts.indexOf(old)] = next;
    _recordOperation('${next.label} ${next.id}');
  }
}
