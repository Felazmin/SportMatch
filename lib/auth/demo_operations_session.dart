part of 'demo_session.dart';

extension DemoOperationsSession on DemoSession {
  int courtRate(int court, [DateTime? time]) {
    if (court < 1 || court > 3) throw ArgumentError.value(court);
    return time == null
        ? _operations.published.rates[court - 1]
        : _operations.published.rateAt(court, time);
  }

  List<int> bookingRates(
    int court,
    DateTime start,
    int hours, {
    String facilityId = '',
  }) {
    if (hours < 1 || hours > 3) throw ArgumentError.value(hours);
    if (facilityId.isNotEmpty) {
      final p = _bookableFacility(facilityId);
      if (p == null || court < 1 || court > p.courtCount) {
        throw StateError('Cơ sở hoặc sân không còn khả dụng.');
      }
      final tariffs =
          _facilityTariffs[facilityId]?.published ?? <FacilityTariffBand>[];
      return List.unmodifiable([
        for (var i = 0; i < hours; i++)
          tariffs
                  .where((b) => b.applies(court, start.add(Duration(hours: i))))
                  .firstOrNull
                  ?.quotedRate ??
              p.baseRate,
      ]);
    }
    return List.unmodifiable([
      for (var i = 0; i < hours; i++)
        courtRate(court, start.add(Duration(hours: i))),
    ]);
  }

  int bookingSubtotal(int court, DateTime start, int hours) =>
      bookingRates(court, start, hours).fold(0, (a, b) => a + b);

  CourtSettings get publishedCourts => _operations.published;
  int get minimumCourtRate {
    final openRates = [
      for (var i = 0; i < 3; i++)
        if (_operations.published.enabled[i]) _operations.published.rates[i],
    ];
    final rates = openRates.isEmpty ? _operations.published.rates : openRates;
    final prices = <int>[];
    for (var day = 0; day < 7; day++) {
      for (var hour = 6; hour < 22; hour++) {
        final time = bookingDay(now).add(Duration(days: day, hours: hour));
        if (!time.isAfter(now)) continue;
        for (var court = 1; court <= 3; court++) {
          if (_operations.published.enabled[court - 1]) {
            prices.add(courtRate(court, time));
          }
        }
      }
    }
    return (prices.isEmpty ? rates : prices).reduce((a, b) => a < b ? a : b);
  }

  List<VenueSummary> get currentVenues => [
    for (final v in _discoveryVenues)
      if (_facilities
              .where(
                (f) =>
                    f.sourceVenueId == v.id &&
                    f.published != null &&
                    !f.suspended,
              )
              .firstOrNull
          case final f?)
        _facilityVenue(f, source: v)
      else
        v,
    for (final f in _facilities.where(
      (f) =>
          f.published != null &&
          !f.suspended &&
          (f.sourceVenueId.isEmpty ||
              !_discoveryVenues.any((v) => v.id == f.sourceVenueId)),
    ))
      _facilityVenue(f),
    for (final v in demoVenues)
      VenueSummary(
        id: v.id,
        name: v.id == demoVenueId
            ? _primaryFacilityProfile?.published?.name ?? v.name
            : v.name,
        address:
            v.id == demoVenueId && _primaryFacilityProfile?.published != null
            ? '${_primaryFacilityProfile!.published!.address}, ${_primaryFacilityProfile!.published!.district}, ${_primaryFacilityProfile!.published!.city}'
            : v.address,
        sport: v.sport,
        image: v.id == demoVenueId
            ? _primaryFacilityProfile?.published?.photo ?? v.image
            : v.image,
        localPhoto:
            v.id == demoVenueId && _primaryFacilityProfile?.published != null,
        price: minimumCourtRate,
        rating: v.id == demoVenueId ? venueRating : v.rating,
        featured: v.featured,
      ),
  ];
  CourtSettings? get draftCourts {
    _requireManager();
    return _operations.draft;
  }

  String get courtReviewState {
    _requireManager();
    return _operations.reviewState;
  }

  String get courtReviewNote {
    _requireManager();
    return _operations.reviewNote;
  }

  void _requireAdmin() {
    _requireManager();
    if (role != DemoRole.admin) throw StateError('Chỉ Admin được thực hiện.');
  }

  ({bool requests, bool overdue, bool weekly})
  get adminNotificationPreferences {
    _requireAdmin();
    return (
      requests: _operations.notifyRequests,
      overdue: _operations.notifyOverdue,
      weekly: _operations.weeklyReport,
    );
  }

  void updateAdminNotifications({
    required String password,
    required bool requests,
    required bool overdue,
    required bool weekly,
  }) {
    _requireAdmin();
    if (_staff[user!.identifier]!.password != password) {
      throw StateError('Mật khẩu không đúng.');
    }
    _operations.notifyRequests = requests;
    _operations.notifyOverdue = overdue;
    _operations.weeklyReport = weekly;
    _recordOperation('Cập nhật tùy chọn thông báo quản trị');
  }

  void _recordOperation(
    String action, {
    String subject = '',
    String decision = '',
    String note = '',
  }) {
    _operations.audit.add(
      DemoAuditEntry(
        actor: user?.identifier ?? activeEmployee!.id,
        action: action,
        subject: subject,
        decision: decision,
        note: note,
        created: now,
      ),
    );
    if (_operations.audit.length > 1000) _operations.audit.removeAt(0);
    _changed();
  }

  void submitCourtSettings(CourtSettings settings) {
    _requireManager();
    if (role != DemoRole.owner) {
      throw StateError('Chủ sân gửi đề nghị thay đổi.');
    }
    if (_operations.reviewState == 'pending') {
      throw StateError('Đề nghị đang chờ duyệt.');
    }
    _operations.draft = settings;
    _operations.reviewState = 'pending';
    _operations.reviewNote = '';
    _recordOperation('Gửi bảng giá / trạng thái sân chờ duyệt');
  }

  void reviewCourtSettings({required bool approve, String note = ''}) {
    _requireAdmin();
    if (_operations.reviewState != 'pending' || _operations.draft == null) {
      throw StateError('Không có đề nghị đang chờ duyệt.');
    }
    if ((!approve && note.trim().length < 5) || note.length > 300) {
      throw StateError('Lý do từ chối cần 5–300 ký tự.');
    }
    if (approve) {
      _operations.published = _operations.draft!;
      _operations.draft = null;
    }
    _operations.reviewState = approve ? 'approved' : 'rejected';
    _operations.reviewNote = note.trim();
    _recordOperation(
      approve
          ? 'Duyệt bảng giá / trạng thái sân'
          : 'Từ chối bảng giá: ${note.trim()}',
      subject: 'primary-pricing',
      decision: approve ? 'approved' : 'rejected',
      note: note.trim(),
    );
  }

  List<DemoEmployee> get employees {
    _requireManager();
    return List.unmodifiable(_operations.employees);
  }

  void saveEmployee({
    String? id,
    required String name,
    required String phone,
    required String job,
    required bool active,
  }) {
    _requireManager();
    final index = id == null
        ? -1
        : _operations.employees.indexWhere((e) => e.id == id);
    if (id != null && index < 0) throw StateError('Nhân viên không tồn tại.');
    if (id == null && _operations.employees.length >= 100) {
      throw StateError('Tối đa 100 nhân viên demo.');
    }
    final e = DemoEmployee.fromJson({
      'id': id ?? 'NS${_operations.nextEmployee.toString().padLeft(4, '0')}',
      'name': name.trim(),
      'phone': DemoSession.normalize(phone),
      'job': job,
      'active': active,
    });
    if (_operations.employees.any(
      (other) => other.id != e.id && other.phone == e.phone,
    )) {
      throw StateError('Số điện thoại nhân viên đã tồn tại.');
    }
    if (id == null) {
      _operations.employees.add(e);
      _operations.nextEmployee++;
    } else {
      _operations.employees[index] = e;
    }
    _recordOperation('${id == null ? 'Thêm' : 'Sửa'} hồ sơ ${e.id}');
  }

  bool isBlocked(String id) {
    _requireAdmin();
    return _operations.blocked.contains(id);
  }

  DemoAccessDecision? playerAccessDecision(String id) {
    managedPlayer(id);
    return _operations.accessDecisions[id];
  }

  DemoUser managedPlayer(String id) {
    _requireAdmin();
    final player = managedUsers.where((u) => u.identifier == id).firstOrNull;
    if (player == null) throw StateError('Không có người dùng.');
    return player;
  }

  String managedContactPhone(String id) {
    managedPlayer(id);
    return _contactPhones[id] ?? (id.startsWith('0') ? id : '');
  }

  int playerAccessRevision(String id) =>
      playerAccessDecision(id)?.revision ?? 0;
  List<DemoWorkflowRecord> playerRecords(String id) {
    managedPlayer(id);
    return List.unmodifiable(managedAttendance.where((r) => r.owner == id));
  }

  void setPlayerBlocked(
    String id,
    bool blocked, {
    required String password,
    required String reason,
    required bool expectedBlocked,
    required int expectedRevision,
  }) {
    _requireAdmin();
    if (!managedUsers.any((u) => u.identifier == id)) {
      throw StateError('Không có người dùng.');
    }
    final old = _operations.blocked.contains(id);
    if (old != expectedBlocked ||
        old == blocked ||
        playerAccessRevision(id) != expectedRevision) {
      throw StateError('Trạng thái đã thay đổi. Mở lại hồ sơ.');
    }
    if (reason.trim().length < 5 || reason.trim().length > 300) {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    if (_accessLockedUntil != null && now.isBefore(_accessLockedUntil!)) {
      throw StateError('Xác nhận tạm khóa. Thử lại sau 60 giây.');
    }
    if (_accessLockedUntil != null) {
      _accessFailures = 0;
      _accessLockedUntil = null;
    }
    if (_staff[user!.identifier]!.password != password) {
      _accessFailures++;
      if (_accessFailures >= 5) {
        _accessLockedUntil = now.add(const Duration(seconds: 60));
      }
      throw StateError(
        _accessFailures >= 5
            ? 'Xác nhận tạm khóa. Thử lại sau 60 giây.'
            : 'Mật khẩu Admin không đúng.',
      );
    }
    _accessFailures = 0;
    if (blocked) {
      _operations.blocked.add(id);
    } else {
      _operations.blocked.remove(id);
    }
    _operations.accessDecisions[id] = DemoAccessDecision(
      blocked: blocked,
      reason: reason.trim(),
      created: now,
      revision: expectedRevision + 1,
    );
    final action =
        '${blocked ? 'Khóa' : 'Mở khóa'} tài khoản $id: ${reason.trim()}';
    _recordOperation(action.length > 400 ? action.substring(0, 400) : action);
  }

  List<DemoPost> get moderationPosts {
    _requireAdmin();
    return List.unmodifiable(_posts);
  }

  bool isPostHidden(String id) {
    _requireAdmin();
    return _operations.hiddenPosts.contains(id);
  }

  void setPostHidden(String id, bool hidden) {
    _requireAdmin();
    if (!_posts.any((p) => p.id == id)) {
      throw StateError('Bài viết không tồn tại.');
    }
    if (hidden) {
      _operations.hiddenPosts.add(id);
    } else {
      _operations.hiddenPosts.remove(id);
    }
    _recordOperation('${hidden ? 'Ẩn' : 'Hiện'} bài viết $id');
  }

  List<DemoAuditEntry> get operationAudit {
    _requireManager();
    return List.unmodifiable(_operations.audit.reversed);
  }
}
