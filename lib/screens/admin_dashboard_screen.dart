import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../widgets/design.dart';
import 'activities_screen.dart';
import 'admin_players_screen.dart';
import 'admin_system_report_screen.dart';
import 'approval_center_screen.dart';
import 'facilities_screen.dart';
import 'finance_screen.dart';
import 'operations_screen.dart';
import 'owner_verification_screen.dart';
import 'play_groups_screen.dart';
import 'reviews_screen.dart';

const adminTabLabels = [
  'Tổng quan',
  'Quản lý',
  'Duyệt',
  'Báo cáo',
  'Tài khoản',
];
const adminTabIcons = [
  Icons.grid_view_outlined,
  Icons.layers_outlined,
  Icons.fact_check_outlined,
  Icons.bar_chart_outlined,
  Icons.person_outline,
];

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.session, this.onTab});
  final DemoSession session;
  final ValueChanged<int>? onTab;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _period = 1;
  DateTimeRange? _custom;

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  void _tab(int index) {
    if (widget.onTab != null) {
      widget.onTab!(index);
    } else {
      _open(
        index == 3
            ? AdminSystemReportScreen(
                session: widget.session,
                initialRange: _range(),
              )
            : ApprovalCenterScreen(session: widget.session),
      );
    }
  }

  DateTimeRange _range() {
    if (_custom != null) return _custom!;
    final today = bookingDay(widget.session.now);
    if (_period == 0) return DateTimeRange(start: today, end: today);
    if (_period == 2) {
      return DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      );
    }
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return DateTimeRange(
      start: monday.subtract(const Duration(days: 7)),
      end: monday.subtract(const Duration(days: 1)),
    );
  }

  Future<void> _pickRange() async {
    final s = widget.session, actor = widget.session.user?.identifier;
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: bookingDay(s.now),
      initialDateRange: _range(),
    );
    if (!mounted ||
        selected == null ||
        s.role != DemoRole.admin ||
        s.user?.identifier != actor) {
      return;
    }
    if (selected.duration.inDays > 365) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chọn tối đa 366 ngày.')));
      return;
    }
    setState(() => _custom = selected);
  }

  Widget _link(String label, VoidCallback action, {Key? key}) => TextButton(
    key: key,
    onPressed: action,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(44, 36),
      textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 10),
    ),
    child: Text(label),
  );

  Widget _heading(String title, String action, VoidCallback callback) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      _link(
        action,
        callback,
        key: action == 'Xem báo cáo'
            ? const Key('dashboard-system-report')
            : null,
      ),
    ],
  );

  Widget _card(List<Widget> children, {Key? key}) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _metric(String title, String value, String note, String id) =>
      Container(
        key: Key('admin-metric-$id'),
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
              title,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.admin) {
        return const Scaffold(
          body: Center(child: Text('Chỉ Admin được truy cập.')),
        );
      }
      final range = _range();
      final report = s.systemOverview(from: range.start, to: range.end);
      final previous = s.systemOverview(
        from: range.start.subtract(Duration(days: range.duration.inDays + 1)),
        to: range.start.subtract(const Duration(days: 1)),
      );
      final delta = previous.bookings == 0
          ? 'Kỳ trước: ${previous.bookings} lượt'
          : '${report.bookings >= previous.bookings ? '↑' : '↓'} ${((report.bookings - previous.bookings).abs() * 100 / previous.bookings).toStringAsFixed(1)}% so với kỳ trước';
      final ownerPending = s.ownerVerification?.state == 'pending' ? 1 : 0;
      final claimPending = s.venueClaims
          .where((c) => c.state == 'pending')
          .length;
      final types = s.managedCourtTypes
          .where((t) => t.state == 'pending')
          .length;
      final tariffs =
          (s.courtReviewState == 'pending' ? 1 : 0) +
          s.managedFacilities
              .where(
                (f) =>
                    f.published != null &&
                    s.facilityTariffPlan(f.id).state == 'pending',
              )
              .length;
      final pending =
          ownerPending +
          claimPending +
          report.pendingFacilities +
          types +
          report.pendingActivities +
          report.pendingGroups +
          tariffs;
      final audits = s.operationAudit;
      final sections = <({String name, IconData icon, Widget page})>[
        (
          name: 'Sân & cơ sở',
          icon: Icons.location_on_outlined,
          page: FacilitiesScreen(session: s),
        ),
        (
          name: 'Chủ sân',
          icon: Icons.person_outline,
          page: OwnerVerificationScreen(session: s),
        ),
        (
          name: 'Người dùng',
          icon: Icons.person_search_outlined,
          page: AdminPlayersScreen(session: s),
        ),
        (
          name: 'Đánh giá',
          icon: Icons.star_outline,
          page: ReviewsScreen(session: s, admin: true),
        ),
        (
          name: 'Hoạt động',
          icon: Icons.emoji_events_outlined,
          page: ActivitiesScreen(session: s),
        ),
        (
          name: 'Hội nhóm',
          icon: Icons.groups_outlined,
          page: PlayGroupsScreen(session: s),
        ),
      ];
      final metrics = [
        _metric(
          'Người dùng',
          '${report.players}',
          '${report.blockedPlayers} tài khoản đã khóa',
          'users',
        ),
        _metric(
          'Chủ sân',
          '${report.owners}',
          '${report.verifiedOwners} đã xác minh',
          'owners',
        ),
        _metric(
          'Cơ sở',
          '${1 + s.managedFacilities.length}',
          '${report.publicFacilities} đang công khai',
          'facilities',
        ),
        _metric('Lượt đặt sân', '${report.bookings}', delta, 'bookings'),
        _metric(
          'Giá trị giao dịch',
          bookingMoney(report.cashflow.received),
          'Theo ngày thu · Trước hoàn tiền',
          'received',
        ),
        _metric('Phí nền tảng', '—', 'Chưa có phí thực thu', 'fees'),
      ];
      return Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme
              .apply(fontFamily: 'Inter', bodyColor: AppColors.ink),
          scaffoldBackgroundColor: AppColors.background,
        ),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            centerTitle: true,
            toolbarHeight: MediaQuery.textScalerOf(context).scale(10) > 14
                ? 96
                : 56,
            leading: IconButton(
              tooltip: 'Tổng quan',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => widget.onTab != null
                  ? widget.onTab!(0)
                  : Navigator.maybePop(context),
            ),
            title: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Quản trị viên · Tổng quan hệ thống',
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Color(0xFFC5EFDC),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                key: const Key('admin-dashboard-notifications'),
                tooltip: 'Yêu cầu cần xử lý',
                onPressed: () => _tab(2),
                icon: const Icon(Icons.notifications_outlined, size: 21),
              ),
            ],
          ),
          body: ListView(
            key: const Key('admin-dashboard-list'),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              if (s.saveFailed) FinanceSaveNotice(session: s),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Xin chào, ${s.user!.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F5EC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'QTV-01',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${s.saveFailed ? 'Chưa lưu được thay đổi' : 'Hệ thống ổn định'} · ${bookingDate(s.now)}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 3; i++)
                    ChoiceChip(
                      key: Key('admin-period-$i'),
                      label: Text(['Hôm nay', 'Tuần trước', 'Tháng này'][i]),
                      showCheckmark: false,
                      selected: _custom == null && _period == i,
                      selectedColor: AppColors.green,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: _custom == null && _period == i
                            ? Colors.white
                            : AppColors.muted,
                      ),
                      onSelected: (_) => setState(() {
                        _period = i;
                        _custom = null;
                      }),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${bookingDate(range.start)} – ${bookingDate(range.end)}',
                      key: const Key('admin-dashboard-range'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _link(
                    'Chọn kỳ',
                    _pickRange,
                    key: const Key('admin-custom-period'),
                  ),
                ],
              ),
              const Text(
                'Tài khoản và cơ sở: hiện tại · Đặt sân và tiền: theo kỳ',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < metrics.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: metrics[i]),
                        const SizedBox(width: 8),
                        Expanded(child: metrics[i + 1]),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              _card([
                _heading(
                  'Xu hướng giao dịch',
                  'Xem báo cáo',
                  () => _open(
                    AdminSystemReportScreen(session: s, initialRange: range),
                  ),
                ),
                const Text(
                  'Triệu đồng',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                AdminTransactionChart(values: report.cashflow.daily()),
                const SizedBox(height: 12),
                Text(
                  'Tổng ${bookingMoney(report.cashflow.received)}${report.cashflow.received == 0 ? ' · Chưa phát sinh giao dịch' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
              ]),
              _card([
                _heading('Yêu cầu chờ duyệt', 'Trung tâm duyệt', () => _tab(2)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pending',
                      key: const Key('admin-dashboard-pending'),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yêu cầu cần xử lý',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$tariffs yêu cầu bảng giá / trạng thái sân',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                for (final e in {
                  'Hồ sơ chủ sân': ownerPending,
                  'Quyền quản lý sân': claimPending,
                  'Cơ sở / sân mới': report.pendingFacilities,
                  'Loại sân mới': types,
                  'Hoạt động / giải đấu': report.pendingActivities,
                  'Hội nhóm': report.pendingGroups,
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      '${e.key}: ${e.value} yêu cầu',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ]),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ưu tiên xử lý hôm nay',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF875200),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pending hồ sơ chờ duyệt · ${report.pendingProofs} chứng từ · ${report.openDisputes} khiếu nại chưa đóng. Hoàn tiền chờ xử lý: ${bookingMoney(report.cashflow.pendingRefund)}.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF875200),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Các phân hệ quản trị',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (var row = 0; row < 2; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var col = 0; col < 3; col++) ...[
                          if (col > 0) const SizedBox(width: 8),
                          Expanded(
                            child: Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: Key('admin-module-${row * 3 + col}'),
                                onTap: () =>
                                    _open(sections[row * 3 + col].page),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 6,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        sections[row * 3 + col].icon,
                                        color: AppColors.green,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        sections[row * 3 + col].name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              _heading(
                'Hoạt động gần nhất',
                'Nhật ký',
                () => _open(OperationsScreen(session: s, initialView: 'audit')),
              ),
              if (audits.isEmpty)
                _card([
                  const Text(
                    'Chưa có hoạt động quản trị.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ]),
              for (final entry in audits.take(2))
                _card([
                  Text(
                    entry.action,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${entry.actor} · ${bookingDate(entry.created)}, ${entry.created.hour.toString().padLeft(2, '0')}:${entry.created.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                  _link(
                    'Xem nhật ký →',
                    () => _open(
                      OperationsScreen(session: s, initialView: 'audit'),
                    ),
                  ),
                ]),
              for (final f
                  in s.managedFacilities
                      .where((f) => f.state == 'pending')
                      .take(2))
                _card([
                  Text(
                    'Hồ sơ ${f.draft.name}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Chờ duyệt',
                    style: TextStyle(fontSize: 11, color: Color(0xFF875200)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${f.draft.courtCount} sân · ${f.draft.sport}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  _link(
                    'Kiểm tra hồ sơ →',
                    () => _open(FacilityDetailScreen(session: s, facility: f)),
                  ),
                ]),
              Text(
                'Cập nhật ${bookingDate(s.now)} lúc ${s.now.hour.toString().padLeft(2, '0')}:${s.now.minute.toString().padLeft(2, '0')} · Giờ Việt Nam',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class AdminTransactionChart extends StatelessWidget {
  const AdminTransactionChart({
    super.key,
    required this.values,
    this.money = true,
  });
  final Map<DateTime, int> values;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList();
    final maxValue = math.max(
      money ? 1000000 : 4,
      values.values.fold<int>(0, math.max),
    );
    final large = MediaQuery.textScalerOf(context).scale(10) > 14;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(
          MediaQuery.sizeOf(context).width - 66,
          entries.length * (large ? 62.0 : 38.0),
        ),
        height: large ? 215 : 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: large ? 48 : 32,
              child: Padding(
                padding: EdgeInsets.only(top: 20, bottom: large ? 40 : 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 4; i >= 0; i--)
                      Text(
                        money
                            ? (maxValue / 1000000 * i / 4).toStringAsFixed(2)
                            : (maxValue * i / 4).ceil().toString(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          color: AppColors.faint,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    top: 20,
                    bottom: large ? 40 : 24,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 5; i++)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.border,
                          ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final e in entries)
                          Expanded(
                            child: Tooltip(
                              message:
                                  '${bookingDate(e.key)}: ${money ? bookingMoney(e.value) : e.value}',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      money
                                          ? (e.value / 1000000).toStringAsFixed(
                                              2,
                                            )
                                          : '${e.value}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9,
                                        color: AppColors.darkGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      height: math.max(
                                        2,
                                        110 * e.value / maxValue,
                                      ),
                                      width: 28,
                                      decoration: BoxDecoration(
                                        color: e.key == entries.last.key
                                            ? AppColors.green
                                            : const Color(0xFFE4F4EB),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(3),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      entries.length == 7
                                          ? [
                                              'T2',
                                              'T3',
                                              'T4',
                                              'T5',
                                              'T6',
                                              'T7',
                                              'CN',
                                            ][e.key.weekday - 1]
                                          : '${e.key.day}/${e.key.month}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
