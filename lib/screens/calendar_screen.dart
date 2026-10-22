import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_calendar.dart';
import '../demo/demo_facilities.dart';
import '../demo/demo_events.dart';
import 'event_courts_screen.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';
import 'workflow_screen.dart';
import 'owner_booking_views.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _day = bookingDay(widget.session.now)
      .add(const Duration(days: 1));
  bool _locking = false;
  String? _error;
  Timer? _timer;
  final _horizontal = ScrollController();
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _horizontal.dispose();
    super.dispose();
  }

  Future<void> _date() async {
    final today = bookingDay(widget.session.now);
    final last = today.add(const Duration(days: 6));
    final result = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: last,
      initialDate: _day.isBefore(today)
          ? today
          : _day.isAfter(last)
          ? last
          : _day,
    );
    if (result != null && mounted) setState(() => _day = result);
  }

  void _edit(int court, DateTime start) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CalendarEditorScreen(
        session: widget.session,
        court: court,
        start: start,
        locking: _locking,
      ),
    ),
  );

  void _scrollCourt(double step) {
    if (!_horizontal.hasClients) return;
    final target = (_horizontal.offset + step)
        .clamp(0.0, _horizontal.position.maxScrollExtent)
        .toDouble();
    _horizontal.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _unblock(DemoCourtBlock block) async {
    if (block.eventId.isNotEmpty) {
      final event =
          demoEvents.where((e) => e.id == block.eventId).firstOrNull ??
          widget.session.managedActivities
              .where((a) => a.id == block.eventId)
              .firstOrNull
              ?.event;
      if (event != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventCourtsScreen(
              session: widget.session,
              event: event,
              start: block.start,
            ),
          ),
        );
      }
      return;
    }
    if (!await financeConfirm(context, 'Mở khóa khung giờ?', block.reason) ||
        !mounted) {
      return;
    }
    try {
      widget.session.unblockCourt(block);
      await widget.session.flush();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user != null && s.role == DemoRole.owner) {
        return OwnerCalendarView(session: s);
      }
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: workflowBar(context, 'Lịch sân'),
          body: const Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final today = bookingDay(s.now),
          last = today.add(const Duration(days: 6));
      final bookings = s.managedBookings
              .where((b) => b.facilityId.isEmpty)
              .toList(),
          blocks = s.courtBlocks.where((b) => b.facilityId.isEmpty).toList();
      final large = MediaQuery.textScalerOf(context).scale(14) > 21;
      final cellWidth = large ? 144.0 : 108.0, cellHeight = large ? 94.0 : 62.0;
      return Scaffold(
        appBar: workflowBar(context, 'Lịch sân'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Row(
              children: [
                IconButton(
                  key: const Key('calendar-prev'),
                  tooltip: 'Ngày trước',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _day.isAfter(today)
                      ? () => setState(
                          () => _day = _day.subtract(const Duration(days: 1)),
                        )
                      : null,
                ),
                Expanded(
                  child: TextButton.icon(
                    key: const Key('calendar-date'),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(bookingDate(_day)),
                    onPressed: _date,
                  ),
                ),
                IconButton(
                  key: const Key('calendar-next'),
                  tooltip: 'Ngày sau',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _day.isBefore(last)
                      ? () => setState(
                          () => _day = _day.add(const Duration(days: 1)),
                        )
                      : null,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('calendar-mode-book'),
                  showCheckmark: false,
                  avatar: const Icon(Icons.add),
                  label: const Text('Đặt sân'),
                  selected: !_locking,
                  onSelected: (_) => setState(() => _locking = false),
                ),
                ChoiceChip(
                  key: const Key('calendar-mode-block'),
                  showCheckmark: false,
                  avatar: const Icon(Icons.lock_outline),
                  label: const Text('Khóa giờ'),
                  selected: _locking,
                  onSelected: (_) => setState(() => _locking = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: _horizontal,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    key: const Key('calendar-scroll-left'),
                    tooltip: 'Sân bên trái',
                    icon: const Icon(Icons.arrow_back),
                    onPressed:
                        !_horizontal.hasClients || _horizontal.offset <= 0
                        ? null
                        : () => _scrollCourt(-cellWidth),
                  ),
                  IconButton(
                    key: const Key('calendar-scroll-right'),
                    tooltip: 'Sân bên phải',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed:
                        _horizontal.hasClients &&
                            _horizontal.offset >=
                                _horizontal.position.maxScrollExtent
                        ? null
                        : () => _scrollCourt(cellWidth),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: FixedColumnWidth(cellWidth),
                border: TableBorder.all(color: AppColors.border),
                children: [
                  TableRow(
                    children: [
                      for (final title in ['Giờ', 'Sân 1', 'Sân 2', 'Sân 3'])
                        SizedBox(
                          height: cellHeight,
                          child: Center(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var hour = 6; hour < 22; hour++)
                    TableRow(
                      children: [
                        SizedBox(
                          height: cellHeight,
                          child: Center(
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                        ),
                        for (var court = 1; court <= 3; court++)
                          Builder(
                            builder: (context) {
                              final start = _day.add(Duration(hours: hour));
                              final b = bookings
                                  .where(
                                    (b) =>
                                        !b.cancelled &&
                                        b.court == court &&
                                        !start.isBefore(b.start) &&
                                        start.isBefore(b.end),
                                  )
                                  .firstOrNull;
                              final block = blocks
                                  .where(
                                    (b) =>
                                        b.court == court &&
                                        !start.isBefore(b.start) &&
                                        start.isBefore(b.end),
                                  )
                                  .firstOrNull;
                              final free = s.available(court, start, 1);
                              final label =
                                  b?.id ??
                                  (block != null
                                      ? 'Đã khóa'
                                      : free
                                      ? 'Trống'
                                      : !start.isAfter(s.now)
                                      ? 'Qua giờ'
                                      : 'Đóng sân');
                              final color = b != null
                                  ? const Color(0xFFE3EFFC)
                                  : block != null
                                  ? const Color(0xFFFFE8E8)
                                  : free
                                  ? const Color(0xFFE5F5EB)
                                  : const Color(0xFFEAEDF0);
                              return SizedBox(
                                height: cellHeight,
                                child: Material(
                                  color: color,
                                  child: Tooltip(
                                    message:
                                        'Sân $court · ${bookingDate(start)} ${bookingTime(start)} · $label',
                                    child: InkWell(
                                      key: Key('calendar-slot-$court-$hour'),
                                      onTap: b != null
                                          ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    WorkflowDetailScreen(
                                                      session: s,
                                                      id: b.id,
                                                    ),
                                              ),
                                            )
                                          : block != null
                                          ? () => _unblock(block)
                                          : free
                                          ? () => _edit(court, start)
                                          : null,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: b != null
                                                  ? const Color(0xFF215A86)
                                                  : block != null
                                                  ? const Color(0xFFA32232)
                                                  : AppColors.ink,
                                              fontSize: 13,
                                            ),
                                          ),
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
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const Divider(height: 32),
            const Text(
              'Khung giờ đã khóa',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (blocks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Chưa có khung giờ khóa.'),
              ),
            for (final b in blocks.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Sân ${b.court} · ${bookingDate(b.start)} ${bookingTime(b.start)}–${bookingTime(b.end)}',
                ),
                subtitle: Text(b.reason),
                trailing: IconButton(
                  key: Key('calendar-unblock-${b.id}'),
                  tooltip: b.eventId.isEmpty ? 'Mở khóa' : 'Phân sân hoạt động',
                  icon: const Icon(Icons.lock_open),
                  onPressed: () => _unblock(b),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class CalendarEditorScreen extends StatefulWidget {
  const CalendarEditorScreen({
    super.key,
    required this.session,
    required this.court,
    required this.start,
    this.locking = false,
    this.booking,
    this.facilityId = '',
  });
  final DemoSession session;
  final int court;
  final DateTime start;
  final bool locking;
  final DemoBooking? booking;
  final String facilityId;
  @override
  State<CalendarEditorScreen> createState() => _CalendarEditorScreenState();
}

class _CalendarEditorScreenState extends State<CalendarEditorScreen> {
  late int _court = widget.court,
      _hours = widget.booking?.hours ?? 1,
      _hour = widget.start.hour;
  late final int _revision;
  String get _facilityId => widget.booking?.facilityId ?? widget.facilityId;
  FacilityProfile? get _facility => widget.session.publicFacilities
      .where((f) => f.id == _facilityId)
      .firstOrNull
      ?.profile;
  late List<int> _quotes = widget.booking != null
      ? widget.booking!.hourlyRates ??
            List.filled(widget.booking!.hours, widget.booking!.rate)
      : widget.locking
      ? [0]
      : widget.session.bookingRates(
          _court,
          widget.start,
          _hours,
          facilityId: _facilityId,
        );
  int get _quote => _quotes.first;
  void _refreshQuote() {
    if (!widget.locking && widget.booking == null) {
      _quotes = widget.session.bookingRates(
        _court,
        _day.add(Duration(hours: _hour)),
        _hours,
        facilityId: _facilityId,
      );
    }
  }

  late DateTime _day = bookingDay(widget.start);
  String? _customer;
  final _contact = TextEditingController(),
      _phone = TextEditingController(),
      _reason = TextEditingController();
  bool _busy = false, _committed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _revision = widget.booking?.revision ?? 0;
    if (!widget.locking &&
        widget.booking == null &&
        widget.session.initialized &&
        widget.session.user != null &&
        widget.session.role != DemoRole.player) {
      final customers = widget.session.calendarCustomers;
      if (customers.isNotEmpty) {
        _customer = customers.first.identifier;
        _contact.text = customers.first.name;
        _phone.text = customers.first.identifier.startsWith('0')
            ? customers.first.identifier
            : '';
      }
    }
  }

  @override
  void dispose() {
    _contact.dispose();
    _phone.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _date() async {
    final today = bookingDay(widget.session.now),
        last = bookingDay(widget.session.now).add(const Duration(days: 6));
    final d = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: last,
      initialDate: _day.isBefore(today)
          ? today
          : _day.isAfter(last)
          ? last
          : _day,
    );
    if (d != null && mounted) {
      setState(() {
        _day = d;
        _refreshQuote();
      });
    }
  }

  Future<void> _save() async {
    if (_busy || _committed) return;
    final actor = widget.session.user?.identifier;
    if (!await financeConfirm(
          context,
          widget.booking != null
              ? 'Xác nhận đổi lịch?'
              : widget.locking
              ? 'Khóa khung giờ?'
              : 'Xác nhận đặt sân thủ công?',
          widget.booking != null
              ? 'Giữ nguyên mã lịch, thời lượng và số tiền đã chốt. Khung giờ cũ sẽ được trả lại.'
              : 'Chỉ cập nhật lịch demo trên thiết bị.',
        ) ||
        !mounted ||
        _busy ||
        _committed) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = widget.session, start = _day.add(Duration(hours: _hour));
      if (actor != s.user?.identifier) {
        throw StateError('Tài khoản đã thay đổi. Mở lại lịch sân.');
      }
      if (widget.booking != null) {
        s.rescheduleBooking(
          widget.booking!,
          court: _court,
          start: start,
          expectedRevision: _revision,
        );
      } else if (widget.locking) {
        s.blockCourt(
          court: _court,
          start: start,
          hours: _hours,
          reason: _reason.text,
          facilityId: _facilityId,
        );
      } else {
        if (_customer == null) throw StateError('Chọn tài khoản khách hàng.');
        s.manualReservation(
          customer: _customer!,
          court: _court,
          start: start,
          hours: _hours,
          contact: _contact.text,
          contactPhone: _phone.text,
          quotedRate: _quote,
          quotedRates: _quotes,
          facilityId: _facilityId,
        );
      }
      setState(() => _committed = true);
      await s.flush();
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
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: workflowBar(context, 'Lịch sân'),
          body: const Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final customers = s.calendarCustomers;
      final profile = _facility;
      if (widget.booking == null && _facilityId.isNotEmpty && profile == null) {
        return Scaffold(
          appBar: workflowBar(context, 'Lịch sân'),
          body: const Center(child: Text('Cơ sở không còn khả dụng.')),
        );
      }
      return Scaffold(
        appBar: workflowBar(
          context,
          widget.booking != null
              ? 'Đổi lịch ${widget.booking!.id}'
              : widget.locking
              ? 'Khóa khung giờ'
              : 'Đặt sân thủ công',
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            if (_committed) ...[
              Text(
                s.saveFailed
                    ? 'Đã cập nhật, đang chờ lưu.'
                    : 'Đã cập nhật lịch sân.',
                key: const Key('calendar-success'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              FilledButton(
                key: const Key('calendar-close'),
                onPressed: _busy
                    ? null
                    : () async {
                        if (s.saveFailed &&
                            !await financeConfirm(
                              context,
                              'Rời khi chưa lưu?',
                              'Đóng app có thể mất thay đổi chưa lưu.',
                            )) {
                          return;
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Về lịch sân'),
              ),
            ] else ...[
              if (widget.booking != null) ...[
                Text('Khách: ${widget.booking!.contact}'),
                Text(
                  'Số tiền giữ nguyên: ${bookingMoney(widget.booking!.total)}',
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<int>(
                key: const Key('calendar-court'),
                initialValue: _court,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sân'),
                items: [
                  for (
                    var i = 1;
                    i <=
                        (widget.booking?.venueCourtCount ??
                            profile?.courtCount ??
                            3);
                    i++
                  )
                    DropdownMenuItem(value: i, child: Text('Sân $i')),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _court = v!;
                        _refreshQuote();
                      }),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('calendar-editor-date'),
                onPressed: _busy ? null : _date,
                icon: const Icon(Icons.calendar_month),
                label: Text(bookingDate(_day)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('calendar-hour'),
                initialValue: _hour,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Giờ bắt đầu'),
                items: [
                  for (
                    var i =
                        widget.booking?.venueOpenHour ?? profile?.openHour ?? 6;
                    i <
                        (widget.booking?.venueCloseHour ??
                            profile?.closeHour ??
                            22);
                    i++
                  )
                    DropdownMenuItem(
                      value: i,
                      child: Text('${i.toString().padLeft(2, '0')}:00'),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _hour = v!;
                        _refreshQuote();
                      }),
              ),
              const SizedBox(height: 16),
              if (widget.booking == null)
                DropdownButtonFormField<int>(
                  key: const Key('calendar-hours'),
                  initialValue: _hours,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Thời lượng'),
                  items: [
                    for (var i = 1; i <= (widget.locking ? 16 : 3); i++)
                      DropdownMenuItem(value: i, child: Text('$i giờ')),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _hours = v!;
                          _refreshQuote();
                        }),
                ),
              if (widget.locking) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const Key('calendar-reason'),
                  controller: _reason,
                  enabled: !_busy,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Lý do khóa'),
                ),
              ],
              if (!widget.locking && widget.booking == null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('calendar-customer'),
                  initialValue: customers.any((u) => u.identifier == _customer)
                      ? _customer
                      : null,
                  isExpanded: true,
                  itemHeight: null,
                  selectedItemBuilder: (context) => [
                    for (final u in customers)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Tài khoản khách hàng',
                  ),
                  items: [
                    for (final u in customers)
                      DropdownMenuItem(
                        value: u.identifier,
                        child: Text(
                          '${u.name} · ${u.identifier}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _customer = v;
                          final u = customers.firstWhere(
                            (u) => u.identifier == v,
                          );
                          _contact.text = u.name;
                          _phone.text = u.identifier.startsWith('0')
                              ? u.identifier
                              : '';
                        }),
                ),
                const SizedBox(height: 16),
                if (_customer != null)
                  Text(
                    _customer!,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                TextField(
                  key: const Key('calendar-contact'),
                  controller: _contact,
                  enabled: !_busy,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Người liên hệ'),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('calendar-phone'),
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _quotes.length; i++)
                  Text(
                    '${bookingTime(_day.add(Duration(hours: _hour + i)))}: ${bookingMoney(_quotes[i])}/giờ',
                  ),
                Text(
                  'Tổng: ${bookingMoney(_quotes.fold<int>(0, (a, b) => a + b))}',
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('calendar-error'),
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('calendar-save'),
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_busy ? 'Đang lưu...' : 'Xác nhận'),
              ),
            ],
          ],
        ),
      );
    },
  );
}
