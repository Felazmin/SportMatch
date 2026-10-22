part of 'demo_session.dart';

extension DemoFacilityTariffsSession on DemoSession {
  FacilityTariffPlan facilityTariffPlan(String id) {
    _requireManager();
    final f = _facilities.where((f) => f.id == id).firstOrNull;
    if (f == null || f.published == null || !canManageFacility(f)) {
      throw StateError('Không có cơ sở được quản lý.');
    }
    return _facilityTariffs[id] ?? FacilityTariffPlan(facilityId: id);
  }

  void submitFacilityTariffs(
    String id,
    List<FacilityTariffBand> bands, {
    required int expectedRevision,
  }) {
    final old = facilityTariffPlan(id);
    final f = _facilities.singleWhere((f) => f.id == id);
    _requireFacilityOwner(f);
    if (f.suspended ||
        old.state == 'pending' ||
        old.revision != expectedRevision) {
      throw StateError('Cơ sở/bảng giá đã thay đổi hoặc đang chờ duyệt.');
    }
    final p = f.published!;
    try {
      FacilityTariffPlan.validateBands(bands);
    } on FormatException {
      throw StateError(
        'Kiểm tra giá, ngày hiệu lực và khung giờ không chồng lấn; tối đa 36 dòng.',
      );
    }
    if (bands.any(
      (b) =>
          b.court > p.courtCount ||
          b.fromHour < p.openHour ||
          b.toHour > p.closeHour,
    )) {
      throw StateError('Bảng giá phải nằm trong sân và giờ mở cửa của cơ sở.');
    }
    _facilityTariffs[id] = FacilityTariffPlan(
      facilityId: id,
      revision: old.revision + 1,
      facilityRevision: f.revision,
      state: 'pending',
      published: old.published,
      draft: bands,
    );
    _recordOperation('Đề xuất bảng giá cơ sở $id');
  }

  void reviewFacilityTariffs(
    String id, {
    required int expectedRevision,
    required bool approve,
    String note = '',
  }) {
    _requireAdmin();
    final old = facilityTariffPlan(id),
        f = _facilities.singleWhere((f) => f.id == id);
    if (old.revision != expectedRevision ||
        old.state != 'pending' ||
        (approve && (f.suspended || f.revision != old.facilityRevision))) {
      throw StateError(
        'Hồ sơ hoặc bảng giá đã thay đổi. Từ chối đề xuất cũ rồi gửi lại.',
      );
    }
    if (!approve && (note.trim().length < 5 || note.length > 300)) {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    _facilityTariffs[id] = FacilityTariffPlan(
      facilityId: id,
      revision: old.revision + 1,
      facilityRevision: old.facilityRevision,
      state: approve ? 'approved' : 'rejected',
      note: approve ? '' : note.trim(),
      published: approve ? old.draft! : old.published,
      draft: old.draft,
    );
    _recordOperation('${approve ? 'Duyệt' : 'Từ chối'} bảng giá cơ sở $id');
  }
}
