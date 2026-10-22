import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_operations.dart';
import '../demo/demo_shifts.dart';
import '../demo/demo_events.dart';
import '../demo/demo_activities.dart';
import '../demo/demo_employee_access.dart';
import '../demo/demo_finance.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import '../widgets/venue_image.dart';
import 'owner_management_widgets.dart';
import 'venue_claims_screen.dart';
import 'owner_prices_view.dart';
import 'home_navigation.dart';
import 'shifts_screen.dart';
import 'employee_access_screen.dart';
import 'activities_screen.dart';
import 'events_screen.dart';
import 'facilities_screen.dart';
import 'facility_calendar_screen.dart';
import 'facility_tariffs_screen.dart';
import 'calendar_screen.dart';
import 'operations_screen.dart';
import 'payout_screen.dart';
import 'owner_verification_screen.dart';
import 'demo_account_screens.dart';
import 'management_screen.dart';
import 'auth_screen.dart';
import 'finance_screen.dart';

class OwnerStaffView extends StatefulWidget {
  const OwnerStaffView({super.key, required this.session});
  final DemoSession session;
  @override
  State<OwnerStaffView> createState() => _OwnerStaffViewState();
}

class _OwnerStaffViewState extends State<OwnerStaffView> {
  int _filter = 0;
  String _query = '';
  bool _searching = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!isOwner(s)) return const SizedBox.shrink();
      final today = s.employeeShifts
          .where(
            (v) =>
                bookingDay(v.start) == bookingDay(s.now) &&
                v.state != DemoShiftState.cancelled,
          )
          .toList();
      bool working(String id) => today.any(
        (v) =>
            v.employeeId == id &&
            v.state == DemoShiftState.checkedIn &&
            !s.now.isBefore(v.start) &&
            s.now.isBefore(v.end),
      );
      final employees = s.employees
          .where(
            (e) =>
                (_filter != 1 || working(e.id)) &&
                venueSearchText('${e.name} ${e.phone} ${e.job}')
                    .contains(venueSearchText(_query)),
          )
          .toList();
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: OwnerBar(
          title: 'Nhân viên',
          subtitle: 'Phân quyền & ca làm việc',
          large: ownerLarge(context),
          icon: Icons.person_add_alt_outlined,
          onAction: () => _edit(context, s),
        ),
        bottomNavigationBar: const OwnerNavigation(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            const OwnerVenueContext(),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  '${s.employees.length} nhân viên',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                OwnerBadge(
                  '${s.employees.where((e) => working(e.id)).length} đang làm việc',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ownerChip(
                  'Tất cả',
                  _filter == 0,
                  () => setState(() => _filter = 0),
                  key: const Key('roster-all'),
                ),
                ownerChip(
                  'Đang làm',
                  _filter == 1,
                  () => setState(() => _filter = 1),
                  key: const Key('roster-active'),
                ),
                ownerChip(
                  'Lịch ca',
                  _filter == 2,
                  () => setState(() => _filter = 2),
                  key: const Key('roster-shifts'),
                ),
                IconButton(
                  tooltip: 'Tìm nhân viên',
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    _query = '';
                  }),
                  icon: const Icon(Icons.search, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_searching)
              TextField(
                key: const Key('roster-search'),
                decoration: const InputDecoration(
                  hintText: 'Tên hoặc số điện thoại',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ownerButton(
              '+ Thêm nhân viên',
              () => _edit(context, s),
              key: const Key('roster-edit'),
              filled: true,
            ),
            OwnerHeading(
              _filter == 2 ? 'Lịch ca hôm nay' : 'Nhân viên cơ sở',
              action: 'Phân quyền',
              onTap: () => _permissions(context, s),
            ),
            if (employees.isEmpty)
              const Text(
                'Không có nhân viên phù hợp.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            for (final e in employees)
              OwnerCard(
                key: Key('roster-${e.id}'),
                onTap: () => ownerOpen(
                  context,
                  EmployeeDetailScreen(session: s, id: e.id),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFE5F6ED),
                          child: Text(
                            ownerInitials(e.name),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.darkGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => ownerOpen(
                              context,
                              EmployeeDetailScreen(session: s, id: e.id),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  e.job,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!ownerLarge(context)) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: OwnerBadge(
                              working(e.id)
                                  ? 'Đang làm'
                                  : e.active
                                  ? 'Ngoài ca'
                                  : 'Ngừng làm',
                              warning: !e.active,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (ownerLarge(context))
                      OwnerBadge(
                        working(e.id)
                            ? 'Đang làm'
                            : e.active
                            ? 'Ngoài ca'
                            : 'Ngừng làm',
                        warning: !e.active,
                      ),
                    const SizedBox(height: 8),
                    ownerLine('Liên hệ', e.phone),
                    ownerLine(
                      'Ca hôm nay',
                      today
                              .where((v) => v.employeeId == e.id)
                              .map(
                                (v) =>
                                    '${bookingTime(v.start)} – ${bookingTime(v.end)}',
                              )
                              .join(', ')
                              .isEmpty
                          ? 'Chưa phân ca'
                          : today
                                .where((v) => v.employeeId == e.id)
                                .map(
                                  (v) =>
                                      '${bookingTime(v.start)} – ${bookingTime(v.end)}',
                                )
                                .join(', '),
                    ),
                    const Divider(color: AppColors.border),
                    Text(
                      (s.employeeAccess(e.id)?.permissions ?? {})
                              .map((p) => employeePermissionLabels[p] ?? p)
                              .join(' · ')
                              .isEmpty
                          ? 'Chưa cấp quyền truy cập'
                          : (s
                                .employeeAccess(e.id)!
                                .permissions
                                .map((p) => employeePermissionLabels[p] ?? p)
                                .join(' · ')),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          ownerButton(
                            'Chỉnh sửa',
                            () => _edit(context, s, e),
                            key: Key('roster-edit-${e.id}'),
                          ),
                          ownerButton(
                            'Đổi ca',
                            e.active
                                ? () => ownerOpen(
                                    context,
                                    EmployeeDetailScreen(session: s, id: e.id),
                                  )
                                : null,
                            key: Key('roster-shift-${e.id}'),
                          ),
                        ],
                      ),
                    ),
                    if (_filter == 2)
                      for (final shift in today.where(
                        (v) => v.employeeId == e.id,
                      ))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${bookingTime(shift.start)} – ${bookingTime(shift.end)} · ${shift.label}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => ownerOpen(
                            context,
                            ShiftDetailScreen(session: s, id: shift.id),
                          ),
                        ),
                  ],
                ),
              ),
            if (today.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F6ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ca làm hôm nay · ${today.length} ca\n${today.map((v) => '${s.shiftEmployee(v.employeeId).name}: ${bookingTime(v.start)}–${bookingTime(v.end)}').join('\n')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  void _permissions(BuildContext context, DemoSession s) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final e in s.employees)
                ListTile(
                  title: Text(e.name),
                  subtitle: Text(e.job),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    ownerOpen(
                      this.context,
                      EmployeeAccessScreen(session: s, id: e.id),
                    );
                  },
                ),
            ],
          ),
        ),
      );

  Future<void> _edit(
    BuildContext context,
    DemoSession s, [
    DemoEmployee? employee,
  ]) async {
    final actor = s.user?.identifier;
    final name = TextEditingController(text: employee?.name),
        phone = TextEditingController(text: employee?.phone);
    var job = employee?.job ?? 'Lễ tân', active = employee?.active ?? true;
    var saving = false;
    String? savedId;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            employee == null ? 'Thêm nhân viên' : 'Chỉnh sửa nhân viên',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('owner-employee-name'),
                  controller: name,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                ),
                TextField(
                  key: const Key('owner-employee-phone'),
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: job,
                  isExpanded: true,
                  items: [
                    for (final value in ['Lễ tân', 'Thu ngân', 'Điều phối'])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (v) => job = v!,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đang làm việc'),
                  value: active,
                  onChanged: (v) => setDialog(() => active = v),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const Key('owner-employee-save'),
              onPressed: saving
                  ? null
                  : () async {
                      setDialog(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        if (!isOwner(s) || s.user?.identifier != actor) {
                          throw StateError(
                            'Tài khoản đã thay đổi. Mở lại danh sách nhân viên.',
                          );
                        }
                        s.saveEmployee(
                          id: savedId ?? employee?.id,
                          name: name.text,
                          phone: phone.text,
                          job: job,
                          active: active,
                        );
                        savedId = s.employees
                            .firstWhere(
                              (e) =>
                                  e.phone == DemoSession.normalize(phone.text),
                            )
                            .id;
                        final saved = await s.flush();
                        if (saved && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        } else if (dialogContext.mounted) {
                          setDialog(
                            () => error =
                                'Đã ghi nhận; chưa lưu được xuống thiết bị.',
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialog(
                            () => error = e is StateError
                                ? e.message
                                : 'Kiểm tra họ tên và số điện thoại.',
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialog(() => saving = false);
                        }
                      }
                    },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    phone.dispose();
  }
}

class OwnerActivitiesView extends StatefulWidget {
  const OwnerActivitiesView({
    super.key,
    required this.session,
    this.embedded = false,
  });
  final DemoSession session;
  final bool embedded;
  @override
  State<OwnerActivitiesView> createState() => _OwnerActivitiesViewState();
}

class _OwnerActivitiesViewState extends State<OwnerActivitiesView> {
  int _phase = 0;
  final _cancelling = <String>{};
  Future<void> _cancel(DemoActivity activity) async {
    if (_cancelling.contains(activity.id)) return;
    setState(() => _cancelling.add(activity.id));
    try {
      await cancelManagedActivity(context, widget.session, activity);
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(activity.id));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!isOwner(s)) return const SizedBox.shrink();
      int phase(DemoActivity a) =>
          a.state == 'cancelled' ||
              !a.event.end(a.event.scheduledStart!).isAfter(s.now)
          ? 2
          : a.event.scheduledStart!.isAfter(s.now)
          ? 0
          : 1;
      final all = s.managedActivities;
      final items = all.where((a) => phase(a) == _phase).toList()
        ..sort(
          (a, b) => a.event.scheduledStart!.compareTo(b.event.scheduledStart!),
        );
      void create() => ownerOpen(context, ActivityFormScreen(session: s));
      final body = ListView(
        padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(16),
        children: [
          if (widget.embedded)
            OwnerHeader(
              title: 'Quản lý trận đấu',
              subtitle: 'Trận đấu & phiên social tại sân',
              icon: Icons.emoji_events_outlined,
              onAction: () => ownerOpen(context, EventsScreen(session: s)),
            ),
          Padding(
            padding: widget.embedded
                ? const EdgeInsets.all(16)
                : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FinanceSaveNotice(session: s),
                const OwnerVenueContext(),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ownerChip(
                        '${['Sắp diễn ra', 'Đang chơi', 'Đã kết thúc'][i]} (${all.where((a) => phase(a) == i).length})',
                        _phase == i,
                        () => setState(() => _phase = i),
                        key: Key('owner-match-phase-$i'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: const Key('owner-create-activity'),
                  child: ownerButton(
                    '+ Tạo trận đấu / Social',
                    create,
                    key: const Key('activity-add'),
                    filled: true,
                  ),
                ),
                OwnerHeading(
                  items.every(
                        (a) =>
                            bookingDay(a.event.scheduledStart!) ==
                            bookingDay(s.now),
                      )
                      ? 'Hôm nay · ${bookingDate(s.now)}'
                      : [
                          'Lịch sắp diễn ra',
                          'Trận đấu đang diễn ra',
                          'Lịch đã kết thúc',
                        ][_phase],
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Chưa có trận đấu phù hợp.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                for (final a in items)
                  Builder(
                    builder: (context) {
                      final e = a.event,
                          tickets = s.managedParticipations
                              .where((p) => p.eventId == a.id && !p.cancelled)
                              .toList();
                      final seats = tickets.fold<int>(
                        0,
                        (sum, p) => sum + p.quantity,
                      );
                      final paid = tickets
                          .where(
                            (p) =>
                                s.workflowPayment(p.id)?.state ==
                                DemoPaymentState.approved,
                          )
                          .length;
                      void details() => ownerOpen(
                        context,
                        ActivityDetailScreen(session: s, id: a.id),
                      );
                      return OwnerCard(
                        key: Key('activity-${a.id}'),
                        onTap: details,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  e.kind == DemoEventKind.social
                                      ? Icons.groups_outlined
                                      : Icons.emoji_events_outlined,
                                  color: AppColors.green,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: OwnerBadge(
                                    a.label,
                                    warning: a.state != 'approved',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${bookingDate(e.scheduledStart!)} · ${bookingTime(e.scheduledStart!)} – ${bookingTime(e.end(e.scheduledStart!))}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ownerLine(
                              'Vé tham gia',
                              '${bookingMoney(e.fee)} / ${e.kind == DemoEventKind.social ? 'người' : 'đội'}',
                            ),
                            ownerLine(
                              '$seats / ${e.capacity} ${e.kind == DemoEventKind.social ? 'người' : 'đội'}',
                              'Còn ${(e.capacity - seats).clamp(0, e.capacity)} chỗ',
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: seats / e.capacity,
                                minHeight: 5,
                                backgroundColor: AppColors.border,
                                color: AppColors.green,
                              ),
                            ),
                            const Divider(height: 24, color: AppColors.border),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Người tham gia',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$paid đã thanh toán',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (tickets.isEmpty)
                              const Text(
                                'Chưa có người đăng ký.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            Wrap(
                              spacing: 4,
                              children: [
                                for (final p in tickets.take(4))
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFFE5F6ED),
                                    child: Text(
                                      ownerInitials(p.contact),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9,
                                        color: AppColors.darkGreen,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                ownerButton(
                                  _phase == 1
                                      ? 'Cập nhật kết quả'
                                      : 'Quản lý người chơi',
                                  details,
                                  key: Key('owner-match-players-${a.id}'),
                                  filled: true,
                                ),
                                if (['draft', 'rejected'].contains(a.state))
                                  ownerButton(
                                    'Chỉnh sửa',
                                    () => ownerOpen(
                                      context,
                                      ActivityFormScreen(
                                        session: s,
                                        activity: a,
                                      ),
                                    ),
                                  )
                                else
                                  ownerButton('Chi tiết trận đấu', details),
                                if ([
                                      'approved',
                                      'suspended',
                                    ].contains(a.state) &&
                                    e.scheduledStart!.isAfter(s.now))
                                  TextButton(
                                    key: Key('owner-match-cancel-${a.id}'),
                                    onPressed: _cancelling.contains(a.id)
                                        ? null
                                        : () => _cancel(a),
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFEEEE),
                                      foregroundColor: const Color(0xFFDC4545),
                                    ),
                                    child: const Text(
                                      'Hủy trận',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      );
      if (widget.embedded) return body;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: OwnerBar(
          title: 'Quản lý trận đấu',
          subtitle: 'Trận đấu & phiên social tại sân',
          large: ownerLarge(context),
          icon: Icons.emoji_events_outlined,
          onAction: () => ownerOpen(context, EventsScreen(session: s)),
        ),
        bottomNavigationBar: const OwnerNavigation(),
        body: body,
      );
    },
  );
}

class OwnerFacilitiesView extends StatefulWidget {
  const OwnerFacilitiesView({
    super.key,
    required this.session,
    this.embedded = false,
  });
  final DemoSession session;
  final bool embedded;
  @override
  State<OwnerFacilitiesView> createState() => _OwnerFacilitiesViewState();
}

class _OwnerFacilitiesViewState extends State<OwnerFacilitiesView> {
  int _filter = 0;
  String _query = '';
  bool _searching = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!isOwner(s)) return const SizedBox.shrink();
      final all = s.ownerMapVenues;
      bool active(VenueSummary v) =>
          v.id == demoVenueId ||
          s.managedFacilities.any(
            (f) => f.id == v.id && f.published != null && !f.suspended,
          );
      bool pending(VenueSummary v) =>
          s.managedFacilities.any((f) => f.id == v.id && f.state == 'pending');
      final venues = all
          .where(
            (v) =>
                (_filter == 0 || (_filter == 1 ? active(v) : pending(v))) &&
                venueSearchText('${v.name} ${v.address}')
                    .contains(venueSearchText(_query)),
          )
          .toList();
      final count =
          (all.any((v) => v.id == demoVenueId)
              ? s.publishedCourts.enabled.length
              : 0) +
          s.managedFacilities.fold<int>(
            0,
            (sum, f) => sum + (f.published ?? f.draft).courtCount,
          );
      void add() => ownerOpen(context, FacilityFormScreen(session: s));
      final body = ListView(
        padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(16),
        children: [
          if (widget.embedded)
            OwnerHeader(
              title: 'Sân của tôi',
              subtitle: '${all.length} cơ sở · $count sân',
              onAction: add,
            ),
          Padding(
            padding: widget.embedded
                ? const EdgeInsets.all(16)
                : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FinanceSaveNotice(session: s),
                OutlinedButton.icon(
                  key: const Key('owner-venue-claims'),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Nhận quản lý sân có sẵn'),
                  onPressed: () =>
                      ownerOpen(context, VenueClaimsScreen(session: s)),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ownerChip(
                        '${['Tất cả', 'Hoạt động', 'Chờ duyệt'][i]} (${i == 0 ? all.length : all.where((v) => i == 1 ? active(v) : pending(v)).length})',
                        _filter == i,
                        () => setState(() => _filter = i),
                        key: Key('owner-facilities-filter-$i'),
                      ),
                    IconButton(
                      key: const Key('facility-search-toggle'),
                      tooltip: 'Tìm sân',
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        _query = '';
                      }),
                      icon: const Icon(Icons.search, size: 20),
                    ),
                  ],
                ),
                if (_searching)
                  TextField(
                    key: const Key('facility-search'),
                    decoration: const InputDecoration(
                      hintText: 'Tên hoặc địa chỉ sân',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                const SizedBox(height: 8),
                ownerButton(
                  '+ Thêm sân',
                  add,
                  key: const Key('owner-add-facility'),
                  filled: true,
                ),
                const SizedBox(height: 12),
                for (final v in venues)
                  Builder(
                    builder: (context) {
                      final f = s.managedFacilities
                          .where((f) => f.id == v.id)
                          .firstOrNull;
                      final live = active(v),
                          profile = f?.published ?? f?.draft;
                      final overview = live
                          ? s.dayOverview(s.now, facilityId: f?.id ?? '')
                          : null;
                      void edit() => ownerOpen(
                        context,
                        f == null
                            ? OperationsScreen(session: s)
                            : FacilityFormScreen(session: s, facility: f),
                      );
                      void calendar() => ownerOpen(
                        context,
                        f == null
                            ? CalendarScreen(session: s)
                            : FacilityCalendarScreen(session: s, id: f.id),
                      );
                      return OwnerCard(
                        padding: 0,
                        key: Key('facility-${v.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!live && v.image.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: AspectRatio(
                                  aspectRatio: 2.2,
                                  child: VenueImage(venue: v),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          v.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: OwnerBadge(
                                          live
                                              ? 'Hoạt động'
                                              : f?.label ?? 'Chờ duyệt',
                                          warning: !live,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    v.address,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (live)
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _smallStat(
                                            '${profile?.courtCount ?? s.publishedCourts.enabled.where((v) => v).length} sân',
                                            'Đang hoạt động',
                                          ),
                                          _smallStat(
                                            '${(profile?.openHour ?? 6).toString().padLeft(2, '0')}:00–${profile?.closeHour ?? 22}:00',
                                            'Giờ mở cửa',
                                          ),
                                          _smallStat(
                                            '${overview!.capacity == 0 ? 0 : (overview.reserved * 100 / overview.capacity).round()}%',
                                            'Lấp đầy',
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${profile?.courtCount ?? s.publishedCourts.enabled.length} sân · ${v.sport}${profile == null ? '' : ' · ${profile.courtTypeId.isEmpty ? 'Loại tiêu chuẩn' : s.courtTypeName(profile.courtTypeId)}'}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (live)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        ownerButton(
                                          'Xem lịch sân',
                                          calendar,
                                          key: Key(
                                            'owner-venue-calendar-${v.id}',
                                          ),
                                          filled: true,
                                        ),
                                        ownerButton(
                                          'Chỉnh sửa sân',
                                          edit,
                                          key: Key('owner-venue-${v.id}'),
                                        ),
                                        IconButton(
                                          key: Key(
                                            'owner-venue-prices-${v.id}',
                                          ),
                                          tooltip: 'Bảng giá',
                                          onPressed: () => ownerOpen(
                                            context,
                                            f == null
                                                ? OwnerPricesView(session: s)
                                                : FacilityTariffsScreen(
                                                    session: s,
                                                    id: f.id,
                                                  ),
                                          ),
                                          icon: const Icon(
                                            Icons.payments_outlined,
                                            color: AppColors.green,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            v.priceLabel,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.green,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: ownerButton(
                                            'Xem hồ sơ',
                                            () => ownerOpen(
                                              context,
                                              FacilityDetailScreen(
                                                session: s,
                                                facility: f!,
                                              ),
                                            ),
                                            key: Key('owner-venue-${v.id}'),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (venues.isEmpty)
                  const Text(
                    'Chưa có sân phù hợp.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                const OwnerHeading('Thiết lập cơ sở'),
                OwnerCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.payments_outlined,
                          color: AppColors.green,
                        ),
                        title: const Text(
                          'Bảng giá',
                          style: TextStyle(fontSize: 12),
                        ),
                        subtitle: const Text(
                          'Theo khung giờ',
                          style: TextStyle(fontSize: 10),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            ownerOpen(context, OwnerPricesView(session: s)),
                      ),
                      const Divider(color: AppColors.border),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.person_add_alt_outlined,
                          color: AppColors.green,
                        ),
                        title: const Text(
                          'Nhân viên',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          '${s.employees.length} nhân viên',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                        onTap: () => ownerOpen(
                          context,
                          EmployeeRosterScreen(session: s),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      if (widget.embedded) return body;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: OwnerBar(
          title: 'Sân của tôi',
          subtitle: '${all.length} cơ sở · $count sân',
          large: ownerLarge(context),
          onAction: add,
        ),
        body: body,
        bottomNavigationBar: const OwnerNavigation(),
      );
    },
  );
  Widget _smallStat(String value, String title) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.green,
        ),
      ),
      Text(title, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
    ],
  );
}

class OwnerProfileView extends StatelessWidget {
  const OwnerProfileView({
    super.key,
    required this.session,
    this.embedded = false,
    this.onEdit,
    this.onLogout,
  });
  final DemoSession session;
  final bool embedded;
  final VoidCallback? onEdit, onLogout;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final s = session;
      if (!isOwner(s)) return const SizedBox.shrink();
      final verified = s.ownerVerification?.state == 'verified';
      final body = ListView(
        padding: EdgeInsets.zero,
        children: [
          if (embedded)
            OwnerHeader(
              title: 'Hồ sơ',
              subtitle: 'Tài khoản Chủ sân',
              icon: Icons.tune_outlined,
              onAction: () =>
                  ownerOpen(context, AccountSettingsScreen(session: s)),
            ),
          Container(
            color: AppColors.green,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(
                    s.user!.initials,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.user!.name,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${s.contactPhone.isEmpty ? s.displayIdentifier : s.contactPhone} · TP. Hồ Chí Minh',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFC5EFDC),
                        ),
                      ),
                      const SizedBox(height: 5),
                      OwnerBadge(
                        verified
                            ? 'CHỦ SÂN · ĐÃ XÁC MINH DEMO'
                            : 'CHỦ SÂN · CHƯA XÁC MINH',
                        warning: !verified,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sửa hồ sơ',
                  onPressed: onEdit ?? () => _edit(context),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _stat(
                        Icons.location_on_outlined,
                        '${s.ownerMapVenues.length} cơ sở',
                        'Sân của tôi',
                        () => ownerOpen(context, FacilitiesScreen(session: s)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _stat(
                        Icons.people_outline,
                        '${s.employees.length} người',
                        'Nhân viên',
                        () => ownerOpen(
                          context,
                          EmployeeRosterScreen(session: s),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _stat(
                        Icons.verified_user_outlined,
                        verified ? 'Đã xác minh' : 'Chờ xác minh',
                        'Chủ sân',
                        () => ownerOpen(
                          context,
                          OwnerVerificationScreen(session: s),
                        ),
                      ),
                    ),
                  ],
                ),
                FinanceSaveNotice(session: s),
                const OwnerHeading('Tài khoản của tôi'),
                OwnerCard(
                  child: Column(
                    children: [
                      _row(
                        Icons.person_outline,
                        'Thông tin cá nhân',
                        onEdit ?? () => _edit(context),
                      ),
                      _row(
                        Icons.account_balance_wallet_outlined,
                        'Tài khoản nhận thanh toán',
                        () =>
                            ownerOpen(context, PayoutAccountScreen(session: s)),
                        detail: s.payoutAccount?.bank ?? 'Chưa thiết lập',
                      ),
                      _row(
                        Icons.notifications_outlined,
                        'Thông báo',
                        () => ownerOpen(context, ManagementScreen(session: s)),
                        detail: 'Trong ứng dụng',
                      ),
                      _row(
                        Icons.shield_outlined,
                        'Bảo mật & mật khẩu',
                        () => ownerOpen(
                          context,
                          AccountSettingsScreen(session: s),
                        ),
                      ),
                      _row(
                        Icons.switch_account_outlined,
                        'Chuyển sang Người chơi',
                        () => _leave(context, player: true),
                      ),
                    ],
                  ),
                ),
                const OwnerHeading('Hỗ trợ & thông tin'),
                OwnerCard(
                  child: Column(
                    children: [
                      _row(
                        Icons.headset_mic_outlined,
                        'Trung tâm trợ giúp',
                        () => ownerOpen(context, SupportScreen(session: s)),
                      ),
                      _row(
                        Icons.description_outlined,
                        'Điều khoản dành cho Chủ sân',
                        () => _info(
                          context,
                          'Điều khoản dành cho Chủ sân',
                          'Quản lý thông tin sân, giá và yêu cầu đặt sân chính xác. Các thao tác trong bản demo được ghi nhận trên thiết bị, không tạo giao dịch thực tế.',
                        ),
                      ),
                      _row(
                        Icons.privacy_tip_outlined,
                        'Chính sách quyền riêng tư',
                        () => _info(
                          context,
                          'Chính sách quyền riêng tư',
                          'Dữ liệu tài khoản và lịch demo được lưu mã hóa trên thiết bị. Chỉ sử dụng thông tin dùng thử.',
                        ),
                      ),
                      _row(
                        Icons.info_outline,
                        'Thông tin ứng dụng',
                        () => _info(
                          context,
                          'NVH Sports',
                          'Phiên bản 1.0.0 · Bản demo đồ án',
                        ),
                        detail: 'v1.0.0',
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('account-logout'),
                  onPressed: onLogout ?? () => _leave(context),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEEEE),
                    foregroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Đăng xuất',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      if (embedded) return body;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: OwnerBar(
          title: 'Hồ sơ',
          subtitle: 'Tài khoản Chủ sân',
          large: ownerLarge(context),
          icon: Icons.tune_outlined,
          onAction: () => ownerOpen(context, AccountSettingsScreen(session: s)),
        ),
        body: body,
        bottomNavigationBar: const OwnerNavigation(selected: 4),
      );
    },
  );
  Widget _stat(IconData icon, String value, String label, VoidCallback onTap) =>
      OwnerCard(
        padding: 8,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.green),
              const SizedBox(height: 5),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
  Widget _row(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? detail,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final inline = constraints.maxWidth >= 280 && !ownerLarge(context);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        minTileHeight: 40,
        minVerticalPadding: 2,
        visualDensity: VisualDensity.compact,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFE5F6ED),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppColors.green, size: 18),
        ),
        title: Text(title, style: const TextStyle(fontSize: 11)),
        subtitle: detail == null || inline
            ? null
            : Text(
                detail,
                style: const TextStyle(fontSize: 9, color: AppColors.faint),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (detail != null && inline) ...[
              Text(
                detail,
                style: const TextStyle(fontSize: 9, color: AppColors.faint),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, size: 16, color: AppColors.faint),
          ],
        ),
        onTap: onTap,
      );
    },
  );
  void _info(BuildContext context, String title, String text) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
  Future<void> _edit(BuildContext context) async {
    final actor = session.user!.identifier;
    final field = TextEditingController(text: session.user!.name);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa hồ sơ'),
        content: TextField(
          controller: field,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Họ và tên'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (field.text.trim().isNotEmpty) {
                Navigator.pop(context, field.text.trim());
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (value != null &&
        isOwner(session) &&
        session.user?.identifier == actor) {
      session.updateName(value);
      await session.flush();
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    field.dispose();
  }

  Future<void> _leave(BuildContext context, {bool player = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(player ? 'Chuyển sang Người chơi?' : 'Đăng xuất?'),
        content: Text(
          player
              ? 'Đăng xuất tài khoản Chủ sân để đăng nhập tài khoản Người chơi.'
              : 'Bạn muốn đăng xuất khỏi tài khoản này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    HomeNavigation.returnHome(context);
    session.logout();
    if (player) {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => AuthScreen(session: session)),
      );
    }
  }
}
