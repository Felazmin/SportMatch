import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import '../demo/demo_calendar.dart';
import '../widgets/design.dart';
import 'owner_management_widgets.dart';
import 'calendar_screen.dart';
import 'finance_screen.dart';
import 'workflow_screen.dart';
import 'event_courts_screen.dart';
import '../demo/demo_events.dart';

const _small = TextStyle(fontSize: 11, color: AppColors.muted);
const _bold = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);

class OwnerOperationsScaffold extends StatelessWidget {
  const OwnerOperationsScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.bottomNavigationBar = const OwnerNavigation(),
  });
  final PreferredSizeWidget appBar;
  final Widget body, bottomNavigationBar;
  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            shape: shape,
            minimumSize: const Size(0, 42),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            shape: shape,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(0, 42),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        chipTheme: Theme.of(context).chipTheme.copyWith(
          shape: const StadiumBorder(),
          selectedColor: AppColors.green,
          backgroundColor: Colors.white,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11),
        ),
      ),
      child: Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

Map<String, String> ownerVenueNames(DemoSession s) => {
  '': DemoBooking.venue,
  for (final f in s.managedFacilities.where((f) => f.published != null))
    f.id: f.published!.name,
};

class OwnerVenuePicker extends StatelessWidget {
  const OwnerVenuePicker({
    super.key,
    required this.session,
    required this.value,
    required this.onChanged,
  });
  final DemoSession session;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => OwnerCard(
    padding: 8,
    child: Row(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.location_on_outlined,
            color: AppColors.green,
            size: 22,
          ),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey('owner-operation-venue-$value'),
              value: value,
              isExpanded: true,
              isDense: false,
              itemHeight: ownerLarge(context) ? 80 : 56,
              selectedItemBuilder: (context) => [
                for (final e in ownerVenueNames(session).entries)
                  SizedBox(
                    height: ownerLarge(context) ? 80 : 56,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bold,
                        ),
                        Text(
                          e.key.isEmpty
                              ? DemoBooking.address
                              : session.managedFacilities
                                    .firstWhere((f) => f.id == e.key)
                                    .published!
                                    .address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              items: [
                for (final e in ownerVenueNames(session).entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: _bold),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class OwnerBookingCard extends StatelessWidget {
  const OwnerBookingCard({
    super.key,
    required this.session,
    required this.booking,
  });
  final DemoSession session;
  final DemoBooking booking;
  @override
  Widget build(BuildContext context) {
    final b = booking;
    final paid = session.paymentFor(b)?.state == DemoPaymentState.approved;
    void open() => ownerOpen(
      context,
      WorkflowDetailScreen(session: session, id: b.id, ownerPresentation: true),
    );
    return OwnerCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: AppColors.green,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.contact, style: _bold),
                    Text('Sân ${b.court} · ${b.sport}', style: _small),
                    Text(
                      '${bookingTime(b.start)} – ${bookingTime(b.end)} · ${bookingDate(b.start)}',
                      style: _small,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OwnerBadge(
              b.cancelled
                  ? 'Đã hủy'
                  : paid
                  ? 'Đã xác nhận'
                  : 'Chờ xác nhận',
              warning: !paid,
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  bookingMoney(b.total),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: open,
                child: const Text(
                  'Chi tiết đặt sân',
                  style: TextStyle(fontSize: 11, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OwnerCalendarView extends StatefulWidget {
  const OwnerCalendarView({
    super.key,
    required this.session,
    this.facilityId = '',
  });
  final DemoSession session;
  final String facilityId;
  @override
  State<OwnerCalendarView> createState() => _OwnerCalendarViewState();
}

class _OwnerCalendarViewState extends State<OwnerCalendarView> {
  late String _venue = widget.facilityId;
  late DateTime _day = bookingDay(widget.session.now)
      .add(const Duration(days: 1));
  int? _court;
  bool _locking = false, _all = false;
  String? _error;

  Future<void> _date() async {
    final today = bookingDay(widget.session.now);
    final d = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 6)),
      initialDate: _day.isBefore(today)
          ? today
          : _day.isAfter(today.add(const Duration(days: 6)))
          ? today
          : _day,
    );
    if (d != null && mounted) setState(() => _day = d);
  }

  void _edit(int court, DateTime start, {bool? locking}) => ownerOpen(
    context,
    CalendarEditorScreen(
      session: widget.session,
      court: court,
      start: start,
      facilityId: _venue,
      locking: locking ?? _locking,
    ),
  );

  Future<void> _unblock(DemoCourtBlock block) async {
    final s = widget.session, actor = widget.session.user?.identifier;
    if (block.eventId.isNotEmpty) {
      final event =
          demoEvents.where((e) => e.id == block.eventId).firstOrNull ??
          s.managedActivities
              .where((a) => a.id == block.eventId)
              .firstOrNull
              ?.event;
      if (event != null && mounted) {
        ownerOpen(
          context,
          EventCourtsScreen(session: s, event: event, start: block.start),
        );
      }
      return;
    }
    if (!await financeConfirm(context, 'Mở khóa khung giờ?', block.reason) ||
        !mounted) {
      return;
    }
    try {
      if (s.user?.identifier != actor || s.role != DemoRole.owner) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      s.unblockCourt(block);
      await s.flush();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.owner) {
        return const Scaffold(
          body: Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final names = ownerVenueNames(s);
      if (!names.containsKey(_venue)) {
        return const Scaffold(body: Center(child: Text('Cơ sở chưa công bố.')));
      }
      final f = s.managedFacilities.where((f) => f.id == _venue).firstOrNull;
      final profile = f?.published;
      final count = profile?.courtCount ?? s.publishedCourts.enabled.length;
      final open = profile?.openHour ?? 6, close = profile?.closeHour ?? 22;
      final sport = profile?.sport ?? 'Cầu lông';
      final active = profile == null
          ? s.publishedCourts.enabled.where((v) => v).length
          : f!.suspended
          ? 0
          : count;
      final today = bookingDay(s.now);
      final days = List.generate(7, (i) => today.add(Duration(days: i)));
      final bookings = s.managedBookings
          .where(
            (b) =>
                b.facilityId == _venue &&
                !b.cancelled &&
                bookingDay(b.start) == _day,
          )
          .toList();
      final blocks = s.courtBlocks
          .where((b) => b.facilityId == _venue && bookingDay(b.start) == _day)
          .toList();
      final pending = bookings
          .where((b) => s.paymentFor(b)?.state != DemoPaymentState.approved)
          .toList();
      final large = ownerLarge(context);
      final cw = large ? 60.0 : 42.0, ch = large ? 72.0 : 42.0;
      Widget cell(Widget child, {double? width}) => SizedBox(
        width: width ?? cw,
        height: ch,
        child: Center(child: child),
      );
      void create(bool locking) {
        for (var hour = open; hour < close; hour++) {
          for (var c = 1; c <= count; c++) {
            final start = _day.add(Duration(hours: hour));
            if ((_court == null || _court == c) &&
                s.available(c, start, 1, facilityId: _venue)) {
              _edit(c, start, locking: locking);
              return;
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ngày này không còn khung giờ trống.')),
        );
      }

      return OwnerOperationsScaffold(
        appBar: OwnerBar(
          title: 'Lịch sân',
          subtitle: names[_venue]!,
          large: large,
          icon: Icons.calendar_month_outlined,
          onAction: _date,
        ),
        bottomNavigationBar: const OwnerNavigation(),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            FinanceSaveNotice(session: s),
            OwnerVenuePicker(
              session: s,
              value: _venue,
              onChanged: (v) => setState(() {
                _venue = v;
                _court = null;
              }),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tháng ${_day.month}, ${_day.year}',
                    style: _bold,
                  ),
                ),
                IconButton(
                  key: const Key('calendar-prev'),
                  tooltip: 'Ngày trước',
                  onPressed: _day.isAfter(today)
                      ? () => setState(
                          () => _day = _day.subtract(const Duration(days: 1)),
                        )
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 18),
                ),
                IconButton(
                  key: const Key('calendar-next'),
                  tooltip: 'Ngày sau',
                  onPressed: _day.isBefore(days.last)
                      ? () => setState(
                          () => _day = _day.add(const Duration(days: 1)),
                        )
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 18),
                ),
              ],
            ),
            SizedBox(
              height: large ? 90 : 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 5),
                itemBuilder: (context, i) {
                  final d = days[i], selected = d == _day;
                  return SizedBox(
                    width: large ? 68 : 40,
                    child: Material(
                      color: selected ? AppColors.green : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        key: Key('owner-calendar-day-$i'),
                        onTap: () => setState(() => _day = d),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              d.weekday == 7 ? 'CN' : 'T${d.weekday + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? Colors.white
                                    : AppColors.muted,
                              ),
                            ),
                            Text(
                              '${d.day}'.padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final e in {
                  const Color(0xFFDDF5E9): 'Sân trống',
                  const Color(0xFFFFE1DC): 'Đã đặt',
                  const Color(0xFFE6E8EB): 'Bị khóa',
                  const Color(0xFFEADFFF): 'Sự kiện',
                }.entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, color: e.key),
                      const SizedBox(width: 4),
                      Text(e.value, style: _small),
                    ],
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text('$active sân đang hoạt động', style: _bold),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Lọc sân',
                  icon: const Icon(
                    Icons.filter_list,
                    size: 18,
                    color: AppColors.green,
                  ),
                  onSelected: (v) => setState(() => _court = v == 0 ? null : v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 0, child: Text('Tất cả sân')),
                    for (var c = 1; c <= count; c++)
                      PopupMenuItem(value: c, child: Text('Sân $c')),
                  ],
                ),
              ],
            ),
            Text(
              'Mở cửa ${open.toString().padLeft(2, '0')}:00 – ${close.toString().padLeft(2, '0')}:00',
              style: _small,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              key: const Key('owner-calendar-grid'),
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      cell(
                        const Text('SÂN', style: _small),
                        width: large ? 105 : 65,
                      ),
                      for (var h = open; h < close; h++)
                        cell(
                          Text(
                            '${h.toString().padLeft(2, '0')}h',
                            style: _small,
                          ),
                        ),
                    ],
                  ),
                  for (var c = 1; c <= count; c++)
                    if (_court == null || c == _court)
                      Row(
                        children: [
                          cell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sân ${c.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  sport,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            width: large ? 105 : 65,
                          ),
                          for (var h = open; h < close; h++)
                            Builder(
                              builder: (context) {
                                final start = _day.add(Duration(hours: h));
                                final b = bookings
                                    .where(
                                      (b) =>
                                          b.court == c &&
                                          !start.isBefore(b.start) &&
                                          start.isBefore(b.end),
                                    )
                                    .firstOrNull;
                                final block = blocks
                                    .where(
                                      (b) =>
                                          b.court == c &&
                                          !start.isBefore(b.start) &&
                                          start.isBefore(b.end),
                                    )
                                    .firstOrNull;
                                final event = block?.eventId.isNotEmpty == true;
                                final free = s.available(
                                  c,
                                  start,
                                  1,
                                  facilityId: _venue,
                                );
                                final color = b != null
                                    ? const Color(0xFFFFE1DC)
                                    : event
                                    ? const Color(0xFFEADFFF)
                                    : block != null || !free
                                    ? const Color(0xFFE6E8EB)
                                    : const Color(0xFFDDF5E9);
                                final label =
                                    b?.id ??
                                    (event
                                        ? 'Sự kiện'
                                        : block != null
                                        ? 'Bị khóa'
                                        : free
                                        ? 'Trống'
                                        : 'Không khả dụng');
                                return SizedBox(
                                  width: cw,
                                  height: ch,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Material(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                      child: Tooltip(
                                        message:
                                            'Sân $c · ${bookingTime(start)} · $label',
                                        child: InkWell(
                                          key: Key('calendar-slot-$c-$h'),
                                          onTap: b != null
                                              ? () => ownerOpen(
                                                  context,
                                                  WorkflowDetailScreen(
                                                    session: s,
                                                    id: b.id,
                                                    ownerPresentation: true,
                                                  ),
                                                )
                                              : block != null
                                              ? () => _unblock(block)
                                              : free
                                              ? () => _edit(c, start)
                                              : null,
                                          child: Center(
                                            child: b != null
                                                ? const Icon(
                                                    Icons.check,
                                                    color: Colors.redAccent,
                                                    size: 15,
                                                  )
                                                : event
                                                ? const Icon(
                                                    Icons
                                                        .confirmation_number_outlined,
                                                    color:
                                                        Colors.deepPurpleAccent,
                                                    size: 14,
                                                  )
                                                : block != null || !free
                                                ? const Icon(
                                                    Icons.lock_outline,
                                                    color: AppColors.muted,
                                                    size: 13,
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('calendar-mode-book'),
                  onPressed: () {
                    setState(() => _locking = false);
                    create(false);
                  },
                  child: const Text('+ Tạo lịch đặt'),
                ),
                OutlinedButton(
                  key: const Key('calendar-mode-block'),
                  onPressed: () {
                    setState(() => _locking = true);
                    create(true);
                  },
                  child: const Text('Khóa khung giờ'),
                ),
              ],
            ),
            if (_locking) const Text('Đang chọn khung giờ khóa', style: _small),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _all
                        ? 'Lịch trong ngày (${bookings.length})'
                        : 'Lịch cần xử lý (${pending.length})',
                    style: _bold,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _all = !_all),
                  child: Text(
                    _all ? 'Cần xử lý' : 'Xem tất cả',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            if ((_all ? bookings : pending).isEmpty)
              const OwnerCard(
                child: Text('Không có lịch phù hợp.', style: _small),
              ),
            for (final b in _all ? bookings : pending)
              OwnerBookingCard(session: s, booking: b),
            for (final block in blocks)
              ListTile(
                title: Text(
                  'Sân ${block.court} · ${block.reason}',
                  style: _small,
                ),
                trailing: IconButton(
                  key: Key('calendar-unblock-${block.id}'),
                  tooltip: 'Mở khóa / phân sân sự kiện',
                  onPressed: () => _unblock(block),
                  icon: const Icon(Icons.lock_open, size: 18),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class OwnerRevenueView extends StatefulWidget {
  const OwnerRevenueView({
    super.key,
    required this.session,
    this.facilityId = '',
  });
  final DemoSession session;
  final String facilityId;
  @override
  State<OwnerRevenueView> createState() => _OwnerRevenueViewState();
}

class _OwnerRevenueViewState extends State<OwnerRevenueView> {
  late String _venue = widget.facilityId;
  int _period = 1;
  DateTimeRange? _range;
  bool _all = false;
  Future<void> _dates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: bookingDay(widget.session.now),
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    if (picked.duration.inDays > 365) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chọn tối đa 366 ngày.')));
      return;
    }
    setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.owner) {
        return const Scaffold(
          body: Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final names = ownerVenueNames(s);
      if (!names.containsKey(_venue)) {
        return const Scaffold(body: Center(child: Text('Cơ sở chưa công bố.')));
      }
      final today = bookingDay(s.now);
      final from =
          _range?.start ??
          (_period == 0
              ? today
              : _period == 1
              ? today.subtract(Duration(days: today.weekday - 1))
              : DateTime(today.year, today.month));
      final to = _range?.end ?? today;
      final report = s.cashflowReport(
        from: from,
        to: to,
        facilityId: _venue,
        tickets: false,
      );
      final previous = s
          .cashflowReport(
            from: from.subtract(Duration(days: to.difference(from).inDays + 1)),
            to: from.subtract(const Duration(days: 1)),
            facilityId: _venue,
            tickets: false,
          )
          .received;
      final change = previous == 0
          ? 'Chưa có dữ liệu kỳ trước'
          : '${report.received >= previous ? '+' : ''}${((report.received - previous) * 100 / previous).toStringAsFixed(1)}% so với kỳ trước';
      final unpaid = s.managedBookings
          .where(
            (b) =>
                !b.cancelled &&
                b.facilityId == _venue &&
                !bookingDay(b.start).isBefore(from) &&
                !bookingDay(b.start).isAfter(to) &&
                s.paymentFor(b)?.state != DemoPaymentState.approved,
          )
          .fold<int>(0, (sum, b) => sum + b.total);
      final sports = <String, int>{};
      for (final e in report.entries.where((e) => !e.refund)) {
        final b = s.managedBookings.where((b) => b.id == e.id).firstOrNull;
        if (b != null) {
          sports.update(b.sport, (v) => v + e.amount, ifAbsent: () => e.amount);
        }
      }
      Future<void> export() async {
        try {
          await Clipboard.setData(ClipboardData(text: report.csv()));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã sao chép báo cáo CSV.')),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể xuất báo cáo. Thử lại.')),
            );
          }
        }
      }

      return OwnerOperationsScaffold(
        appBar: OwnerBar(
          title: 'Doanh thu',
          subtitle: names[_venue]!,
          large: ownerLarge(context),
          icon: Icons.download_outlined,
          onAction: report.entries.isEmpty ? null : export,
        ),
        bottomNavigationBar: const OwnerNavigation(),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            FinanceSaveNotice(session: s),
            OwnerVenuePicker(
              session: s,
              value: _venue,
              onChanged: (v) => setState(() => _venue = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                    key: Key('cashflow-days-${[1, 7, 30][i]}'),
                    showCheckmark: false,
                    label: Text(
                      ['Hôm nay', 'Tuần này', 'Tháng này'][i],
                      style: TextStyle(
                        fontSize: 11,
                        color: _range == null && _period == i
                            ? Colors.white
                            : AppColors.muted,
                      ),
                    ),
                    selected: _range == null && _period == i,
                    onSelected: (_) => setState(() {
                      _period = i;
                      _range = null;
                    }),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${bookingDate(from)} – ${bookingDate(to)}',
                    style: _bold,
                  ),
                ),
                TextButton(
                  key: const Key('cashflow-dates'),
                  onPressed: _dates,
                  child: const Text(
                    'Chọn kỳ khác',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            OwnerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Tổng doanh thu đã ghi nhận', style: _small),
                  const SizedBox(height: 8),
                  Text(
                    bookingMoney(report.received),
                    key: const Key('cashflow-received'),
                    style: const TextStyle(
                      fontSize: 25,
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OwnerBadge(change),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đã thu', style: _small),
                          Text(
                            bookingMoney(report.received),
                            style: const TextStyle(
                              fontSize: 17,
                              color: AppColors.darkGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Chưa thu · lịch trong kỳ', style: _small),
                          Text(
                            bookingMoney(unpaid),
                            key: const Key('owner-revenue-unpaid'),
                            style: const TextStyle(
                              fontSize: 17,
                              color: AppColors.darkGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (report.refunded > 0) ...[
                    const Divider(),
                    ownerLine('Đã hoàn', bookingMoney(report.refunded)),
                    ownerLine('Thu sau hoàn', bookingMoney(report.balance)),
                  ],
                  if (report.undatedPayments > 0)
                    Text(
                      '${report.undatedPayments} khoản chưa có ngày ghi nhận.',
                      style: _small,
                    ),
                ],
              ),
            ),
            OwnerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text('Doanh thu theo ngày', style: _bold),
                      ),
                      Text(
                        'Triệu đồng',
                        style: TextStyle(fontSize: 10, color: AppColors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OwnerRevenueChart(values: report.daily(), today: today),
                ],
              ),
            ),
            OwnerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Theo loại sân', style: _bold),
                  const SizedBox(height: 10),
                  if (sports.isEmpty)
                    const Text('Chưa có doanh thu trong kỳ.', style: _small),
                  for (final e in sports.entries)
                    ownerLine(e.key, bookingMoney(e.value)),
                ],
              ),
            ),
            Row(
              children: [
                const Expanded(child: Text('Giao dịch gần đây', style: _bold)),
                TextButton(
                  onPressed: () => setState(() => _all = !_all),
                  child: Text(
                    _all ? 'Thu gọn' : 'Xem tất cả',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            OwnerCard(
              child: Column(
                children: [
                  if (report.entries.isEmpty)
                    const Text(
                      'Không có giao dịch trong khoảng ngày này.',
                      key: Key('cashflow-empty'),
                      style: _small,
                    ),
                  for (final e
                      in (_all
                          ? report.entries.reversed
                          : report.entries.reversed.take(3)))
                    Builder(
                      builder: (context) {
                        final b = s.managedBookings
                            .where((b) => b.id == e.id)
                            .firstOrNull;
                        return ListTile(
                          key: Key('cashflow-entry-${e.id}-${e.refund}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.receipt_long_outlined,
                            color: e.refund ? Colors.red : AppColors.green,
                            size: 22,
                          ),
                          title: Text(
                            b?.contact ?? e.title,
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            b == null
                                ? bookingDate(e.date)
                                : 'Sân ${b.court} · ${bookingTime(b.start)}–${bookingTime(b.end)}',
                            style: _small,
                          ),
                          trailing: Text(
                            '${e.refund ? '-' : '+'}${bookingMoney(e.amount)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: e.refund
                                  ? Colors.red
                                  : AppColors.darkGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () => ownerOpen(
                            context,
                            WorkflowDetailScreen(
                              session: s,
                              id: e.id,
                              ownerPresentation: true,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            OutlinedButton(
              key: const Key('cashflow-export'),
              onPressed: report.entries.isEmpty ? null : export,
              child: const Text('Xuất báo cáo doanh thu'),
            ),
          ],
        ),
      );
    },
  );
}

class OwnerBookingView extends StatefulWidget {
  const OwnerBookingView({super.key, required this.session, required this.id});
  final DemoSession session;
  final String id;
  @override
  State<OwnerBookingView> createState() => _OwnerBookingViewState();
}

class _OwnerBookingViewState extends State<OwnerBookingView> {
  bool _busy = false;
  String? _error;
  Future<void> _contact(String scheme, String phone) async {
    try {
      if (!await launchUrl(Uri(scheme: scheme, path: phone))) {
        throw StateError('Không có ứng dụng phù hợp trên thiết bị.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở liên hệ trên thiết bị này.'),
          ),
        );
      }
    }
  }

  Future<void> _confirm(DemoBooking b) async {
    if (_busy) return;
    final s = widget.session, actor = widget.session.user?.identifier;
    final payment = s.paymentFor(b), revision = b.revision;
    if (!await financeConfirm(
          context,
          'Xác nhận thanh toán & lịch đặt?',
          'Kiểm tra khoản tiền thực nhận trước khi xác nhận.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (s.user?.identifier != actor ||
          s.role != DemoRole.owner ||
          b.revision != revision ||
          s.paymentFor(b) != payment) {
        throw StateError('Hồ sơ đã thay đổi. Mở lại để kiểm tra.');
      }
      if (payment == null) {
        s.confirmVenuePayment(b);
      } else {
        s.reviewPayment(b, approve: true);
      }
      if (!await s.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.owner) {
        return const Scaffold(
          body: Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final b = s.managedBookings.where((b) => b.id == widget.id).firstOrNull;
      if (b == null) {
        return const Scaffold(
          body: Center(child: Text('Không tìm thấy lịch đặt.')),
        );
      }
      final p = s.paymentFor(b), bank = s.payoutAccount;
      final status = b.cancelled
          ? 'Đã hủy lịch'
          : p?.label(s.now) ?? 'Chờ xác nhận thanh toán';
      final history = s.workflowHistory(b.id);
      final canConfirm =
          !b.cancelled &&
          b.attendance == DemoAttendance.pending &&
          s.now.isBefore(b.end) &&
          (p == null ||
              (p.state == DemoPaymentState.pending &&
                  p.cancellation != DemoCancellationState.requested));
      final canMove =
          !b.cancelled &&
          b.attendance == DemoAttendance.pending &&
          b.start.isAfter(s.now) &&
          (p == null ||
              (p.state == DemoPaymentState.approved &&
                  p.cancellation != DemoCancellationState.requested &&
                  p.refund == DemoRefundState.none));
      void payment() =>
          ownerOpen(context, PaymentScreen(session: s, booking: b));
      Widget group(String title, List<Widget> children) => OwnerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: _bold),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
      return OwnerOperationsScaffold(
        appBar: OwnerBar(
          title: 'Chi tiết đặt sân',
          subtitle: b.id,
          large: ownerLarge(context),
          icon: Icons.calendar_month_outlined,
          onAction: () => ownerOpen(
            context,
            OwnerCalendarView(session: s, facilityId: b.facilityId),
          ),
        ),
        bottomNavigationBar: const OwnerNavigation(),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            FinanceSaveNotice(session: s),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p?.state == DemoPaymentState.approved
                    ? const Color(0xFFE5F6ED)
                    : const Color(0xFFFFF6E4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.darkGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(status, style: _bold)),
                ],
              ),
            ),
            group(b.venueName, [
              Text('Sân ${b.court} · ${b.sport}', style: _small),
              const SizedBox(height: 10),
              ownerLine('Ngày đặt', bookingDate(b.start)),
              ownerLine(
                'Giờ đặt',
                '${bookingTime(b.start)} – ${bookingTime(b.end)}',
              ),
              ownerLine('Thời lượng', '${b.hours} giờ'),
              ownerLine(
                'Nguồn đặt',
                p?.atVenue == true ? 'Tại sân' : 'SportMatch',
              ),
            ]),
            group('Thông tin khách hàng', [
              Text(b.contact, style: _bold),
              ownerLine('Số điện thoại', b.phone),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _contact('tel', b.phone),
                    icon: const Icon(Icons.call_outlined, size: 16),
                    label: const Text(
                      'Gọi khách',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _contact('sms', b.phone),
                    icon: const Icon(Icons.sms_outlined, size: 16),
                    label: const Text(
                      'Nhắn tin',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ]),
            group('Thông tin thanh toán', [
              Text(
                p?.atVenue == true || p == null
                    ? 'Thanh toán tại sân.'
                    : 'Chuyển khoản · Kiểm tra minh chứng và khoản thực nhận.',
                style: _small,
              ),
              ownerLine('Tổng đơn', bookingMoney(b.subtotal)),
              if (b.discount > 0)
                ownerLine(
                  'Ưu đãi ${b.voucherCode ?? ''}',
                  '-${bookingMoney(b.discount)}',
                ),
              const Divider(),
              ownerLine('Tổng thanh toán', bookingMoney(b.total)),
              if (bank != null) ...[
                ownerLine('Ngân hàng', bank.bank),
                ownerLine('Chủ tài khoản', bank.holder),
                ownerLine('Số tài khoản', bank.number),
              ] else
                const Text(
                  'Chưa thiết lập tài khoản nhận thanh toán.',
                  style: _small,
                ),
              ownerLine(
                'Nội dung CK',
                p?.reference.isNotEmpty == true ? p!.reference : b.id,
              ),
            ]),
            group('Giấy tờ đã gửi', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Hình ảnh thanh toán',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  p?.proof.isNotEmpty == true ? 'Xem ảnh ›' : 'Chưa gửi',
                  style: _small,
                ),
                onTap: p?.proof.isNotEmpty == true
                    ? () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: Image.memory(
                            decodeProof(p!.proof),
                            fit: BoxFit.contain,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Đóng'),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
              if (p?.reviewNote.isNotEmpty == true)
                Text(p!.reviewNote, style: _small),
            ]),
            group('Lịch sử xử lý', [
              if (history.isEmpty)
                const Text('Chưa có thao tác được ghi nhận.', style: _small),
              for (final h in history)
                ownerLine(
                  '${bookingDate(h.created)} ${h.created.hour.toString().padLeft(2, '0')}:${h.created.minute.toString().padLeft(2, '0')}',
                  h.action,
                ),
            ]),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (canConfirm)
              FilledButton(
                key: const Key('owner-booking-confirm'),
                onPressed: _busy ? null : () => _confirm(b),
                child: const Text('Xác nhận thanh toán & lịch đặt'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canMove)
                  OutlinedButton(
                    key: const Key('calendar-reschedule'),
                    onPressed: _busy
                        ? null
                        : () => ownerOpen(
                            context,
                            CalendarEditorScreen(
                              session: s,
                              court: b.court,
                              start: b.start,
                              booking: b,
                            ),
                          ),
                    child: const Text('Đổi lịch'),
                  ),
                OutlinedButton(
                  key: const Key('booking-payment'),
                  onPressed: _busy ? null : payment,
                  child: Text(
                    p?.state == DemoPaymentState.pending
                        ? 'Từ chối minh chứng'
                        : 'Thanh toán / Hủy lịch',
                  ),
                ),
              ],
            ),
            TextButton(
              key: const Key('owner-booking-workflow'),
              onPressed: () => ownerOpen(
                context,
                WorkflowDetailScreen(
                  session: s,
                  id: b.id,
                  ownerPresentation: false,
                ),
              ),
              child: const Text('Điểm danh & xử lý hoàn tiền'),
            ),
          ],
        ),
      );
    },
  );
}

class OwnerBookingDirectory extends StatefulWidget {
  const OwnerBookingDirectory({
    super.key,
    required this.session,
    this.facilityId = '',
  });
  final DemoSession session;
  final String facilityId;
  @override
  State<OwnerBookingDirectory> createState() => _OwnerBookingDirectoryState();
}

class _OwnerBookingDirectoryState extends State<OwnerBookingDirectory> {
  String _query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.owner) {
        return const Scaffold(
          body: Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final entries =
          s.managedBookings
              .where(
                (b) =>
                    (widget.facilityId == '*' ||
                        b.facilityId == widget.facilityId) &&
                    '${b.contact} ${b.phone} ${b.id}'.toLowerCase().contains(
                      _query.toLowerCase(),
                    ),
              )
              .toList()
            ..sort((a, b) => b.start.compareTo(a.start));
      return OwnerOperationsScaffold(
        appBar: OwnerBar(
          title: 'Chi tiết đặt sân',
          subtitle: 'Danh sách lịch đặt',
          large: ownerLarge(context),
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            TextField(
              key: const Key('owner-booking-search'),
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tên, số điện thoại hoặc mã lịch',
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const OwnerCard(
                child: Text('Không có lịch phù hợp.', style: _small),
              ),
            for (final b in entries) OwnerBookingCard(session: s, booking: b),
          ],
        ),
      );
    },
  );
}

class OwnerRevenueChart extends StatelessWidget {
  const OwnerRevenueChart({
    super.key,
    required this.values,
    required this.today,
  });
  final Map<DateTime, int> values;
  final DateTime today;
  @override
  Widget build(BuildContext context) {
    final maximum = values.values.fold<int>(0, (a, b) => a > b ? a : b);
    final top = maximum == 0 ? 1000000 : ((maximum / 1000000).ceil() * 1000000);
    return LayoutBuilder(
      builder: (context, box) {
        final large = ownerLarge(context);
        final axis = large ? 65.0 : 38.0;
        final column = values.length <= 7
            ? ((box.maxWidth - axis) / values.length).clamp(32.0, 60.0)
            : 42.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: axis,
              height: 160,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 4; i >= 0; i--)
                    Text(
                      (top * i / 4 / 1000000).toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: SizedBox(
                  width: column * values.length,
                  height: large ? 215 : 192,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 160,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < 5; i++)
                              const Divider(height: 1, color: AppColors.border),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in values.entries)
                            Tooltip(
                              message:
                                  '${bookingDate(e.key)}: ${bookingMoney(e.value)}',
                              child: Semantics(
                                label:
                                    '${bookingDate(e.key)}: ${bookingMoney(e.value)}',
                                child: SizedBox(
                                  width: column,
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 160,
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            width: 18,
                                            height: 160 * e.value / top,
                                            decoration: BoxDecoration(
                                              color: e.key == today
                                                  ? AppColors.green
                                                  : const Color(0xFFE1F2E9),
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(3),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        values.length <= 7
                                            ? (e.key.weekday == 7
                                                  ? 'CN'
                                                  : 'T${e.key.weekday + 1}')
                                            : '${e.key.day}',
                                        style: const TextStyle(
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
