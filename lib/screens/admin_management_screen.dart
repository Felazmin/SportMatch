import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_activities.dart';
import '../demo/demo_court_types.dart';
import '../demo/demo_facilities.dart';
import '../demo/demo_finance.dart';
import '../demo/demo_play_groups.dart';
import '../demo/demo_reviews.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import 'admin_account_screen.dart';
import 'admin_facility_review_screen.dart';
import 'admin_players_screen.dart';
import 'admin_review_widgets.dart';
import 'approval_center_screen.dart';
import 'facilities_screen.dart';
import 'facility_calendar_screen.dart';
import 'facility_tariffs_screen.dart';
import 'finance_screen.dart';
import 'operations_screen.dart';
import 'workflow_screen.dart';

const adminManagementKinds = [
  'Quản lý sân',
  'Quản lý chủ sân',
  'Quản lý người dùng',
  'Quản lý đánh giá',
  'Quản lý loại sân',
  'Quản lý hoạt động',
  'Quản lý hội nhóm',
];

class AdminManagementEntry {
  const AdminManagementEntry({
    required this.id,
    required this.name,
    required this.state,
    required this.description,
    this.sport = '',
    this.region = '',
    this.updated,
    this.photo = '',
    this.assetPhoto = false,
    this.data,
  });
  final String id, name, state, description, sport, region, photo;
  final DateTime? updated;
  final bool assetPhoto;
  final Object? data;
}

String adminState(String state) =>
    const {
      'all': 'Tất cả',
      'approved': 'Hoạt động',
      'pending': 'Chờ duyệt',
      'draft': 'Bản nháp',
      'rejected': 'Từ chối / cần bổ sung',
      'suspended': 'Tạm ngưng',
      'visible': 'Đã hiển thị',
      'hidden': 'Đã ẩn',
      'unverified': 'Chưa xác minh',
      'verified': 'Đã xác minh',
      'cancelled': 'Đã hủy',
      'supplement': 'Yêu cầu bổ sung',
      'ongoing': 'Đang diễn ra',
    }[state] ??
    state;

List<AdminManagementEntry> adminManagementEntries(DemoSession s, int kind) {
  if (s.user == null || s.role != DemoRole.admin) {
    throw StateError('Chỉ Admin được truy cập.');
  }
  switch (kind) {
    case 0:
      return [
        AdminManagementEntry(
          id: '',
          name: DemoBooking.venue,
          state: s.publishedCourts.enabled.any((v) => v)
              ? 'approved'
              : 'suspended',
          description: '${DemoBooking.address}\n3 sân · Cầu lông\nCơ sở chính',
          sport: 'Cầu lông',
          region: 'TP. Hồ Chí Minh',
          photo: demoVenues.first.image,
          assetPhoto: true,
        ),
        for (final f in s.managedFacilities)
          AdminManagementEntry(
            id: f.id,
            name: f.draft.name,
            state: f.suspended ? 'suspended' : f.state,
            description:
                '${f.draft.address}, ${f.draft.district}\nChủ sân: ${f.draft.ownerName}\n${f.draft.courtCount} sân · ${f.draft.sport}',
            sport: f.draft.sport,
            region: f.draft.city,
            updated: f.updated,
            photo: f.draft.photo,
            data: f,
          ),
      ];
    case 1:
      final v = s.ownerVerification, facilities = s.managedFacilities;
      return [
        AdminManagementEntry(
          id: '__owner__',
          name:
              v?.name ??
              (facilities.isEmpty
                  ? 'Chủ sân demo'
                  : facilities.first.draft.ownerName),
          state: v?.state == 'verified'
              ? 'verified'
              : v?.state == 'pending'
              ? 'pending'
              : v?.state == 'rejected'
              ? (v?.reviewDecision == 'rejected' ? 'rejected' : 'supplement')
              : 'unverified',
          description:
              '${DemoSession.ownerEmail}\n${v?.phone ?? ''}\n${facilities.length + 1} cơ sở · ${3 + facilities.fold<int>(0, (n, f) => n + f.draft.courtCount)} sân đăng ký',
          updated: v?.updated,
          data: v,
        ),
      ];
    case 2:
      return [
        for (final u in s.managedUsers)
          AdminManagementEntry(
            id: u.identifier,
            name: u.name,
            state: s.isBlocked(u.identifier) ? 'suspended' : 'approved',
            description:
                '${u.identifier}\n${s.managedContactPhone(u.identifier)}\n${s.playerRecords(u.identifier).length} lượt đặt · ${s.managedReviews.where((r) => r.owner == u.identifier).length} đánh giá',
            updated: u.registeredAt,
            data: u,
          ),
      ];
    case 3:
      return [
        for (final r in s.managedReviews)
          AdminManagementEntry(
            id: r.bookingId,
            name: r.author,
            state: r.hidden ? 'hidden' : 'visible',
            description:
                '${s.reviewVenueName(r.bookingId)} · ★ ${r.stars}/5\n${r.message}',
            updated: r.moderatedAt ?? r.created,
            data: r,
          ),
      ];
    case 4:
      return [
        for (final t in s.managedCourtTypes)
          AdminManagementEntry(
            id: t.id,
            name: t.name,
            state: t.state == 'rejected' && t.reviewDecision == 'supplement'
                ? 'supplement'
                : t.state,
            description:
                'Môn: ${t.sport}\n${t.description}\n${s.managedFacilities.where((f) => f.draft.courtTypeId == t.id).fold<int>(0, (n, f) => n + f.draft.courtCount)} sân đăng ký áp dụng',
            sport: t.sport,
            updated: t.updated,
            data: t,
          ),
      ];
    case 5:
      return [
        for (final a in s.managedActivities)
          AdminManagementEntry(
            id: a.id,
            name: a.event.title,
            state:
                a.state == 'approved' &&
                    !s.now.isBefore(a.event.scheduledStart!) &&
                    s.now.isBefore(a.event.end(a.event.scheduledStart!))
                ? 'ongoing'
                : a.state == 'rejected' && a.reviewDecision == 'supplement'
                ? 'supplement'
                : a.state,
            description:
                '${a.event.kind.name == 'social' ? 'Giao lưu (Social)' : 'Giải đấu'}\n${adminTime(a.event.scheduledStart!)}\n${a.event.capacity} người tối đa · ${bookingMoney(a.event.fee)} / người',
            updated: a.updated,
            data: a,
          ),
      ];
    case 6:
      return [
        for (final g in s.managedPlayGroups)
          AdminManagementEntry(
            id: g.id,
            name: g.name,
            state: g.state == 'rejected' && g.reviewDecision == 'supplement'
                ? 'supplement'
                : g.state,
            description:
                '${playGroupSports[g.sport]}\n${g.description}\nQuản trị nhóm: ${g.owner}',
            sport: playGroupSports[g.sport]!,
            updated: g.updated,
            photo: g.photo,
            data: g,
          ),
      ];
    default:
      throw ArgumentError.value(kind);
  }
}

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({
    super.key,
    required this.session,
    this.initialKind = 0,
    this.embedded = false,
  });
  final DemoSession session;
  final int initialKind;
  final bool embedded;
  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  late int _kind = widget.initialKind;
  String _state = 'all', _query = '';
  String? _sport, _region;
  int? _stars;
  int _limit = 5;
  bool _newest = true;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(int? value) {
    if (value == null) return;
    setState(() {
      _kind = value;
      _state = 'all';
      _query = '';
      _search.clear();
      _sport = null;
      _region = null;
      _stars = null;
      _limit = 5;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.admin) {
        return Scaffold(
          appBar: financeBar('Quản lý'),
          body: const Center(child: Text('Chỉ Admin được truy cập.')),
        );
      }
      final all = adminManagementEntries(s, _kind),
          sports = <String>{
            for (final e in adminManagementEntries(s, _kind))
              if (e.sport.isNotEmpty) e.sport,
          }.toList()..sort();
      final regions = <String>{
        for (final e in all)
          if (e.region.isNotEmpty) e.region,
      }.toList()..sort();
      final items = all
          .where(
            (e) =>
                (_state == 'all' || e.state == _state) &&
                (_sport == null ||
                    !sports.contains(_sport) ||
                    e.sport == _sport) &&
                (_region == null ||
                    !regions.contains(_region) ||
                    e.region == _region) &&
                (_stars == null ||
                    e.data is DemoVenueReview &&
                        (e.data as DemoVenueReview).stars == _stars) &&
                venueSearchText('${e.name} ${e.id} ${e.description}')
                    .contains(venueSearchText(_query)),
          )
          .toList();
      items.sort((a, b) {
        if (a.updated == null) {
          return b.updated == null ? a.name.compareTo(b.name) : 1;
        }
        if (b.updated == null) return -1;
        return _newest
            ? b.updated!.compareTo(a.updated!)
            : a.updated!.compareTo(b.updated!);
      });
      final states = <String>{
        'all',
        ...switch (_kind) {
          0 => ['approved', 'pending', 'suspended'],
          1 => ['pending', 'verified', 'unverified'],
          2 => ['approved', 'suspended'],
          3 => ['visible', 'hidden'],
          _ => ['pending', 'approved', 'suspended'],
        },
        ...all.map((e) => e.state),
      };
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: adminReviewBar(
          context,
          adminManagementKinds[_kind],
          'Quản trị viên · ${const ['Cơ sở & sân con', 'Hồ sơ đối tác', 'Thành viên SportMatch', 'Nội dung & kiểm duyệt', 'Danh mục môn & cấu hình sân', 'Giao lưu, trận đấu & giải đấu', 'Cộng đồng SportMatch'][_kind]}',
          onNotifications: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AdminAccountScreen(session: s),
            ),
          ),
        ),
        bottomNavigationBar: widget.embedded
            ? null
            : const AdminReviewNavigation(selected: 1),
        body: ListView(
          key: const Key('admin-management-list'),
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            DropdownButtonFormField<int>(
              key: const Key('admin-management-kind'),
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Loại quản lý',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var i = 0; i < adminManagementKinds.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      adminManagementKinds[i],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
              onChanged: _select,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin-management-search'),
              controller: _search,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: const [
                  'Tên cơ sở, mã sân hoặc chủ sân',
                  'Tên, số điện thoại hoặc mã chủ sân',
                  'Tên, số điện thoại, email hoặc mã',
                  'Nội dung, tác giả hoặc tên sân',
                  'Tên môn hoặc loại sân',
                  'Tên hoạt động hoặc người tổ chức',
                  'Tên nhóm hoặc quản trị nhóm',
                ][_kind],
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: PopupMenuButton<bool>(
                  tooltip: 'Thứ tự hiển thị',
                  icon: const Icon(Icons.tune, size: 18),
                  onSelected: (v) => setState(() => _newest = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: true, child: Text('Mới cập nhật')),
                    PopupMenuItem(value: false, child: Text('Cũ nhất trước')),
                  ],
                ),
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (v) => setState(() {
                _query = v;
                _limit = 5;
              }),
            ),
            const SizedBox(height: 12),
            if (_kind == 1 || _kind == 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _metric(
                        _kind == 1 ? 'Tổng chủ sân' : 'Tổng người dùng',
                        '${all.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metric(
                        _kind == 1 ? 'Đã xác minh' : 'Mới trong tuần',
                        '${_kind == 1 ? all.where((e) => e.state == 'verified').length : all.where((e) => e.updated != null && !e.updated!.isBefore(DateTime(s.now.year, s.now.month, s.now.day).subtract(Duration(days: s.now.weekday - 1))) && !e.updated!.isAfter(s.now)).length}',
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final state in states)
                  AdminReviewChip(
                    key: Key('admin-management-state-$state'),
                    label: Text(
                      '${adminState(state)} (${state == 'all' ? all.length : all.where((e) => e.state == state).length})',
                    ),
                    selected: state == _state,
                    onSelected: (_) => setState(() {
                      _state = state;
                      _limit = 5;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (sports.isNotEmpty)
                  _scope(
                    'Môn',
                    _sport,
                    sports,
                    (v) => setState(() {
                      _sport = v;
                      _limit = 5;
                    }),
                  ),
                if (regions.isNotEmpty)
                  _scope(
                    'Khu vực',
                    _region,
                    regions,
                    (v) => setState(() {
                      _region = v;
                      _limit = 5;
                    }),
                  ),
                if (_kind == 3)
                  PopupMenuButton<int>(
                    key: const Key('admin-management-stars'),
                    onSelected: (v) => setState(() {
                      _stars = v == 0 ? null : v;
                      _limit = 5;
                    }),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 0, child: Text('Tất cả sao')),
                      for (var i = 1; i <= 5; i++)
                        PopupMenuItem(value: i, child: Text('$i sao')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _stars == null ? 'Tất cả sao ⌄' : '$_stars sao ⌄',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
            if (_kind == 0)
              const AdminReviewNote(
                'Quản lý theo cơ sở; mỗi cơ sở có nhiều sân con. Hồ sơ chờ duyệt chưa công khai và chưa nhận đặt lịch mới.',
              ),
            if (_kind == 1)
              const AdminReviewNote(
                'Xác minh chủ sân và duyệt cơ sở là hai quyết định riêng. Xác minh không tự động công bố các cơ sở đang chờ duyệt.',
              ),
            if (_kind == 3)
              const AdminReviewNote(
                'Đánh giá gốc chỉ đọc. Không ẩn nhận xét chỉ vì nội dung tiêu cực. Chưa có dữ liệu báo cáo hoặc bằng chứng riêng trong bản hiện tại.',
                warning: true,
              ),
            if (_kind == 4)
              const AdminReviewNote(
                'Loại sân khác cơ sở mới. Đây là danh mục môn và đặc điểm sân, không phải hồ sơ đăng ký cơ sở.',
              ),
            if (_kind >= 5)
              const AdminReviewNote(
                'Nội dung chờ duyệt chưa công khai. Không thay đổi nội dung do người tổ chức hoặc người lập nhóm cung cấp.',
                warning: true,
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  const [
                    'Danh sách cơ sở',
                    'Chủ sân trong hệ thống',
                    'Danh sách thành viên',
                    'Danh sách đánh giá',
                    'Danh mục & đề xuất',
                    'Danh sách hoạt động',
                    'Danh sách hội nhóm',
                  ][_kind],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  key: const Key('admin-management-sort'),
                  onPressed: () => setState(() => _newest = !_newest),
                  child: Text(
                    _newest ? 'Mới cập nhật' : 'Cũ nhất trước',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            if (items.isEmpty)
              const AdminReviewCard(
                children: [Text('Không có kết quả phù hợp.')],
              ),
            for (final e in items.take(_limit))
              AdminReviewCard(
                key: Key('admin-management-entry-$_kind-${e.id}'),
                onTap: () => _open(e),
                children: [
                  if (e.photo.isNotEmpty) ...[
                    adminManagementPhoto(e.photo, asset: e.assetPhoto),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    e.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    adminState(e.state),
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          ['suspended', 'rejected', 'hidden'].contains(e.state)
                          ? Colors.red
                          : e.state == 'pending'
                          ? const Color(0xFF855200)
                          : AppColors.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    e.description,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    e.id.isEmpty ? 'Cơ sở chính' : e.id,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                  if (e.updated != null)
                    Text(
                      'Cập nhật ${adminTime(e.updated!)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _open(e),
                      child: Text(
                        e.state == 'pending'
                            ? 'Kiểm tra & duyệt hồ sơ →'
                            : 'Xem chi tiết →',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            Text(
              'Đang hiển thị ${items.take(_limit).length} / ${items.length} kết quả',
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            if (items.length > _limit)
              OutlinedButton(
                key: const Key('admin-management-more'),
                onPressed: () => setState(() => _limit += 5),
                child: const Text('Xem thêm kết quả'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('management-approval-center'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ApprovalCenterScreen(session: s),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Trung tâm duyệt'),
              ),
            ),
          ],
        ),
      );
    },
  );
  void _open(AdminManagementEntry e) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          _kind == 0 && e.state == 'pending' && e.data is DemoFacility
          ? AdminFacilityReviewScreen(
              session: widget.session,
              facility: e.data as DemoFacility,
            )
          : AdminManagementDetailScreen(
              session: widget.session,
              kind: _kind,
              id: e.id,
            ),
    ),
  );
  Widget _scope(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> select,
  ) => PopupMenuButton<String>(
    tooltip: label,
    onSelected: (v) => select(v.isEmpty ? null : v),
    itemBuilder: (_) => [
      PopupMenuItem(value: '', child: Text('Tất cả $label')),
      for (final v in values) PopupMenuItem(value: v, child: Text(v)),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value != null && values.contains(value) ? value : 'Tất cả $label',
            style: const TextStyle(fontSize: 10),
          ),
          const Icon(Icons.expand_more, size: 15),
        ],
      ),
    ),
  );
  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreen,
          ),
        ),
      ],
    ),
  );
}

Widget adminManagementPhoto(String encoded, {bool asset = false}) => ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: AspectRatio(
    aspectRatio: 1.85,
    child: asset
        ? Image.asset(encoded, fit: BoxFit.cover)
        : Image.memory(decodeProof(encoded), fit: BoxFit.cover),
  ),
);

class AdminManagementDetailScreen extends StatefulWidget {
  const AdminManagementDetailScreen({
    super.key,
    required this.session,
    required this.kind,
    required this.id,
  });
  final DemoSession session;
  final int kind;
  final String id;
  @override
  State<AdminManagementDetailScreen> createState() =>
      _AdminManagementDetailScreenState();
}

class _AdminManagementDetailScreenState
    extends State<AdminManagementDetailScreen> {
  final _reason = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String? _error;
  int _activityTab = 0;
  @override
  void dispose() {
    _reason.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _allowed =>
      widget.session.user != null && widget.session.role == DemoRole.admin;
  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Text(text, style: const TextStyle(fontSize: 12, height: 1.6)),
  );
  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!_allowed) {
        return Scaffold(
          appBar: financeBar('Chi tiết quản lý'),
          body: const Center(child: Text('Chỉ Admin được truy cập.')),
        );
      }
      final entry = adminManagementEntries(
        s,
        widget.kind,
      ).where((e) => e.id == widget.id).firstOrNull;
      if (entry == null) {
        return Scaffold(
          appBar: financeBar('Chi tiết quản lý'),
          body: const Center(child: Text('Hồ sơ không còn tồn tại.')),
        );
      }
      final audit = s.operationAudit
          .where(
            (e) =>
                e.subject == widget.id ||
                e.subject.isEmpty &&
                    widget.id.isNotEmpty &&
                    RegExp(
                      '(?:^|[^A-Za-z0-9])${RegExp.escape(widget.id)}(?:\$|[^A-Za-z0-9])',
                    ).hasMatch(e.action),
          )
          .toList();
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: adminReviewBar(
          context,
          const [
            'Chi tiết sân',
            'Chi tiết chủ sân',
            'Chi tiết người dùng',
            'Xử lý đánh giá',
            'Duyệt loại sân mới',
            'Duyệt hoạt động',
            'Duyệt hội nhóm',
          ][widget.kind],
          'Quản trị viên · ${widget.id.isEmpty ? 'Cơ sở chính' : widget.id}',
          onNotifications: () => _open(AdminAccountScreen(session: s)),
        ),
        bottomNavigationBar: const AdminReviewNavigation(selected: 1),
        body: ListView(
          key: const Key('admin-management-detail-list'),
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            if (entry.state == 'pending')
              AdminReviewNote(
                'Chờ duyệt${entry.updated != null && s.now.difference(entry.updated!).inHours >= 48 ? ' · Quá 48 giờ' : ''}\nHồ sơ chưa được công khai. ${entry.updated == null ? '' : 'Cập nhật ${adminTime(entry.updated!)}.'}',
                warning: true,
              ),
            AdminReviewCard(
              children: [
                if (entry.photo.isNotEmpty) ...[
                  adminManagementPhoto(entry.photo, asset: entry.assetPhoto),
                  const SizedBox(height: 12),
                ],
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  adminState(entry.state),
                  key: const Key('admin-management-detail-state'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 12),
                _line(entry.description),
              ],
            ),
            ...switch (widget.kind) {
              0 => _facility(entry),
              1 => _owner(),
              2 => _player(),
              3 => _review(entry.data as DemoVenueReview),
              4 => _type(entry.data as DemoCourtType),
              5 => _activity(entry.data as DemoActivity),
              _ => _group(entry.data as DemoPlayGroup),
            },
            AdminReviewCard(
              title: 'Lịch sử xử lý',
              children: [
                if (audit.isEmpty)
                  const Text(
                    'Chưa có nhật ký xử lý.',
                    style: TextStyle(fontSize: 12),
                  ),
                for (final e in audit)
                  _line(
                    '${e.actor} · ${e.action}\n${adminTime(e.created)}${e.note.isEmpty ? '' : '\nLý do: ${e.note}'}',
                  ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('admin-management-error'),
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      );
    },
  );

  List<Widget> _facility(AdminManagementEntry e) {
    final s = widget.session,
        f = e.data as DemoFacility?,
        p = (e.data as DemoFacility?)?.draft;
    final bookings = s.managedBookings
        .where((b) => b.facilityId == e.id)
        .toList();
    final owner = s.ownerVerification;
    return [
      AdminReviewCard(
        title: p?.ownerName ?? owner?.name ?? 'Chủ sân demo',
        children: [
          _line(owner?.label ?? 'Chưa gửi hồ sơ xác minh'),
          _line(DemoSession.ownerEmail),
          TextButton(
            onPressed: () => _open(
              AdminManagementDetailScreen(session: s, kind: 1, id: '__owner__'),
            ),
            child: const Text('Xem hồ sơ chủ sân →'),
          ),
        ],
      ),
      AdminReviewCard(
        title: 'Môn thể thao & sân con',
        children: [
          _line('${p?.courtCount ?? 3} sân · ${p?.sport ?? 'Cầu lông'}'),
          if (p != null && p.courtTypeId.isNotEmpty)
            _line('Loại sân: ${s.courtTypeName(p.courtTypeId)}'),
          _line(
            'Kích thước / mặt sân: ${p?.description.isNotEmpty == true ? p!.description : 'Chưa có thông số riêng được khai báo.'}',
          ),
          Wrap(
            spacing: 5,
            children: [
              for (final a in p?.amenities ?? <String>{})
                Chip(label: Text(a, style: const TextStyle(fontSize: 10))),
            ],
          ),
        ],
      ),
      AdminReviewCard(
        title: 'Giá thuê & lịch hoạt động',
        children: [
          _line(
            'Giờ hoạt động: ${p?.openHour ?? 6}:00 – ${p?.closeHour ?? 22}:00 · Hằng ngày',
          ),
          _line(
            'Giá từ ${bookingMoney(p?.baseRate ?? s.minimumCourtRate)} / giờ',
          ),
          _line(
            '${bookings.where((b) => adminDate(b.start) == adminDate(s.now) && !b.cancelled).length} lịch hôm nay · ${bookings.length} lịch đã ghi nhận',
          ),
          OutlinedButton(
            onPressed: () => _open(
              e.id.isEmpty
                  ? OperationsScreen(session: s)
                  : FacilityTariffsScreen(session: s, id: e.id),
            ),
            child: const Text('Xem lịch sân & bảng giá'),
          ),
          if (f?.published != null)
            TextButton(
              onPressed: () =>
                  _open(FacilityCalendarScreen(session: s, id: e.id)),
              child: const Text('Lịch sân →'),
            ),
        ],
      ),
      AdminReviewCard(
        title: 'Hồ sơ kiểm duyệt',
        children: [
          _line('Trạng thái: ${f?.label ?? 'Cơ sở chính đã công bố'}'),
          if (f != null) facilityLegalDocument(s, f),
          _line(
            'Đánh giá công khai: ${s.publicReviewsForFacility(e.id).length} · ${s.facilityRating(e.id).toStringAsFixed(1)} / 5',
          ),
          if (f?.note.isNotEmpty == true) _line(f!.note),
        ],
      ),
      if (f != null && f.state == 'pending')
        FilledButton(
          onPressed: () =>
              _open(AdminFacilityReviewScreen(session: s, facility: f)),
          child: const Text('Xem hồ sơ chờ duyệt'),
        ),
      if (f?.published != null)
        _decisionPanel(
          'Hành động quản trị',
          [
            (
              f!.suspended ? 'Khôi phục cơ sở' : 'Tạm ngưng cơ sở',
              'facility-access',
              () => _perform(
                f.suspended ? 'Khôi phục cơ sở' : 'Tạm ngưng cơ sở',
                () => s.suspendFacility(
                  f,
                  !f.suspended,
                  reason: _reason.text.trim(),
                  expectedRevision: f.revision,
                ),
                requiredReason: true,
                revision: () => f.revision,
              ),
            ),
          ],
          warning: 'Cơ sở tạm ngưng sẽ không nhận lịch mới. Lịch đã đặt được giữ nguyên; không tự động hủy hoặc hoàn tiền.',
        ),
    ];
  }

  List<Widget> _owner() {
    final s = widget.session, v = s.ownerVerification;
    final facilities = s.managedFacilities;
    return [
      if (v?.state != 'verified')
        const AdminReviewNote(
          'Hồ sơ chủ sân chưa được xác minh. Duyệt chủ sân không đồng nghĩa với duyệt cơ sở.',
          warning: true,
        ),
      AdminReviewCard(
        title: 'Hồ sơ người đại diện',
        children: [
          _line('Họ và tên: ${v?.name ?? 'Chưa gửi hồ sơ'}'),
          _line('Liên hệ: ${v?.phone ?? 'Chưa khai báo'}'),
          const Text(
            'Ngày sinh, CCCD, mã số thuế: Chưa được cung cấp trong hồ sơ hiện tại.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
      AdminReviewCard(
        title: 'Giấy tờ xác minh',
        children: [
          if (v?.proof.isNotEmpty == true)
            adminManagementPhoto(v!.proof)
          else
            const Text('Chưa gửi giấy tờ.'),
          const SizedBox(height: 12),
          const Text(
            'Tài liệu cá nhân chỉ dành cho người có quyền xác minh. Bản hiện tại chỉ lưu ảnh hồ sơ thử nghiệm.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
      AdminReviewCard(
        title: 'Cơ sở sở hữu',
        children: [
          for (final f in facilities)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                f.draft.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${f.id} · ${f.label} · ${f.draft.courtCount} sân',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(
                f.state == 'pending'
                    ? AdminFacilityReviewScreen(session: s, facility: f)
                    : AdminManagementDetailScreen(
                        session: s,
                        kind: 0,
                        id: f.id,
                      ),
              ),
            ),
          TextButton(
            onPressed: () =>
                _open(AdminManagementDetailScreen(session: s, kind: 0, id: '')),
            child: const Text('Xem cơ sở chính →'),
          ),
        ],
      ),
      if (v != null && ['pending', 'verified'].contains(v.state))
        _decisionPanel('Quyết định kiểm duyệt', [
          if (v.state == 'pending')
            (
              'Duyệt xác minh chủ sân',
              'owner-approve',
              () => _perform(
                'Duyệt xác minh chủ sân',
                () => s.reviewOwnerVerification(
                  approve: true,
                  expectedRevision: v.revision,
                  password: _password.text,
                ),
                revision: () => s.ownerVerification!.revision,
              ),
            ),
          if (v.state == 'pending')
            (
              'Từ chối xác minh',
              'owner-reject',
              () => _perform(
                'Từ chối xác minh',
                () => s.reviewOwnerVerification(
                  approve: false,
                  reject: true,
                  expectedRevision: v.revision,
                  password: _password.text,
                  note: _reason.text,
                ),
                requiredReason: true,
                revision: () => s.ownerVerification!.revision,
              ),
            ),
          (
            'Yêu cầu bổ sung',
            'owner-supplement',
            () => _perform(
              'Yêu cầu bổ sung',
              () => s.reviewOwnerVerification(
                approve: false,
                expectedRevision: v.revision,
                password: _password.text,
                note: _reason.text,
              ),
              requiredReason: true,
              revision: () => s.ownerVerification!.revision,
            ),
          ),
        ], password: true),
      const AdminReviewNote(
        'Quyết định xác minh không tự động công bố cơ sở. Tài khoản chủ sân có thể bổ sung và gửi lại hồ sơ.',
      ),
    ];
  }

  List<Widget> _player() {
    final s = widget.session, id = widget.id, user = s.managedPlayer(widget.id);
    final records = s.playerRecords(id),
        reviews = s.managedReviews.where((r) => r.owner == id).toList();
    final paid = records
        .where(
          (r) => s.workflowPayment(r.id)?.state == DemoPaymentState.approved,
        )
        .fold<int>(0, (n, r) => n + r.total);
    return [
      AdminReviewCard(
        title: 'Thông tin hồ sơ',
        children: [
          _line(
            'Tham gia: ${user.registeredAt == null ? 'Chưa có ngày đăng ký trong dữ liệu cũ' : adminDate(user.registeredAt!)}',
          ),
          _line(
            'Điện thoại: ${s.managedContactPhone(id).isEmpty ? 'Chưa khai báo' : s.managedContactPhone(id)}',
          ),
          const Text(
            'Khu vực, môn yêu thích, lần đăng nhập gần nhất: Chưa có dữ liệu.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
      AdminReviewCard(
        title: 'Thống kê thành viên',
        children: [
          _line('Lượt đặt: ${records.length}'),
          _line('Thanh toán đã xác nhận: ${bookingMoney(paid)}'),
          _line('Đánh giá: ${reviews.length}'),
          _line('Khiếu nại: ${s.disputes.where((d) => d.owner == id).length}'),
        ],
      ),
      Wrap(
        spacing: 6,
        children: [
          for (var i = 0; i < 3; i++)
            AdminReviewChip(
              label: Text(const ['Đặt sân', 'Hội nhóm', 'Đánh giá'][i]),
              selected: _activityTab == i,
              onSelected: (_) => setState(() => _activityTab = i),
            ),
        ],
      ),
      const SizedBox(height: 12),
      AdminReviewCard(
        title: 'Hoạt động gần đây',
        children: [
          if (_activityTab == 0) ...[
            if (records.isEmpty) const Text('Chưa có lịch đặt.'),
            for (final r in records)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.title, style: const TextStyle(fontSize: 12)),
                subtitle: Text(
                  '${adminTime(r.start)}\n${bookingMoney(r.total)} · ${r.cancelled ? 'Đã hủy' : s.workflowPayment(r.id)?.label(s.now) ?? 'Chưa thanh toán'}',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => _open(WorkflowDetailScreen(session: s, id: r.id)),
              ),
          ],
          if (_activityTab == 1)
            const Text(
              'Chưa có danh sách hội nhóm theo thành viên trong hồ sơ quản trị hiện tại.',
              style: TextStyle(fontSize: 12),
            ),
          if (_activityTab == 2) ...[
            if (reviews.isEmpty) const Text('Chưa có đánh giá.'),
            for (final r in reviews)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${r.stars} / 5 · ${s.reviewVenueName(r.bookingId)}',
                  style: const TextStyle(fontSize: 12),
                ),
                subtitle: Text(r.message, style: const TextStyle(fontSize: 11)),
                onTap: () => _open(
                  AdminManagementDetailScreen(
                    session: s,
                    kind: 3,
                    id: r.bookingId,
                  ),
                ),
              ),
          ],
        ],
      ),
      AdminReviewCard(
        title: 'Hành động quản trị',
        children: [
          const AdminReviewNote(
            'Tạm khóa chặn đăng nhập và thao tác mới. Lịch đã đặt được giữ nguyên. Cần lý do và xác thực mật khẩu trước khi xác nhận.',
            warning: true,
          ),
          if (s.playerAccessDecision(id) != null)
            _line('Lý do gần nhất: ${s.playerAccessDecision(id)!.reason}'),
          OutlinedButton(
            key: const Key('admin-management-player-access'),
            onPressed: () => showPlayerAccess(context, s, id),
            child: Text(
              s.isBlocked(id) ? 'Khôi phục tài khoản' : 'Tạm khóa tài khoản',
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _review(DemoVenueReview r) => [
    AdminReviewCard(
      title: 'Đánh giá gốc',
      children: [
        _line('${r.author} · ★ ${r.stars}/5'),
        _line(
          '${widget.session.reviewVenueName(r.bookingId)}\n${adminTime(r.created)}',
        ),
        _line(r.message),
        const AdminReviewNote(
          'Nội dung gốc chỉ đọc. Quản trị viên không được chỉnh sửa nhận xét hoặc số sao của người dùng.',
        ),
      ],
    ),
    AdminReviewCard(
      title: 'Đối chiếu lịch & giao dịch',
      children: [
        _line('Lịch liên quan: ${r.bookingId}'),
        OutlinedButton(
          onPressed: () => _open(
            WorkflowDetailScreen(session: widget.session, id: r.bookingId),
          ),
          child: const Text('Xem lịch & giao dịch →'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Chưa có phản hồi riêng của chủ sân hoặc hồ sơ báo cáo kèm bằng chứng.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
    _decisionPanel(
      'Quyết định xử lý',
      [
        (
          r.hidden ? 'Khôi phục hiển thị' : 'Ẩn đánh giá',
          'review-moderate',
          () => _perform(
            r.hidden ? 'Khôi phục hiển thị' : 'Ẩn đánh giá',
            () => widget.session.moderateVenueReview(
              r.bookingId,
              hidden: !r.hidden,
              reason: _reason.text,
              expectedRevision: r.revision,
            ),
            requiredReason: true,
            revision: () => widget.session.managedReviews
                .firstWhere((v) => v.bookingId == r.bookingId)
                .revision,
          ),
        ),
      ],
      warning: 'Chỉ ẩn khi có lý do vi phạm cụ thể. Không ẩn đánh giá chỉ vì nội dung tiêu cực.',
    ),
  ];

  List<Widget> _type(DemoCourtType t) => [
    AdminReviewCard(
      title: 'Thông số loại sân',
      children: [
        _line('Môn: ${t.sport}'),
        _line(t.description),
        _line('Người gửi: Chủ sân demo'),
        const Text(
          'Kích thước và cấu hình riêng chưa được tách thành trường dữ liệu.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
    AdminReviewCard(
      title: 'Cơ sở áp dụng',
      children: [
        for (final f in widget.session.managedFacilities.where(
          (f) => f.draft.courtTypeId == t.id,
        ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.draft.name),
            subtitle: Text('${f.id} · ${f.draft.courtCount} sân'),
            onTap: () => _open(
              AdminManagementDetailScreen(
                session: widget.session,
                kind: 0,
                id: f.id,
              ),
            ),
          ),
        if (!widget.session.managedFacilities.any(
          (f) => f.draft.courtTypeId == t.id,
        ))
          const Text(
            'Chưa có cơ sở đăng ký áp dụng.',
            style: TextStyle(fontSize: 12),
          ),
      ],
    ),
    if (t.state == 'pending')
      _decisionPanel('Quyết định kiểm duyệt', [
        (
          'Phê duyệt loại sân',
          'type-approve',
          () => _perform(
            'Phê duyệt loại sân',
            () => widget.session.transitionCourtType(
              t.id,
              'approved',
              t.revision,
            ),
            revision: () => widget.session.managedCourtTypes
                .firstWhere((v) => v.id == t.id)
                .revision,
          ),
        ),
        (
          'Từ chối đề xuất',
          'type-reject',
          () => _perform(
            'Từ chối đề xuất',
            () => widget.session.transitionCourtType(
              t.id,
              'rejected',
              t.revision,
              note: _reason.text,
            ),
            requiredReason: true,
            revision: () => widget.session.managedCourtTypes
                .firstWhere((v) => v.id == t.id)
                .revision,
          ),
        ),
        (
          'Yêu cầu bổ sung',
          'type-supplement',
          () => _supplement(4, t.id, t.revision),
        ),
      ]),
    if (['approved', 'suspended'].contains(t.state))
      _decisionPanel('Hành động quản trị', [
        (
          t.state == 'approved' ? 'Tạm ngưng loại sân' : 'Khôi phục loại sân',
          'type-access',
          () => _perform(
            'Thay đổi trạng thái loại sân',
            () => widget.session.transitionCourtType(
              t.id,
              t.state == 'approved' ? 'suspended' : 'approved',
              t.revision,
              note: _reason.text,
            ),
            requiredReason: t.state == 'approved',
            revision: () => widget.session.managedCourtTypes
                .firstWhere((v) => v.id == t.id)
                .revision,
          ),
        ),
      ]),
  ];

  List<Widget> _activity(DemoActivity a) => [
    AdminReviewCard(
      title: 'Người tổ chức & lệ phí',
      children: [
        _line(
          '${a.owner} · ${widget.session.ownerVerification?.label ?? 'Chưa xác minh'}',
        ),
        _line(
          '${bookingMoney(a.event.fee)} / người · ${a.event.capacity} người tối đa',
        ),
        _line(
          'Tổng thu tối đa: ${bookingMoney(a.event.fee * a.event.capacity)}',
        ),
        _line(a.event.description),
        TextButton(
          onPressed: () => _open(
            AdminManagementDetailScreen(
              session: widget.session,
              kind: 1,
              id: '__owner__',
            ),
          ),
          child: const Text('Xem hồ sơ người tổ chức →'),
        ),
      ],
    ),
    const AdminReviewCard(
      title: 'Quy tắc & kiểm duyệt',
      children: [
        Text(
          'Kiểm tra người tổ chức, lịch tổ chức, sức chứa và lệ phí trước khi phê duyệt. Không thay đổi nội dung người gửi. Bản hiện tại chưa có giấy xác nhận phân sân hoặc chính sách hoàn riêng theo hoạt động.',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
      ],
    ),
    if (a.state == 'pending')
      _decisionPanel('Quyết định kiểm duyệt', [
        (
          'Phê duyệt & mở đăng ký',
          'activity-approve',
          () => _perform(
            'Phê duyệt & mở đăng ký',
            () =>
                widget.session.transitionActivity(a.id, 'approved', a.revision),
            revision: () => widget.session.managedActivities
                .firstWhere((v) => v.id == a.id)
                .revision,
          ),
        ),
        (
          'Từ chối hoạt động',
          'activity-reject',
          () => _perform(
            'Từ chối hoạt động',
            () => widget.session.transitionActivity(
              a.id,
              'rejected',
              a.revision,
              note: _reason.text,
            ),
            requiredReason: true,
            revision: () => widget.session.managedActivities
                .firstWhere((v) => v.id == a.id)
                .revision,
          ),
        ),
        (
          'Yêu cầu bổ sung',
          'activity-supplement',
          () => _supplement(5, a.id, a.revision),
        ),
      ]),
    if (['approved', 'suspended'].contains(a.state))
      _decisionPanel('Hành động quản trị', [
        (
          a.state == 'approved' ? 'Tạm ngưng hoạt động' : 'Khôi phục hoạt động',
          'activity-access',
          () => _perform(
            'Thay đổi trạng thái hoạt động',
            () => widget.session.transitionActivity(
              a.id,
              a.state == 'approved' ? 'suspended' : 'approved',
              a.revision,
              note: _reason.text,
            ),
            requiredReason: a.state == 'approved',
            revision: () => widget.session.managedActivities
                .firstWhere((v) => v.id == a.id)
                .revision,
          ),
        ),
      ]),
  ];

  List<Widget> _group(DemoPlayGroup g) => [
    AdminReviewCard(
      title: 'Mô tả & người lập',
      children: [
        _line(g.description),
        _line('Người lập & quản trị: ${g.owner}'),
        _line('Môn: ${playGroupSports[g.sport]}'),
        _line(
          g.requiresApproval
              ? 'Thành viên cần được chấp thuận khi tham gia.'
              : 'Thành viên có thể tham gia nhóm đã công bố.',
        ),
      ],
    ),
    const AdminReviewCard(
      title: 'Quy tắc hội nhóm',
      children: [
        Text(
          'Tôn trọng và an toàn. Không xúc phạm, phân biệt đối xử hoặc công khai dữ liệu cá nhân khi chưa đồng ý. Không quảng cáo, spam hoặc cá cược. Người quản trị nhóm có trách nhiệm tiếp nhận phản ánh.',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
      ],
    ),
    if (g.state == 'pending')
      _decisionPanel('Quyết định kiểm duyệt', [
        (
          'Phê duyệt & công khai nhóm',
          'group-approve',
          () => _perform(
            'Phê duyệt & công khai nhóm',
            () => widget.session.transitionPlayGroup(
              g.id,
              'approved',
              g.revision,
            ),
            revision: () => widget.session.managedPlayGroups
                .firstWhere((v) => v.id == g.id)
                .revision,
          ),
        ),
        (
          'Từ chối hội nhóm',
          'group-reject',
          () => _perform(
            'Từ chối hội nhóm',
            () => widget.session.transitionPlayGroup(
              g.id,
              'rejected',
              g.revision,
              note: _reason.text,
            ),
            requiredReason: true,
            revision: () => widget.session.managedPlayGroups
                .firstWhere((v) => v.id == g.id)
                .revision,
          ),
        ),
        (
          'Yêu cầu bổ sung',
          'group-supplement',
          () => _supplement(6, g.id, g.revision),
        ),
      ]),
    if (['approved', 'suspended'].contains(g.state))
      _decisionPanel('Hành động quản trị', [
        (
          g.state == 'approved' ? 'Tạm ngưng hội nhóm' : 'Khôi phục hội nhóm',
          'group-access',
          () => _perform(
            'Thay đổi trạng thái hội nhóm',
            () => widget.session.transitionPlayGroup(
              g.id,
              g.state == 'approved' ? 'suspended' : 'approved',
              g.revision,
              note: _reason.text,
            ),
            requiredReason: g.state == 'approved',
            revision: () => widget.session.managedPlayGroups
                .firstWhere((v) => v.id == g.id)
                .revision,
          ),
        ),
      ]),
  ];

  Widget _decisionPanel(
    String title,
    List<(String, String, VoidCallback)> actions, {
    bool password = false,
    String? warning,
  }) => AdminReviewCard(
    title: title,
    children: [
      const Text(
        'Lý do xử lý *',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      TextField(
        key: const Key('admin-management-reason'),
        controller: _reason,
        enabled: !_busy,
        minLines: 3,
        maxLines: 5,
        maxLength: 300,
        decoration: const InputDecoration(
          hintText: 'Nhập lý do hoặc nội dung cần bổ sung…',
          border: OutlineInputBorder(),
        ),
      ),
      if (password)
        TextField(
          key: const Key('admin-management-password'),
          controller: _password,
          obscureText: true,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Mật khẩu Admin'),
        ),
      const SizedBox(height: 12),
      _line('Người xử lý: ${widget.session.user!.name}'),
      AdminReviewNote(
        warning ?? 'Bạn sẽ xem lại quyết định trước khi xác nhận. Kết quả và lý do được lưu vào nhật ký.',
        warning: warning != null,
      ),
      for (var i = 0; i < actions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: i == 0
              ? FilledButton(
                  key: Key('admin-management-${actions[i].$2}'),
                  onPressed: _busy ? null : actions[i].$3,
                  child: Text(actions[i].$1),
                )
              : OutlinedButton(
                  key: Key('admin-management-${actions[i].$2}'),
                  onPressed: _busy ? null : actions[i].$3,
                  child: Text(actions[i].$1),
                ),
        ),
    ],
  );

  Future<void> _supplement(int kind, String id, int revision) => _perform(
    'Yêu cầu bổ sung',
    () {
      final s = widget.session;
      if (kind == 4) {
        s.transitionCourtType(
          id,
          'rejected',
          revision,
          note: _reason.text.trim(),
          requestSupplement: true,
        );
      }
      if (kind == 5) {
        s.transitionActivity(
          id,
          'rejected',
          revision,
          note: _reason.text.trim(),
          requestSupplement: true,
        );
      }
      if (kind == 6) {
        s.transitionPlayGroup(
          id,
          'rejected',
          revision,
          note: _reason.text.trim(),
          requestSupplement: true,
        );
      }
    },
    requiredReason: true,
    revision: () => switch (kind) {
      4 =>
        widget.session.managedCourtTypes.firstWhere((v) => v.id == id).revision,
      5 =>
        widget.session.managedActivities.firstWhere((v) => v.id == id).revision,
      _ =>
        widget.session.managedPlayGroups.firstWhere((v) => v.id == id).revision,
    },
  );

  Future<void> _perform(
    String title,
    VoidCallback change, {
    bool requiredReason = false,
    int Function()? revision,
  }) async {
    if (_busy || !_allowed) return;
    if (_reason.text.trim().length > 300 ||
        requiredReason && _reason.text.trim().length < 5) {
      setState(() => _error = 'Nhập lý do từ 5 đến 300 ký tự.');
      return;
    }
    final actor = widget.session.user!.identifier, version = revision?.call();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await financeConfirm(
        context,
        '$title?',
        '${widget.id}\n${_reason.text.trim().isEmpty ? 'Không kèm lý do.' : 'Lý do: ${_reason.text.trim()}'}\nLịch đặt và dữ liệu gốc sẽ được giữ nguyên.',
      );
      if (!mounted || !ok) return;
      if (!_allowed ||
          widget.session.user!.identifier != actor ||
          version != revision?.call()) {
        throw StateError(
          'Phiên tài khoản hoặc hồ sơ đã thay đổi. Mở lại hồ sơ.',
        );
      }
      change();
      final saved = await widget.session.flush();
      if (mounted && _allowed) {
        setState(() {
          _error = saved ? null : 'Chưa lưu được quyết định. Thử lưu lại trước khi đóng ứng dụng.';
          _password.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved ? 'Đã xử lý hồ sơ.' : 'Chưa lưu được thay đổi.',
            ),
          ),
        );
      }
    } on StateError catch (e) {
      if (mounted && _allowed) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && _allowed) {
        setState(() => _error = 'Không thể xử lý hồ sơ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
