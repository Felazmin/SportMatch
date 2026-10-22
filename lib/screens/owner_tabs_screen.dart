import 'package:flutter/material.dart';

import 'owner_management_views.dart';
import 'owner_prices_view.dart';
import 'owner_booking_views.dart';
import 'facility_pending_screen.dart';
import 'owner_facility_edit_list_screen.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_events.dart';
import '../demo/demo_finance.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import '../widgets/venue_image.dart';
import 'activities_screen.dart';
import 'calendar_screen.dart';
import 'cashflow_screen.dart';
import 'customer_discovery_screen.dart' show DiscoveryHeader, DiscoveryHeading;
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'facilities_screen.dart';
import 'facility_calendar_screen.dart';
import 'facility_tariffs_screen.dart';
import 'finance_screen.dart';
import 'management_screen.dart';
import 'operations_screen.dart';
import 'owner_venue_navigation.dart';
import 'settlement_screen.dart';
import 'shifts_screen.dart';
import 'workflow_screen.dart';

void _open(BuildContext context, Widget screen) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

class OwnerDashboardTab extends StatefulWidget {
  const OwnerDashboardTab({super.key, required this.session});
  final DemoSession session;
  @override
  State<OwnerDashboardTab> createState() => _OwnerDashboardTabState();
}

class _OwnerDashboardTabState extends State<OwnerDashboardTab> {
  String _facility = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.role != DemoRole.owner) return const SizedBox.shrink();
      final facilities = s.managedFacilities
          .where((f) => f.published != null)
          .toList();
      final selected =
          _facility == '*' ||
              _facility.isEmpty ||
              facilities.any((f) => f.id == _facility)
          ? _facility
          : '*';
      final overview = selected == '*'
          ? s.allFacilitiesOverview(s.now)
          : s.dayOverview(s.now, facilityId: selected);
      final occupancy = overview.capacity == 0
          ? 0
          : overview.reserved * 100 / overview.capacity;
      final facility = facilities.where((f) => f.id == selected).firstOrNull;
      final venue = s.currentVenues.firstWhere((v) => v.id == demoVenueId);
      final facilityName = selected == '*'
          ? 'Tất cả cơ sở'
          : facility?.published?.name ?? venue.name;
      final address = selected == '*'
          ? '${facilities.length + 1} cơ sở quản lý'
          : facility == null
          ? venue.address
          : '${facility.published!.address}, ${facility.published!.district}';
      final pending = overview.bookings
          .where(
            (b) => s.workflowPayment(b.id)?.state != DemoPaymentState.approved,
          )
          .length;
      final today = bookingDay(s.now);
      final yesterday = today.subtract(const Duration(days: 1));
      final revenue = s
          .cashflowReport(
            from: today,
            to: today,
            facilityId: selected,
            tickets: false,
          )
          .received;
      final previousRevenue = s
          .cashflowReport(
            from: yesterday,
            to: yesterday,
            facilityId: selected,
            tickets: false,
          )
          .received;
      final change = previousRevenue == 0
          ? (revenue == 0 ? 'Chưa có doanh thu' : 'Hôm qua chưa có doanh thu')
          : '${revenue >= previousRevenue ? '↑' : '↓'} ${((revenue - previousRevenue).abs() * 100 / previousRevenue).toStringAsFixed(0)}% so với hôm qua';
      final primaryCount = s.publishedCourts.enabled.length;
      final primaryActive = s.publishedCourts.enabled.where((v) => v).length;
      final totalCourts = selected == '*'
          ? primaryCount +
                facilities.fold<int>(
                  0,
                  (sum, f) => sum + f.published!.courtCount,
                )
          : facility?.published?.courtCount ?? primaryCount;
      final activeCourts = selected == '*'
          ? primaryActive +
                facilities
                    .where((f) => !f.suspended)
                    .fold<int>(0, (sum, f) => sum + f.published!.courtCount)
          : facility == null
          ? primaryActive
          : facility.suspended
          ? 0
          : totalCourts;
      final actions =
          <({String id, String title, IconData icon, Widget screen})>[
            (
              id: 'calendar',
              title: 'Lịch sân',
              icon: Icons.calendar_month_outlined,
              screen: selected.isEmpty || selected == '*'
                  ? CalendarScreen(session: s)
                  : FacilityCalendarScreen(session: s, id: selected),
            ),
            (
              id: 'facilities',
              title: 'Sân của tôi',
              icon: Icons.location_on_outlined,
              screen: FacilitiesScreen(session: s),
            ),
            (
              id: 'add',
              title: 'Thêm sân',
              icon: Icons.add_circle_outline,
              screen: FacilityFormScreen(session: s),
            ),
            (
              id: 'edit',
              title: 'Chỉnh sửa sân',
              icon: Icons.edit_outlined,
              screen: OwnerFacilityEditListScreen(session: s),
            ),
            (
              id: 'requests',
              title: 'Chờ duyệt',
              icon: Icons.schedule_outlined,
              screen: OwnerPendingFacilitiesScreen(session: s),
            ),
            (
              id: 'prices',
              title: 'Bảng giá',
              icon: Icons.payments_outlined,
              screen: selected.isEmpty || selected == '*'
                  ? OwnerPricesView(session: s)
                  : FacilityTariffsScreen(session: s, id: selected),
            ),
            (
              id: 'revenue',
              title: 'Doanh thu',
              icon: Icons.bar_chart_outlined,
              screen: OwnerRevenueView(
                session: s,
                facilityId: selected == '*' ? '' : selected,
              ),
            ),
            (
              id: 'customers',
              title: 'Khách hàng',
              icon: Icons.people_outline,
              screen: CustomersScreen(session: s),
            ),
            (
              id: 'employees',
              title: 'Nhân viên',
              icon: Icons.person_add_alt_outlined,
              screen: EmployeeRosterScreen(session: s),
            ),
            (
              id: 'activities',
              title: 'Quản lý trận đấu',
              icon: Icons.emoji_events_outlined,
              screen: ActivitiesScreen(session: s),
            ),
            (
              id: 'details',
              title: 'Chi tiết đặt sân',
              icon: Icons.event_available_outlined,
              screen: OwnerBookingDirectory(session: s, facilityId: selected),
            ),
            (
              id: 'profile',
              title: 'Hồ sơ',
              icon: Icons.person_outline,
              screen: OwnerProfileView(session: s),
            ),
          ];
      return ListView(
        key: const PageStorageKey('owner-dashboard-scroll'),
        padding: EdgeInsets.zero,
        children: [
          _DashboardHeader(
            name: s.user!.name,
            onBack: () => Navigator.maybePop(context),
            onNotifications: () => _open(context, ManagementScreen(session: s)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('owner-facility-$selected'),
                  initialValue: selected,
                  isExpanded: true,
                  isDense: false,
                  itemHeight:
                      MediaQuery.textScalerOf(context).scale(22) * 1.5 + 16,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.green,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFE7EBEF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: AppColors.green),
                    ),
                  ),
                  selectedItemBuilder: (context) => [
                    for (final _ in ['*', '', ...facilities.map((f) => f.id)])
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            facilityName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            address,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                  ],
                  items: [
                    const DropdownMenuItem(
                      value: '*',
                      child: Text('Tất cả cơ sở'),
                    ),
                    const DropdownMenuItem(
                      value: '',
                      child: Text(DemoBooking.venue),
                    ),
                    for (final f in facilities)
                      DropdownMenuItem(
                        value: f.id,
                        child: Text(f.published!.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _facility = v!),
                ),
                _DashboardHeading(
                  'Tổng quan hôm nay',
                  action: bookingDate(s.now),
                  onPressed: () => _open(
                    context,
                    DashboardScreen(session: s, facilityId: selected),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final large =
                        MediaQuery.textScalerOf(context).scale(12) > 17;
                    final width = large
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Metric(
                          width: width,
                          title: 'Lịch đặt',
                          value: '${overview.bookings.length}',
                          detail: '$pending lịch chờ xác nhận',
                        ),
                        _Metric(
                          width: width,
                          title: 'Doanh thu',
                          value: bookingMoney(revenue),
                          detail: change,
                        ),
                        _Metric(
                          width: width,
                          title: 'Tỷ lệ lấp đầy',
                          value: '${occupancy.toStringAsFixed(0)}%',
                        ),
                        _Metric(
                          width: width,
                          title: 'Sân hoạt động',
                          value: '$activeCourts/$totalCourts',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFFFFF4DC),
                  borderRadius: BorderRadius.circular(6),
                  child: ListTile(
                    key: const Key('owner-pending'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    minLeadingWidth: 16,
                    leading: const Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: Color(0xFFAD7915),
                    ),
                    title: Text(
                      '$pending lịch cần xác nhận',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B580E),
                      ),
                    ),
                    subtitle: const Text(
                      'Kiểm tra thanh toán để giữ sân cho khách.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF8B580E)),
                    ),
                    onTap: () => _open(context, ManagementScreen(session: s)),
                  ),
                ),
                const _DashboardHeading('Quản lý sân'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        MediaQuery.textScalerOf(context).scale(12) > 17 ? 2 : 3;
                    final width =
                        (constraints.maxWidth - 8 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in actions)
                          SizedBox(
                            width: width,
                            child: Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(
                                  color: Color(0xFFE7EBEF),
                                ),
                              ),
                              child: InkWell(
                                key: Key('owner-action-${action.id}'),
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _open(context, action.screen),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE5F6ED),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          action.icon,
                                          size: 18,
                                          color: AppColors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        action.title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                _DashboardHeading(
                  'Lịch đặt gần nhất',
                  action: 'Xem tất cả',
                  onPressed: () => _open(context, AttendanceScreen(session: s)),
                ),
                if (overview.bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Chưa có lịch đặt trong ngày.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                for (final b in overview.bookings.take(3))
                  _DashboardBooking(
                    key: Key('owner-booking-${b.id}'),
                    booking: b,
                    approved:
                        s.workflowPayment(b.id)?.state ==
                        DemoPaymentState.approved,
                    onTap: () => _open(
                      context,
                      WorkflowDetailScreen(
                        session: s,
                        id: b.id,
                        ownerPresentation: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Dữ liệu cập nhật lúc ${bookingTime(s.now)} · $facilityName',
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.onBack,
    required this.onNotifications,
  });
  final String name;
  final VoidCallback onBack, onNotifications;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.green,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            _headerButton(Icons.chevron_left, 'Quay lại', onBack),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Xin chào, $name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: Color(0xFFC5EFDC),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _headerButton(
              Icons.notifications_outlined,
              'Lịch chờ xác nhận',
              onNotifications,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _headerButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.all(6),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0x33FFFFFF),
          minimumSize: const Size(36, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, color: Colors.white, size: 20),
      );
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading(this.title, {this.action, this.onPressed});
  final String title;
  final String? action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: InkWell(
              onTap: onPressed,
              child: Text(
                action!,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 11, color: AppColors.green),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _DashboardBooking extends StatelessWidget {
  const _DashboardBooking({
    super.key,
    required this.booking,
    required this.approved,
    required this.onTap,
  });
  final DemoBooking booking;
  final bool approved;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(12) > 17;
    final price = Text(
      '${bookingMoney(booking.total).replaceAll('đ', '')} VNĐ',
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.green,
        fontWeight: FontWeight.w700,
      ),
    );
    final button = TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFF5F6F8),
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: const Text(
        'Chi tiết đặt sân',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F6ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.contact,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sân ${booking.court} · ${booking.sport}\n${bookingTime(booking.start)} – ${bookingTime(booking.end)} · ${bookingDate(booking.start)}',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!large) ...[
                const SizedBox(width: 5),
                Flexible(child: _DashboardStatus(approved: approved)),
              ],
            ],
          ),
          if (large) ...[
            const SizedBox(height: 8),
            _DashboardStatus(approved: approved),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE7EBEF)),
          ),
          if (large)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [price, const SizedBox(height: 8), button],
            )
          else
            Row(
              children: [
                Expanded(child: price),
                const SizedBox(width: 8),
                button,
              ],
            ),
        ],
      ),
    );
  }
}

class _DashboardStatus extends StatelessWidget {
  const _DashboardStatus({required this.approved});
  final bool approved;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: approved ? const Color(0xFFE5F6ED) : const Color(0xFFFFF4DC),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      approved ? 'Đã xác nhận' : 'Chờ xác nhận',
      style: TextStyle(
        fontSize: 9,
        color: approved ? AppColors.darkGreen : const Color(0xFF8B580E),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.title,
    required this.value,
    this.detail,
  });
  final double width;
  final String title, value;
  final String? detail;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    constraints: BoxConstraints(minHeight: detail == null ? 64 : 76),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE7EBEF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            height: 1.2,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreen,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 5),
          Text(
            detail!,
            style: const TextStyle(
              fontSize: 9,
              height: 1.2,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    ),
  );
}

class OwnerExploreTab extends StatefulWidget {
  const OwnerExploreTab({super.key, required this.session});
  final DemoSession session;
  @override
  State<OwnerExploreTab> createState() => _OwnerExploreTabState();
}

class _OwnerExploreTabState extends State<OwnerExploreTab> {
  DemoEventKind? _kind;
  String _query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.role != DemoRole.owner) return const SizedBox.shrink();
      final activities =
          s.managedActivities
              .where(
                (a) =>
                    (_kind == null || a.event.kind == _kind) &&
                    venueSearchText(a.event.title)
                        .contains(venueSearchText(_query)),
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.event.scheduledStart!.compareTo(b.event.scheduledStart!),
            );
      return ListView(
        key: const PageStorageKey('owner-explore-scroll'),
        padding: EdgeInsets.zero,
        children: [
          DiscoveryHeader(
            title: 'Quản lý hoạt động',
            subtitle: 'Giao lưu và giải đấu tại sân',
            icon: Icons.event_note_outlined,
            tooltip: 'Danh sách hoạt động',
            onPressed: () => _open(context, ActivitiesScreen(session: s)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FinanceSaveNotice(session: s),
                FilledButton.icon(
                  key: const Key('owner-create-activity'),
                  onPressed: () =>
                      _open(context, ActivityFormScreen(session: s)),
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo giao lưu / giải đấu'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('owner-activity-search'),
                  decoration: const InputDecoration(
                    hintText: 'Tìm hoạt động',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final kind in [
                      null,
                      DemoEventKind.social,
                      DemoEventKind.tournament,
                    ])
                      ChoiceChip(
                        showCheckmark: false,
                        selectedColor: AppColors.green,
                        labelStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: kind == _kind ? Colors.white : AppColors.ink,
                        ),
                        label: Text(
                          kind == null
                              ? 'Tất cả'
                              : kind == DemoEventKind.social
                              ? 'Giao lưu'
                              : 'Giải đấu',
                        ),
                        selected: kind == _kind,
                        onSelected: (_) => setState(() => _kind = kind),
                      ),
                  ],
                ),
                const DiscoveryHeading('Hoạt động của tôi'),
                if (activities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Chưa có hoạt động phù hợp.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                for (final a in activities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      child: ListTile(
                        key: Key('owner-activity-${a.id}'),
                        leading: Icon(
                          a.event.kind == DemoEventKind.social
                              ? Icons.groups_outlined
                              : Icons.emoji_events_outlined,
                          color: AppColors.green,
                        ),
                        title: Text(
                          a.event.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${a.label}\n${bookingDate(a.event.scheduledStart!)} · ${bookingTime(a.event.scheduledStart!)}\n${a.event.capacity} người · ${bookingMoney(a.event.fee)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(
                          context,
                          ActivityDetailScreen(session: s, id: a.id),
                        ),
                      ),
                    ),
                  ),
                const DiscoveryHeading('Điều phối sân'),
                _OwnerLink(
                  id: 'explore-calendar',
                  icon: Icons.calendar_month_outlined,
                  title: 'Lịch sân & phân sân',
                  onTap: () => _open(context, CalendarScreen(session: s)),
                ),
                _OwnerLink(
                  id: 'explore-customers',
                  icon: Icons.people_outline,
                  title: 'Khách hàng',
                  onTap: () => _open(context, CustomersScreen(session: s)),
                ),
                _OwnerLink(
                  id: 'explore-employees',
                  icon: Icons.badge_outlined,
                  title: 'Nhân viên & ca làm',
                  onTap: () => _open(context, EmployeeRosterScreen(session: s)),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class OwnerFacilitiesTab extends StatefulWidget {
  const OwnerFacilitiesTab({
    super.key,
    required this.session,
    required this.onMap,
  });
  final DemoSession session;
  final VoidCallback onMap;
  @override
  State<OwnerFacilitiesTab> createState() => _OwnerFacilitiesTabState();
}

class _OwnerFacilitiesTabState extends State<OwnerFacilitiesTab> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.role != DemoRole.owner) return const SizedBox.shrink();
      final venues = s.ownerMapVenues.where((v) {
        if (_filter == 'all') return true;
        if (v.id == demoVenueId) return _filter == 'approved';
        final f = s.managedFacilities.singleWhere((f) => f.id == v.id);
        return _filter == 'approved'
            ? f.published != null && !f.suspended
            : f.state == 'pending';
      }).toList();
      return ListView(
        key: const PageStorageKey('owner-facilities-scroll'),
        padding: EdgeInsets.zero,
        children: [
          DiscoveryHeader(
            title: 'Sân của tôi',
            subtitle: 'Cơ sở, hồ sơ và bảng giá',
            icon: Icons.map_outlined,
            tooltip: 'Bản đồ sân của tôi',
            onPressed: widget.onMap,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FinanceSaveNotice(session: s),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in const {
                      'all': 'Tất cả',
                      'approved': 'Hoạt động',
                      'pending': 'Chờ duyệt',
                    }.entries)
                      ChoiceChip(
                        showCheckmark: false,
                        selectedColor: AppColors.green,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: _filter == entry.key
                              ? Colors.white
                              : AppColors.ink,
                        ),
                        key: Key('owner-facility-filter-${entry.key}'),
                        label: Text(entry.value),
                        selected: _filter == entry.key,
                        onSelected: (_) => setState(() => _filter = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('owner-add-facility'),
                  onPressed: () =>
                      _open(context, FacilityFormScreen(session: s)),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm sân'),
                ),
                const SizedBox(height: 16),
                if (venues.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Chưa có sân phù hợp.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final v in venues) _venue(context, s, v),
                const DiscoveryHeading('Thiết lập cơ sở'),
                _OwnerLink(
                  id: 'facilities-all',
                  icon: Icons.storefront_outlined,
                  title: 'Hồ sơ cơ sở & trạng thái duyệt',
                  onTap: () => _open(context, FacilitiesScreen(session: s)),
                ),
                _OwnerLink(
                  id: 'facilities-prices',
                  icon: Icons.sell_outlined,
                  title: 'Bảng giá sân chính',
                  onTap: () => _open(context, OperationsScreen(session: s)),
                ),
                _OwnerLink(
                  id: 'facilities-revenue',
                  icon: Icons.bar_chart_outlined,
                  title: 'Doanh thu',
                  onTap: () => _open(context, CashflowScreen(session: s)),
                ),
                _OwnerLink(
                  id: 'facilities-settlement',
                  icon: Icons.receipt_long_outlined,
                  title: 'Đối soát thanh toán',
                  onTap: () => _open(context, SettlementScreen(session: s)),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  Widget _venue(BuildContext context, DemoSession s, VenueSummary v) {
    final f = s.managedFacilities.where((f) => f.id == v.id).firstOrNull;
    final live = v.id == demoVenueId || f?.published != null && !f!.suspended;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (v.image.isNotEmpty)
              AspectRatio(aspectRatio: 2.5, child: VenueImage(venue: v)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${f?.label ?? 'Đang hoạt động'} · ${v.sport}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.darkGreen,
                    ),
                  ),
                  Text(
                    v.address,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    v.priceLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                        key: Key('owner-venue-${v.id}'),
                        onPressed: () => openOwnerVenue(context, s, v.id),
                        child: const Text('Quản lý sân'),
                      ),
                      if (live)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                            ),
                          ),
                          key: Key('owner-venue-calendar-${v.id}'),
                          onPressed: () => _open(
                            context,
                            v.id == demoVenueId
                                ? CalendarScreen(session: s)
                                : FacilityCalendarScreen(session: s, id: v.id),
                          ),
                          child: const Text('Lịch sân'),
                        ),
                      if (live)
                        IconButton(
                          key: Key('owner-venue-prices-${v.id}'),
                          tooltip: 'Bảng giá',
                          onPressed: () => _open(
                            context,
                            v.id == demoVenueId
                                ? OperationsScreen(session: s)
                                : FacilityTariffsScreen(session: s, id: v.id),
                          ),
                          icon: const Icon(
                            Icons.sell_outlined,
                            color: AppColors.green,
                          ),
                        ),
                    ],
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

class _OwnerLink extends StatelessWidget {
  const _OwnerLink({
    required this.id,
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final String id, title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('owner-$id'),
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.green, size: 21),
    title: Text(title, style: const TextStyle(fontSize: 13)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
