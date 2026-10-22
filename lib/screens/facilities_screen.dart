import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_facilities.dart';
import '../demo/demo_cancellation_policy.dart';
import '../demo/demo_payout.dart';
import '../demo/demo_finance.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';
import 'owner_management_views.dart';
import 'owner_management_widgets.dart';
import 'facility_pending_screen.dart';
import 'facility_booking_screen.dart';
import 'reviews_screen.dart';
import 'facility_calendar_screen.dart';
import 'facility_document_screen.dart';
import 'cancellation_policy_screen.dart';
import 'admin_facility_review_screen.dart';

Widget facilityLegalDocument(DemoSession session, DemoFacility facility) =>
    facility.draft.legalProof.isEmpty
    ? const Text('Chưa gửi giấy tờ.')
    : _FacilityLegalDocument(
        session: session,
        encoded: facility.draft.legalProof,
        facility: facility,
      );

class FacilitiesScreen extends StatefulWidget {
  const FacilitiesScreen({
    super.key,
    required this.session,
    this.publicOnly = false,
  });
  final DemoSession session;
  final bool publicOnly;
  @override
  State<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends State<FacilitiesScreen> {
  String _filter = 'all';
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!s.initialized ||
          (!widget.publicOnly &&
              (s.user == null || s.role == DemoRole.player))) {
        return Scaffold(
          appBar: financeBar('Cơ sở'),
          body: const Center(child: Text('Chưa có quyền truy cập.')),
        );
      }
      if (!widget.publicOnly && s.role == DemoRole.owner) {
        return OwnerFacilitiesView(session: s);
      }
      final query = _search.text.trim().toLowerCase();
      final managed = widget.publicOnly
          ? <DemoFacility>[]
          : s.managedFacilities
                .where(
                  (f) =>
                      (_filter == 'all' ||
                          (_filter == 'suspended'
                              ? f.suspended
                              : f.state == _filter && !f.suspended)) &&
                      '${f.id} ${f.draft.name} ${f.draft.address}'
                          .toLowerCase()
                          .contains(query),
                )
                .toList();
      final public = widget.publicOnly
          ? s.publicFacilities
                .where(
                  (f) => '${f.profile.name} ${f.profile.address}'
                      .toLowerCase()
                      .contains(query),
                )
                .toList()
          : const [];
      return Scaffold(
        appBar: financeBar(
          widget.publicOnly
              ? 'Cơ sở đã duyệt'
              : s.role == DemoRole.admin
              ? 'Quản lý cơ sở'
              : 'Sân của tôi',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.publicOnly) FinanceSaveNotice(session: s),
            TextField(
              key: const Key('facility-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm tên hoặc địa chỉ cơ sở',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: () => setState(_search.clear),
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.publicOnly)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in {
                    'all': 'Tất cả',
                    'draft': 'Nháp',
                    'pending': 'Chờ duyệt',
                    'rejected': 'Bổ sung',
                    'approved': 'Đã duyệt',
                    'suspended': 'Tạm ngưng',
                  }.entries)
                    ChoiceChip(
                      key: Key('facility-filter-${entry.key}'),
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                ],
              ),
            if (!widget.publicOnly && s.role == DemoRole.owner)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: FilledButton.icon(
                  key: const Key('facility-add'),
                  icon: const Icon(Icons.add),
                  label: Text(
                    s.facilityFormDraft() == null
                        ? 'Thêm cơ sở'
                        : 'Tiếp tục bản nháp',
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FacilityFormScreen(session: s),
                    ),
                  ),
                ),
              ),
            if (widget.publicOnly && public.isEmpty ||
                !widget.publicOnly && managed.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Chưa có cơ sở phù hợp.'),
              ),
            for (final f in managed)
              _facilityTile(
                profile: f.draft,
                id: f.id,
                label: f.label,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FacilityDetailScreen(session: s, facility: f),
                  ),
                ),
              ),
            for (final f in public)
              _facilityTile(
                profile: f.profile,
                id: f.id,
                label: 'Đã duyệt',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicFacilityScreen(session: s, id: f.id),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Hồ sơ cơ sở demo. Phê duyệt trên thiết bị không phải xác minh pháp lý.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
  Widget _facilityTile({
    required FacilityProfile profile,
    required String id,
    required String label,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('facility-$id'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile.photo.isNotEmpty)
                _FacilityPhoto(encoded: profile.photo),
              const SizedBox(height: 8),
              Text(
                profile.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '$id · $label',
                style: const TextStyle(color: AppColors.darkGreen),
              ),
              Text('${profile.sport} · ${profile.address}'),
              Text(
                '${profile.courtCount} sân · ${bookingMoney(profile.baseRate)} / giờ',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({
    super.key,
    required this.session,
    required this.facility,
  });
  final DemoSession session;
  final DemoFacility facility;
  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _perform(VoidCallback action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      action();
      await widget.session.flush();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Không thể cập nhật hồ sơ.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(bool approve) async {
    final revision = widget.facility.revision;
    final note = approve
        ? ''
        : await financeText(
            context,
            'Yêu cầu bổ sung',
            minimum: 5,
            maximum: 300,
          );
    if (!mounted || note == null) return;
    if (approve &&
        !await financeConfirm(
          context,
          'Duyệt hồ sơ cơ sở?',
          'Công bố thông tin demo. Đây không phải kiểm tra giấy phép thật.',
        )) {
      return;
    }
    if (mounted) {
      await _perform(
        () => widget.session.reviewFacility(
          widget.facility,
          approve: approve,
          note: note,
          expectedRevision: revision,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session, f = widget.facility;
      if (!s.canManageFacility(f)) {
        return Scaffold(
          appBar: financeBar('Chi tiết cơ sở'),
          body: const Center(child: Text('Chưa có quyền truy cập.')),
        );
      }
      final admin = s.role == DemoRole.admin;
      if (admin && f.state == 'pending') {
        return AdminFacilityReviewScreen(session: s, facility: f);
      }
      if (!admin && f.state == 'pending') {
        return FacilityPendingScreen(session: s, facility: f);
      }
      return Scaffold(
        appBar: financeBar('Chi tiết cơ sở'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              '${f.id} · ${f.label}',
              key: const Key('facility-status'),
              style: const TextStyle(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (f.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(f.note),
              ),
            ..._profileDetails(f.draft, s.courtTypeName(f.draft.courtTypeId)),
            if (f.published != null)
              TextButton.icon(
                key: const Key('facility-calendar'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FacilityCalendarScreen(session: s, id: f.id),
                  ),
                ),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Lịch cơ sở'),
              ),
            const Divider(height: 24),
            const Text(
              'Ảnh giấy tờ mẫu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (f.draft.legalProof.isEmpty)
              const Text('Chưa bổ sung')
            else
              _FacilityLegalDocument(
                session: s,
                encoded: f.draft.legalProof,
                facility: f,
              ),
            const Text(
              'Chỉ dùng ảnh thử nghiệm, không nhập giấy tờ cá nhân thật.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('facility-error'),
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            if (!admin && f.state != 'pending') ...[
              OutlinedButton.icon(
                key: const Key('facility-policy-edit'),
                icon: const Icon(Icons.rule_outlined),
                label: const Text('Chính sách hủy & hoàn tiền'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CancellationPolicyScreen(session: s, facility: f),
                        ),
                      ),
              ),
              OutlinedButton.icon(
                key: const Key('facility-edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa hồ sơ'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FacilityFormScreen(session: s, facility: f),
                        ),
                      ),
              ),
              if (f.state == 'draft' || f.state == 'rejected')
                FilledButton(
                  key: const Key('facility-submit'),
                  onPressed: _busy
                      ? null
                      : () => _perform(() => s.submitFacility(f)),
                  child: const Text('Gửi yêu cầu duyệt sân'),
                ),
            ],
            if (admin && f.state == 'pending') ...[
              FilledButton(
                key: const Key('facility-approve'),
                onPressed: _busy ? null : () => _review(true),
                child: const Text('Phê duyệt hồ sơ'),
              ),
              OutlinedButton(
                key: const Key('facility-reject'),
                onPressed: _busy ? null : () => _review(false),
                child: const Text('Yêu cầu bổ sung'),
              ),
            ],
            if (admin && f.published != null)
              OutlinedButton(
                key: const Key('facility-suspend'),
                onPressed: _busy
                    ? null
                    : () async {
                        final suspended = f.suspended;
                        if (await financeConfirm(
                              context,
                              suspended ? 'Mở lại cơ sở?' : 'Tạm ngưng cơ sở?',
                              'Thay đổi hiển thị hồ sơ trong danh sách cơ sở đã duyệt.',
                            ) &&
                            mounted) {
                          await _perform(
                            () => s.suspendFacility(f, !suspended),
                          );
                        }
                      },
                child: Text(f.suspended ? 'Mở lại cơ sở' : 'Tạm ngưng cơ sở'),
              ),
            if (f.published != null)
              TextButton(
                key: const Key('facility-public-preview'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicFacilityScreen(session: s, id: f.id),
                  ),
                ),
                child: const Text('Xem thông tin đang công bố'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Bản nháp và đề nghị đang duyệt không thay thế thông tin đã công bố. Hồ sơ mới chưa được nối vào lịch đặt sân.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      );
    },
  );
}

class PublicFacilityScreen extends StatelessWidget {
  const PublicFacilityScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final f = session.initialized
          ? session.publicFacilities.where((f) => f.id == id).firstOrNull
          : null;
      return Scaffold(
        appBar: financeBar('Cơ sở đã duyệt'),
        body: f == null
            ? const Center(child: Text('Cơ sở chưa công bố hoặc đã tạm ngưng.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._profileDetails(
                    f.profile,
                    session.courtTypeName(f.profile.courtTypeId),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: Key('facility-reviews-$id'),
                    icon: const Icon(Icons.star_outline),
                    label: Text(
                      'Đánh giá · ${session.facilityRating(id).toStringAsFixed(1)}/5',
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReviewsScreen(session: session, facilityId: id),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('facility-book'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FacilityBookingScreen(session: session, id: id),
                      ),
                    ),
                    icon: const Icon(Icons.event_available),
                    label: const Text('Đặt sân'),
                  ),
                ],
              ),
      );
    },
  );
}

List<Widget> _profileDetails(FacilityProfile p, String typeName) => [
  if (p.photo.isNotEmpty) _FacilityPhoto(encoded: p.photo),
  const SizedBox(height: 12),
  Text(
    p.name,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  Text('${p.sport} · ${p.courtCount} sân'),
  if (typeName.isNotEmpty) Text('Loại sân: $typeName'),
  const SizedBox(height: 12),
  Text('${p.address}, ${p.district}, ${p.city}'),
  Text('Liên hệ: ${p.phone}'),
  if (p.receivingAccount case final account?) ...[
    const Divider(height: 24),
    const Text('Nhận tiền mô phỏng · Không chuyển tiền thật'),
    Text('${account.bank} · ${account.holder} · ${account.masked}'),
  ],
  Text(
    'Giờ hoạt động: ${p.openHour.toString().padLeft(2, '0')}:00–${p.closeHour.toString().padLeft(2, '0')}:00',
  ),
  Text(
    '${bookingMoney(p.baseRate)} / giờ',
    style: const TextStyle(
      color: AppColors.darkGreen,
      fontWeight: FontWeight.w700,
    ),
  ),
  if (p.description.isNotEmpty) ...[
    const Divider(height: 24),
    const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.w700)),
    Text(p.description),
  ],
  if (p.amenities.isNotEmpty) ...[
    const Divider(height: 24),
    const Text('Tiện ích', style: TextStyle(fontWeight: FontWeight.w700)),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in p.amenities)
          Chip(label: Text(a), avatar: const Icon(Icons.check, size: 16)),
      ],
    ),
  ],
  ...[
    const Divider(height: 24),
    const Text('Chính sách hủy', style: TextStyle(fontWeight: FontWeight.w700)),
    Text(p.cancellationPolicy.summary),
    if (p.cancelPolicy.isNotEmpty) Text(p.cancelPolicy),
  ],
];

class _FacilityPhoto extends StatefulWidget {
  const _FacilityPhoto({required this.encoded});
  final String encoded;
  @override
  State<_FacilityPhoto> createState() => _FacilityPhotoState();
}

class _FacilityPhotoState extends State<_FacilityPhoto> {
  late Uint8List _bytes = decodeProof(widget.encoded);
  @override
  void didUpdateWidget(_FacilityPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.encoded != widget.encoded) {
      _bytes = decodeProof(widget.encoded);
    }
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Image.memory(
      _bytes,
      cacheWidth: 1200,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Center(child: Text('Không đọc được ảnh.')),
    ),
  );
}

class _FacilityLegalDocument extends StatelessWidget {
  const _FacilityLegalDocument({
    required this.session,
    required this.encoded,
    this.facility,
  });
  final DemoSession session;
  final String encoded;
  final DemoFacility? facility;
  @override
  Widget build(BuildContext context) {
    if (!isFacilityPdf(encoded)) return _FacilityPhoto(encoded: encoded);
    final bytes = decodeFacilityDocument(encoded);
    return ListTile(
      key: const Key('facility-pdf-document'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: const Text('Tài liệu PDF'),
      subtitle: Text('${(bytes.length / 1024).toStringAsFixed(1)} KB'),
      trailing: const Icon(Icons.open_in_full),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FacilityDocumentScreen(
            session: session,
            encoded: encoded,
            actor: session.user!.identifier,
            facility: facility,
          ),
        ),
      ),
    );
  }
}

class FacilityFormScreen extends StatefulWidget {
  const FacilityFormScreen({
    super.key,
    required this.session,
    this.facility,
    this.pickImage,
    this.pickPdf,
    this.editProfile = false,
    this.claimVenueId,
  });
  final DemoSession session;
  final DemoFacility? facility;
  final Future<Uint8List?> Function()? pickImage;
  final Future<Uint8List?> Function()? pickPdf;
  final bool editProfile;
  final String? claimVenueId;
  @override
  State<FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<FacilityFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late final TextEditingController _bank, _holder, _number;
  late final int? _claimRevision;
  String get _sourceId =>
      widget.facility?.sourceVenueId ?? widget.claimVenueId ?? '';
  late String _sport, _photo, _legal;
  late String _courtType;
  late Set<String> _amenities;
  late int _open, _close;
  late final int? _revision;
  late final bool _editingPending;
  late final String? _actor;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = widget.facility?.draft;
    final claim =
        _sourceId.isEmpty ||
            !widget.session.initialized ||
            widget.session.user == null ||
            widget.session.role != DemoRole.owner
        ? null
        : widget.session.ownVenueClaim(_sourceId);
    final source = widget.session.currentVenues
        .where((v) => v.id == _sourceId)
        .firstOrNull;
    _claimRevision = claim?.revision;
    _bank = TextEditingController(text: p?.receivingAccount?.bank ?? '');
    _holder = TextEditingController(text: p?.receivingAccount?.holder ?? '');
    _number = TextEditingController(text: p?.receivingAccount?.number ?? '');
    _revision = widget.facility?.revision;
    _editingPending = widget.facility?.state == 'pending';
    _actor = widget.session.user?.identifier;
    _fields = {
      for (final e in {
        'name': p?.name ?? claim?.venueName ?? '',
        'address': p?.address ?? source?.address ?? '',
        'city': p?.city ?? 'TP.HCM',
        'district': p?.district ?? '',
        'phone': p?.phone ?? claim?.phone ?? '',
        'ownerName':
            p?.ownerName ?? claim?.contact ?? widget.session.user?.name ?? '',
        'courtCount': '${p?.courtCount ?? 1}',
        'baseRate': p != null
            ? '${p.baseRate}'
            : _sourceId.isEmpty
            ? '120000'
            : '',
        'description': p?.description ?? '',
        'cancelPolicy': p?.cancelPolicy ?? '',
      }.entries)
        e.key: TextEditingController(text: e.value),
    };
    _sport = p?.sport ?? source?.sport ?? 'Cầu lông';
    _courtType = p?.courtTypeId ?? '';
    _photo = p?.photo ?? '';
    _legal = p?.legalProof ?? '';
    _amenities = {...?p?.amenities};
    _open = p?.openHour ?? 6;
    _close = p?.closeHour ?? 22;
    if (_sourceId.isEmpty &&
        widget.session.initialized &&
        widget.session.role == DemoRole.owner &&
        (widget.facility == null ||
            widget.session.canManageFacility(widget.facility!))) {
      final saved = widget.session.facilityFormDraft(widget.facility);
      if (saved != null) {
        for (final e in saved.fields.entries) {
          _fields[e.key]!.text = e.value;
        }
        _sport = saved.sport;
        _courtType = saved.courtTypeId;
        _photo = saved.photo;
        _legal = saved.legalProof;
        _amenities = {...saved.amenities};
        _open = saved.openHour;
        _close = saved.closeHour;
      }
    }
  }

  bool get _sameActor =>
      widget.session.user?.identifier == _actor &&
      widget.session.role == DemoRole.owner;
  bool get _primary =>
      widget.facility != null &&
      widget.session.isPrimaryFacility(widget.facility!);
  bool get _pendingStale =>
      _editingPending &&
      (widget.facility!.state != 'pending' ||
          widget.facility!.revision != _revision);

  Future<void> _savePartial() async {
    if (_busy || !_sameActor) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.saveFacilityFormDraft(
        FacilityFormDraft(
          fields: {for (final e in _fields.entries) e.key: e.value.text},
          facilityId: widget.facility?.id ?? '',
          revision: _revision ?? 0,
          sport: _sport,
          courtTypeId: _courtType,
          photo: _photo,
          legalProof: _legal,
          amenities: _amenities,
          openHour: _open,
          closeHour: _close,
        ),
        facility: widget.facility,
      );
      if (!await widget.session.flush()) {
        throw StateError(
          'Chưa lưu được vào thiết bị. Thử lưu lại trước khi thoát.',
        );
      }
      if (mounted && _sameActor) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã giữ bản nháp đang nhập.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e is StateError ? e.message : 'Không lưu được bản nháp.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discardPartial() async {
    if (_busy || !_sameActor) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ bản nháp đang nhập?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ bản nháp'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_sameActor) return;
    widget.session.discardFacilityFormDraft(widget.facility);
    if (!await widget.session.flush()) {
      if (mounted) {
        setState(() => _error = 'Chưa lưu được thao tác bỏ nháp. Thử lại.');
      }
      return;
    }
    if (mounted && _sameActor) Navigator.pop(context);
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _bank.dispose();
    _holder.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _pick(bool legal) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await (widget.pickImage ?? ProofPicker.pick)();
      if (bytes != null && mounted && _sameActor) {
        setState(() {
          if (legal) {
            _legal = encodeProof(bytes);
          } else {
            _photo = encodeProof(bytes);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không chọn được ảnh PNG/JPEG tối đa 400KB.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPdf() async {
    if (_busy || !_sameActor) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await (widget.pickPdf ?? pickFacilityPdf)();
      if (bytes != null && mounted && _sameActor) {
        final encoded = encodeFacilityPdf(bytes);
        setState(() => _legal = encoded);
      }
    } catch (_) {
      if (mounted && _sameActor) {
        setState(
          () => _error = 'Chọn PDF đọc được, không khóa mật khẩu, tối đa 400KB và 50 trang.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool submit = false}) async {
    if (_busy || !_sameActor || !_form.currentState!.validate()) return;
    if ((submit || _editingPending) && (_photo.isEmpty || _legal.isEmpty)) {
      setState(
        () => _error = 'Thêm ảnh sân và giấy tờ mẫu trước khi gửi duyệt.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = FacilityProfile(
        name: _fields['name']!.text.trim(),
        sport: _sport,
        courtTypeId: _courtType,
        address: _fields['address']!.text.trim(),
        city: _fields['city']!.text.trim(),
        district: _fields['district']!.text.trim(),
        phone: DemoSession.normalize(_fields['phone']!.text),
        ownerName: _fields['ownerName']!.text.trim(),
        courtCount: int.tryParse(_fields['courtCount']!.text) ?? 0,
        baseRate: int.tryParse(_fields['baseRate']!.text) ?? 0,
        openHour: _open,
        closeHour: _close,
        description: _fields['description']!.text.trim(),
        cancelPolicy: _fields['cancelPolicy']!.text.trim(),
        cancellationPolicy:
            widget.facility?.draft.cancellationPolicy ??
            const CancellationPolicy.standard(),
        photo: _photo,
        legalProof: _legal,
        amenities: _amenities,
        receivingAccount: _sourceId.isEmpty
            ? widget.facility?.draft.receivingAccount
            : [
                _bank.text,
                _holder.text,
                _number.text,
              ].every((v) => v.trim().isEmpty)
            ? null
            : DemoBankAccount.fromJson({
                'bank': _bank.text.trim(),
                'holder': _holder.text.trim(),
                'number': _number.text.trim(),
                'revision':
                    (widget.facility?.draft.receivingAccount?.revision ?? 0) +
                    1,
              }),
      );
      if (submit &&
          _courtType.isNotEmpty &&
          !widget.session.managedCourtTypes.any(
            (t) => t.id == _courtType && t.state == 'approved',
          )) {
        throw StateError(
          'Chọn loại sân đang được phê duyệt trước khi gửi hồ sơ.',
        );
      }
      final DemoFacility f;
      if (submit && _sourceId.isNotEmpty && p.receivingAccount == null) {
        throw StateError(
          'Bổ sung ngân hàng, chủ tài khoản và số tài khoản mô phỏng.',
        );
      }
      if (_editingPending) {
        f = widget.facility!;
        widget.session.updatePendingFacility(
          p,
          facility: f,
          expectedRevision: _revision!,
        );
      } else {
        f = widget.session.saveFacility(
          p,
          facility: widget.facility,
          expectedRevision: _revision,
          sourceVenueId: _sourceId,
          expectedClaimRevision: _claimRevision,
        );
        if (submit) widget.session.submitFacility(f);
      }
      if (!await widget.session.flush()) {
        throw StateError(
          'Chưa lưu được hồ sơ trên thiết bị. Dùng nút Thử lưu lại phía trên trước khi thoát.',
        );
      }
      if (mounted && _sameActor) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FacilityDetailScreen(session: widget.session, facility: f),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Kiểm tra số sân, đơn giá và giờ hoạt động.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _text(
    String key,
    String label, {
    int min = 1,
    int max = 100,
    bool numeric = false,
    bool optional = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: Key('facility-field-$key'),
          controller: _fields[key],
          enabled:
              !_busy &&
              !(_primary &&
                  ['courtCount', 'baseRate', 'cancelPolicy'].contains(key)),
          style: const TextStyle(fontSize: 12),
          maxLength: max,
          maxLines: lines,
          keyboardType: numeric
              ? TextInputType.number
              : key == 'phone'
              ? TextInputType.phone
              : TextInputType.text,
          decoration: InputDecoration(
            counterText: '',
            errorMaxLines: 3,
            hintText: optional ? 'Không bắt buộc' : null,
          ),
          validator: (v) {
            final text = (v ?? '').trim();
            if (optional && text.isEmpty) return null;
            if (text.length < min || text.length > max) {
              return 'Nhập $min–$max ký tự.';
            }
            if (key == 'phone' &&
                !RegExp(r'^0[35789]\d{8}$')
                    .hasMatch(DemoSession.normalize(text))) {
              return 'Số điện thoại chưa hợp lệ.';
            }
            if (numeric && int.tryParse(text) == null) return 'Nhập số nguyên.';
            return null;
          },
        ),
      ],
    ),
  );
  Widget _bankField(
    TextEditingController controller,
    String key,
    String label,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: Key('facility-bank-$key'),
      controller: controller,
      enabled: !_busy,
      maxLength: key == 'number'
          ? 24
          : key == 'bank'
          ? 80
          : 60,
      keyboardType: key == 'number' ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (value) {
        if ([
          _bank.text,
          _holder.text,
          _number.text,
        ].every((v) => v.trim().isEmpty)) {
          return null;
        }
        final text = (value ?? '').trim();
        if (key == 'number') {
          return RegExp(r'^\d{6,24}$').hasMatch(text)
              ? null
              : 'Số tài khoản cần 6–24 chữ số.';
        }
        return text.length >= 3 ? null : 'Nhập ít nhất 3 ký tự.';
      },
    ),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, size) => size.maxWidth < 280 || ownerLarge(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          ),
  );
  Widget _hour(bool opening) => DropdownButtonFormField<int>(
    initialValue: opening ? _open : _close,
    isExpanded: true,
    style: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      color: AppColors.ink,
    ),
    decoration: InputDecoration(
      labelText: opening ? 'Giờ mở cửa' : 'Giờ đóng cửa',
      prefixIcon: const Icon(Icons.schedule, size: 16),
    ),
    items: [
      for (var i = opening ? 0 : 1; i <= (opening ? 23 : 24); i++)
        DropdownMenuItem(
          value: i,
          child: Text('${i.toString().padLeft(2, '0')}:00'),
        ),
    ],
    onChanged: _busy || _primary
        ? null
        : (v) => setState(() {
            if (opening) {
              _open = v!;
            } else {
              _close = v!;
            }
          }),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!s.initialized ||
          s.user == null ||
          s.role != DemoRole.owner ||
          (widget.facility != null && !s.canManageFacility(widget.facility!))) {
        return Scaffold(
          appBar: financeBar('Hồ sơ cơ sở'),
          body: const Center(child: Text('Chưa có quyền truy cập.')),
        );
      }
      return Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            labelStyle: const TextStyle(fontSize: 11, color: AppColors.muted),
            hintStyle: const TextStyle(fontSize: 11, color: AppColors.muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.green),
            ),
          ),
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: OwnerBar(
            title: widget.facility == null ? 'Thêm sân' : 'Chỉnh sửa sân',
            subtitle: _editingPending
                ? widget.facility!.draft.name
                : 'Thông tin đăng ký cơ sở',
            large: ownerLarge(context),
            icon: Icons.description_outlined,
            onAction: _busy
                ? null
                : _editingPending || widget.editProfile
                ? () => ownerOpen(
                    context,
                    FacilityDetailScreen(
                      session: s,
                      facility: widget.facility!,
                    ),
                  )
                : _sourceId.isEmpty
                ? _savePartial
                : () => _save(),
          ),
          bottomNavigationBar: const OwnerNavigation(),
          body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FinanceSaveNotice(session: s),
                if (_sourceId.isNotEmpty) ...[
                  Text('Nguồn địa điểm: $_sourceId'),
                  const Text(
                    'Cấu hình thử nghiệm · Không xác minh cơ sở hoặc chuyển tiền thật.',
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F6ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _pendingStale && !_busy
                        ? 'Hồ sơ đã được xử lý hoặc thay đổi. Mở lại hồ sơ trước khi sửa.'
                        : _primary
                        ? 'Hồ sơ sân chính: giữ 3 sân cầu lông, giờ 06:00–22:00. Giá và điều kiện hủy tiếp tục theo thiết lập vận hành hiện tại. Thông tin hồ sơ sửa đổi cần được duyệt.'
                        : _editingPending
                        ? 'Hồ sơ đang chờ duyệt. Thông tin bổ sung sẽ được gửi lại để SportMatch kiểm tra.'
                        : 'Điền thông tin cơ sở để gửi yêu cầu duyệt sân trên SportMatch.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.darkGreen,
                    ),
                  ),
                ),
                OwnerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading('Thông tin cơ bản'),
                      _text('name', 'Tên cơ sở', min: 3),
                      DropdownButtonFormField<String>(
                        initialValue: _sport,
                        isExpanded: true,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.ink,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Môn thể thao',
                        ),
                        items: [
                          for (final sport in facilitySports)
                            DropdownMenuItem(value: sport, child: Text(sport)),
                        ],
                        onChanged: _busy || _primary
                            ? null
                            : (v) => setState(() {
                                _sport = v!;
                                _courtType = '';
                              }),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'facility-court-type-$_sport-$_courtType',
                        ),
                        initialValue: _courtType,
                        isExpanded: true,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.ink,
                        ),
                        itemHeight: null,
                        selectedItemBuilder: (context) => [
                          const Text(
                            'Loại tiêu chuẩn',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          for (final t in s.managedCourtTypes.where(
                            (t) =>
                                t.sport == _sport &&
                                (t.state == 'approved' || t.id == _courtType),
                          ))
                            Text(t.id),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Loại sân',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Loại tiêu chuẩn'),
                          ),
                          for (final t in s.managedCourtTypes.where(
                            (t) =>
                                t.sport == _sport &&
                                (t.state == 'approved' || t.id == _courtType),
                          ))
                            DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.name}${t.state == 'suspended' ? ' (tạm ngưng)' : ''}',
                              ),
                            ),
                        ],
                        onChanged: _busy || _primary
                            ? null
                            : (v) => setState(() => _courtType = v!),
                      ),
                      if (_courtType.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(s.courtTypeName(_courtType)),
                        ),
                      const SizedBox(height: 14),
                      _text('address', 'Địa chỉ', min: 5, max: 200),
                      _pair(
                        _text('city', 'Tỉnh / Thành phố', min: 2, max: 60),
                        _text('district', 'Quận / Huyện', min: 2, max: 60),
                      ),
                      _text('phone', 'Số điện thoại liên hệ', max: 30),
                      _text(
                        'description',
                        'Mô tả cơ sở',
                        max: 1000,
                        optional: true,
                        lines: 3,
                      ),
                    ],
                  ),
                ),
                OwnerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading('Sân & giờ hoạt động'),
                      _text(
                        'courtCount',
                        'Số sân (1–20)',
                        numeric: true,
                        max: 2,
                      ),
                      _pair(_hour(true), _hour(false)),
                      const SizedBox(height: 14),
                      _text(
                        'baseRate',
                        'Giá thuê từ (VND / giờ)',
                        numeric: true,
                        max: 7,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Thiết lập giá chi tiết cho từng sân tại Bảng giá.',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                OwnerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading('Hình ảnh & tiện ích'),
                      if (_photo.isNotEmpty) _FacilityPhoto(encoded: _photo),
                      OutlinedButton.icon(
                        key: const Key('facility-photo'),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        onPressed: _busy ? null : () => _pick(false),
                        label: const Text('Chọn ảnh sân'),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in facilityAmenities)
                            FilterChip(
                              label: Text(a),
                              selected: _amenities.contains(a),
                              onSelected: _busy
                                  ? null
                                  : (v) => setState(() {
                                      if (v) {
                                        _amenities.add(a);
                                      } else {
                                        _amenities.remove(a);
                                      }
                                    }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đã chọn ${_amenities.length} tiện ích',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ảnh sân PNG/JPEG · tối đa 400KB · lưu 1 ảnh đại diện',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                OwnerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading('Hồ sơ & chính sách'),
                      _text('ownerName', 'Người đại diện', min: 2, max: 60),
                      if (_editingPending && _legal.isNotEmpty)
                        ListTile(
                          key: const Key('facility-pending-document'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(
                            Icons.description_outlined,
                            color: AppColors.green,
                          ),
                          title: const Text(
                            'Giấy tờ cơ sở',
                            style: TextStyle(fontSize: 11),
                          ),
                          subtitle: Text(
                            isFacilityPdf(_legal)
                                ? 'PDF giấy tờ mẫu'
                                : 'Ảnh giấy tờ mẫu',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () => ownerOpen(
                            context,
                            FacilityDocumentScreen(
                              session: s,
                              encoded: _legal,
                              actor: _actor!,
                              facility: widget.facility,
                            ),
                          ),
                        )
                      else if (_legal.isNotEmpty)
                        _FacilityLegalDocument(
                          session: s,
                          encoded: _legal,
                          facility: widget.facility,
                        ),
                      if (_editingPending)
                        Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              key: const Key('facility-legal'),
                              tooltip: 'Thay ảnh giấy tờ mẫu',
                              onPressed: _busy ? null : () => _pick(true),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.green,
                              ),
                            ),
                            IconButton(
                              key: const Key('facility-legal-pdf'),
                              tooltip: 'Thay PDF giấy tờ mẫu',
                              onPressed: _busy ? null : _pickPdf,
                              icon: const Icon(
                                Icons.picture_as_pdf_outlined,
                                color: AppColors.green,
                              ),
                            ),
                            if (_legal.isNotEmpty)
                              IconButton(
                                key: const Key('facility-legal-remove'),
                                tooltip: 'Gỡ tài liệu',
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _legal = ''),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                        )
                      else ...[
                        OutlinedButton.icon(
                          key: const Key('facility-legal'),
                          icon: const Icon(Icons.attach_file),
                          onPressed: _busy ? null : () => _pick(true),
                          label: const Text('Ảnh giấy tờ mẫu'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('facility-legal-pdf'),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          onPressed: _busy ? null : _pickPdf,
                          label: const Text('PDF giấy tờ mẫu'),
                        ),
                        if (_legal.isNotEmpty)
                          TextButton.icon(
                            key: const Key('facility-legal-remove'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy
                                ? null
                                : () => setState(() => _legal = ''),
                            label: const Text('Gỡ tài liệu'),
                          ),
                      ],
                      const Text(
                        'Giấy tờ mẫu PNG/JPEG hoặc PDF tối đa 400KB. Không dùng giấy tờ cá nhân thật.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      _text(
                        'cancelPolicy',
                        'Chính sách hủy',
                        max: 1000,
                        optional: true,
                        lines: 3,
                      ),
                      const Text(
                        'Tôi xác nhận thông tin cơ sở chính xác và đồng ý với điều khoản dành cho Chủ sân khi gửi yêu cầu.',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    key: const Key('facility-form-error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                if (_sourceId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OwnerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _heading('Tài khoản nhận tiền mô phỏng'),
                        _bankField(_bank, 'bank', 'Ngân hàng'),
                        _bankField(_holder, 'holder', 'Chủ tài khoản'),
                        _bankField(_number, 'number', 'Số tài khoản'),
                      ],
                    ),
                  ),
                ],
                if (_editingPending ||
                    (widget.editProfile && widget.facility != null)) ...[
                  ListTile(
                    key: const Key('facility-pending-status'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule, color: AppColors.green),
                    title: const Text(
                      'Trạng thái hồ sơ',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      '${widget.facility!.label} ›',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    onTap: () => ownerOpen(
                      context,
                      FacilityDetailScreen(
                        session: s,
                        facility: widget.facility!,
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const Key('facility-save-pending'),
                    onPressed: _busy || _pendingStale
                        ? null
                        : () => _save(submit: !_editingPending),
                    child: Text(_busy ? 'Đang lưu...' : 'Lưu thay đổi'),
                  ),
                  OutlinedButton(
                    key: const Key('facility-cancel-changes'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: _busy ? null : () => Navigator.maybePop(context),
                    child: const Text('Hủy thay đổi'),
                  ),
                ] else ...[
                  FilledButton(
                    key: const Key('facility-submit-application'),
                    onPressed: _busy ? null : () => _save(submit: true),
                    child: Text(
                      _busy ? 'Đang lưu...' : 'Gửi yêu cầu duyệt sân',
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('facility-save-draft'),
                    onPressed: _busy ? null : () => _save(),
                    child: const Text('Lưu bản nháp'),
                  ),
                  if (_sourceId.isEmpty)
                    OutlinedButton.icon(
                      key: const Key('facility-save-partial'),
                      onPressed: _busy ? null : _savePartial,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Lưu thông tin đang nhập'),
                    ),
                  if (_sourceId.isEmpty)
                    TextButton(
                      key: const Key('facility-discard-partial'),
                      onPressed: _busy ? null : _discardPartial,
                      child: const Text('Bỏ bản nháp đang nhập'),
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    },
  );
}
