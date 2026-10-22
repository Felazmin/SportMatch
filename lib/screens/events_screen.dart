import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_events.dart';
import '../widgets/design.dart';
import 'auth_screen.dart';
import 'customer_tournament_checkout_screen.dart';
import 'workflow_screen.dart';
import 'tournament_screen.dart';
import '../demo/demo_finance.dart';
import 'event_courts_screen.dart';

AppBar _bar(String title, {List<Widget>? actions}) => AppBar(
  title: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
  actions: actions,
);
String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
Future<bool> _login(BuildContext context, DemoSession session) async {
  if (session.user != null) return true;
  await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => AuthScreen(session: session)),
  );
  return context.mounted && session.user != null;
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    required this.session,
    this.initialKind = DemoEventKind.social,
  });
  final DemoSession session;
  final DemoEventKind initialKind;
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _search = TextEditingController();
  late DemoEventKind _kind = widget.initialKind;
  late final _starts = {
    for (final e in widget.session.availableEvents)
      e.id: e.start(widget.session.now),
  };
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final query = removeDiacritics(_search.text.trim()).toLowerCase();
      for (final e in widget.session.availableEvents) {
        _starts.putIfAbsent(e.id, () => e.start(widget.session.now));
      }
      final events = widget.session.availableEvents.where(
        (e) =>
            e.kind == _kind &&
            removeDiacritics(e.title).toLowerCase().contains(query),
      );
      final managerOccurrences = <(String, DateTime), DemoEvent>{};
      if (widget.session.user != null &&
          widget.session.role != DemoRole.player) {
        for (final ticket in widget.session.managedParticipations) {
          if (demoEvents.any((e) => e.id == ticket.eventId)) {
            managerOccurrences[(ticket.eventId, ticket.start)] = ticket.event;
          }
        }
        for (final block in widget.session.courtBlocks.where(
          (b) => b.eventId.isNotEmpty,
        )) {
          final e = demoEvents.where((e) => e.id == block.eventId).firstOrNull;
          if (e != null) managerOccurrences[(e.id, block.start)] = e;
        }
        managerOccurrences.removeWhere(
          (key, e) =>
              !key.$2.isAfter(widget.session.now) ||
              key.$2 == _starts[e.id] ||
              e.kind != _kind ||
              !removeDiacritics(e.title).toLowerCase().contains(query),
        );
      }
      return Scaffold(
        appBar: _bar(
          'Giao lưu & giải đấu',
          actions: [
            IconButton(
              key: const Key('events-mine'),
              tooltip: 'Vé và lịch của tôi',
              icon: const Icon(Icons.confirmation_number_outlined),
              onPressed: () async {
                if (await _login(context, widget.session) && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyEventsScreen(session: widget.session),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SaveNotice(session: widget.session),
            TextField(
              key: const Key('events-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm giao lưu, giải đấu',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () => setState(() => _search.clear()),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final kind in DemoEventKind.values)
                  ChoiceChip(
                    key: Key('events-kind-${kind.name}'),
                    selected: _kind == kind,
                    label: Text(
                      kind == DemoEventKind.social ? 'Giao lưu' : 'Giải đấu',
                    ),
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Không tìm thấy sự kiện phù hợp.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final occurrence in managerOccurrences.entries)
              ListTile(
                key: Key(
                  'event-cohort-${occurrence.key.$1}-${occurrence.key.$2.toIso8601String()}',
                ),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(occurrence.value.title),
                subtitle: Text(
                  '${bookingDate(occurrence.key.$2)} · ${_time(occurrence.key.$2)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(
                      session: widget.session,
                      event: occurrence.value,
                      start: occurrence.key.$2,
                    ),
                  ),
                ),
              ),
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: Key('event-${e.id}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(
                          session: widget.session,
                          event: e,
                          start: _starts[e.id]!,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: Image.asset(
                            'assets/figma/c0697.png',
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${bookingDate(_starts[e.id]!)} · ${_time(_starts[e.id]!)}',
                              ),
                              const Text(
                                'Cầu lông · Sân Đại Học Công Thương',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${bookingMoney(e.fee)} / ${e.kind == DemoEventKind.social ? 'vé' : 'đội'}',
                                style: const TextStyle(
                                  color: AppColors.darkGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.session.eventCancellation(
                                          e.id,
                                          _starts[e.id]!,
                                        ) !=
                                        null
                                    ? 'Đã hủy buổi này'
                                    : 'Còn ${widget.session.eventSeats(e.id, _starts[e.id]!)} ${e.kind == DemoEventKind.social ? 'chỗ' : 'đội'}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Text(
              'Lịch và vé demo, không tạo đăng ký thực tế.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final registered = session.participations.where(
        (p) => p.eventId == event.id && p.start == start && !p.cancelled,
      );
      final seats = session.eventSeats(event.id, start);
      final cancellation = session.eventCancellation(event.id, start);
      final available =
          session.availableEvents.any((e) => e.id == event.id) &&
          start.isAfter(session.now) &&
          start == event.start(session.now) &&
          cancellation == null &&
          seats > 0;
      return Scaffold(
        appBar: _bar(
          event.kind == DemoEventKind.social
              ? 'Chi tiết giao lưu'
              : 'Chi tiết giải đấu',
        ),
        body: ListView(
          children: [
            Image.asset(
              'assets/figma/c0697.png',
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SaveNotice(session: session),
                  if (cancellation != null)
                    Text(
                      'Đã hủy buổi này: ${cancellation.reason}',
                      key: const Key('event-cancelled'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Info(
                    Icons.calendar_today_outlined,
                    '${bookingDate(start)} · ${_time(start)} – ${_time(event.end(start))}',
                  ),
                  const _Info(
                    Icons.location_on_outlined,
                    '${DemoBooking.venue}\n${DemoBooking.address}',
                  ),
                  if (session.eventCourts(event.id, start).isNotEmpty)
                    _Info(
                      Icons.grid_view_outlined,
                      'Sân ${session.eventCourts(event.id, start).map((b) => b.court).join(', ')}',
                    ),
                  _Info(
                    Icons.people_outline,
                    cancellation != null
                        ? 'Buổi đã hủy'
                        : 'Còn $seats / ${event.capacity} ${event.kind == DemoEventKind.social ? 'chỗ' : 'đội'}',
                  ),
                  _Info(
                    Icons.payments_outlined,
                    '${bookingMoney(event.fee)} / ${event.kind == DemoEventKind.social ? 'vé · Thanh toán tại sân' : 'đội · Thanh toán demo'}',
                  ),
                  const Divider(height: 32),
                  Text(event.description, style: const TextStyle(height: 1.5)),
                  if (session.eventGroupName(event.id) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('Nhóm: ${session.eventGroupName(event.id)}'),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Vé chưa có hồ sơ thanh toán có thể hủy trước giờ bắt đầu. Khi đã mở hồ sơ thanh toán, cần yêu cầu hủy trước ít nhất 24 giờ và chưa check-in. Hoàn tiền được mô phỏng, không chuyển tiền thật.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  if (session.user != null &&
                      session.role != DemoRole.player &&
                      cancellation == null)
                    OutlinedButton.icon(
                      key: const Key('event-allocate-courts'),
                      icon: const Icon(Icons.grid_view_outlined),
                      label: const Text('Phân sân hoạt động'),
                      onPressed: !start.isAfter(session.now)
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventCourtsScreen(
                                  session: session,
                                  event: event,
                                  start: start,
                                ),
                              ),
                            ),
                    ),
                  if (session.role != DemoRole.player &&
                      session.user != null &&
                      demoEvents.any((e) => e.id == event.id))
                    OutlinedButton.icon(
                      key: const Key('event-cancel-occurrence'),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: const Text('Hủy toàn bộ buổi'),
                      onPressed:
                          cancellation != null ||
                              !start.isAfter(session.now) ||
                              !session.eventOccurrenceExists(event.id, start)
                          ? null
                          : () async {
                              final actor = session.user!.identifier;
                              final note = await showDialog<String>(
                                context: context,
                                builder: (_) => const _CancelOccurrenceDialog(),
                              );
                              if (note == null || !context.mounted) return;
                              try {
                                if (session.user?.identifier != actor) {
                                  throw StateError('Tài khoản đã thay đổi.');
                                }
                                session.cancelEventOccurrence(
                                  event.id,
                                  start,
                                  note,
                                );
                                if (!await session.flush()) {
                                  throw StateError(
                                    'Chưa lưu được dữ liệu hủy. Hãy thử lưu lại.',
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$error')),
                                  );
                                }
                              }
                            },
                    ),
                  if (session.role == DemoRole.player)
                    FilledButton.icon(
                      key: const Key('event-register'),
                      icon: const Icon(Icons.confirmation_number_outlined),
                      onPressed: registered.isNotEmpty
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParticipationDetailScreen(
                                  session: session,
                                  participation: registered.first,
                                ),
                              ),
                            )
                          : !available
                          ? null
                          : () async {
                              if (await _login(context, session) &&
                                  context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        event.kind == DemoEventKind.tournament
                                        ? CustomerTournamentRegistrationScreen(
                                            session: session,
                                            event: event,
                                            start: start,
                                          )
                                        : EventRegistrationScreen(
                                            session: session,
                                            event: event,
                                            start: start,
                                          ),
                                  ),
                                );
                              }
                            },
                      label: Text(
                        registered.isNotEmpty
                            ? 'Xem đăng ký của tôi'
                            : !available
                            ? 'Không còn khả dụng'
                            : event.kind == DemoEventKind.social
                            ? 'Đặt vé'
                            : 'Đăng ký đội',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CancelOccurrenceDialog extends StatefulWidget {
  const _CancelOccurrenceDialog();
  @override
  State<_CancelOccurrenceDialog> createState() =>
      _CancelOccurrenceDialogState();
}

class _CancelOccurrenceDialogState extends State<_CancelOccurrenceDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hủy toàn bộ buổi?'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Vé đã thanh toán sẽ chờ hoàn 100%. Không chuyển tiền thật.',
            ),
            TextFormField(
              key: const Key('event-cancel-reason'),
              controller: _reason,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Lý do hủy'),
              validator: (value) => (value?.trim().length ?? 0) < 5
                  ? 'Nhập ít nhất 5 ký tự.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      TextButton(
        key: const Key('event-cancel-confirm'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: const Text('Xác nhận hủy'),
      ),
    ],
  );
}

class EventRegistrationScreen extends StatefulWidget {
  const EventRegistrationScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  @override
  State<EventRegistrationScreen> createState() =>
      _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  late final _contact = TextEditingController(
    text: widget.session.user?.name ?? '',
  );
  late final _phone = TextEditingController(text: widget.session.contactPhone);
  final _team = TextEditingController();
  final _partner = TextEditingController();
  int _quantity = 1;
  bool _saving = false;
  String? _error;
  bool get _tournament => widget.event.kind == DemoEventKind.tournament;
  @override
  void dispose() {
    for (final c in [_contact, _phone, _team, _partner]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    final actor = widget.session.user?.identifier;
    FocusScope.of(context).unfocus();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng ký'),
        content: Text(
          '${widget.event.title}\n${bookingDate(widget.start)} · ${_time(widget.start)}\n${_tournament ? 'Đội ${_team.text.trim()}' : '$_quantity vé'}\nTổng: ${bookingMoney(_quantity * widget.event.fee)}\nChưa thanh toán · Dữ liệu demo',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            key: const Key('event-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final latest = widget.session.availableEvents
          .where((e) => e.id == widget.event.id)
          .firstOrNull;
      if (actor == null ||
          widget.session.user?.identifier != actor ||
          latest == null ||
          latest.fee != widget.event.fee ||
          latest.kind != widget.event.kind ||
          latest.durationMinutes != widget.event.durationMinutes ||
          latest.start(widget.session.now) != widget.start) {
        throw StateError(
          'Tài khoản, lịch hoặc mức phí đã thay đổi. Vui lòng mở lại sự kiện.',
        );
      }
      final p = widget.session.joinEvent(
        eventId: widget.event.id,
        start: widget.start,
        quantity: _quantity,
        contact: _contact.text,
        contactPhone: _phone.text,
        team: _team.text,
        partner: _partner.text,
      );
      await widget.session.flush();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParticipationDetailScreen(
            session: widget.session,
            participation: p,
            justCreated: true,
          ),
        ),
      );
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _name(String label, TextEditingController c, String key) =>
      TextFormField(
        key: Key(key),
        controller: c,
        decoration: InputDecoration(labelText: label, errorMaxLines: 3),
        validator: (value) => (value ?? '').trim().isEmpty
            ? 'Nhập $label'
            : value!.trim().length > 60
            ? 'Tối đa 60 ký tự'
            : null,
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _bar(_tournament ? 'Đăng ký đội' : 'Đặt vé giao lưu'),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.event.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text('${bookingDate(widget.start)} · ${_time(widget.start)}'),
          const SizedBox(height: 24),
          _name('Người liên hệ', _contact, 'event-contact'),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('event-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              errorMaxLines: 3,
            ),
            validator: (value) =>
                RegExp(r'^0[35789]\d{8}$')
                    .hasMatch(DemoSession.normalize(value ?? ''))
                ? null
                : 'Nhập số điện thoại hợp lệ',
          ),
          const SizedBox(height: 16),
          if (_tournament) ...[
            _name('Tên đội', _team, 'event-team'),
            const SizedBox(height: 16),
            _name('Đồng đội', _partner, 'event-partner'),
            const SizedBox(height: 16),
          ] else
            DropdownButtonFormField<int>(
              key: const Key('event-quantity'),
              initialValue: _quantity,
              decoration: const InputDecoration(labelText: 'Số vé'),
              items: [
                for (final n in [1, 2])
                  DropdownMenuItem(value: n, child: Text('$n vé')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _quantity = value!),
            ),
          const SizedBox(height: 24),
          Text(
            'Tổng tiền: ${bookingMoney(_quantity * widget.event.fee)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Text(
            'Thanh toán tại sân · Chưa thanh toán',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              key: const Key('event-error'),
              style: const TextStyle(color: Colors.red),
            ),
          FilledButton(
            key: const Key('event-submit'),
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Đang lưu...' : 'Tiếp tục'),
          ),
        ],
      ),
    ),
  );
}

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final entries = widget.session.participations
          .where(
            (p) =>
                _filter == 'all' ||
                (_filter == 'upcoming' &&
                    !p.cancelled &&
                    widget.session.now.isBefore(p.event.end(p.start))) ||
                (_filter == 'cancelled' && p.cancelled),
          )
          .toList();
      return Scaffold(
        appBar: _bar('Vé & lịch tham gia'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SaveNotice(session: widget.session),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in {
                  'all': 'Tất cả',
                  'upcoming': 'Còn hiệu lực',
                  'cancelled': 'Đã hủy',
                }.entries)
                  ChoiceChip(
                    key: Key('my-events-${entry.key}'),
                    label: Text(entry.value),
                    selected: _filter == entry.key,
                    onSelected: (_) => setState(() => _filter = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Chưa có đăng ký trong mục này.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final p in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    key: Key('my-event-${p.id}'),
                    contentPadding: const EdgeInsets.all(16),
                    leading: Icon(
                      p.event.kind == DemoEventKind.social
                          ? Icons.confirmation_number_outlined
                          : Icons.emoji_events_outlined,
                      color: AppColors.green,
                    ),
                    title: Text(p.event.title),
                    subtitle: Text(
                      '${p.id} · ${bookingDate(p.start)} · ${_time(p.start)}\n${p.state(widget.session.now)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParticipationDetailScreen(
                          session: widget.session,
                          participation: p,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class ParticipationDetailScreen extends StatefulWidget {
  const ParticipationDetailScreen({
    super.key,
    required this.session,
    required this.participation,
    this.justCreated = false,
  });
  final DemoSession session;
  final DemoParticipation participation;
  final bool justCreated;
  @override
  State<ParticipationDetailScreen> createState() =>
      _ParticipationDetailScreenState();
}

class _ParticipationDetailScreenState extends State<ParticipationDetailScreen> {
  bool _busy = false;
  Future<void> _action(bool checkIn) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(checkIn ? 'Mô phỏng check-in?' : 'Hủy đăng ký?'),
        content: Text(
          checkIn
              ? 'Chỉ cập nhật trạng thái trên thiết bị. Không check-in tại sân thực tế.'
              : 'Chỗ đã đăng ký sẽ được trả lại. Vé chưa thanh toán, không phát sinh hoàn tiền.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            key: const Key('participation-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    setState(() => _busy = true);
    final changed = checkIn
        ? widget.session.demoCheckIn(widget.participation)
        : widget.session.cancelParticipation(widget.participation);
    final saved = changed && await widget.session.flush();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !changed
              ? 'Không thể thực hiện ở trạng thái hiện tại.'
              : !saved
              ? 'Đã cập nhật nhưng chưa lưu được. Hãy thử lưu lại.'
              : checkIn
              ? 'Đã check-in demo.'
              : 'Đã hủy đăng ký.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final p = widget.participation;
      final now = widget.session.now;
      if (widget.session.user?.identifier != p.owner) {
        return Scaffold(
          appBar: _bar('Đăng ký'),
          body: const Center(child: Text('Vui lòng đăng nhập đúng tài khoản.')),
        );
      }
      final payment = widget.session.workflowPayment(p.id);
      final valid =
          !p.cancelled &&
          !p.checkedIn &&
          p.attendance == DemoAttendance.pending &&
          (payment == null ||
              (payment.state == DemoPaymentState.approved &&
                  payment.cancellation != DemoCancellationState.requested));
      return Scaffold(
        appBar: _bar('Chi tiết đăng ký'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SaveNotice(session: widget.session),
            if (widget.justCreated)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  widget.session.saveFailed
                      ? 'Đăng ký đang chờ lưu'
                      : 'Đăng ký thành công',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
            Text(
              p.event.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              p.state(now),
              style: const TextStyle(
                color: AppColors.darkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (p.registration != null &&
                !p.cancelled &&
                payment == null &&
                p.start.isAfter(now))
              FilledButton.icon(
                key: const Key('participation-tournament-pay'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerTournamentPaymentScreen(
                      session: widget.session,
                      participation: p,
                    ),
                  ),
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Tiếp tục thanh toán lệ phí demo'),
              ),
            if (p.registration != null &&
                payment?.simulatedGateway == true &&
                !p.cancelled)
              OutlinedButton.icon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerTournamentSuccessScreen(
                      session: widget.session,
                      participation: p,
                    ),
                  ),
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Xem biên nhận demo'),
              ),
            if (valid && now.isBefore(p.event.end(p.start)))
              OutlinedButton.icon(
                key: const Key('participation-qr'),
                icon: const Icon(Icons.qr_code),
                label: const Text('Mã QR vé demo'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Vé ${p.id}'),
                    content: SingleChildScrollView(
                      child: SizedBox(
                        width: 260,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: QrImageView(
                                data: p.qrPayload,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                                semanticsLabel: 'Mã QR vé demo ${p.id}',
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Chỉ dùng trong bản demo trên thiết bị này.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 32),
            _Info(Icons.confirmation_number_outlined, 'Mã đăng ký: ${p.id}'),
            _Info(
              Icons.calendar_today_outlined,
              '${bookingDate(p.start)} · ${_time(p.start)} – ${_time(p.event.end(p.start))}',
            ),
            const _Info(
              Icons.location_on_outlined,
              '${DemoBooking.venue}\n${DemoBooking.address}',
            ),
            _Info(Icons.person_outline, '${p.contact}\n${p.phone}'),
            if (p.event.kind == DemoEventKind.tournament)
              _Info(
                Icons.groups_outlined,
                'Đội: ${p.team}\nĐồng đội: ${p.partner}',
              )
            else
              _Info(Icons.people_outline, '${p.quantity} vé'),
            _Info(
              Icons.payments_outlined,
              '${bookingMoney(p.total)} · ${payment?.label(now) ?? (p.cancelled ? 'Không thu tiền' : 'Chưa thanh toán')}',
            ),
            const Divider(height: 32),
            OutlinedButton.icon(
              key: const Key('participation-finance'),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Thanh toán / hủy / hoàn / khiếu nại'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      WorkflowDetailScreen(session: widget.session, id: p.id),
                ),
              ),
            ),
            if (p.event.kind == DemoEventKind.tournament)
              OutlinedButton.icon(
                key: const Key('participation-matches'),
                icon: const Icon(Icons.scoreboard_outlined),
                label: const Text('Lịch đấu & kết quả'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TournamentScreen(
                      session: widget.session,
                      event: p.event,
                      start: p.start,
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: p.cancelled
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: p.id));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép mã đăng ký.'),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép mã'),
            ),
            if (valid &&
                !now.isBefore(p.start.subtract(const Duration(minutes: 30))) &&
                now.isBefore(p.event.end(p.start)))
              FilledButton.icon(
                key: const Key('participation-check-in'),
                onPressed: _busy ? null : () => _action(true),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Mô phỏng check-in'),
              ),
            if (valid && payment == null && now.isBefore(p.start))
              OutlinedButton.icon(
                key: const Key('participation-cancel'),
                onPressed: _busy ? null : () => _action(false),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Hủy đăng ký'),
              ),
            if (widget.justCreated)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyEventsScreen(session: widget.session),
                  ),
                ),
                child: const Text('Vé & lịch tham gia'),
              ),
            const SizedBox(height: 12),
            const Text(
              'Mã đăng ký chỉ có hiệu lực trong bản demo trên thiết bị này.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      );
    },
  );
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: AppColors.muted),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}

class _SaveNotice extends StatelessWidget {
  const _SaveNotice({required this.session});
  final DemoSession session;
  @override
  Widget build(BuildContext context) => !session.saveFailed
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chưa lưu được dữ liệu. Đừng đóng ứng dụng.',
                style: TextStyle(color: Colors.red),
              ),
              TextButton.icon(
                key: const Key('event-retry-save'),
                onPressed: session.retrySave,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lưu lại'),
              ),
            ],
          ),
        );
}
