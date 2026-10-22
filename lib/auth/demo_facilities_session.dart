part of 'demo_session.dart';

extension DemoFacilitiesSession on DemoSession {
  DemoFacility? claimedFacility(String venueId) {
    _requireManager();
    return _facilities
        .where(
          (f) =>
              f.sourceVenueId == venueId &&
              (role == DemoRole.admin || f.owner == user!.identifier),
        )
        .firstOrNull;
  }

  void _validateClaimedProfile(
    String sourceId,
    String owner,
    FacilityProfile p, {
    bool publishing = false,
  }) {
    if (sourceId.isEmpty) return;
    final claim = _venueClaims
        .where(
          (c) =>
              c.venueId == sourceId &&
              c.owner == owner &&
              c.state == 'approved',
        )
        .firstOrNull;
    final source = _discoveryVenues.where((v) => v.id == sourceId).firstOrNull;
    if (claim == null ||
        (source != null &&
            p.sport != source.sport &&
            !source.sports.contains(p.sport))) {
      throw StateError(
        'Chưa được duyệt quyền quản lý hoặc môn thể thao không khớp địa điểm.',
      );
    }
    if (publishing && p.receivingAccount == null) {
      throw StateError(
        'Bổ sung tài khoản nhận tiền mô phỏng trước khi gửi duyệt.',
      );
    }
  }

  VenueSummary _facilityVenue(
    DemoFacility f, {
    VenueSummary? source,
    bool ownerView = false,
  }) {
    final p = ownerView ? f.published ?? f.draft : f.published!;
    final claim = f.sourceVenueId.isEmpty
        ? null
        : _venueClaims
              .where(
                (c) =>
                    c.venueId == f.sourceVenueId &&
                    c.owner == f.owner &&
                    c.state == 'approved',
              )
              .firstOrNull;
    return VenueSummary(
      id: ownerView || f.sourceVenueId.isEmpty ? f.id : f.sourceVenueId,
      bookingFacilityId: f.id,
      name: p.name,
      address: '${p.address}, ${p.district}, ${p.city}',
      sport: p.sport,
      sports: [p.sport],
      image: p.photo,
      localPhoto: p.photo.isNotEmpty,
      price: p.baseRate,
      rating: facilityRating(f.id),
      latitude: source?.latitude ?? claim?.latitude,
      longitude: source?.longitude ?? claim?.longitude,
      sourceUrl: claim == null
          ? null
          : source?.sourceUrl ??
                'https://www.openstreetmap.org/${f.sourceVenueId.substring(4).replaceFirst('-', '/')}',
      representativeCenter: source?.representativeCenter ?? claim != null,
      phone: p.phone,
      bookingEnabled: f.published != null && !f.suspended,
    );
  }

  bool isPrimaryFacility(DemoFacility facility) =>
      identical(facility, _primaryFacilityProfile);
  List<DemoFacility> get ownerEditableFacilities {
    _requireFacilityOwner();
    return [?_primaryFacilityProfile, ...managedFacilities];
  }

  DemoFacility ensurePrimaryFacilityProfile(String photo) {
    _requireFacilityOwner();
    if (user!.identifier != '__owner__') {
      throw StateError('Chưa có quyền sửa sân chính.');
    }
    if (_primaryFacilityProfile != null) return _primaryFacilityProfile!;
    final venue = currentVenues.firstWhere((v) => v.id == demoVenueId);
    final profile = FacilityProfile(
      name: venue.name,
      sport: 'Cầu lông',
      address: '73/1 Nguyễn Đỗ Cung, Tây Thạnh',
      city: 'TP.HCM',
      district: 'Tân Phú',
      phone: DemoSession.phone,
      ownerName: user!.name,
      courtCount: 3,
      openHour: 6,
      closeHour: 22,
      baseRate: minimumCourtRate,
      photo: photo,
      cancellationPolicy: _primaryCancellationPolicy,
    );
    _primaryFacilityProfile = DemoFacility(
      id: 'CS0000',
      owner: user!.identifier,
      draft: profile,
      updated: now,
    );
    _recordOperation('Khởi tạo hồ sơ chỉnh sửa sân chính');
    return _primaryFacilityProfile!;
  }

  void _checkPrimaryProfile(DemoFacility? facility, FacilityProfile profile) {
    if (facility != null &&
        isPrimaryFacility(facility) &&
        (profile.courtCount != 3 ||
            profile.openHour != 6 ||
            profile.closeHour != 22 ||
            profile.sport != 'Cầu lông' ||
            profile.courtTypeId.isNotEmpty)) {
      throw StateError('Sân chính giữ 3 sân cầu lông, giờ 06:00–22:00.');
    }
  }

  List<VenueSummary> get ownerMapVenues {
    _requireFacilityOwner();
    return List.unmodifiable([
      if (user!.identifier == '__owner__')
        ...currentVenues.where((v) => v.id == demoVenueId),
      for (final f in managedFacilities) _facilityVenue(f, ownerView: true),
    ]);
  }

  FacilityFormDraft? facilityFormDraft([DemoFacility? facility]) {
    _requireFacilityOwner(facility);
    final draft = _facilityFormDrafts[facility?.id ?? ''];
    return facility != null &&
            (facility.state == 'pending' ||
                draft?.revision != facility.revision)
        ? null
        : draft;
  }

  void saveFacilityFormDraft(
    FacilityFormDraft draft, {
    DemoFacility? facility,
  }) {
    _requireFacilityOwner(facility);
    if ((facility != null && isPrimaryFacility(facility)) ||
        draft.facilityId != (facility?.id ?? '') ||
        draft.revision != (facility?.revision ?? 0) ||
        facility?.state == 'pending') {
      throw StateError('Hồ sơ đã thay đổi. Mở lại hồ sơ trước khi lưu nháp.');
    }
    final checked = FacilityFormDraft.fromJson(draft.toJson());
    _facilityFormDrafts[draft.facilityId] = checked;
    _recordOperation('Lưu thông tin cơ sở đang nhập ${draft.facilityId}');
  }

  void discardFacilityFormDraft([DemoFacility? facility]) {
    _requireFacilityOwner(facility);
    if (_facilityFormDrafts.remove(facility?.id ?? '') != null) _changed();
  }

  List<DemoFacility> get managedFacilities {
    _requireManager();
    return List.unmodifiable(
      _facilities
          .where((f) => role == DemoRole.admin || f.owner == user!.identifier)
          .followedBy(
            role == DemoRole.admin && _primaryFacilityProfile != null
                ? [_primaryFacilityProfile!]
                : <DemoFacility>[],
          )
          .toList()
        ..sort((a, b) => b.updated.compareTo(a.updated)),
    );
  }

  List<({String id, FacilityProfile profile})> get publicFacilities {
    _requireReady();
    return List.unmodifiable([
      for (final f in _facilities)
        if (f.published != null && !f.suspended)
          (id: f.id, profile: f.published!.publicView),
    ]);
  }

  bool canManageFacility(DemoFacility f) =>
      initialized &&
      user != null &&
      (_facilities.contains(f) || isPrimaryFacility(f)) &&
      (role == DemoRole.admin ||
          (role == DemoRole.owner && f.owner == user!.identifier));
  void _requireFacilityOwner([DemoFacility? f]) {
    _requireManager();
    if (role != DemoRole.owner || (f != null && !canManageFacility(f))) {
      throw StateError('Chỉ Chủ sân sở hữu hồ sơ được sửa.');
    }
  }

  DemoFacility saveFacility(
    FacilityProfile profile, {
    DemoFacility? facility,
    int? expectedRevision,
    String sourceVenueId = '',
    int? expectedClaimRevision,
  }) {
    _requireFacilityOwner(facility);
    _checkPrimaryProfile(facility, profile);
    final sourceId = facility?.sourceVenueId ?? sourceVenueId;
    _validateClaimedProfile(sourceId, user!.identifier, profile);
    if (facility == null &&
        sourceId.isNotEmpty &&
        (_facilities.any((f) => f.sourceVenueId == sourceId) ||
            ownVenueClaim(sourceId)?.revision != expectedClaimRevision)) {
      throw StateError(
        'Hồ sơ vận hành đã được tạo hoặc quyền quản lý đã thay đổi. Mở lại hồ sơ.',
      );
    }
    if (facility != null &&
        (facility.state == 'pending' ||
            (expectedRevision != null &&
                facility.revision != expectedRevision))) {
      throw StateError('Hồ sơ đã thay đổi hoặc đang chờ duyệt. Mở lại hồ sơ.');
    }
    if (facility == null && _facilities.length >= 20) {
      throw StateError('Tối đa 20 cơ sở demo.');
    }
    FacilityProfile.fromJson(profile.toJson());
    _validateFacilityType(profile, retained: facility?.draft);
    final f =
        facility ??
        DemoFacility(
          id: 'CS${_nextFacility.toString().padLeft(4, '0')}',
          owner: user!.identifier,
          draft: profile,
          updated: now,
          sourceVenueId: sourceId,
        );
    if (facility == null) {
      _facilities.add(f);
      _nextFacility++;
    } else {
      f.draft = profile;
      f.state = 'draft';
      f.reviewDecision = '';
      f.note = '';
      f.revision++;
      f.updated = now;
    }
    _facilityFormDrafts.remove(facility?.id ?? '');
    _recordOperation('Lưu nháp hồ sơ ${f.id}');
    return f;
  }

  void updatePendingFacility(
    FacilityProfile profile, {
    required DemoFacility facility,
    required int expectedRevision,
  }) {
    _requireFacilityOwner(facility);
    _checkPrimaryProfile(facility, profile);
    if (facility.state != 'pending' || facility.revision != expectedRevision) {
      throw StateError(
        'Hồ sơ đã được xử lý hoặc thay đổi. Mở lại hồ sơ trước khi sửa.',
      );
    }
    FacilityProfile.fromJson(profile.toJson());
    if (profile.photo.isEmpty || profile.legalProof.isEmpty) {
      throw StateError('Hồ sơ chờ duyệt cần có ảnh sân và giấy tờ mẫu.');
    }
    _validateClaimedProfile(
      facility.sourceVenueId,
      facility.owner,
      profile,
      publishing: true,
    );
    _validateFacilityType(profile, requireApproved: true);
    facility.draft = profile;
    facility.note = '';
    facility.reviewDecision = '';
    facility.updated = now;
    facility.revision++;
    _facilityFormDrafts.remove(facility.id);
    _recordOperation('Cập nhật hồ sơ chờ duyệt ${facility.id}');
  }

  void submitFacility(DemoFacility f) {
    _requireFacilityOwner(f);
    _validateClaimedProfile(
      f.sourceVenueId,
      f.owner,
      f.draft,
      publishing: true,
    );
    if (f.state != 'draft' && f.state != 'rejected') {
      throw StateError('Hồ sơ không ở trạng thái gửi duyệt.');
    }
    if (f.draft.photo.isEmpty || f.draft.legalProof.isEmpty) {
      throw StateError(
        'Thêm ảnh sân và ảnh giấy tờ mẫu trước khi gửi duyệt. Không dùng giấy tờ thật.',
      );
    }
    _validateFacilityType(f.draft, requireApproved: true);
    f.state = 'pending';
    f.reviewDecision = '';
    f.note = '';
    f.updated = now;
    f.revision++;
    _recordOperation('Gửi duyệt cơ sở ${f.id}');
  }

  void reviewFacility(
    DemoFacility f, {
    required bool approve,
    bool reject = false,
    String note = '',
    int? expectedRevision,
  }) {
    _requireAdmin();
    if (approve && reject) throw StateError('Quyết định không hợp lệ.');
    if (!canManageFacility(f) ||
        f.state != 'pending' ||
        (expectedRevision != null && f.revision != expectedRevision)) {
      throw StateError('Hồ sơ không còn chờ duyệt.');
    }
    if ((!approve && note.trim().length < 5) || note.length > 300) {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    if (approve) {
      _validateClaimedProfile(
        f.sourceVenueId,
        f.owner,
        f.draft,
        publishing: true,
      );
      _validateFacilityType(f.draft, requireApproved: true);
      f.published = f.draft;
    }
    f.state = approve ? 'approved' : 'rejected';
    f.reviewDecision = approve
        ? 'approved'
        : reject
        ? 'rejected'
        : 'supplement';
    f.note = note.trim();
    f.updated = now;
    f.revision++;
    _recordOperation(
      '${approve
          ? 'Duyệt'
          : reject
          ? 'Từ chối'
          : 'Yêu cầu bổ sung'} cơ sở ${f.id}',
      subject: f.id,
      decision: f.reviewDecision,
      note: f.note,
    );
  }

  void suspendFacility(
    DemoFacility f,
    bool suspended, {
    String reason = '',
    int? expectedRevision,
  }) {
    _requireAdmin();
    if (isPrimaryFacility(f)) {
      throw StateError('Dùng quản lý lịch sân để khóa sân chính.');
    }
    if (!canManageFacility(f) ||
        f.published == null ||
        (expectedRevision != null && f.revision != expectedRevision)) {
      throw StateError('Chỉ tạm ngưng hồ sơ đã công bố.');
    }
    if (reason.length > 300 ||
        (expectedRevision != null && reason.trim().length < 5)) {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    f.suspended = suspended;
    f.updated = now;
    f.revision++;
    _recordOperation(
      '${suspended ? 'Tạm ngưng' : 'Mở lại'} cơ sở ${f.id}',
      subject: f.id,
      note: reason.trim(),
    );
  }
}
