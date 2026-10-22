part of 'demo_session.dart';

extension DemoVenueClaimsSession on DemoSession {
  List<DemoVenueClaim> get venueClaims {
    _requireManager();
    return List.unmodifiable(
      _venueClaims
          .where((c) => role == DemoRole.admin || c.owner == user!.identifier)
          .toList()
        ..sort((a, b) => b.updated.compareTo(a.updated)),
    );
  }

  DemoVenueClaim? ownVenueClaim(String venueId) {
    _requireFacilityOwner();
    return _venueClaims
        .where((c) => c.venueId == venueId && c.owner == user!.identifier)
        .firstOrNull;
  }

  bool venueHasClaim(String venueId) {
    _requireFacilityOwner();
    return _venueClaims.any(
      (c) => c.venueId == venueId && ['pending', 'approved'].contains(c.state),
    );
  }

  void submitVenueClaim({
    required String venueId,
    required String contact,
    required String phone,
    required String explanation,
    required String proof,
    required int expectedRevision,
  }) {
    _requireFacilityOwner();
    final venue = _discoveryVenues.where((v) => v.id == venueId).firstOrNull;
    final old = ownVenueClaim(venueId);
    if (venue == null ||
        !venue.isImported ||
        venue.bookingEnabled ||
        venue.latitude == null ||
        venue.longitude == null ||
        (old?.revision ?? 0) != expectedRevision ||
        venueHasClaim(venueId) ||
        (old == null && _venueClaims.length >= 100)) {
      throw StateError(
        'Địa điểm đã có yêu cầu, đã được quản lý hoặc hồ sơ đã thay đổi.',
      );
    }
    final claim = DemoVenueClaim(
      venueId: venue.id,
      venueName: venue.name,
      address: venue.addressLabel,
      latitude: venue.latitude!,
      longitude: venue.longitude!,
      owner: user!.identifier,
      contact: contact.trim(),
      phone: DemoSession.normalize(phone),
      explanation: explanation.trim(),
      proof: proof,
      created: old?.created ?? now,
      updated: now,
      revision: expectedRevision + 1,
    );
    try {
      DemoVenueClaim.fromJson(claim.toJson());
    } on FormatException {
      throw StateError(
        'Nhập người đại diện (3–60 ký tự), số điện thoại, '
        'nội dung chứng minh (20–1.000 ký tự) và ảnh minh chứng hợp lệ.',
      );
    }
    if (old != null) _venueClaims.remove(old);
    _venueClaims.add(claim);
    _recordOperation(
      'Gửi yêu cầu quản lý ${claim.venueName}',
      subject: venueId,
    );
  }

  void withdrawVenueClaim(String venueId, {required int expectedRevision}) {
    _requireFacilityOwner();
    final old = ownVenueClaim(venueId);
    if (old == null ||
        old.state != 'pending' ||
        old.revision != expectedRevision) {
      throw StateError('Yêu cầu đã được xử lý hoặc thay đổi.');
    }
    _replaceVenueClaim(old, state: 'withdrawn');
    _recordOperation('Rút yêu cầu quản lý ${old.venueName}', subject: venueId);
  }

  void reviewVenueClaim(
    String key, {
    required bool approve,
    required int expectedRevision,
    required String password,
    String note = '',
  }) {
    _requireAdmin();
    final old = _venueClaims.where((c) => c.key == key).firstOrNull;
    if (old == null ||
        old.state != 'pending' ||
        old.revision != expectedRevision ||
        _venueClaims.any(
          (c) => c.venueId == old.venueId && c.state == 'approved',
        )) {
      throw StateError('Yêu cầu đã được xử lý hoặc sân đã có người quản lý.');
    }
    if (!approve && (note.trim().length < 5 || note.trim().length > 300)) {
      throw StateError('Lý do từ chối cần 5–300 ký tự.');
    }
    _verifyAdminConfirmation(password);
    _replaceVenueClaim(
      old,
      state: approve ? 'approved' : 'rejected',
      note: approve ? '' : note.trim(),
      reviewer: user!.identifier,
    );
    _recordOperation(
      '${approve ? 'Duyệt' : 'Từ chối'} quyền quản lý ${old.venueName}',
      subject: old.venueId,
      decision: approve ? 'approved' : 'rejected',
      note: approve ? '' : note.trim(),
    );
  }

  void _replaceVenueClaim(
    DemoVenueClaim old, {
    required String state,
    String note = '',
    String reviewer = '',
  }) {
    final next = DemoVenueClaim(
      venueId: old.venueId,
      venueName: old.venueName,
      address: old.address,
      latitude: old.latitude,
      longitude: old.longitude,
      owner: old.owner,
      contact: old.contact,
      phone: old.phone,
      explanation: old.explanation,
      proof: old.proof,
      created: old.created,
      updated: now,
      revision: old.revision + 1,
      state: state,
      note: note,
      reviewer: reviewer,
    );
    DemoVenueClaim.fromJson(next.toJson());
    _venueClaims[_venueClaims.indexOf(old)] = next;
  }
}
