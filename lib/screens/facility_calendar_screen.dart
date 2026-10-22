import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import 'booking_screen.dart';
import 'finance_screen.dart';
import 'calendar_screen.dart';
import 'facility_tariffs_screen.dart';
import 'dashboard_screen.dart';
import 'owner_booking_views.dart';

class FacilityCalendarScreen extends StatefulWidget {
  const FacilityCalendarScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  State<FacilityCalendarScreen> createState() => _FacilityCalendarScreenState();
}

class _FacilityCalendarScreenState extends State<FacilityCalendarScreen> {
  late DateTime _day = bookingDay(widget.session.now);
  String _error = '';
  void _edit(bool locking, int openHour) {
    final today = bookingDay(widget.session.now);
    final day =
        _day.isAfter(today) && !_day.isAfter(today.add(const Duration(days: 6)))
        ? _day
        : today.add(const Duration(days: 1));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarEditorScreen(
          session: widget.session,
          facilityId: widget.id,
          court: 1,
          start: day.add(Duration(hours: openHour)),
          locking: locking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user != null && s.role == DemoRole.owner) {
        return OwnerCalendarView(session: s, facilityId: widget.id);
      }
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Lịch cơ sở'),
          body: const Center(child: Text('Cần tài khoản quản lý.')),
        );
      }
      final f = s.managedFacilities.where((f) => f.id == widget.id).firstOrNull;
      if (f?.published == null) {
        return Scaffold(
          appBar: financeBar('Lịch cơ sở'),
          body: const Center(child: Text('Cơ sở chưa công bố.')),
        );
      }
      final p = f!.published!;
      final blocks = s.courtBlocks
          .where(
            (b) => b.facilityId == widget.id && bookingDay(b.start) == _day,
          )
          .toList();
      final bookings = s.managedBookings
          .where(
            (b) => b.facilityId == widget.id && bookingDay(b.start) == _day,
          )
          .toList();
      return Scaffold(
        appBar: financeBar('Lịch cơ sở'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            OutlinedButton.icon(
              key: const Key('facility-calendar-dashboard'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DashboardScreen(session: s, facilityId: widget.id),
                ),
              ),
              icon: const Icon(Icons.bar_chart),
              label: const Text('Tổng quan cơ sở'),
            ),
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '${p.courtCount} sân · ${p.openHour}:00–${p.closeHour}:00 · ${bookingMoney(p.baseRate)}/giờ',
            ),
            OutlinedButton.icon(
              key: const Key('facility-calendar-tariffs'),
              icon: const Icon(Icons.price_change_outlined),
              label: const Text('Bảng giá theo giờ'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FacilityTariffsScreen(session: s, id: widget.id),
                ),
              ),
            ),
            if (!f.suspended)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('facility-calendar-manual'),
                    onPressed: () => _edit(false, p.openHour),
                    icon: const Icon(Icons.add),
                    label: const Text('Đặt hộ khách'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('facility-calendar-lock'),
                    onPressed: () => _edit(true, p.openHour),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Khóa giờ'),
                  ),
                ],
              ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(bookingDate(_day)),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) setState(() => _day = date);
              },
            ),
            if (bookings.isEmpty) const Text('Chưa có lịch đặt trong ngày.'),
            for (final b in bookings)
              ListTile(
                key: Key('facility-calendar-${b.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  'Sân ${b.court} · ${bookingTime(b.start)}–${bookingTime(b.end)}',
                ),
                subtitle: Text(
                  '${b.id} · ${b.contact}\n${b.cancelled ? 'Đã hủy' : s.attendanceLabel(b.attendance)} · ${bookingMoney(b.total)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingDetailScreen(session: s, booking: b),
                  ),
                ),
              ),
            const Divider(),
            const Text(
              'Số giờ đã đặt theo sân',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (var court = 1; court <= p.courtCount; court++)
              Text(
                'Sân $court: ${bookings.where((b) => b.court == court && !b.cancelled).fold<int>(0, (sum, b) => sum + b.hours)} giờ',
              ),
            const Divider(),
            const Text(
              'Khung giờ khóa',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (blocks.isEmpty)
              const Text('Chưa có khung giờ khóa trong ngày.'),
            for (final b in blocks)
              ListTile(
                key: Key('facility-block-${b.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Sân ${b.court} · ${bookingTime(b.start)}–${bookingTime(b.end)}',
                ),
                subtitle: Text(b.reason),
                trailing: IconButton(
                  key: Key('facility-unblock-${b.id}'),
                  tooltip: 'Mở khóa',
                  icon: const Icon(Icons.lock_open),
                  onPressed: () async {
                    final actor = s.user?.identifier;
                    if (!await financeConfirm(
                          context,
                          'Mở khóa giờ?',
                          '${b.reason}\nSân ${b.court} · ${bookingTime(b.start)}',
                        ) ||
                        !mounted) {
                      return;
                    }
                    try {
                      if (actor != s.user?.identifier) {
                        throw StateError('Tài khoản đã thay đổi.');
                      }
                      s.unblockCourt(b);
                      await s.flush();
                    } on StateError catch (e) {
                      if (mounted) setState(() => _error = e.message);
                    }
                  },
                ),
              ),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}
