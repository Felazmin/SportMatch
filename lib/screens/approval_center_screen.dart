import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../demo/demo_finance.dart';
import '../venues/venue_catalog.dart';
import 'facilities_screen.dart';
import 'finance_screen.dart';
import 'operations_screen.dart';
import 'workflow_screen.dart';
import 'facility_tariffs_screen.dart';
import 'admin_management_screen.dart';
import '../widgets/design.dart';
import 'admin_review_widgets.dart';
import 'admin_account_screen.dart';
import 'venue_claims_screen.dart';

typedef _ApprovalItem = ({
  String key,
  String group,
  String title,
  String subtitle,
  Widget screen,
  DateTime? updated,
});

class ApprovalCenterScreen extends StatefulWidget {
  const ApprovalCenterScreen({
    super.key,
    required this.session,
    this.embedded = false,
  });
  final DemoSession session;
  final bool embedded;
  @override
  State<ApprovalCenterScreen> createState() => _ApprovalCenterScreenState();
}

class _ApprovalCenterScreenState extends State<ApprovalCenterScreen> {
  String _group = 'all', _query = '';
  int _age = 0, _limit = 5;
  bool _oldest = true;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.admin) {
        return Scaffold(
          appBar: financeBar('Trung tâm xử lý'),
          body: const Center(child: Text('Chỉ Admin được truy cập.')),
        );
      }
      final items = <_ApprovalItem>[
        for (final c in s.venueClaims.where((c) => c.state == 'pending'))
          (
            key: 'venue-claim-${c.key}',
            updated: c.updated,
            group: 'venue-claims',
            title: c.venueName,
            subtitle:
                '${c.contact} · ${c.phone} · Yêu cầu quyền quản lý sân OSM',
            screen: VenueClaimScreen(
              session: s,
              venueId: c.venueId,
              claimKey: c.key,
            ),
          ),
        if (s.ownerVerification?.state == 'pending')
          (
            key: 'owner-verification',
            updated: s.ownerVerification!.updated,
            group: 'owners',
            title: s.ownerVerification!.name,
            subtitle: 'Hồ sơ chủ sân chờ xác minh',
            screen: AdminManagementDetailScreen(
              session: s,
              kind: 1,
              id: '__owner__',
            ),
          ),
        for (final t in s.managedCourtTypes.where((t) => t.state == 'pending'))
          (
            key: 'court-type-${t.id}',
            updated: t.updated,
            group: 'court-types',
            title: t.name,
            subtitle: '${t.id} · Loại sân chờ duyệt',
            screen: AdminManagementDetailScreen(session: s, kind: 4, id: t.id),
          ),
        for (final a in s.managedActivities.where((a) => a.state == 'pending'))
          (
            key: 'activity-${a.id}',
            updated: a.updated,
            group: 'activities',
            title: a.event.title,
            subtitle: '${a.id} · Hoạt động chờ duyệt',
            screen: AdminManagementDetailScreen(session: s, kind: 5, id: a.id),
          ),
        for (final g in s.managedPlayGroups.where((g) => g.state == 'pending'))
          (
            key: 'group-${g.id}',
            updated: g.updated,
            group: 'groups',
            title: g.name,
            subtitle: '${g.id} · Nhóm chơi chờ duyệt',
            screen: AdminManagementDetailScreen(session: s, kind: 6, id: g.id),
          ),
        for (final f in s.managedFacilities.where((f) => f.state == 'pending'))
          (
            key: 'facility-${f.id}',
            updated: f.updated,
            group: 'facility',
            title: f.draft.name,
            subtitle:
                '${f.id} · ${f.draft.ownerName} · ${f.draft.district} · ${f.draft.courtCount} sân · Hồ sơ cơ sở chờ duyệt',
            screen: FacilityDetailScreen(session: s, facility: f),
          ),
        if (s.courtReviewState == 'pending')
          (
            key: 'pricing',
            updated: null,
            group: 'pricing',
            title: 'Bảng giá / trạng thái sân',
            subtitle: 'Đề nghị Chủ sân chờ duyệt',
            screen: OperationsScreen(session: s),
          ),
        for (final f in s.managedFacilities.where(
          (f) =>
              f.published != null &&
              s.facilityTariffPlan(f.id).state == 'pending',
        ))
          (
            key: 'facility-pricing-${f.id}',
            updated: null,
            group: 'pricing',
            title: f.published!.name,
            subtitle: '${f.id} · Bảng giá cơ sở chờ duyệt',
            screen: FacilityTariffsScreen(session: s, id: f.id),
          ),
      ];
      for (final r in s.managedAttendance) {
        final p = s.workflowPayment(r.id);
        if (p == null) continue;
        if (p.cancellation == DemoCancellationState.requested) {
          items.add((
            key: 'cancel-${r.id}',
            updated: p.cancellationRequestedAt,
            group: 'cancel',
            title: r.title,
            subtitle: '${r.id} · Yêu cầu hủy',
            screen: WorkflowDetailScreen(session: s, id: r.id),
          ));
        } else if (!r.cancelled && p.state == DemoPaymentState.pending) {
          items.add((
            key: 'proof-${r.id}',
            updated: null,
            group: 'proof',
            title: r.title,
            subtitle: '${r.id} · Chứng từ chờ duyệt',
            screen: WorkflowDetailScreen(session: s, id: r.id),
          ));
        }
        if (p.refund == DemoRefundState.pending) {
          items.add((
            key: 'refund-${r.id}',
            updated: p.cancellationRequestedAt,
            group: 'refund',
            title: r.title,
            subtitle: '${r.id} · Chờ ghi nhận hoàn tiền',
            screen: WorkflowDetailScreen(session: s, id: r.id),
          ));
        }
      }
      for (final d in s.disputes.where((d) => d.closedAt == null)) {
        items.add((
          key: 'dispute-${d.id}',
          updated: d.created,
          group: 'dispute',
          title: d.subject,
          subtitle: '${d.id} · ${d.label}',
          screen: DisputeDetailScreen(session: s, dispute: d),
        ));
      }
      final groups = {
        'all': 'Tất cả',
        'owners': 'Chủ sân',
        'venue-claims': 'Quyền quản lý sân',
        'court-types': 'Loại sân',
        'facility': 'Cơ sở',
        'groups': 'Nhóm chơi',
        'activities': 'Hoạt động',
        'pricing': 'Bảng giá',
        'proof': 'Chứng từ',
        'cancel': 'Hủy',
        'refund': 'Hoàn',
        'dispute': 'Khiếu nại',
      };
      final visible = items
          .where(
            (i) =>
                (_group == 'all' || i.group == _group) &&
                (_age == 0 ||
                    (i.updated != null &&
                        s.now.difference(i.updated!).inHours >=
                            (_age == 1 ? 48 : 72))) &&
                venueSearchText('${i.title} ${i.subtitle}')
                    .contains(venueSearchText(_query)),
          )
          .toList();
      visible.sort((a, b) {
        if (a.updated == null) {
          return b.updated == null ? a.key.compareTo(b.key) : 1;
        }
        if (b.updated == null) return -1;
        final order = a.updated!.compareTo(b.updated!);
        return _oldest ? order : -order;
      });
      final overdue = items
          .where(
            (i) =>
                i.updated != null && s.now.difference(i.updated!).inHours >= 48,
          )
          .length;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: adminReviewBar(
          context,
          'Trung tâm duyệt',
          'Quản trị viên · Hàng đợi kiểm duyệt',
          onNotifications: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AdminAccountScreen(session: s),
            ),
          ),
        ),
        bottomNavigationBar: widget.embedded
            ? null
            : const AdminReviewNavigation(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            OutlinedButton.icon(
              key: const Key('admin-venue-claims'),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Hồ sơ quyền quản lý sân'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => VenueClaimsScreen(session: s),
                ),
              ),
            ),
            AdminReviewCard(
              children: [
                Text(
                  '${items.length} công việc đang chờ',
                  key: const Key('approval-count'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tập trung hồ sơ đăng ký mới của toàn hệ thống.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                for (final group in [
                  'owners',
                  'venue-claims',
                  'facility',
                  'court-types',
                  'activities',
                  'groups',
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      '${groups[group]}: ${items.where((i) => i.group == group).length} yêu cầu',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            if (overdue > 0)
              AdminReviewNote(
                '$overdue yêu cầu quá 48 giờ kể từ lần cập nhật gần nhất. Ưu tiên xử lý các hồ sơ cũ.',
                warning: true,
              ),
            TextField(
              key: const Key('approval-search'),
              decoration: const InputDecoration(
                hintText: 'Tên, người gửi hoặc mã yêu cầu',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                prefixIcon: Icon(Icons.search, size: 20),
                suffixIcon: Icon(Icons.tune, size: 20),
              ),
              onChanged: (v) => setState(() {
                _query = v;
                _limit = 5;
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < 3; i++)
                  AdminReviewChip(
                    key: Key('approval-age-$i'),
                    label: Text(
                      i == 0
                          ? 'Tất cả (${items.length})'
                          : i == 1
                          ? 'Quá hạn ($overdue)'
                          : 'Ưu tiên · Trên 72 giờ',
                    ),
                    selected: _age == i,
                    onSelected: (_) => setState(() {
                      _age = i;
                      _limit = 5;
                    }),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in groups.entries.where(
                  (e) =>
                      [
                        'all',
                        'owners',
                        'facility',
                        'court-types',
                        'activities',
                        'groups',
                      ].contains(e.key) ||
                      items.any((i) => i.group == e.key),
                ))
                  AdminReviewChip(
                    key: Key('approval-filter-${e.key}'),
                    label: Text(
                      '${e.value} (${e.key == 'all' ? items.length : items.where((i) => i.group == e.key).length})',
                    ),
                    selected: _group == e.key,
                    onSelected: (_) => setState(() {
                      _group = e.key;
                      _limit = 5;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Hàng đợi chờ duyệt',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextButton(
                  key: const Key('approval-sort'),
                  onPressed: () => setState(() => _oldest = !_oldest),
                  child: Text(_oldest ? 'Cũ nhất trước' : 'Mới nhất trước'),
                ),
              ],
            ),
            if (visible.isEmpty) const Text('Không có công việc phù hợp.'),
            for (final i in visible.take(_limit))
              AdminReviewCard(
                key: Key('approval-${i.key}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => i.screen),
                ),
                children: [
                  Text(
                    i.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                  if (i.updated != null)
                    Text(
                      'Cập nhật ${adminTime(i.updated!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  if (i.updated != null &&
                      s.now.difference(i.updated!).inHours >= 48)
                    const Text(
                      'Quá hạn',
                      style: TextStyle(fontSize: 11, color: Color(0xFF855200)),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => i.screen),
                      ),
                      child: Text(
                        '${const {'facility': 'Duyệt sân mới', 'owners': 'Duyệt hồ sơ chủ sân', 'court-types': 'Duyệt loại sân mới', 'groups': 'Duyệt hội nhóm', 'activities': 'Duyệt hoạt động'}[i.group] ?? 'Xem & xử lý'} →',
                      ),
                    ),
                  ),
                ],
              ),
            Text(
              'Đang hiển thị ${visible.take(_limit).length} / ${visible.length} yêu cầu · Không bao gồm đánh giá bị báo cáo',
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            if (visible.length > _limit)
              OutlinedButton(
                key: const Key('approval-more'),
                onPressed: () => setState(() => _limit += 5),
                child: const Text('Xem thêm kết quả'),
              ),
          ],
        ),
      );
    },
  );
}
