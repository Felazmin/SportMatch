import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_activities.dart';
import '../demo/demo_events.dart';
import '../venues/venue_catalog.dart';
import 'finance_screen.dart';
import 'owner_management_views.dart';
import 'workflow_screen.dart';
import 'tournament_screen.dart';
import 'events_screen.dart';
import 'event_courts_screen.dart';

Future<void> cancelManagedActivity(
  BuildContext context,
  DemoSession session,
  DemoActivity activity,
) async {
  final actor = session.user?.identifier;
  final role = session.role;
  final note = await financeText(context, 'Lý do hủy hoạt động');
  if (note == null || !context.mounted) return;
  if (!await financeConfirm(
        context,
        'Hủy toàn bộ hoạt động?',
        'Hủy vé và lịch trận. Vé đã thanh toán sẽ chờ hoàn đủ 100%; chưa ghi nhận chuyển tiền.',
      ) ||
      !context.mounted) {
    return;
  }
  if (session.user?.identifier != actor || session.role != role) {
    throw StateError('Tài khoản đã thay đổi.');
  }
  session.cancelActivity(activity.id, activity.revision, note);
  if (!await session.flush()) {
    throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
  }
}

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  String _query = '', _state = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Quản lý hoạt động'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      if (s.role == DemoRole.owner) return OwnerActivitiesView(session: s);
      final activities =
          s.managedActivities
              .where(
                (a) =>
                    (_state == 'all' || a.state == _state) &&
                    venueSearchText('${a.id} ${a.event.title}')
                        .contains(venueSearchText(_query)),
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.event.scheduledStart!.compareTo(b.event.scheduledStart!),
            );
      return Scaffold(
        appBar: financeBar('Quản lý hoạt động'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            OutlinedButton.icon(
              key: const Key('activity-seeded-events'),
              icon: const Icon(Icons.event_outlined),
              label: const Text('Giao lưu & giải đấu có sẵn'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventsScreen(session: s)),
              ),
            ),
            if (s.role == DemoRole.owner)
              FilledButton.icon(
                key: const Key('activity-add'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityFormScreen(session: s),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tạo hoạt động'),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('activity-search'),
              decoration: const InputDecoration(
                labelText: 'Tìm hoạt động',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in const {
                  'all': 'Tất cả',
                  'draft': 'Nháp',
                  'pending': 'Chờ duyệt',
                  'approved': 'Đã duyệt',
                  'rejected': 'Từ chối',
                  'suspended': 'Tạm ngưng',
                  'cancelled': 'Đã hủy',
                }.entries)
                  ChoiceChip(
                    key: Key('activity-filter-${e.key}'),
                    selected: _state == e.key,
                    label: Text(e.value),
                    onSelected: (_) => setState(() => _state = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (activities.isEmpty) const Text('Không có hoạt động phù hợp.'),
            for (final a in activities)
              ListTile(
                key: Key('activity-${a.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(a.event.title),
                subtitle: Text(
                  '${a.id} · ${a.label}\n${bookingDate(a.event.scheduledStart!)} · ${bookingTime(a.event.scheduledStart!)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityDetailScreen(session: s, id: a.id),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class ActivityFormScreen extends StatefulWidget {
  const ActivityFormScreen({super.key, required this.session, this.activity});
  final DemoSession session;
  final DemoActivity? activity;
  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  late final _title = TextEditingController(text: widget.activity?.event.title);
  late final _description = TextEditingController(
    text: widget.activity?.event.description,
  );
  late final _capacity = TextEditingController(
    text: '${widget.activity?.event.capacity ?? 12}',
  );
  late final _fee = TextEditingController(
    text: '${widget.activity?.event.fee ?? 60000}',
  );
  late DemoEventKind _kind =
      widget.activity?.event.kind ?? DemoEventKind.social;
  late DateTime _day = bookingDay(
    widget.activity?.event.scheduledStart ??
        widget.session.now.add(const Duration(days: 2)),
  );
  late int _hour = widget.activity?.event.hour ?? 18;
  late int _duration = widget.activity?.event.durationMinutes ?? 120;
  late String _groupId = widget.activity?.groupId ?? '';
  bool _busy = false, _committed = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_title, _description, _capacity, _fee]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = bookingDay(widget.session.now),
        last = bookingDay(widget.session.now).add(const Duration(days: 30));
    final initial = _day.isBefore(today)
        ? today
        : _day.isAfter(last)
        ? last
        : _day;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: last,
    );
    if (day != null && mounted) setState(() => _day = day);
  }

  Future<void> _save() async {
    if (_busy || _committed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.saveActivity(
        id: widget.activity?.id,
        expectedRevision: widget.activity?.revision,
        title: _title.text,
        kind: _kind,
        start: _day.add(Duration(hours: _hour)),
        durationMinutes: _duration,
        capacity: int.tryParse(_capacity.text) ?? 0,
        fee: int.tryParse(_fee.text) ?? 0,
        description: _description.text,
        groupId: _groupId,
      );
      _committed = true;
      final saved = await widget.session.flush();
      if (mounted && saved) Navigator.pop(context);
    } on StateError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.owner) {
        return Scaffold(
          appBar: financeBar('Hồ sơ hoạt động'),
          body: const Center(child: Text('Chỉ Chủ sân được tạo hoạt động.')),
        );
      }
      final enabled = !_busy && !_committed;
      return Scaffold(
        appBar: financeBar(
          widget.activity == null ? 'Tạo hoạt động' : 'Sửa hoạt động',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            TextField(
              key: const Key('activity-title'),
              controller: _title,
              enabled: enabled,
              minLines: 1,
              maxLines: 3,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Tên hoạt động'),
            ),
            DropdownButtonFormField<DemoEventKind>(
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Loại hoạt động'),
              items: [
                for (final k in DemoEventKind.values)
                  DropdownMenuItem(
                    value: k,
                    child: Text(
                      k == DemoEventKind.social ? 'Giao lưu' : 'Giải đấu',
                    ),
                  ),
              ],
              onChanged: enabled ? (v) => setState(() => _kind = v!) : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(bookingDate(_day))),
                IconButton(
                  key: const Key('activity-date'),
                  tooltip: 'Chọn ngày',
                  onPressed: enabled ? _pickDate : null,
                  icon: const Icon(Icons.calendar_month),
                ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: _hour,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Giờ bắt đầu'),
              items: [
                for (var h = 6; h <= 21; h++)
                  DropdownMenuItem(
                    value: h,
                    child: Text('${h.toString().padLeft(2, '0')}:00'),
                  ),
              ],
              onChanged: enabled ? (v) => setState(() => _hour = v!) : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Thời lượng'),
              items: [
                for (final m in [60, 120, 180, 240])
                  DropdownMenuItem(value: m, child: Text('${m ~/ 60} giờ')),
              ],
              onChanged: enabled ? (v) => setState(() => _duration = v!) : null,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('activity-capacity'),
              controller: _capacity,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _kind == DemoEventKind.social ? 'Số chỗ' : 'Số đội',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('activity-fee'),
              controller: _fee,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Phí (VND)'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('activity-description'),
              controller: _description,
              enabled: enabled,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Nội dung & thể lệ'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('activity-group'),
              isExpanded: true,
              initialValue:
                  _groupId.isEmpty ||
                      s.managedPlayGroups.any(
                        (g) =>
                            g.id == _groupId &&
                            g.state == 'approved' &&
                            g.sport == 'badminton',
                      )
                  ? _groupId
                  : null,
              decoration: const InputDecoration(labelText: 'Nhóm chơi'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Không liên kết'),
                ),
                for (final g in s.managedPlayGroups.where(
                  (g) => g.state == 'approved' && g.sport == 'badminton',
                ))
                  DropdownMenuItem(value: g.id, child: Text(g.id)),
              ],
              onChanged: enabled
                  ? (v) => setState(() => _groupId = v ?? '')
                  : null,
            ),
            if (_groupId.isNotEmpty)
              Text(
                s.managedPlayGroups
                        .where((g) => g.id == _groupId)
                        .firstOrNull
                        ?.name ??
                    _groupId,
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_committed) const Text('Đã tạo hồ sơ trong phiên hiện tại.'),
            FilledButton.icon(
              key: const Key('activity-save'),
              onPressed: enabled ? _save : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu bản nháp'),
            ),
            if (_committed)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Về danh sách'),
              ),
          ],
        ),
      );
    },
  );
}

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _change(DemoActivity a, String state, String title) async {
    if (_busy) return;
    final actor = widget.session.user?.identifier;
    final reason = ['rejected', 'suspended'].contains(state)
        ? await financeText(context, 'Lý do $title')
        : '';
    if (reason == null ||
        !mounted ||
        !await financeConfirm(
          context,
          title,
          state == 'suspended'
              ? 'Dừng đăng ký mới. Vé đã đăng ký vẫn giữ hiệu lực và quy trình thanh toán/hủy hiện tại.'
              : 'Xác nhận $title cho hoạt động ${a.event.title}.',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.session.user?.identifier != actor) {
        throw StateError('Tài khoản đã thay đổi. Mở lại hồ sơ.');
      }
      widget.session.transitionActivity(a.id, state, a.revision, note: reason);
      if (!await widget.session.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
    } on StateError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel(DemoActivity a) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await cancelManagedActivity(context, widget.session, a);
    } on StateError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Hồ sơ hoạt động'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final a = s.managedActivities.where((a) => a.id == widget.id).firstOrNull;
      if (a == null) {
        return Scaffold(
          appBar: financeBar('Hồ sơ hoạt động'),
          body: const Center(child: Text('Không tìm thấy hoạt động.')),
        );
      }
      final e = a.event, start = a.event.scheduledStart!;
      final tickets = s.managedParticipations
          .where((p) => p.eventId == a.id)
          .toList();
      final seats = tickets
          .where((p) => !p.cancelled)
          .fold<int>(0, (sum, p) => sum + p.quantity);
      return Scaffold(
        appBar: financeBar('Hồ sơ hoạt động'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              e.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('${a.id} · ${a.label}'),
            Text(
              e.kind == DemoEventKind.social
                  ? 'Giao lưu cầu lông'
                  : 'Giải cầu lông',
            ),
            Text(
              '${bookingDate(start)} · ${bookingTime(start)}–${bookingTime(e.end(start))}',
            ),
            Text(
              '${bookingMoney(e.fee)} / ${e.kind == DemoEventKind.social ? 'vé' : 'đội'}',
            ),
            Text(
              '$seats / ${e.capacity} ${e.kind == DemoEventKind.social ? 'chỗ đã đăng ký' : 'đội đã đăng ký'}',
            ),
            const Divider(height: 32),
            SelectableText(e.description),
            if (a.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Lý do: ${a.note}'),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            if (['approved', 'suspended'].contains(a.state) &&
                start.isAfter(s.now))
              OutlinedButton.icon(
                key: const Key('activity-allocate-courts'),
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text('Phân sân hoạt động'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventCourtsScreen(
                            session: s,
                            event: e,
                            start: start,
                          ),
                        ),
                      ),
              ),
            if (['approved', 'suspended'].contains(a.state) &&
                start.isAfter(s.now))
              OutlinedButton.icon(
                key: const Key('activity-cancel-all'),
                onPressed: _busy ? null : () => _cancel(a),
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Hủy toàn bộ hoạt động'),
              ),
            if (s.role == DemoRole.owner &&
                ['draft', 'rejected'].contains(a.state))
              OutlinedButton.icon(
                key: const Key('activity-edit'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ActivityFormScreen(session: s, activity: a),
                        ),
                      ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa'),
              ),
            for (final item
                in (s.role == DemoRole.owner
                        ? (a.state == 'draft'
                              ? {'pending': 'Gửi duyệt'}
                              : <String, String>{})
                        : (a.state == 'pending'
                              ? {
                                  'approved': 'Duyệt hoạt động',
                                  'rejected': 'Từ chối',
                                }
                              : a.state == 'approved'
                              ? {'suspended': 'Tạm ngưng đăng ký'}
                              : a.state == 'suspended'
                              ? {'approved': 'Mở lại đăng ký'}
                              : <String, String>{}))
                    .entries)
              FilledButton(
                key: Key('activity-action-${item.key}'),
                onPressed: _busy
                    ? null
                    : () => _change(a, item.key, item.value),
                child: Text(item.value),
              ),
            const Divider(height: 32),
            const Text(
              'Danh sách đăng ký',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (e.kind == DemoEventKind.tournament &&
                ['approved', 'suspended', 'cancelled'].contains(a.state))
              OutlinedButton.icon(
                key: const Key('activity-matches'),
                icon: const Icon(Icons.scoreboard_outlined),
                label: const Text('Lịch đấu & kết quả'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TournamentScreen(session: s, event: e, start: start),
                  ),
                ),
              ),
            if (tickets.isEmpty) const Text('Chưa có đăng ký.'),
            for (final p in tickets)
              ListTile(
                key: Key('activity-ticket-${p.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(p.contact),
                subtitle: Text(
                  '${p.id} · ${p.state(s.now)}\n${bookingMoney(p.total)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkflowDetailScreen(session: s, id: p.id),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
