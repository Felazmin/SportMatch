import 'dart:convert';

import '../demo/demo_payment_method.dart';

import 'package:flutter/foundation.dart';

import '../booking/demo_booking.dart';
import '../venues/venue_catalog.dart';
import 'session_store.dart';
import '../demo/demo_extras.dart';
import '../chat/demo_chat.dart';
import '../chat/demo_voice.dart';
import '../demo/demo_events.dart';
import 'demo_recovery.dart';
import 'demo_registration.dart';
import '../demo/demo_community.dart';
import '../demo/demo_finance.dart';
import '../demo/demo_operations.dart';
import '../demo/demo_employee_access.dart';
import '../demo/demo_owner_verification.dart';
import '../demo/demo_venue_claim.dart';
import '../demo/demo_payout.dart';
import '../demo/demo_settlement.dart';
import '../demo/demo_facilities.dart';
import '../demo/demo_calendar.dart';
import '../demo/demo_facility_tariffs.dart';
import '../demo/demo_cancellation_policy.dart';
import '../demo/demo_cashflow.dart';
import '../demo/demo_reviews.dart';
import '../demo/demo_shifts.dart';
import '../demo/demo_play_groups.dart';
import '../demo/demo_activities.dart';
import '../demo/demo_court_types.dart';
import '../demo/demo_matches.dart';
import '../demo/demo_seed_data.dart';
export '../demo/demo_finance.dart' show DemoRole;
part 'demo_management.dart';
part 'demo_operations_session.dart';
part 'demo_employee_access_session.dart';
part 'demo_owner_verification_session.dart';
part 'demo_venue_claims_session.dart';
part 'demo_payout_session.dart';
part 'demo_settlement_session.dart';
part 'demo_facilities_session.dart';
part 'demo_registration_session.dart';
part 'demo_workflow_session.dart';
part 'demo_calendar_session.dart';
part 'demo_facility_tariffs_session.dart';
part 'demo_reviews_session.dart';
part 'demo_customers_session.dart';
part 'demo_shifts_session.dart';
part 'demo_dashboard_session.dart';
part 'demo_play_groups_session.dart';
part 'demo_activities_session.dart';
part 'demo_court_types_session.dart';
part 'demo_matches_session.dart';
part 'demo_seed_session.dart';
part 'demo_social_session.dart';

class DemoUser {
  DemoUser({
    required this.name,
    required this.identifier,
    this.seeded = false,
    this.role = DemoRole.player,
    this.registeredAt,
  });
  String name;
  final String identifier;
  final bool seeded;
  final DemoRole role;
  final DateTime? registeredAt;
  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }
}

// Production entry point supplies an encrypted local store; tests can omit it.
class DemoSession extends ChangeNotifier {
  DemoSession({
    DateTime Function()? now,
    SessionStore? store,
    this.demoFixtureLoader,
    this.venueCatalogLoader,
  }) : _now = now ?? DateTime.now,
       _store = store,
       initialized = store == null {
    final tomorrow = bookingDay(this.now).add(const Duration(days: 1));
    for (final hour in [9, 18]) {
      _bookings.add(
        DemoBooking(
          id: 'NVH${(_bookings.length + 1).toString().padLeft(4, '0')}',
          owner: phone,
          court: 1,
          start: tomorrow.add(Duration(hours: hour)),
          hours: 1,
          contact: _demoUser.name,
          phone: phone,
        ),
      );
    }
  }
  final SessionStore? _store;
  final Future<List<VenueSummary>> Function()? venueCatalogLoader;
  List<VenueSummary> _discoveryVenues = const [];
  final Future<({String photo, String proof})> Function()? demoFixtureLoader;
  int _demoSeedVersion = 0;
  bool initialized;
  bool loading = false;
  bool loadFailed = false;
  bool saveFailed = false;
  bool _disposed = false;
  Future<void> _pending = Future.value();
  static const _guestOwner = '__guest__';
  final Map<String, Set<String>> _favorites = {};
  String _demoPassword = password;
  final Map<String, String> _contactPhones = {};
  final List<DemoEnrollment> _enrollments = [];
  final List<DemoSupportTicket> _tickets = [];
  final Map<String, List<DemoPaymentMethod>> _paymentMethods = {};
  final Map<String, List<DemoConversation>> _chats = {};
  final List<DemoParticipation> _participations = [];
  final List<DemoActivity> _activities = [];
  final List<DemoEventCancellation> _eventCancellations = [];
  final List<DemoCourtType> _courtTypes = [];
  int _nextCourtType = 1;
  int _nextActivity = 1;
  final List<DemoMatch> _matches = [];
  int _nextMatch = 1;
  final List<DemoPost> _posts = [];
  int _nextPost = 1;
  final Map<String, Set<String>> _groups = {};
  final List<DemoPlayGroup> _playGroups = [];
  final List<DemoGroupRequest> _groupRequests = [];
  int _nextPlayGroup = 1;
  final List<DemoExpense> _expenses = [];
  final Map<String, DemoPayment> _payments = {};
  final List<DemoDispute> _disputes = [];
  final List<DemoVenueReview> _reviews = [];
  final List<DemoShift> _shifts = [];
  int _nextShift = 1;
  String? _proofPickerTarget;
  DemoOperations _operations = DemoOperations();
  final Map<String, DemoEmployeeAccess> _employeeAccess = {};
  DemoOwnerVerification? _ownerVerification;
  final List<DemoVenueClaim> _venueClaims = [];
  DemoBankAccount? _payoutAccount;
  final List<DemoPayout> _payouts = [];
  int _nextPayout = 1;
  String? _activeEmployeeId;
  int _employeeLoginFailures = 0;
  DateTime? _employeeLoginLockedUntil;
  int _accessFailures = 0;
  DateTime? _accessLockedUntil;
  final List<DemoFacility> _facilities = [];
  DemoFacility? _primaryFacilityProfile;
  final List<DemoCourtBlock> _courtBlocks = [];
  final Map<String, FacilityTariffPlan> _facilityTariffs = {};
  final Map<String, FacilityFormDraft> _facilityFormDrafts = {};
  CancellationPolicy _primaryCancellationPolicy =
      const CancellationPolicy.standard();
  int _primaryCancellationRevision = 0;
  int _nextBlock = 1;
  int _nextFacility = 1;
  DemoRegistration? _registration;
  ({String name, String identifier, String password})? _registrationDraft;
  static const ownerEmail = 'owner@nvh.demo';
  static const adminEmail = 'admin@nvh.demo';
  final Map<String, ({DemoUser user, String password})> _staff = {
    '__owner__': (
      user: DemoUser(
        name: 'Chủ sân demo',
        identifier: '__owner__',
        role: DemoRole.owner,
      ),
      password: password,
    ),
    '__admin__': (
      user: DemoUser(
        name: 'Admin demo',
        identifier: '__admin__',
        role: DemoRole.admin,
      ),
      password: password,
    ),
  };
  bool loginStaff(DemoRole requestedRole, String identifier, String secret) {
    _requireReady();
    if (requestedRole == DemoRole.player) return false;
    final alias = requestedRole == DemoRole.owner ? ownerEmail : adminEmail;
    final id = requestedRole == DemoRole.owner ? '__owner__' : '__admin__';
    final record = _staff[id]!;
    if (identifier.trim().toLowerCase() != alias || record.password != secret) {
      return false;
    }
    user = record.user;
    _activeEmployeeId = null;
    _changed();
    return true;
  }

  List<DemoPost> get posts => List.unmodifiable(
    _posts
        .where(
          (p) =>
              !_operations.hiddenPosts.contains(p.id) &&
              (p.groupId == 'public' || publicGroups.containsKey(p.groupId)),
        )
        .toList()
      ..sort((a, b) => b.created.compareTo(a.created)),
  );
  Set<String> get joinedGroups => Set.unmodifiable(
    (_groups[user?.identifier] ?? <String>{}).where(publicGroups.containsKey),
  );
  List<DemoExpense> get expenses => List.unmodifiable(
    _expenses.where((e) => e.owner == user?.identifier).toList()
      ..sort((a, b) => b.created.compareTo(a.created)),
  );
  void toggleGroup(String id) {
    _requireReady();
    if (user == null) throw StateError('Vui lòng đăng nhập.');
    if (!publicGroups.containsKey(id)) {
      throw StateError('Nhóm không còn hoạt động.');
    }
    final joined = _groups.putIfAbsent(user!.identifier, () => <String>{});
    final group = _playGroups.where((g) => g.id == id).firstOrNull;
    if (group?.requiresApproval == true) {
      if (role != DemoRole.player ||
          _operations.blocked.contains(user!.identifier)) {
        throw StateError('Cần tài khoản người chơi đang hoạt động.');
      }
      final old = ownGroupRequest(id);
      if (old == null && _groupRequests.length >= 500) {
        throw StateError('Đã đủ 500 yêu cầu demo.');
      }
      final withdrawing = joined.contains(id) || old?.state == 'pending';
      final next = DemoGroupRequest(
        groupId: id,
        member: user!.identifier,
        state: withdrawing ? 'withdrawn' : 'pending',
        created: old?.created ?? now,
        updated: now,
        revision: old == null ? 0 : old.revision + 1,
      );
      if (old == null) {
        _groupRequests.add(next);
      } else {
        _groupRequests[_groupRequests.indexOf(old)] = next;
      }
      if (withdrawing) joined.remove(id);
      _changed();
      return;
    }
    if (!joined.remove(id)) joined.add(id);
    _changed();
  }

  DemoPost createPost(String groupId, String text) {
    _requireReady();
    if (user == null) throw StateError('Vui lòng đăng nhập.');
    if (groupId != 'public' && !joinedGroups.contains(groupId)) {
      throw StateError('Tham gia nhóm trước khi đăng bài.');
    }
    final message = text.trim();
    if (message.isEmpty || message.length > 1000) {
      throw StateError('Nội dung cần 1–1.000 ký tự.');
    }
    final p = DemoPost(
      id: 'BD${_nextPost.toString().padLeft(4, '0')}',
      owner: user!.identifier,
      author: user!.name,
      groupId: groupId,
      message: message,
      created: now,
    );
    _nextPost++;
    _posts.add(p);
    _changed();
    return p;
  }

  bool deletePost(DemoPost p) {
    _requireReady();
    if (user == null || p.owner != user!.identifier || !_posts.remove(p)) {
      return false;
    }
    _operations.hiddenPosts.remove(p.id);
    _changed();
    return true;
  }

  DemoExpense createExpense(String title, int amount, List<String> names) {
    _requireReady();
    if (user == null) throw StateError('Vui lòng đăng nhập.');
    final e = DemoExpense(
      id: 'CP${(_expenses.length + 1).toString().padLeft(4, '0')}',
      owner: user!.identifier,
      title: title.trim(),
      amount: amount,
      names: List.unmodifiable(names.map((n) => n.trim())),
      created: now,
    );
    try {
      DemoExpense.fromJson(e.toJson());
    } on FormatException {
      throw StateError(
        'Nhập khoản chi và 2–20 tên khác nhau; số tiền từ 1 đến 100.000.000đ.',
      );
    }
    _expenses.add(e);
    _changed();
    return e;
  }

  DemoRecovery? _recovery;
  DemoRecovery beginDemoRecovery(String identifier) {
    _requireReady();
    if (_recovery != null && now.isBefore(_recovery!.resendAt)) {
      throw StateError('Chờ 60 giây trước khi yêu cầu mã mới.');
    }
    final id = normalize(identifier);
    if (id != phone && id != email && !_registered.containsKey(id)) {
      throw StateError('Tài khoản chưa được đăng ký trên thiết bị này.');
    }
    return _recovery = DemoRecovery(
      identifier: id == email ? phone : id,
      issued: now,
    );
  }

  void verifyDemoRecovery(DemoRecovery recovery, String code) {
    _requireReady();
    _requireRecovery(recovery);
    if (recovery.attempts >= 5) {
      throw StateError('Đã nhập sai 5 lần. Hãy yêu cầu mã mới.');
    }
    if (code.trim() != DemoRecovery.code) {
      recovery.attempts++;
      throw StateError('Mã không đúng. Còn ${5 - recovery.attempts} lần thử.');
    }
    recovery.verified = true;
  }

  void _requireRecovery(DemoRecovery recovery) {
    if (!identical(recovery, _recovery) ||
        recovery.consumed ||
        !now.isBefore(recovery.expires)) {
      throw StateError(
        'Mã hết hạn hoặc không còn hiệu lực. Hãy yêu cầu mã mới.',
      );
    }
  }

  void resetDemoPassword(DemoRecovery recovery, String next) {
    _requireReady();
    _requireRecovery(recovery);
    if (!recovery.verified) throw StateError('Vui lòng xác nhận mã trước.');
    if (next.length < 8 ||
        next.length > 128 ||
        !RegExp(r'[A-Za-z]').hasMatch(next) ||
        !RegExp(r'\d').hasMatch(next)) {
      throw StateError('Mật khẩu cần 8–128 ký tự, có chữ và số.');
    }
    if (recovery.identifier == phone) {
      _demoPassword = next;
    } else {
      final record = _registered[recovery.identifier]!;
      _registered[recovery.identifier] = (user: record.user, password: next);
    }
    recovery.consumed = true;
    if (user?.identifier == recovery.identifier) user = null;
    _changed();
  }

  List<DemoParticipation> get participations => List.unmodifiable(
    _participations.where((p) => p.owner == user?.identifier).toList()
      ..sort((a, b) => b.start.compareTo(a.start)),
  );

  int eventSeats(String eventId, DateTime start) =>
      (_activityEvent(eventId) ??
              (throw StateError('Không tìm thấy hoạt động.')))
          .capacity -
      _participations
          .where(
            (p) =>
                p.eventId == eventId &&
                p.start == start &&
                !p.cancelled &&
                !_socialReservationExpired(p),
          )
          .fold<int>(0, (sum, p) => sum + p.quantity);

  DemoParticipation joinEvent({
    required String eventId,
    required DateTime start,
    required int quantity,
    required String contact,
    required String contactPhone,
    String team = '',
    String partner = '',
    DemoTournamentRegistration? registration,
    bool socialCheckout = false,
    String note = '',
  }) {
    _requireReady();
    expireSocialTickets();
    if (user == null || role != DemoRole.player) {
      throw StateError('Vui lòng đăng nhập tài khoản người chơi.');
    }
    if (!availableEvents.any((e) => e.id == eventId)) {
      throw StateError('Sự kiện không tồn tại.');
    }
    final event = _activityEvent(eventId)!;
    final activity = _activities.where((a) => a.id == eventId).firstOrNull;
    if (activity != null &&
        activity.groupId.isNotEmpty &&
        !joinedGroups.contains(activity.groupId)) {
      throw StateError('Tham gia nhóm trước khi đăng ký hoạt động này.');
    }
    if (start != event.start(now) ||
        !(socialCheckout && event.kind == DemoEventKind.social
            ? event.end(start).isAfter(now)
            : start.isAfter(now))) {
      throw StateError('Lịch tham gia không còn khả dụng.');
    }
    if (eventCancellation(eventId, start) != null) {
      throw StateError('Buổi này đã bị hủy, không thể đăng ký.');
    }
    if (participations.any(
      (p) => p.eventId == eventId && p.start == start && !p.cancelled,
    )) {
      throw StateError('Bạn đã đăng ký lịch này.');
    }
    final p = DemoParticipation(
      id: 'VE${(_participations.length + 1).toString().padLeft(4, '0')}',
      owner: user!.identifier,
      eventId: eventId,
      start: start,
      quantity: quantity,
      contact: contact.trim(),
      phone: normalize(contactPhone),
      team: team.trim(),
      partner: partner.trim(),
      registration: registration,
      socialCheckout: socialCheckout,
      note: note.trim(),
      eventSnapshot: event.scheduledStart == null ? null : event,
    );
    try {
      DemoParticipation.fromJson(p.toJson());
      if (registration != null && registration.birthYear > now.year) {
        throw const FormatException('Invalid birth year');
      }
    } on FormatException {
      throw StateError('Kiểm tra số vé và thông tin đăng ký.');
    }
    if (quantity > eventSeats(eventId, start)) {
      throw StateError('Không còn đủ chỗ.');
    }
    _participations.add(p);
    if (socialCheckout) {
      final until = now.add(const Duration(minutes: 15));
      final cutoff = p.event.end(p.start);
      _payments[p.id] = DemoPayment(
        bookingId: p.id,
        deadline: until.isBefore(cutoff) ? until : cutoff,
      );
      _recordOperation(
        'Giữ ${p.quantity} vé social ${p.id} trong tối đa 15 phút',
      );
    }
    _changed();
    return p;
  }

  bool cancelParticipation(DemoParticipation p) {
    _requireReady();
    if (!_participations.contains(p) ||
        user == null ||
        p.owner != user!.identifier ||
        p.cancelled ||
        p.checkedIn ||
        p.attendance != DemoAttendance.pending ||
        _payments.containsKey(p.id) ||
        !p.start.isAfter(now)) {
      return false;
    }
    p.cancelled = true;
    _changed();
    return true;
  }

  bool demoCheckIn(DemoParticipation p) {
    _requireReady();
    if (!_participations.contains(p) ||
        user == null ||
        p.owner != user!.identifier ||
        p.cancelled ||
        p.checkedIn ||
        p.attendance != DemoAttendance.pending ||
        (_payments.containsKey(p.id) &&
            (_payments[p.id]!.state != DemoPaymentState.approved ||
                _payments[p.id]!.cancellation ==
                    DemoCancellationState.requested)) ||
        now.isBefore(p.start.subtract(const Duration(minutes: 30))) ||
        !now.isBefore(p.event.end(p.start))) {
      return false;
    }
    p.checkedIn = true;
    p.attendance = DemoAttendance.checkedIn;
    _changed();
    return true;
  }

  List<DemoConversation> get conversations => List.unmodifiable(
    [...?_chats[user?.identifier]]..sort(
      (a, b) => b.messages.last.created.compareTo(a.messages.last.created),
    ),
  );
  int get unreadMessages => conversations.fold(0, (sum, c) => sum + c.unread);

  bool _ensureChats() {
    if (user == null ||
        user!.role != DemoRole.player ||
        _chats.containsKey(user!.identifier)) {
      return false;
    }
    _chats[user!.identifier] = seedConversations(now);
    return true;
  }

  DemoConversation conversation(String contactId) {
    _requireReady();
    if (user == null) throw StateError('Vui lòng đăng nhập.');
    return conversations.singleWhere(
      (c) => c.contactId == contactId,
      orElse: () => throw StateError('Cuộc trò chuyện không tồn tại.'),
    );
  }

  void markChatRead(String contactId) {
    final current = conversation(contactId);
    if (current.unread == 0) return;
    final list = _chats[user!.identifier]!;
    list[list.indexOf(current)] = current.copy(unread: 0);
    _changed();
  }

  void markAllChatsRead() {
    _requireReady();
    if (user == null) throw StateError('Vui lòng đăng nhập.');
    if (unreadMessages == 0) return;
    _chats[user!.identifier] = [
      for (final c in conversations) c.copy(unread: 0),
    ];
    _changed();
  }

  DemoChatMessage sendChatMessage(
    String contactId,
    String text, {
    Uint8List? image,
    Uint8List? voice,
  }) {
    final current = conversation(contactId);
    final trimmed = text.trim();
    if ((trimmed.isEmpty && image == null && voice == null) ||
        trimmed.length > 2000 ||
        (image != null && voice != null)) {
      throw StateError('Tin nhắn cần có từ 1 đến 2.000 ký tự hoặc một ảnh.');
    }
    var encoded = '';
    var audio = '';
    var milliseconds = 0;
    if (voice != null) {
      if (conversations
              .expand((c) => c.messages)
              .where((m) => m.voice.isNotEmpty)
              .length >=
          maxChatVoicesPerAccount) {
        throw StateError('Đã đủ 20 bản ghi chat trong tài khoản demo.');
      }
      try {
        milliseconds = voiceDurationMillis(voice);
        audio = encodeVoice(voice);
      } on FormatException catch (e) {
        throw StateError(e.message);
      }
    }
    if (image != null) {
      if (conversations
              .expand((c) => c.messages)
              .where((m) => m.image.isNotEmpty)
              .length >=
          maxChatImagesPerAccount) {
        throw StateError('Đã đủ 20 ảnh chat trong tài khoản demo.');
      }
      try {
        encoded = encodeProof(image);
      } on FormatException catch (e) {
        throw StateError(e.message);
      }
    }
    // Sequence is scoped to a persisted conversation, not a wall-clock timestamp.
    var sequence = current.messages.length;
    while (current.messages.any((m) => m.id == 'local-$sequence')) {
      sequence++;
    }
    final message = DemoChatMessage(
      id: 'local-$sequence',
      text: trimmed,
      created: now,
      outgoing: true,
      image: encoded,
      voice: audio,
      voiceMillis: milliseconds,
    );
    final list = _chats[user!.identifier]!;
    list[list.indexOf(current)] = current.copy(
      messages: [...current.messages, message],
      unread: 0,
    );
    _changed();
    return message;
  }

  String get contactPhone =>
      _contactPhones[user?.identifier] ??
      (user != null && RegExp(r'^0[35789]\d{8}$').hasMatch(user!.identifier)
          ? user!.identifier
          : '');
  List<DemoVoucher> get vouchers => user == null
      ? []
      : demoVouchers
            .where(
              (v) => !_bookings.any(
                (b) =>
                    b.owner == user!.identifier &&
                    !b.cancelled &&
                    b.voucherCode == v.code,
              ),
            )
            .toList();
  int get points => user == null
      ? 0
      : (user!.seeded ? 1040 : 0) +
            bookings
                .where((b) => !b.cancelled)
                .fold(0, (sum, b) => sum + b.total ~/ 1000);
  List<DemoEnrollment> get enrollments => List.unmodifiable(
    _enrollments.where((e) => e.owner == user?.identifier).toList()
      ..sort((a, b) => b.start.compareTo(a.start)),
  );
  List<DemoSupportTicket> get tickets => List.unmodifiable(
    _tickets.where((t) => t.owner == user?.identifier).toList()
      ..sort((a, b) => b.created.compareTo(a.created)),
  );
  int courseSeats(String courseId, DateTime start) =>
      DemoCourse.capacity -
      _enrollments
          .where(
            (e) => e.courseId == courseId && e.start == start && !e.cancelled,
          )
          .length;
  DemoEnrollment enroll(String courseId, DateTime start) {
    _requireReady();
    if (user == null) throw StateError('Vui lòng đăng nhập.');
    final courses = demoCourses.where((c) => c.id == courseId);
    if (courses.isEmpty ||
        start != courses.first.start(now) ||
        !start.isAfter(now)) {
      throw StateError('Lịch học không còn khả dụng.');
    }
    if (enrollments.any(
      (e) => e.courseId == courseId && e.start == start && !e.cancelled,
    )) {
      throw StateError('Bạn đã đăng ký buổi học này.');
    }
    if (courseSeats(courseId, start) <= 0) {
      throw StateError('Buổi học đã đủ chỗ.');
    }
    final enrollment = DemoEnrollment(
      id: 'HL${(_enrollments.length + 1).toString().padLeft(4, '0')}',
      owner: user!.identifier,
      courseId: courseId,
      start: start,
    );
    _enrollments.add(enrollment);
    _changed();
    return enrollment;
  }

  bool cancelEnrollment(DemoEnrollment enrollment) {
    _requireReady();
    if (!_enrollments.contains(enrollment) ||
        enrollment.owner != user?.identifier ||
        enrollment.cancelled ||
        !enrollment.start.isAfter(now)) {
      return false;
    }
    enrollment.cancelled = true;
    _changed();
    return true;
  }

  void updateContactPhone(String value) {
    _requireReady();
    final normalized = normalize(value);
    if (user == null || !RegExp(r'^0[35789]\d{8}$').hasMatch(normalized)) {
      throw StateError('Nhập số điện thoại hợp lệ.');
    }
    _contactPhones[user!.identifier] = normalized;
    _changed();
  }

  void clearContactPhone() {
    _requireReady();
    if (user == null) throw StateError('Vui lòng đăng nhập.');
    _contactPhones[user!.identifier] = '';
    _changed();
  }

  bool changePassword(String current, String next) {
    _requireReady();
    if (user == null ||
        next.length < 8 ||
        next.length > 128 ||
        !RegExp(r'[A-Za-z]').hasMatch(next) ||
        !RegExp(r'\d').hasMatch(next)) {
      return false;
    }
    final id = user!.identifier;
    if (user!.role != DemoRole.player) {
      final record = _staff[id]!;
      if (current != record.password) return false;
      _staff[id] = (user: record.user, password: next);
      if (user!.role == DemoRole.admin) {
        _recordOperation('Đổi mật khẩu quản trị');
      }
    } else if (user!.seeded) {
      if (current != _demoPassword) return false;
      _demoPassword = next;
    } else {
      final record = _registered[id]!;
      if (current != record.password) return false;
      _registered[id] = (user: record.user, password: next);
    }
    _changed();
    return true;
  }

  DemoSupportTicket createTicket(String subject, String message) {
    _requireReady();
    if (user == null ||
        subject.trim().isEmpty ||
        subject.trim().length > 80 ||
        message.trim().length < 10 ||
        message.trim().length > 1000) {
      throw StateError('Kiểm tra tiêu đề và nội dung (10–1.000 ký tự).');
    }
    final ticket = DemoSupportTicket(
      id: 'HT${(_tickets.length + 1).toString().padLeft(4, '0')}',
      owner: user!.identifier,
      subject: subject.trim(),
      message: message.trim(),
      created: now,
    );
    _tickets.add(ticket);
    _changed();
    return ticket;
  }

  bool closeTicket(DemoSupportTicket ticket) {
    _requireReady();
    if (!_tickets.contains(ticket) ||
        ticket.owner != user?.identifier ||
        ticket.closed) {
      return false;
    }
    ticket.closed = true;
    _changed();
    return true;
  }

  Set<String> get favoriteVenueIds => Set.unmodifiable(
    _favorites[user?.identifier ?? _guestOwner] ?? <String>{},
  );
  bool isFavorite(String venueId) => favoriteVenueIds.contains(venueId);
  List<DemoPaymentMethod> get savedPaymentMethods {
    _requireReady();
    if (user == null || role != DemoRole.player) return const [];
    return List.unmodifiable(_paymentMethods[user!.identifier] ?? []);
  }

  void savePaymentMethod(String provider, String last4) {
    _requireReady();
    if (user == null || role != DemoRole.player) {
      throw StateError('Vui lòng đăng nhập tài khoản khách hàng.');
    }
    final method = DemoPaymentMethod.fromJson({
      'provider': provider,
      'last4': last4,
    });
    final methods = _paymentMethods.putIfAbsent(user!.identifier, () => []);
    if (methods.length >= 5 ||
        methods.any(
          (m) => m.id == method.id || (!m.isCard && m.provider == provider),
        )) {
      throw StateError('Phương thức đã tồn tại hoặc đã đủ 5 phương thức.');
    }
    methods.add(
      DemoPaymentMethod(
        provider: provider,
        last4: last4,
        isDefault: methods.isEmpty,
      ),
    );
    _changed();
  }

  void updatePaymentMethod(String id, {bool remove = false}) {
    _requireReady();
    if (user == null || role != DemoRole.player) {
      throw StateError('Vui lòng đăng nhập.');
    }
    final methods = _paymentMethods[user!.identifier];
    if (methods == null || !methods.any((m) => m.id == id)) {
      throw StateError('Phương thức không còn tồn tại.');
    }
    if (remove) methods.removeWhere((m) => m.id == id);
    final defaultId = remove
        ? (methods.where((m) => m.isDefault).firstOrNull?.id ??
              methods.firstOrNull?.id)
        : id;
    _paymentMethods[user!.identifier] = [
      for (final m in methods)
        DemoPaymentMethod(
          provider: m.provider,
          last4: m.last4,
          isDefault: m.id == defaultId,
        ),
    ];
    _changed();
  }

  void toggleFavorite(String venueId) {
    _requireReady();
    if (!currentVenues.any((venue) => venue.id == venueId)) {
      throw ArgumentError.value(venueId);
    }
    final favorites = _favorites.putIfAbsent(
      user?.identifier ?? _guestOwner,
      () => <String>{},
    );
    if (!favorites.remove(venueId)) favorites.add(venueId);
    _changed();
  }

  Future<void> initialize() async {
    if (initialized || loading) return;
    loading = true;
    loadFailed = false;
    _notify();
    try {
      if (venueCatalogLoader != null) {
        final catalog = await venueCatalogLoader!();
        if (_disposed) return;
        _discoveryVenues = List.unmodifiable(catalog);
      }
      final stored = await _store!.read();
      if (_disposed) return;
      if (stored != null) _restore(stored);
      final seedNeeded =
          demoFixtureLoader != null && _demoSeedVersion < demoSeedVersion;
      if (seedNeeded) {
        final assets = await demoFixtureLoader!();
        if (_disposed) return;
        installDemoFixtures(assets.photo, proof: assets.proof);
      }
      initialized = true;
      expireSocialTickets();
      final seededChats = _ensureChats();
      if (stored == null || seededChats || seedNeeded) {
        _queueSave();
        await flush();
      }
    } catch (_) {
      loadFailed = true;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> flush() async {
    await _pending;
    return !saveFailed;
  }

  Future<void> retrySave() async {
    if (!initialized) return;
    _queueSave();
    await flush();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    _queueSave();
    _notify();
  }

  void _queueSave() {
    if (_store == null || !initialized) return;
    final snapshot = _snapshot();
    // Capture each state before queueing so slower writes cannot reorder changes.
    _pending = _pending.then((_) async {
      try {
        await _store.write(snapshot);
        saveFailed = false;
      } catch (_) {
        saveFailed = true;
      }
      _notify();
    });
  }

  String _snapshot() => jsonEncode({
    'version': 1,
    'demoSeedVersion': _demoSeedVersion,
    'demoName': _demoUser.name,
    'demoPassword': _demoPassword,
    'staff': {
      for (final e in _staff.entries)
        e.key: {'name': e.value.user.name, 'password': e.value.password},
    },
    'payments': [for (final p in _payments.values) p.toJson()],
    'paymentMethods': {
      for (final e in _paymentMethods.entries)
        e.key: e.value.map((m) => m.toJson()).toList(),
    },
    'disputes': [for (final d in _disputes) d.toJson()],
    'reviews': [for (final r in _reviews) r.toJson()],
    'shifts': [for (final s in _shifts) s.toJson()],
    'nextShift': _nextShift,
    'proofPickerTarget': _proofPickerTarget,
    'operations': _operations.toJson(),
    'employeeAccess': {
      for (final e in _employeeAccess.entries) e.key: e.value.toJson(),
    },
    'activeEmployee': initialized ? activeEmployee?.id : _activeEmployeeId,
    'ownerVerification': _ownerVerification?.toJson(),
    'venueClaims': [for (final c in _venueClaims) c.toJson()],
    'payoutAccount': _payoutAccount?.toJson(),
    'payouts': [for (final p in _payouts) p.toJson()],
    'nextPayout': _nextPayout,
    'facilities': _facilities.map((f) => f.toJson()).toList(),
    'primaryFacilityProfile': _primaryFacilityProfile?.toJson(),
    'nextFacility': _nextFacility,
    'primaryCancellationPolicy': _primaryCancellationPolicy.toJson(),
    'primaryCancellationRevision': _primaryCancellationRevision,
    'facilityFormDrafts': _facilityFormDrafts.values
        .map((d) => d.toJson())
        .toList(),
    'courtBlocks': _courtBlocks.map((b) => b.toJson()).toList(),
    'facilityTariffs': _facilityTariffs.values.map((p) => p.toJson()).toList(),
    'nextBlock': _nextBlock,
    'contactPhones': _contactPhones,
    'enrollments': [for (final enrollment in _enrollments) enrollment.toJson()],
    'tickets': [for (final ticket in _tickets) ticket.toJson()],
    'participations': [for (final p in _participations) p.toJson()],
    'activities': [for (final a in _activities) a.toJson()],
    'eventCancellations': [for (final c in _eventCancellations) c.toJson()],
    'nextActivity': _nextActivity,
    'courtTypes': [for (final t in _courtTypes) t.toJson()],
    'nextCourtType': _nextCourtType,
    'matches': [for (final m in _matches) m.toJson()],
    'nextMatch': _nextMatch,
    'posts': [for (final p in _posts) p.toJson()],
    'nextPost': _nextPost,
    'playGroups': [for (final g in _playGroups) g.toJson()],
    'nextPlayGroup': _nextPlayGroup,
    'groupRequests': [for (final r in _groupRequests) r.toJson()],
    'groups': {for (final e in _groups.entries) e.key: e.value.toList()},
    'expenses': [for (final e in _expenses) e.toJson()],
    'chats': {
      for (final entry in _chats.entries)
        entry.key: [for (final chat in entry.value) chat.toJson()],
    },
    'activeUser': user?.identifier,
    'users': [
      for (final record in _registered.values)
        {
          'name': record.user.name,
          'identifier': record.user.identifier,
          'password': record.password,
          'registeredAt': record.user.registeredAt?.toIso8601String(),
        },
    ],
    'bookings': [for (final booking in _bookings) booking.toJson()],
    'favorites': {
      for (final entry in _favorites.entries) entry.key: entry.value.toList(),
    },
  });

  void _restore(String stored) {
    final data = jsonDecode(stored) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unsupported version');
    }
    final demoName = data['demoName'] as String;
    if (demoName.trim().isEmpty || demoName.length > 60) {
      throw const FormatException('Invalid name');
    }
    final registered = <String, ({DemoUser user, String password})>{};
    for (final raw in data['users'] as List<dynamic>) {
      final record = raw as Map<String, dynamic>;
      final identifier = record['identifier'] as String;
      final name = record['name'] as String;
      final secret = record['password'] as String;
      if (identifier != normalize(identifier) ||
          identifier == phone ||
          identifier == email ||
          registered.containsKey(identifier) ||
          name.trim().isEmpty ||
          name.length > 60 ||
          secret.isEmpty ||
          !(RegExp(r'^0[35789]\d{8}$').hasMatch(identifier) ||
              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(identifier))) {
        throw const FormatException('Invalid user');
      }
      registered[identifier] = (
        user: DemoUser(
          name: name,
          identifier: identifier,
          registeredAt: record['registeredAt'] == null
              ? null
              : DateTime.parse(record['registeredAt'] as String).toLocal(),
        ),
        password: secret,
      );
    }
    final staff = <String, ({DemoUser user, String password})>{};
    final storedStaff = data['staff'] as Map<String, dynamic>? ?? {};
    if (storedStaff.keys.any((id) => !_staff.containsKey(id))) {
      throw const FormatException('Unknown staff identity');
    }
    for (final e in _staff.entries) {
      final raw = storedStaff[e.key] as Map<String, dynamic>?;
      final name = raw?['name'] as String? ?? e.value.user.name;
      final secret = raw?['password'] as String? ?? e.value.password;
      if (name.trim().isEmpty ||
          name.length > 60 ||
          secret.isEmpty ||
          secret.length > 128) {
        throw const FormatException('Invalid staff');
      }
      staff[e.key] = (
        user: DemoUser(name: name, identifier: e.key, role: e.value.user.role),
        password: secret,
      );
    }
    final bookings = (data['bookings'] as List<dynamic>)
        .map((raw) => DemoBooking.fromJson(raw as Map<String, dynamic>))
        .toList();
    final ids = <String>{};
    for (final booking in bookings) {
      if (!ids.add(booking.id) ||
          (booking.owner != phone && !registered.containsKey(booking.owner))) {
        throw const FormatException('Invalid booking owner');
      }
    }
    final active = data['activeUser'] as String?;
    final previousEnd = <String, DateTime>{};
    final liveBookings = bookings.where((b) => !b.cancelled).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final b in liveBookings) {
      final key = '${b.facilityId}:${b.court}';
      if (previousEnd[key]?.isAfter(b.start) == true) {
        throw const FormatException('Overlapping bookings');
      }
      previousEnd[key] = b.end;
    }
    if (active != null &&
        active != phone &&
        !registered.containsKey(active) &&
        !staff.containsKey(active)) {
      throw const FormatException('Invalid active user');
    }
    final favorites = <String, Set<String>>{};
    bool validOwner(String owner) =>
        owner == phone ||
        registered.containsKey(owner) ||
        staff.containsKey(owner);
    final demoPassword = (data['demoPassword'] ?? password) as String;
    if (demoPassword.isEmpty) throw const FormatException('Invalid password');
    final contactPhones = (data['contactPhones'] as Map<String, dynamic>? ?? {})
        .cast<String, String>();
    if (contactPhones.entries.any(
      (e) =>
          !validOwner(e.key) ||
          (e.value.isNotEmpty && !RegExp(r'^0[35789]\d{8}$').hasMatch(e.value)),
    )) {
      throw const FormatException('Invalid contact');
    }
    final enrollments = (data['enrollments'] as List<dynamic>? ?? [])
        .map((e) => DemoEnrollment.fromJson(e as Map<String, dynamic>))
        .toList();
    final tickets = (data['tickets'] as List<dynamic>? ?? [])
        .map((e) => DemoSupportTicket.fromJson(e as Map<String, dynamic>))
        .toList();
    if (enrollments.any((e) => !validOwner(e.owner)) ||
        tickets.any((t) => !validOwner(t.owner)) ||
        enrollments.map((e) => e.id).toSet().length != enrollments.length ||
        tickets.map((t) => t.id).toSet().length != tickets.length) {
      throw const FormatException('Invalid extras owner');
    }
    final usedVouchers = <String>{};
    final enrolledOwners = <String>{};
    final seats = <String, int>{};
    for (final enrollment in enrollments.where((e) => !e.cancelled)) {
      final slot =
          '${enrollment.courseId}:${enrollment.start.toIso8601String()}';
      if (!enrolledOwners.add('${enrollment.owner}:$slot')) {
        throw const FormatException('Duplicate enrollment');
      }
      seats[slot] = (seats[slot] ?? 0) + 1;
      if (seats[slot]! > DemoCourse.capacity) {
        throw const FormatException('Course capacity exceeded');
      }
    }
    for (final booking in bookings.where((b) => b.voucherCode != null)) {
      final voucher = demoVouchers.where((v) => v.code == booking.voucherCode);
      if (voucher.isEmpty ||
          voucher.first.discount(booking.subtotal) != booking.discount ||
          (!booking.cancelled &&
              !usedVouchers.add('${booking.owner}:${booking.voucherCode}'))) {
        throw const FormatException('Invalid voucher');
      }
    }
    // Optional additive field keeps snapshots from the previous APK compatible.
    if (data['favorites'] != null) {
      for (final entry in (data['favorites'] as Map<String, dynamic>).entries) {
        if (entry.key != _guestOwner &&
            entry.key != phone &&
            !registered.containsKey(entry.key) &&
            !staff.containsKey(entry.key)) {
          throw const FormatException('Invalid favorites owner');
        }
        final ids = (entry.value as List<dynamic>).cast<String>().toSet();
        favorites[entry.key] = ids
            .where(
              (id) =>
                  demoVenues.any((venue) => venue.id == id) ||
                  _discoveryVenues.any((venue) => venue.id == id) ||
                  RegExp(r'^CS\d{4,}$').hasMatch(id),
            )
            .toSet();
      }
    }
    final chats = <String, List<DemoConversation>>{};
    for (final entry
        in (data['chats'] as Map<String, dynamic>? ?? {}).entries) {
      final threads = (entry.value as List<dynamic>)
          .map((raw) => DemoConversation.fromJson(raw as Map<String, dynamic>))
          .toList();
      if (!validOwner(entry.key) ||
          threads
                  .expand((c) => c.messages)
                  .where((m) => m.voice.isNotEmpty)
                  .length >
              maxChatVoicesPerAccount ||
          threads
                  .expand((c) => c.messages)
                  .where((m) => m.image.isNotEmpty)
                  .length >
              maxChatImagesPerAccount ||
          threads.map((c) => c.contactId).toSet().length != threads.length) {
        throw const FormatException(
          'Invalid chat owner or duplicate conversation',
        );
      }
      chats[entry.key] = threads;
    }
    final activities = (data['activities'] as List<dynamic>? ?? [])
        .map((raw) => DemoActivity.fromJson(raw as Map<String, dynamic>))
        .toList();
    final nextActivity = (data['nextActivity'] ?? 1) as int;
    final activityKeys = <String>{};
    if (activities.length > 100 ||
        nextActivity < 1 ||
        activities
                .map(
                  (a) =>
                      '${venueSearchText(a.event.title)}:${a.event.scheduledStart}',
                )
                .toSet()
                .length !=
            activities.length ||
        activities.any(
          (a) =>
              !validOwner(a.owner) ||
              !activityKeys.add(a.id) ||
              int.parse(a.id.substring(2)) >= nextActivity,
        )) {
      throw const FormatException('Invalid activity registry');
    }
    final participations = (data['participations'] as List<dynamic>? ?? [])
        .map((raw) => DemoParticipation.fromJson(raw as Map<String, dynamic>))
        .toList();
    final participationIds = <String>{};
    final eventCancellations =
        (data['eventCancellations'] as List<dynamic>? ?? [])
            .map(
              (raw) =>
                  DemoEventCancellation.fromJson(raw as Map<String, dynamic>),
            )
            .toList();
    if (eventCancellations.length > 1000 ||
        eventCancellations.map((c) => c.key).toSet().length !=
            eventCancellations.length ||
        eventCancellations.any(
          (c) => participations.any(
            (p) => p.eventId == c.eventId && p.start == c.start && !p.cancelled,
          ),
        )) {
      throw const FormatException('Invalid cancelled occurrence history');
    }
    final participantSlots = <String>{};
    final eventCounts = <String, int>{};
    for (final p in participations) {
      if (p.eventSnapshot != null) {
        final a = activities.where((a) => a.id == p.eventId).firstOrNull;
        if (a == null ||
            !['approved', 'suspended', 'cancelled'].contains(a.state) ||
            !mapEquals(a.event.toJson(), p.eventSnapshot!.toJson())) {
          throw const FormatException('Invalid ticket activity link');
        }
      }
      if (!validOwner(p.owner) || !participationIds.add(p.id)) {
        throw const FormatException(
          'Invalid participation owner or duplicate id',
        );
      }
      if (p.cancelled) continue;
      final slot = '${p.eventId}:${p.start.toIso8601String()}';
      if (!participantSlots.add('${p.owner}:$slot')) {
        throw const FormatException('Duplicate participation');
      }
      eventCounts[slot] = (eventCounts[slot] ?? 0) + p.quantity;
      if (eventCounts[slot]! > p.event.capacity) {
        throw const FormatException('Event capacity exceeded');
      }
    }
    final matches = (data['matches'] as List<dynamic>? ?? [])
        .map((raw) => DemoMatch.fromJson(raw as Map<String, dynamic>))
        .toList();
    if (activities
        .where((a) => a.state == 'cancelled')
        .any(
          (a) =>
              participations.any((p) => p.eventId == a.id && !p.cancelled) ||
              matches.any(
                (m) =>
                    m.state != 'cancelled' &&
                    participations.any(
                      (p) => p.id == m.first && p.eventId == a.id,
                    ),
              ),
        )) {
      throw const FormatException('Invalid cancelled activity history');
    }
    final nextMatch = (data['nextMatch'] ?? 1) as int;
    if (eventCancellations.any(
      (c) => matches.any(
        (m) =>
            m.state != 'cancelled' &&
            participations.any(
              (p) =>
                  p.id == m.first &&
                  p.eventId == c.eventId &&
                  p.start == c.start,
            ),
      ),
    )) {
      throw const FormatException('Invalid cancelled occurrence fixtures');
    }
    validateMatches(matches, participations, nextMatch);
    final playGroups = (data['playGroups'] as List<dynamic>? ?? [])
        .map((raw) => DemoPlayGroup.fromJson(raw as Map<String, dynamic>))
        .toList();
    final nextPlayGroup = (data['nextPlayGroup'] ?? 1) as int;
    final additionalGroups = playGroups.map((g) => g.id).toSet();
    final historicalGroups = playGroups
        .where((g) => ['approved', 'suspended'].contains(g.state))
        .map((g) => g.id)
        .toSet();
    if (playGroups.length > 100 ||
        nextPlayGroup < 1 ||
        additionalGroups.length != playGroups.length ||
        playGroups.map((g) => venueSearchText(g.name)).toSet().length !=
            playGroups.length ||
        playGroups.any(
          (g) =>
              !validOwner(g.owner) ||
              int.parse(g.id.substring(2)) >= nextPlayGroup ||
              demoGroups.values.any(
                (name) => venueSearchText(name) == venueSearchText(g.name),
              ),
        )) {
      throw const FormatException('Invalid group registry');
    }
    final posts = (data['posts'] as List<dynamic>? ?? [])
        .map(
          (raw) => DemoPost.fromJson(
            raw as Map<String, dynamic>,
            additionalGroups: historicalGroups,
          ),
        )
        .toList();
    final expenses = (data['expenses'] as List<dynamic>? ?? [])
        .map((raw) => DemoExpense.fromJson(raw as Map<String, dynamic>))
        .toList();
    if (activities.any(
      (a) =>
          a.groupId.isNotEmpty &&
          !playGroups.any(
            (g) =>
                g.id == a.groupId &&
                g.owner == a.owner &&
                g.sport == 'badminton' &&
                historicalGroups.contains(g.id),
          ),
    )) {
      throw const FormatException('Invalid activity group link');
    }
    final groups = <String, Set<String>>{};
    for (final e in (data['groups'] as Map<String, dynamic>? ?? {}).entries) {
      final ids = (e.value as List).cast<String>().toSet();
      if (!validOwner(e.key) ||
          ids.any(
            (id) =>
                !demoGroups.containsKey(id) && !historicalGroups.contains(id),
          )) {
        throw const FormatException('Invalid membership');
      }
      groups[e.key] = ids;
    }
    final nextPost = (data['nextPost'] ?? 1) as int;
    final groupRequests = (data['groupRequests'] as List<dynamic>? ?? [])
        .map((raw) => DemoGroupRequest.fromJson(raw as Map<String, dynamic>))
        .toList();
    if (groupRequests.length > 500 ||
        groupRequests.map((r) => r.key).toSet().length !=
            groupRequests.length ||
        groupRequests.any((r) {
          final g = playGroups.where((g) => g.id == r.groupId).firstOrNull;
          return (r.member != phone && !registered.containsKey(r.member)) ||
              g == null ||
              !g.requiresApproval ||
              !historicalGroups.contains(g.id) ||
              r.created.isBefore(g.created) ||
              ((r.state == 'approved') !=
                  (groups[r.member]?.contains(g.id) ?? false));
        }) ||
        groups.entries.any(
          (e) => e.value.any((id) {
            final g = playGroups.where((g) => g.id == id).firstOrNull;
            return g?.requiresApproval == true &&
                !groupRequests.any(
                  (r) =>
                      r.member == e.key &&
                      r.groupId == id &&
                      r.state == 'approved',
                );
          }),
        )) {
      throw const FormatException('Invalid group requests');
    }
    if (nextPost < 1 ||
        posts.any(
          (p) =>
              !validOwner(p.owner) || int.parse(p.id.substring(2)) >= nextPost,
        ) ||
        expenses.any((e) => !validOwner(e.owner)) ||
        posts.map((p) => p.id).toSet().length != posts.length ||
        expenses.map((e) => e.id).toSet().length != expenses.length) {
      throw const FormatException('Invalid community snapshot');
    }
    final payments = <String, DemoPayment>{};
    for (final raw in (data['payments'] as List<dynamic>? ?? [])) {
      final p = DemoPayment.fromJson(raw as Map<String, dynamic>);
      final target = bookings.where((b) => b.id == p.bookingId).firstOrNull;
      final ticket = participations
          .where((b) => b.id == p.bookingId)
          .firstOrNull;
      final start = target?.start ?? ticket?.start;
      final cancelled = target?.cancelled ?? ticket?.cancelled ?? false;
      final total = target?.total ?? ticket?.total ?? 0;
      if (start == null ||
          (p.simulatedGateway &&
              (ticket == null ||
                  ticket.registration == null ||
                  ticket.event.kind != DemoEventKind.tournament)) ||
          payments.containsKey(p.bookingId) ||
          (p.deadline.isAfter(
                ticket?.socialCheckout == true
                    ? ticket!.event.end(start)
                    : start,
              ) &&
              p.state != DemoPaymentState.approved) ||
          (p.refundAmount != null && p.refundAmount! > total) ||
          (p.cancellationEstimate != null && p.cancellationEstimate! > total) ||
          (cancelled && p.cancellation != DemoCancellationState.accepted) ||
          (p.cancellation == DemoCancellationState.accepted && !cancelled) ||
          (p.refund != DemoRefundState.none && !cancelled) ||
          (p.cancellation == DemoCancellationState.accepted &&
              p.state == DemoPaymentState.approved &&
              p.refund == DemoRefundState.none)) {
        throw const FormatException('Invalid payment target/state');
      }
      payments[p.bookingId] = p;
    }
    if (participations.any(
      (ticket) => ticket.socialCheckout && !payments.containsKey(ticket.id),
    )) {
      throw const FormatException(
        'Social checkout requires a payment reservation',
      );
    }
    final disputes = (data['disputes'] as List<dynamic>? ?? [])
        .map((raw) => DemoDispute.fromJson(raw as Map<String, dynamic>))
        .toList();
    final disputeIds = <String>{};
    final openCases = <String>{};
    for (final d in disputes) {
      if (!disputeIds.add(d.id) ||
          (!bookings.any((b) => b.id == d.bookingId && b.owner == d.owner) &&
              !participations.any(
                (p) => p.id == d.bookingId && p.owner == d.owner,
              )) ||
          (d.resolution.isEmpty && !openCases.add(d.bookingId)) ||
          (d.closedAt != null &&
              d.decision == DemoDisputeDecision.refund &&
              (payments[d.bookingId]?.refund != DemoRefundState.recorded ||
                  payments[d.bookingId]?.refundRecordedAt == null ||
                  payments[d.bookingId]!.refundRecordedAt!.isAfter(
                    d.closedAt!,
                  ) ||
                  payments[d.bookingId]!.refundReference.isEmpty ||
                  payments[d.bookingId]!.refundProof.isEmpty))) {
        throw const FormatException('Invalid dispute target');
      }
    }
    final reviews = (data['reviews'] as List<dynamic>? ?? [])
        .map((raw) => DemoVenueReview.fromJson(raw as Map<String, dynamic>))
        .toList();
    final reviewIds = <String>{};
    for (final r in reviews) {
      final b = bookings.where((b) => b.id == r.bookingId).firstOrNull;
      if (!reviewIds.add(r.bookingId) ||
          b == null ||
          b.owner != r.owner ||
          b.cancelled ||
          b.attendance != DemoAttendance.completed ||
          payments[b.id]?.state != DemoPaymentState.approved ||
          r.created.isBefore(b.end)) {
        throw const FormatException('Invalid review target');
      }
    }
    final proofPickerTarget = data['proofPickerTarget'] as String?;
    if (proofPickerTarget != null && !payments.containsKey(proofPickerTarget)) {
      throw const FormatException('Invalid proof draft target');
    }
    final operations = data['operations'] == null
        ? DemoOperations()
        : DemoOperations.fromJson(data['operations'] as Map<String, dynamic>);
    final employeeAccess = <String, DemoEmployeeAccess>{
      for (final e
          in ((data['employeeAccess'] as Map<String, dynamic>?) ?? {}).entries)
        e.key: DemoEmployeeAccess.fromJson(e.value as Map<String, dynamic>),
    };
    final activeEmployee = data['activeEmployee'] as String?;
    final payoutAccount = data['payoutAccount'] == null
        ? null
        : DemoBankAccount.fromJson(
            data['payoutAccount'] as Map<String, dynamic>,
          );
    final payouts = (data['payouts'] as List? ?? [])
        .map((raw) => DemoPayout.fromJson(raw as Map<String, dynamic>))
        .toList();
    final nextPayout = (data['nextPayout'] ?? 1) as int;
    if (payouts.length > 500 ||
        nextPayout < 1 ||
        payouts.map((p) => p.id).toSet().length != payouts.length ||
        payouts.any(
          (p) =>
              int.parse(p.id.substring(2)) >= nextPayout ||
              payoutAccount == null ||
              p.account.revision > payoutAccount.revision,
        ) ||
        payouts
                .where((p) => p.state == 'recorded')
                .map((p) => p.reference.toLowerCase())
                .toSet()
                .length !=
            payouts.where((p) => p.state == 'recorded').length) {
      throw const FormatException('Invalid payout ledger');
    }
    final claims = (data['venueClaims'] as List? ?? [])
        .map((raw) => DemoVenueClaim.fromJson(raw as Map<String, dynamic>))
        .toList();
    final claimedVenues = <String>{};
    if (claims.length > 100 ||
        claims.map((c) => c.key).toSet().length != claims.length ||
        claims.any(
          (c) =>
              staff[c.owner]?.user.role != DemoRole.owner ||
              (c.reviewer.isNotEmpty &&
                  staff[c.reviewer]?.user.role != DemoRole.admin) ||
              (['pending', 'approved'].contains(c.state) &&
                  !claimedVenues.add(c.venueId)),
        )) {
      throw const FormatException('Invalid venue claim references');
    }
    final ownerVerification = data['ownerVerification'] == null
        ? null
        : DemoOwnerVerification.fromJson(
            data['ownerVerification'] as Map<String, dynamic>,
          );
    if (employeeAccess.keys.any(
          (id) => !operations.employees.any((e) => e.id == id),
        ) ||
        (activeEmployee != null &&
            (active != null || !employeeAccess.containsKey(activeEmployee)))) {
      throw const FormatException('Invalid employee access references');
    }
    if (operations.blocked.any(
          (id) => id != phone && !registered.containsKey(id),
        ) ||
        operations.accessDecisions.keys.any(
          (id) => id != phone && !registered.containsKey(id),
        ) ||
        operations.audit.any(
          (entry) =>
              entry.actor != '__system__' &&
              !validOwner(entry.actor) &&
              !staff.containsKey(entry.actor) &&
              !operations.employees.any((e) => e.id == entry.actor),
        ) ||
        operations.hiddenPosts.any((id) => !posts.any((p) => p.id == id)) ||
        operations.employees.map((e) => e.phone).toSet().length !=
            operations.employees.length ||
        operations.blocked.contains(active)) {
      throw const FormatException('Invalid operations references');
    }
    final shifts = (data['shifts'] as List? ?? [])
        .map((raw) => DemoShift.fromJson(raw as Map<String, dynamic>))
        .toList();
    final nextShift = (data['nextShift'] ?? 1) as int;
    if (nextShift < 1 ||
        shifts.length > 500 ||
        shifts.map((s) => s.id).toSet().length != shifts.length ||
        shifts.any(
          (s) =>
              int.parse(s.id.substring(2)) >= nextShift ||
              !operations.employees.any((e) => e.id == s.employeeId),
        )) {
      throw const FormatException('Invalid shift references');
    }
    for (var i = 0; i < shifts.length; i++) {
      final s = shifts[i];
      if (s.state != DemoShiftState.cancelled &&
          shifts
              .take(i)
              .any(
                (other) =>
                    other.state != DemoShiftState.cancelled &&
                    other.employeeId == s.employeeId &&
                    s.start.isBefore(other.end) &&
                    s.end.isAfter(other.start),
              )) {
        throw const FormatException('Overlapping shifts');
      }
    }
    final primaryFacilityProfile = data['primaryFacilityProfile'] == null
        ? null
        : DemoFacility.fromJson(
            data['primaryFacilityProfile'] as Map<String, dynamic>,
          );
    if (primaryFacilityProfile != null &&
        (primaryFacilityProfile.id != 'CS0000' ||
            primaryFacilityProfile.sourceVenueId.isNotEmpty ||
            primaryFacilityProfile.suspended ||
            [
              primaryFacilityProfile.draft,
              if (primaryFacilityProfile.published != null)
                primaryFacilityProfile.published!,
            ].any(
              (p) =>
                  p.courtCount != 3 ||
                  p.openHour != 6 ||
                  p.closeHour != 22 ||
                  p.sport != 'Cầu lông' ||
                  p.courtTypeId.isNotEmpty,
            ))) {
      throw const FormatException('Invalid primary facility profile');
    }
    final facilities = (data['facilities'] as List? ?? [])
        .map((raw) => DemoFacility.fromJson(raw as Map<String, dynamic>))
        .toList();
    if (facilities.any((f) => f.id == 'CS0000')) {
      throw const FormatException('Reserved primary profile id');
    }
    final linkedSources = <String>{};
    if (facilities.any(
      (f) =>
          f.sourceVenueId.isNotEmpty &&
          (!linkedSources.add(f.sourceVenueId) ||
              !claims.any(
                (c) =>
                    c.venueId == f.sourceVenueId &&
                    c.owner == f.owner &&
                    c.state == 'approved',
              ) ||
              (f.published != null && f.published!.receivingAccount == null) ||
              (f.state == 'pending' && f.draft.receivingAccount == null)),
    )) {
      throw const FormatException(
        'Invalid claimed facility links or receiving account',
      );
    }
    final courtTypes = (data['courtTypes'] as List? ?? [])
        .map((raw) => DemoCourtType.fromJson(raw as Map<String, dynamic>))
        .toList();
    final nextCourtType = (data['nextCourtType'] ?? 1) as int;
    if (courtTypes.length > 100 ||
        nextCourtType < 1 ||
        courtTypes.map((t) => t.id).toSet().length != courtTypes.length ||
        courtTypes
                .map((t) => '${t.sport}:${venueSearchText(t.name)}')
                .toSet()
                .length !=
            courtTypes.length ||
        courtTypes.any((t) => int.parse(t.id.substring(2)) >= nextCourtType) ||
        facilities.any(
          (f) => [f.draft, if (f.published != null) f.published!].any(
            (p) =>
                p.courtTypeId.isNotEmpty &&
                !courtTypes.any(
                  (t) =>
                      t.id == p.courtTypeId &&
                      t.sport == p.sport &&
                      ['approved', 'suspended'].contains(t.state),
                ),
          ),
        )) {
      throw const FormatException(
        'Invalid court type collection or facility link',
      );
    }
    final nextFacility = (data['nextFacility'] ?? 1) as int;
    if (employeeAccess.values.any(
      (a) => a.facilityIds.any(
        (id) =>
            !['*', ''].contains(id) &&
            !facilities.any((f) => f.id == id && f.published != null),
      ),
    )) {
      throw const FormatException('Invalid employee facility assignment');
    }
    if (favorites.values.any(
      (ids) => ids.any(
        (id) =>
            id.startsWith('CS') &&
            !facilities.any((f) => f.id == id && f.published != null),
      ),
    )) {
      throw const FormatException('Invalid facility favorite link');
    }
    if (bookings.any(
      (b) =>
          b.facilityId.isNotEmpty &&
          !facilities.any((f) => f.id == b.facilityId && f.published != null),
    )) {
      throw const FormatException('Invalid booking facility link');
    }
    if (facilities.length > 20 ||
        nextFacility < 1 ||
        facilities.map((f) => f.id).toSet().length != facilities.length ||
        facilities.any((f) => int.parse(f.id.substring(2)) >= nextFacility) ||
        facilities.any(
          (f) =>
              f.state == 'pending' &&
              (f.draft.photo.isEmpty || f.draft.legalProof.isEmpty),
        )) {
      throw const FormatException('Invalid facility collection');
    }
    final formDrafts = (data['facilityFormDrafts'] as List? ?? [])
        .map((j) => FacilityFormDraft.fromJson(j as Map<String, dynamic>))
        .toList();
    if (formDrafts.length > 21 ||
        formDrafts.map((d) => d.facilityId).toSet().length !=
            formDrafts.length ||
        formDrafts.any(
          (d) =>
              d.facilityId.isNotEmpty &&
              !facilities.any(
                (f) =>
                    f.id == d.facilityId &&
                    f.owner == '__owner__' &&
                    f.revision >= d.revision,
              ),
        )) {
      throw const FormatException('Invalid partial facility links');
    }
    final blocks = (data['courtBlocks'] as List? ?? [])
        .map((raw) => DemoCourtBlock.fromJson(raw as Map<String, dynamic>))
        .toList();
    final facilityTariffs = (data['facilityTariffs'] as List? ?? [])
        .map((j) => FacilityTariffPlan.fromJson(j as Map<String, dynamic>))
        .toList();
    if (facilityTariffs.length > 20 ||
        facilityTariffs.map((p) => p.facilityId).toSet().length !=
            facilityTariffs.length ||
        facilityTariffs.any(
          (p) => !facilities.any(
            (f) =>
                f.id == p.facilityId &&
                f.published != null &&
                f.revision >= p.facilityRevision,
          ),
        )) {
      throw const FormatException('Invalid facility tariff links');
    }
    final nextBlock = (data['nextBlock'] ?? 1) as int;
    if (blocks.length > 500 ||
        nextBlock < 1 ||
        blocks.map((b) => b.id).toSet().length != blocks.length ||
        blocks.any((b) => int.parse(b.id.substring(2)) >= nextBlock)) {
      throw const FormatException('Invalid block collection');
    }
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b.eventId.isNotEmpty) {
        final activity = activities.where((a) => a.id == b.eventId).firstOrNull;
        final event =
            demoEvents.where((e) => e.id == b.eventId).firstOrNull ??
            activity?.event;
        if (event == null ||
            b.hours * 60 != event.durationMinutes ||
            b.start.hour != event.hour ||
            (activity != null &&
                (!['approved', 'suspended'].contains(activity.state) ||
                    b.start != event.scheduledStart)) ||
            eventCancellations.any(
              (c) => c.eventId == b.eventId && c.start == b.start,
            )) {
          throw const FormatException('Invalid event court allocation');
        }
        final courts = blocks
            .where((r) => r.eventId == b.eventId && r.start == b.start)
            .map((r) => r.court)
            .toSet();
        if (matches.any(
          (m) =>
              m.state != 'cancelled' &&
              !courts.contains(m.court) &&
              participations.any(
                (p) =>
                    p.id == m.first &&
                    p.eventId == b.eventId &&
                    p.start == b.start,
              ),
        )) {
          throw const FormatException('Fixture outside allocated courts');
        }
      }
      if (b.facilityId.isNotEmpty) {
        final p = facilities
            .where((f) => f.id == b.facilityId)
            .firstOrNull
            ?.published;
        if (p == null) {
          throw const FormatException('Invalid block facility contract');
        }
      }
      if (bookings.any(
            (r) =>
                !r.cancelled &&
                r.facilityId == b.facilityId &&
                r.court == b.court &&
                b.start.isBefore(r.end) &&
                b.end.isAfter(r.start),
          ) ||
          blocks
              .take(i)
              .any(
                (r) =>
                    r.facilityId == b.facilityId &&
                    r.court == b.court &&
                    b.start.isBefore(r.end) &&
                    b.end.isAfter(r.start),
              )) {
        throw const FormatException('Overlapping court block');
      }
    }
    final paymentMethods = <String, List<DemoPaymentMethod>>{};
    for (final entry
        in ((data['paymentMethods'] ?? <String, dynamic>{})
                as Map<String, dynamic>)
            .entries) {
      if (entry.key != phone && !registered.containsKey(entry.key)) {
        throw const FormatException('Invalid payment method owner');
      }
      final methods = (entry.value as List)
          .map((m) => DemoPaymentMethod.fromJson(m as Map<String, dynamic>))
          .toList();
      if (methods.length > 5 ||
          methods.map((m) => m.id).toSet().length != methods.length ||
          methods
                  .where((m) => !m.isCard)
                  .map((m) => m.provider)
                  .toSet()
                  .length !=
              methods.where((m) => !m.isCard).length ||
          (methods.isNotEmpty &&
              methods.where((m) => m.isDefault).length != 1)) {
        throw const FormatException('Invalid payment methods');
      }
      paymentMethods[entry.key] = methods;
    }
    // Commit only once the entire snapshot has been validated.
    final primaryPolicy = data['primaryCancellationPolicy'] == null
        ? const CancellationPolicy.standard()
        : CancellationPolicy.fromJson(
            data['primaryCancellationPolicy'] as Map<String, dynamic>,
          );
    final primaryPolicyRevision =
        (data['primaryCancellationRevision'] ?? 0) as int;
    if (primaryPolicyRevision < 0) {
      throw const FormatException('Invalid policy revision');
    }
    final seedVersion = (data['demoSeedVersion'] ?? 0) as int;
    if (seedVersion < 0 || seedVersion > demoSeedVersion) {
      throw const FormatException('Unsupported demo seed version');
    }
    _demoSeedVersion = seedVersion;
    _primaryCancellationPolicy = primaryPolicy;
    _paymentMethods.clear();
    _paymentMethods.addAll(paymentMethods);
    _primaryCancellationRevision = primaryPolicyRevision;
    _facilityFormDrafts.clear();
    _facilityFormDrafts.addEntries(
      formDrafts.map((d) => MapEntry(d.facilityId, d)),
    );
    _courtTypes.clear();
    _courtTypes.addAll(courtTypes);
    _nextCourtType = nextCourtType;
    _courtBlocks.clear();
    _courtBlocks.addAll(blocks);
    _facilityTariffs.clear();
    _facilityTariffs.addEntries(
      facilityTariffs.map((p) => MapEntry(p.facilityId, p)),
    );
    _nextBlock = nextBlock;
    _facilities.clear();
    _facilities.addAll(facilities);
    _primaryFacilityProfile = primaryFacilityProfile;
    _nextFacility = nextFacility;
    _operations = operations;
    _employeeAccess.clear();
    _employeeAccess.addAll(employeeAccess);
    _ownerVerification = ownerVerification;
    _venueClaims.clear();
    _venueClaims.addAll(claims);
    _payoutAccount = payoutAccount;
    _payouts.clear();
    _payouts.addAll(payouts);
    _nextPayout = nextPayout;
    _activeEmployeeId =
        operations.employees.any((e) => e.id == activeEmployee && e.active) &&
            (employeeAccess[activeEmployee]?.permissions.isNotEmpty ?? false)
        ? activeEmployee
        : null;
    _shifts.clear();
    _shifts.addAll(shifts);
    _nextShift = nextShift;
    _staff.clear();
    _staff.addAll(staff);
    _payments.clear();
    _payments.addAll(payments);
    _disputes.clear();
    _disputes.addAll(disputes);
    _reviews.clear();
    _reviews.addAll(reviews);
    _proofPickerTarget = proofPickerTarget;
    _posts.clear();
    _posts.addAll(posts);
    _nextPost = nextPost;
    _playGroups.clear();
    _playGroups.addAll(playGroups);
    _groupRequests.clear();
    _groupRequests.addAll(groupRequests);
    _nextPlayGroup = nextPlayGroup;
    _groups.clear();
    _groups.addAll(groups);
    _expenses.clear();
    _expenses.addAll(expenses);
    _participations.clear();
    _activities.clear();
    _activities.addAll(activities);
    _eventCancellations
      ..clear()
      ..addAll(eventCancellations);
    _nextActivity = nextActivity;
    _matches.clear();
    _matches.addAll(matches);
    _nextMatch = nextMatch;
    _participations.addAll(participations);
    _chats.clear();
    _chats.addAll(chats);
    _demoUser.name = demoName;
    _demoPassword = demoPassword;
    _contactPhones.clear();
    _contactPhones.addAll(contactPhones);
    _enrollments.clear();
    _enrollments.addAll(enrollments);
    _tickets.clear();
    _tickets.addAll(tickets);
    _registered.clear();
    _registered.addAll(registered);
    _bookings.clear();
    _bookings.addAll(bookings);
    _favorites.clear();
    _favorites.addAll(favorites);
    user = active == phone
        ? _demoUser
        : registered[active]?.user ?? staff[active]?.user;
  }

  void _requireReady() {
    if (!initialized) throw StateError('Đang đọc dữ liệu. Vui lòng thử lại.');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final DateTime Function() _now;
  DateTime get now => _now();
  final List<DemoBooking> _bookings = [];
  List<DemoBooking> get bookings => List.unmodifiable(
    _bookings.where((b) => b.owner == user?.identifier).toList()
      ..sort((a, b) => b.start.compareTo(a.start)),
  );
  int get upcomingCount =>
      bookings.where((b) => !b.cancelled && b.end.isAfter(now)).length;

  FacilityProfile? _bookableFacility(String id) => _facilities
      .where((f) => f.id == id && f.published != null && !f.suspended)
      .firstOrNull
      ?.published;
  bool available(
    int court,
    DateTime start,
    int hours, {
    String facilityId = '',
  }) {
    return _slotAvailable(court, start, hours, facilityId: facilityId);
  }

  bool _slotAvailable(
    int court,
    DateTime start,
    int hours, {
    String facilityId = '',
    DemoBooking? excluding,
  }) {
    _requireReady();
    final profile = facilityId.isEmpty ? null : _bookableFacility(facilityId);
    if (facilityId.isNotEmpty && profile == null) return false;
    final today = bookingDay(now);
    final day = bookingDay(start);
    if (court < 1 ||
        court > (profile?.courtCount ?? 3) ||
        (profile == null && !_operations.published.enabled[court - 1]) ||
        hours < 1 ||
        hours > 3 ||
        start.minute != 0 ||
        start.second != 0 ||
        start.millisecond != 0 ||
        start.microsecond != 0 ||
        !start.isAfter(now) ||
        day.isBefore(today) ||
        day.isAfter(today.add(const Duration(days: 6))) ||
        start.isUtc ||
        start.hour < (profile?.openHour ?? 6) ||
        start.hour + hours > (profile?.closeHour ?? 22)) {
      return false;
    }
    final end = start.add(Duration(hours: hours));
    return !_courtBlocks.any(
          (b) =>
              b.facilityId == facilityId &&
              b.court == court &&
              start.isBefore(b.end) &&
              end.isAfter(b.start),
        ) &&
        !_bookings.any(
          (b) =>
              !b.cancelled &&
              !identical(b, excluding) &&
              b.facilityId == facilityId &&
              b.court == court &&
              start.isBefore(b.end) &&
              end.isAfter(b.start),
        );
  }

  DemoBooking reserve({
    required int court,
    required DateTime start,
    required int hours,
    required String contact,
    required String contactPhone,
    String? voucherCode,
    int? quotedRate,
    List<int>? quotedRates,
    String facilityId = '',
    CancellationPolicy? quotedCancellationPolicy,
  }) {
    _requireReady();
    if (user == null || user!.role != DemoRole.player) {
      throw StateError('Vui lòng dùng tài khoản người chơi để đặt sân.');
    }
    final normalized = normalize(contactPhone);
    if (contact.trim().isEmpty ||
        contact.trim().length > 60 ||
        !RegExp(r'^0[35789]\d{8}$').hasMatch(normalized)) {
      throw StateError('Kiểm tra họ tên và số điện thoại liên hệ.');
    }
    if (!available(court, start, hours, facilityId: facilityId)) {
      throw StateError('Khung giờ không còn khả dụng. Vui lòng chọn lại.');
    }
    final profile = facilityId.isEmpty ? null : _bookableFacility(facilityId);
    final policy = profile?.cancellationPolicy ?? _primaryCancellationPolicy;
    if (quotedCancellationPolicy != null &&
        quotedCancellationPolicy != policy) {
      throw StateError(
        'Chính sách hủy đã thay đổi. Xác nhận lại trước khi đặt sân.',
      );
    }
    final rates = bookingRates(court, start, hours, facilityId: facilityId);
    final subtotal = rates.fold<int>(0, (a, b) => a + b);
    if ((quotedRate != null && quotedRate != rates.first) ||
        (quotedRates != null &&
            (quotedRates.length != rates.length ||
                Iterable.generate(rates.length)
                    .any((i) => quotedRates[i] != rates[i])))) {
      throw StateError(
        'Đơn giá đã thay đổi. Vui lòng quay lại chọn lịch để xác nhận giá mới.',
      );
    }
    var discount = 0;
    if (voucherCode != null) {
      final matches = vouchers.where((v) => v.code == voucherCode);
      if (matches.isEmpty || matches.first.discount(subtotal) == 0) {
        throw StateError('Ưu đãi không còn khả dụng hoặc chưa đủ điều kiện.');
      }
      discount = matches.first.discount(subtotal);
    }
    final booking = DemoBooking(
      id: 'NVH${(_bookings.length + 1).toString().padLeft(4, '0')}',
      owner: user!.identifier,
      facilityId: facilityId,
      venueName: profile?.name ?? DemoBooking.venue,
      venueAddress: profile == null
          ? DemoBooking.address
          : '${profile.address}, ${profile.district}, ${profile.city}',
      sport: profile?.sport ?? 'Cầu lông',
      venueCourtCount: profile?.courtCount ?? 3,
      venueOpenHour: profile?.openHour ?? 6,
      venueCloseHour: profile?.closeHour ?? 22,
      cancellationPolicy: policy,
      court: court,
      start: start,
      hours: hours,
      contact: contact.trim(),
      phone: normalized,
      voucherCode: voucherCode,
      discount: discount,
      rate: rates.first,
      hourlyRates: rates,
      receivingAccount: profile?.receivingAccount,
    );
    _bookings.add(booking);
    _changed();
    return booking;
  }

  bool cancel(DemoBooking booking) {
    _requireReady();
    if (!_bookings.contains(booking) ||
        user?.identifier != booking.owner ||
        booking.cancelled ||
        _payments.containsKey(booking.id) ||
        !booking.cancellationPolicy.canRequest(booking.start, now)) {
      return false;
    }
    booking.cancelled = true;
    _changed();
    return true;
  }

  static const phone = '0901234567';
  static const email = 'demo@nvh.vn';
  static const password = 'Demo1234';
  final _demoUser = DemoUser(name: 'Văn Hùng', identifier: phone, seeded: true);
  final Map<String, ({DemoUser user, String password})> _registered = {};
  DemoUser? user;

  static String normalize(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.contains('@')) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('84') && digits.length == 11) {
      return '0${digits.substring(2)}';
    }
    if (digits.length == 9) return '0$digits';
    return digits;
  }

  bool login(String identifier, String secret) {
    _requireReady();
    final key = normalize(identifier);
    if (_operations.blocked.contains(key == email ? phone : key)) return false;
    if ((key == phone || key == email) && secret == _demoPassword) {
      user = _demoUser;
    } else {
      final record = _registered[key];
      if (record == null || record.password != secret) return false;
      user = record.user;
    }
    _ensureChats();
    _activeEmployeeId = null;
    _changed();
    return true;
  }

  bool register(String name, String identifier, String secret) {
    _requireReady();
    final key = normalize(identifier);
    if (name.trim().isEmpty ||
        name.trim().length > 60 ||
        secret.length < 8 ||
        secret.length > 128 ||
        !(RegExp(r'^0[35789]\d{8}$').hasMatch(key) ||
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(key))) {
      return false;
    }
    if (key == phone || key == email || _registered.containsKey(key)) {
      return false;
    }
    final newUser = DemoUser(
      name: name.trim(),
      identifier: key,
      registeredAt: now,
    );
    _registered[key] = (user: newUser, password: secret);
    user = newUser;
    _ensureChats();
    _changed();
    return true;
  }

  void updateName(String name) {
    _requireReady();
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60 || user == null) return;
    user!.name = trimmed;
    _changed();
  }

  void logout() {
    _requireReady();
    user = null;
    _activeEmployeeId = null;
    _changed();
  }
}
