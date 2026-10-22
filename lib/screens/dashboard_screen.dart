import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import 'approval_center_screen.dart';
import 'calendar_screen.dart';
import 'customers_screen.dart';
import 'facilities_screen.dart';
import 'finance_screen.dart';
import 'settlement_screen.dart';
import 'cashflow_screen.dart';
import 'shifts_screen.dart';
import 'workflow_screen.dart';
import 'facility_calendar_screen.dart';
import 'admin_system_report_screen.dart';
import 'admin_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.session,
    this.facilityId = '',
  });
  final DemoSession session;
  final String facilityId;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _offset = 0;
  late String _facilityId = widget.facilityId;
  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user != null && s.role == DemoRole.admin) {
        return AdminDashboardScreen(session: s);
      }
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Tổng quan'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final facilities = s.managedFacilities
          .where((f) => f.published != null)
          .toList();
      final selected =
          _facilityId == '*' ||
              _facilityId.isEmpty ||
              facilities.any((f) => f.id == _facilityId)
          ? _facilityId
          : '';
      final date = bookingDay(s.now).add(Duration(days: _offset));
      final d = selected == '*'
          ? s.allFacilitiesOverview(date)
          : s.dayOverview(date, facilityId: selected);
      var proof = 0, cancel = 0, refund = 0;
      for (final r in s.managedAttendance) {
        final p = s.workflowPayment(r.id);
        if (p == null) continue;
        if (p.cancellation == DemoCancellationState.requested) {
          cancel++;
        } else if (!r.cancelled && p.state == DemoPaymentState.pending) {
          proof++;
        }
        if (p.refund == DemoRefundState.pending) refund++;
      }
      final disputes = s.disputes.where((d) => d.closedAt == null).length;
      final pct = d.capacity == 0 ? 0.0 : d.reserved / d.capacity;
      final shortcuts =
          <({String id, String label, IconData icon, Widget screen})>[
            (
              id: 'calendar',
              label: 'Lịch sân',
              icon: Icons.calendar_month,
              screen: selected.isEmpty || selected == '*'
                  ? CalendarScreen(session: s)
                  : FacilityCalendarScreen(session: s, id: selected),
            ),
            (
              id: 'customers',
              label: 'Khách hàng',
              icon: Icons.people_outline,
              screen: CustomersScreen(session: s),
            ),
            (
              id: 'employees',
              label: 'Nhân viên',
              icon: Icons.badge_outlined,
              screen: EmployeeRosterScreen(session: s),
            ),
            (
              id: 'facilities',
              label: 'Cơ sở',
              icon: Icons.storefront_outlined,
              screen: FacilitiesScreen(session: s),
            ),
            (
              id: 'settlement',
              label: 'Đối soát',
              icon: Icons.receipt_long_outlined,
              screen: SettlementScreen(session: s),
            ),
            (
              id: 'cashflow',
              label: 'Doanh thu',
              icon: Icons.bar_chart_outlined,
              screen: CashflowScreen(session: s),
            ),
            (
              id: 'attendance',
              label: 'Vé & check-in',
              icon: Icons.qr_code_scanner,
              screen: AttendanceScreen(session: s),
            ),
            if (s.role == DemoRole.admin)
              (
                id: 'system-report',
                label: 'Báo cáo hệ thống',
                icon: Icons.analytics_outlined,
                screen: AdminSystemReportScreen(session: s),
              ),
            if (s.role == DemoRole.admin)
              (
                id: 'approval',
                label: 'Trung tâm xử lý',
                icon: Icons.pending_actions,
                screen: ApprovalCenterScreen(session: s),
              ),
          ];
      return Scaffold(
        appBar: financeBar(
          s.role == DemoRole.admin ? 'Tổng quan Admin' : 'Tổng quan Chủ sân',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            DropdownButtonFormField<String>(
              key: const Key('dashboard-facility'),
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cơ sở'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text(DemoBooking.venue),
                ),
                const DropdownMenuItem(value: '*', child: Text('Tất cả cơ sở')),
                for (final f in facilities)
                  DropdownMenuItem(value: f.id, child: Text(f.published!.name)),
              ],
              onChanged: (v) => setState(() => _facilityId = v!),
            ),
            Text(
              selected == '*'
                  ? 'Tất cả cơ sở'
                  : selected.isEmpty
                  ? DemoBooking.venue
                  : facilities
                        .singleWhere((f) => f.id == selected)
                        .published!
                        .name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              bookingDate(d.day),
              textAlign: TextAlign.center,
              key: const Key('dashboard-date'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const Key('dashboard-previous'),
                  tooltip: 'Ngày trước',
                  onPressed: _offset == 0
                      ? null
                      : () => setState(() => _offset--),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  key: const Key('dashboard-next'),
                  tooltip: 'Ngày tiếp theo',
                  onPressed: _offset == 6
                      ? null
                      : () => setState(() => _offset++),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: 'Cập nhật thời gian',
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text(
              '${(pct * 100).toStringAsFixed(1)}% giờ sân đã đặt',
              key: const Key('dashboard-occupancy'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: pct, minHeight: 6),
            const SizedBox(height: 12),
            _metric('Lịch còn hiệu lực', '${d.bookings.length}', 'bookings'),
            _metric(
              'Giờ sân đã đặt',
              '${d.reserved} / ${d.capacity}',
              'reserved',
            ),
            _metric('Giờ sân khóa', '${d.blocked}', 'blocked'),
            _metric(
              'Giờ chưa đặt / chưa khóa',
              '${d.capacity - d.reserved - d.blocked}',
              'free',
            ),
            _metric(
              'Giá trị lịch đã xác nhận',
              bookingMoney(d.confirmedValue),
              'value',
            ),
            const Text(
              'Trước hoàn tiền và phí · Theo ngày sử dụng · Cơ sở demo',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 32),
            const Text(
              'Chờ xử lý toàn hệ thống',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            _metric('Chứng từ', '$proof', 'proof'),
            _metric('Yêu cầu hủy', '$cancel', 'cancel'),
            _metric('Hoàn tiền', '$refund', 'refund'),
            _metric('Khiếu nại chưa đóng', '$disputes', 'disputes'),
            const Divider(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in shortcuts)
                  OutlinedButton.icon(
                    key: Key('dashboard-${e.id}'),
                    onPressed: () => _open(e.screen),
                    icon: Icon(e.icon),
                    label: Text(e.label),
                  ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Lịch trong ngày',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (d.bookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Chưa có lịch đặt trong ngày.'),
              ),
            for (final b in d.bookings)
              ListTile(
                key: Key('dashboard-booking-${b.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(b.contact),
                subtitle: Text(
                  '${b.id} · Sân ${b.court}\n${bookingTime(b.start)}–${bookingTime(b.end)} · ${bookingMoney(b.total)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(WorkflowDetailScreen(session: s, id: b.id)),
              ),
          ],
        ),
      );
    },
  );

  Widget _metric(String label, String value, String id) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label),
        Text(
          value,
          key: Key('dashboard-metric-$id'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
