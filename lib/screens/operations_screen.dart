import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import '../demo/demo_operations.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';
import 'customers_screen.dart';
import 'workflow_screen.dart';
import 'settlement_screen.dart';
import 'admin_players_screen.dart';
import 'cancellation_policy_screen.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({
    super.key,
    required this.session,
    this.initialView = 'courts',
  });
  final DemoSession session;
  final String initialView;
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  late String _view = widget.initialView;
  bool _busy = false;
  String? _error;
  DateTimeRange? _range;
  Future<void> _perform(VoidCallback action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      action();
      await widget.session.flush();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e is StateError ? e.message : 'Kiểm tra thông tin nhập.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCourts() async {
    final s = widget.session;
    final settings = await showDialog<CourtSettings>(
      context: context,
      builder: (_) => _CourtEditor(
        settings: s.draftCourts ?? s.publishedCourts,
        today: bookingDay(s.now),
      ),
    );
    if (settings != null && mounted) {
      await _perform(() => s.submitCourtSettings(settings));
    }
  }

  Future<void> _review(bool approve) async {
    final note = approve
        ? ''
        : await financeText(context, 'Lý do từ chối', minimum: 5, maximum: 300);
    if (note == null || !mounted) return;
    if (approve &&
        !await financeConfirm(
          context,
          'Duyệt bảng giá?',
          'Áp dụng cho lịch đặt mới; giá của lịch đã đặt được giữ nguyên.',
        )) {
      return;
    }
    if (mounted) {
      await _perform(
        () => widget.session.reviewCourtSettings(approve: approve, note: note),
      );
    }
  }

  Future<void> _editEmployee([DemoEmployee? employee]) async {
    final result = await showDialog<DemoEmployee>(
      context: context,
      builder: (_) => _EmployeeEditor(employee: employee),
    );
    if (result != null && mounted) {
      await _perform(
        () => widget.session.saveEmployee(
          id: employee?.id,
          name: result.name,
          phone: result.phone,
          job: result.job,
          active: result.active,
        ),
      );
    }
  }

  Future<void> _togglePlayer(DemoUser user) async {
    await showPlayerAccess(context, widget.session, user.identifier);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Quản lý vận hành'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final admin = s.role == DemoRole.admin;
      final views = {
        'courts': 'Sân & giá',
        'employees': 'Nhân viên',
        'customers': 'Khách hàng',
        'reports': 'Báo cáo',
        'audit': 'Nhật ký',
        if (admin) 'accounts': 'Tài khoản',
        if (admin) 'moderation': 'Kiểm duyệt',
      };
      // A role switch must not leave a privileged view visible.
      final view = views.containsKey(_view) ? _view : 'courts';
      return Scaffold(
        appBar: financeBar('Quản lý vận hành'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in views.entries)
                  ChoiceChip(
                    key: Key('operations-${e.key}'),
                    label: Text(e.value),
                    selected: view == e.key,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _view = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(
                _error!,
                key: const Key('operations-error'),
                style: const TextStyle(color: Colors.red),
              ),
            if (view == 'courts') ..._courts(s, admin),
            if (view == 'employees') ...[
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('employee-add'),
                  tooltip: 'Thêm nhân viên',
                  icon: const Icon(Icons.person_add_alt),
                  onPressed: _busy ? null : () => _editEmployee(),
                ),
              ),
              if (s.employees.isEmpty) const Text('Chưa có nhân viên.'),
              for (final e in s.employees)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.name),
                  subtitle: Text(
                    '${e.id} · ${e.job}\n${e.phone} · ${e.active ? 'Đang làm' : 'Ngừng làm'}',
                  ),
                  trailing: IconButton(
                    key: Key('employee-edit-${e.id}'),
                    tooltip: 'Sửa hồ sơ',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _busy ? null : () => _editEmployee(e),
                  ),
                ),
            ],
            if (view == 'customers') ..._customers(s),
            if (view == 'reports') ..._reports(s),
            if (view == 'audit') ...[
              if (s.operationAudit.isEmpty)
                const Text('Chưa có thay đổi vận hành.'),
              for (final e in s.operationAudit)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(e.action),
                  subtitle: Text(
                    '${e.actor == '__admin__' ? 'Admin' : 'Chủ sân'} · ${bookingDate(e.created)} ${e.created.hour}:${e.created.minute.toString().padLeft(2, '0')}',
                  ),
                ),
            ],
            if (view == 'accounts') ...[
              ListTile(
                key: const Key('operations-player-directory'),
                leading: const Icon(Icons.manage_search),
                title: const Text('Tìm & xem người dùng'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminPlayersScreen(session: s),
                  ),
                ),
              ),
              for (final u in s.managedUsers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(u.name),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminPlayerDetailScreen(session: s, id: u.identifier),
                    ),
                  ),
                  subtitle: Text(
                    '${u.identifier}\n${s.isBlocked(u.identifier) ? 'Đã khóa' : 'Hoạt động'}',
                  ),
                  trailing: IconButton(
                    key: Key('account-block-${u.identifier}'),
                    tooltip: s.isBlocked(u.identifier)
                        ? 'Mở khóa'
                        : 'Khóa đăng nhập',
                    icon: Icon(
                      s.isBlocked(u.identifier)
                          ? Icons.lock_open
                          : Icons.lock_outline,
                    ),
                    onPressed: _busy ? null : () => _togglePlayer(u),
                  ),
                ),
            ],
            if (view == 'moderation') ...[
              if (s.moderationPosts.isEmpty) const Text('Chưa có bài viết.'),
              for (final p in s.moderationPosts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.message),
                  subtitle: Text(
                    '${p.author} · ${p.id}\n${s.isPostHidden(p.id) ? 'Đã ẩn' : 'Đang hiển thị'}',
                  ),
                  trailing: IconButton(
                    key: Key('post-hide-${p.id}'),
                    tooltip: s.isPostHidden(p.id)
                        ? 'Hiện bài viết'
                        : 'Ẩn bài viết',
                    icon: Icon(
                      s.isPostHidden(p.id)
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: _busy
                        ? null
                        : () async {
                            final hidden = s.isPostHidden(p.id);
                            if (await financeConfirm(
                                  context,
                                  hidden ? 'Hiện bài viết?' : 'Ẩn bài viết?',
                                  'Thay đổi hiển thị trên diễn đàn của thiết bị này.',
                                ) &&
                                mounted) {
                              await _perform(
                                () => s.setPostHidden(p.id, !hidden),
                              );
                            }
                          },
                  ),
                ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Dữ liệu vận hành demo trên thiết bị này. Không đồng bộ máy chủ.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      );
    },
  );
  List<Widget> _courts(DemoSession s, bool admin) {
    final draft = s.draftCourts;
    final labels = {
      'none': 'Chưa có đề nghị',
      'pending': 'Chờ Admin duyệt',
      'approved': 'Đã duyệt',
      'rejected': 'Bị từ chối',
    };
    return [
      const Text(
        DemoBooking.venue,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      const Text('Bảng giá đang áp dụng'),
      Text(s.primaryCancellationPolicy.summary),
      if (admin)
        OutlinedButton.icon(
          key: const Key('primary-policy-edit'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CancellationPolicyScreen(session: s),
            ),
          ),
          icon: const Icon(Icons.rule_outlined),
          label: const Text('Chính sách hủy & hoàn tiền'),
        ),
      for (var i = 0; i < 3; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.sports_tennis),
          title: Text('Sân ${i + 1}'),
          subtitle: Text(
            '${bookingMoney(s.courtRate(i + 1))} / giờ · ${s.publishedCourts.enabled[i] ? 'Mở đặt mới' : 'Đóng đặt mới'}',
          ),
        ),
      const Divider(),
      for (final t in s.publishedCourts.tariffs)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(_tariffLabel(t)),
          subtitle: Text(_tariffPrice(t)),
        ),
      Text(labels[s.courtReviewState]!, key: const Key('court-review-status')),
      if (s.courtReviewNote.isNotEmpty) Text(s.courtReviewNote),
      if (draft != null) ...[
        const SizedBox(height: 12),
        const Text('Đề nghị thay đổi'),
        for (var i = 0; i < 3; i++)
          Text(
            'Sân ${i + 1}: ${bookingMoney(draft.rates[i])} / giờ · ${draft.enabled[i] ? 'Mở' : 'Đóng'}',
          ),
        for (final t in draft.tariffs)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${_tariffLabel(t)} · ${_tariffPrice(t)}'),
          ),
      ],
      const SizedBox(height: 16),
      if (!admin)
        FilledButton.icon(
          key: const Key('court-edit'),
          icon: const Icon(Icons.edit_outlined),
          onPressed: _busy || s.courtReviewState == 'pending'
              ? null
              : _editCourts,
          label: const Text('Đề nghị thay đổi'),
        ),
      if (admin && s.courtReviewState == 'pending') ...[
        FilledButton(
          key: const Key('court-approve'),
          onPressed: _busy ? null : () => _review(true),
          child: const Text('Duyệt thay đổi'),
        ),
        OutlinedButton(
          key: const Key('court-reject'),
          onPressed: _busy ? null : () => _review(false),
          child: const Text('Từ chối'),
        ),
      ],
    ];
  }

  List<Widget> _customers(DemoSession s) {
    final ids = s.managedBookings.map((b) => b.owner).toSet();
    return [
      TextButton.icon(
        key: const Key('operations-customers-directory'),
        icon: const Icon(Icons.people_outline),
        label: const Text('Tìm & xem khách hàng'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CustomersScreen(session: s)),
        ),
      ),
      if (ids.isEmpty) const Text('Chưa có khách đặt sân.'),
      for (final id in ids)
        Builder(
          builder: (_) {
            final rows = s.managedBookings.where((b) => b.owner == id).toList();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(rows.last.contact),
              subtitle: Text(
                '$id\n${rows.length} lịch · ${rows.where((b) => b.cancelled).length} đã hủy',
              ),
            );
          },
        ),
    ];
  }

  List<Widget> _reports(DemoSession s) {
    final bookings = s.managedAttendance
        .where(
          (b) =>
              _range == null ||
              (!bookingDay(b.start).isBefore(_range!.start) &&
                  !bookingDay(b.start).isAfter(_range!.end)),
        )
        .toList();
    final paid = bookings
        .where(
          (b) => s.workflowPayment(b.id)?.state == DemoPaymentState.approved,
        )
        .toList();
    final retained = paid
        .where((b) => !b.cancelled)
        .fold<int>(0, (sum, b) => sum + b.total);
    final pending = paid
        .where(
          (b) => s.workflowPayment(b.id)?.refund == DemoRefundState.pending,
        )
        .fold<int>(
          0,
          (sum, b) => sum + (s.workflowPayment(b.id)!.refundAmount ?? b.total),
        );
    final refunded = paid
        .where(
          (b) => s.workflowPayment(b.id)?.refund == DemoRefundState.recorded,
        )
        .fold<int>(
          0,
          (sum, b) => sum + (s.workflowPayment(b.id)!.refundAmount ?? b.total),
        );
    final fees = paid
        .where((b) => b.cancelled)
        .fold<int>(
          0,
          (sum, b) =>
              sum +
              b.total -
              (s.workflowPayment(b.id)!.refundAmount ?? b.total),
        );
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              _range == null
                  ? 'Tất cả ngày sử dụng sân'
                  : '${bookingDate(_range!.start)} – ${bookingDate(_range!.end)}',
            ),
          ),
          IconButton(
            key: const Key('report-date'),
            tooltip: 'Chọn khoảng ngày',
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDateRange: _range,
              );
              if (range != null && mounted) setState(() => _range = range);
            },
          ),
          if (_range != null)
            IconButton(
              tooltip: 'Xóa bộ lọc',
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _range = null),
            ),
        ],
      ),
      Text(
        '${bookings.length} lịch · ${bookings.where((b) => b.cancelled).length} đã hủy',
      ),
      const SizedBox(height: 16),
      Text('Thanh toán đã duyệt, lịch còn hiệu lực: ${bookingMoney(retained)}'),
      Text('Chờ ghi nhận hoàn: ${bookingMoney(pending)}'),
      Text('Đã ghi nhận hoàn demo: ${bookingMoney(refunded)}'),
      Text('Phần giữ lại theo chính sách hủy: ${bookingMoney(fees)}'),
      const SizedBox(height: 12),
      const Text(
        'Theo ngày sử dụng sân, không phải ngày giao dịch ngân hàng. Chỉ tính thanh toán đã xác nhận, gồm tại sân.',
        style: TextStyle(color: AppColors.muted),
      ),
      const Divider(height: 24),
      ListTile(
        key: const Key('report-settlement'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.receipt_long),
        title: const Text('Đối soát chi tiết'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SettlementScreen(session: s)),
        ),
      ),
      for (final b in bookings)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${b.id} · ${bookingMoney(b.total)}'),
          subtitle: Text(
            '${bookingDate(b.start)} · ${b.cancelled ? 'Đã hủy' : s.workflowPayment(b.id)?.label(s.now) ?? 'Chưa thanh toán'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkflowDetailScreen(session: s, id: b.id),
            ),
          ),
        ),
    ];
  }
}

class _CourtEditor extends StatefulWidget {
  const _CourtEditor({required this.settings, required this.today});
  final CourtSettings settings;
  final DateTime today;
  @override
  State<_CourtEditor> createState() => _CourtEditorState();
}

class _CourtEditorState extends State<_CourtEditor> {
  late final _rates = [
    for (final rate in widget.settings.rates)
      TextEditingController(text: '$rate'),
  ];
  late final _enabled = [...widget.settings.enabled];
  late final _tariffs = [...widget.settings.tariffs];
  String? _error;
  Future<void> _addTariff() async {
    final tariff = await showDialog<CourtTariff>(
      context: context,
      builder: (_) => _TariffEditor(today: widget.today),
    );
    if (tariff == null || !mounted) return;
    try {
      CourtSettings(
        rates: _rates.map((c) => int.tryParse(c.text) ?? 0).toList(),
        enabled: _enabled,
        tariffs: [..._tariffs, tariff],
      );
      setState(() {
        _tariffs.add(tariff);
        _error = null;
      });
    } catch (_) {
      setState(
        () => _error = 'Kiểm tra giá cơ bản; khung giá không được chồng giờ trên cùng sân và nhóm ngày.',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _rates) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sân & bảng giá', style: TextStyle(fontSize: 18)),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              TextField(
                key: Key('court-rate-${i + 1}'),
                controller: _rates[i],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Sân ${i + 1} · đ/giờ',
                  helperText: '10.000–1.000.000, bội số 1.000',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Mở đặt sân ${i + 1}'),
                value: _enabled[i],
                onChanged: (v) => setState(() => _enabled[i] = v),
              ),
            ],
            for (var i = 0; i < _tariffs.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_tariffLabel(_tariffs[i])),
                subtitle: Text(_tariffPrice(_tariffs[i])),
                trailing: IconButton(
                  key: Key('tariff-delete-$i'),
                  tooltip: 'Xóa khung giá',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _tariffs.removeAt(i)),
                ),
              ),
            IconButton(
              key: const Key('tariff-add'),
              tooltip: 'Thêm khung giá',
              onPressed: _tariffs.length >= 36 ? null : _addTariff,
              icon: const Icon(Icons.add_alarm),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        key: const Key('court-submit'),
        onPressed: () {
          try {
            Navigator.pop(
              context,
              CourtSettings(
                rates: _rates.map((c) => int.tryParse(c.text) ?? 0).toList(),
                enabled: _enabled,
                tariffs: _tariffs,
              ),
            );
          } catch (_) {
            setState(() => _error = 'Kiểm tra đơn giá của cả ba sân.');
          }
        },
        child: const Text('Gửi duyệt'),
      ),
    ],
  );
}

String _tariffLabel(CourtTariff t) =>
    'Sân ${t.court} · ${t.weekend ? 'Cuối tuần' : 'Ngày thường'} · ${t.fromHour.toString().padLeft(2, '0')}:00–${t.toHour.toString().padLeft(2, '0')}:00';
String _tariffPrice(CourtTariff t) =>
    '${bookingMoney(t.quotedRate)}/giờ · Từ ${bookingDate(t.effectiveFrom)}'
    '${t.effectiveUntil == null ? '' : ' đến ${bookingDate(t.effectiveUntil!)}'}'
    '${t.surcharge == 0 ? '' : ' · Phụ thu ${bookingMoney(t.surcharge)}'}';

class _TariffEditor extends StatefulWidget {
  const _TariffEditor({required this.today});
  final DateTime today;
  @override
  State<_TariffEditor> createState() => _TariffEditorState();
}

class _TariffEditorState extends State<_TariffEditor> {
  int _court = 1, _from = 6, _to = 12;
  bool _weekend = false;
  late DateTime _effective = widget.today;
  DateTime? _until;
  final _rate = TextEditingController(text: '120000');
  final _surcharge = TextEditingController(text: '0');
  String? _error;
  @override
  void dispose() {
    _rate.dispose();
    _surcharge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Khung giá', style: TextStyle(fontSize: 18)),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              key: const Key('tariff-court'),
              isExpanded: true,
              initialValue: _court,
              decoration: const InputDecoration(labelText: 'Sân'),
              items: [
                for (var i = 1; i <= 3; i++)
                  DropdownMenuItem(value: i, child: Text('Sân $i')),
              ],
              onChanged: (v) => setState(() => _court = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool>(
              key: const Key('tariff-days'),
              isExpanded: true,
              initialValue: _weekend,
              decoration: const InputDecoration(labelText: 'Nhóm ngày'),
              items: const [
                DropdownMenuItem(value: false, child: Text('Thứ 2–6')),
                DropdownMenuItem(value: true, child: Text('Thứ 7, CN')),
              ],
              onChanged: (v) => setState(() => _weekend = v!),
            ),
            for (final begin in [true, false]) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: Key(begin ? 'tariff-from' : 'tariff-to'),
                isExpanded: true,
                initialValue: begin ? _from : _to,
                decoration: InputDecoration(
                  labelText: begin ? 'Từ giờ' : 'Đến giờ',
                ),
                items: [
                  for (var i = begin ? 6 : 7; i <= (begin ? 21 : 22); i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text('${i.toString().padLeft(2, '0')}:00'),
                    ),
                ],
                onChanged: (v) => setState(() {
                  if (begin) {
                    _from = v!;
                  } else {
                    _to = v!;
                  }
                }),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('tariff-rate'),
              controller: _rate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Đơn giá đ/giờ'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tariff-surcharge'),
              controller: _surcharge,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Phụ thu đ/giờ'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const Key('tariff-effective'),
              icon: const Icon(Icons.calendar_month),
              label: Text('Từ ${bookingDate(_effective)}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _effective,
                  firstDate: widget.today,
                  lastDate: widget.today.add(const Duration(days: 365)),
                );
                if (d != null && mounted) {
                  setState(() {
                    _effective = d;
                    if (_until?.isBefore(d) ?? false) _until = null;
                  });
                }
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    key: const Key('tariff-until'),
                    icon: const Icon(Icons.event_busy),
                    label: Text(
                      _until == null
                          ? 'Không giới hạn'
                          : 'Đến ${bookingDate(_until!)}',
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _until ?? _effective,
                        firstDate: _effective,
                        lastDate: widget.today.add(const Duration(days: 365)),
                      );
                      if (d != null && mounted) setState(() => _until = d);
                    },
                  ),
                ),
                if (_until != null)
                  IconButton(
                    tooltip: 'Bỏ ngày hết hạn',
                    onPressed: () => setState(() => _until = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        key: const Key('tariff-save'),
        child: const Text('Thêm'),
        onPressed: () {
          try {
            final t = CourtTariff(
              court: _court,
              weekend: _weekend,
              fromHour: _from,
              toHour: _to,
              rate: int.tryParse(_rate.text) ?? 0,
              effectiveFrom: _effective,
              effectiveUntil: _until,
              surcharge: int.tryParse(_surcharge.text) ?? -1,
            );
            Navigator.pop(context, t);
          } catch (_) {
            setState(
              () => _error =
                  'Kiểm tra giờ và giá 10.000–1.000.000, bội số 1.000.',
            );
          }
        },
      ),
    ],
  );
}

class _EmployeeEditor extends StatefulWidget {
  const _EmployeeEditor({this.employee});
  final DemoEmployee? employee;
  @override
  State<_EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends State<_EmployeeEditor> {
  late final _name = TextEditingController(text: widget.employee?.name ?? '');
  late final _phone = TextEditingController(text: widget.employee?.phone ?? '');
  late String _job = widget.employee?.job ?? 'Lễ tân';
  late bool _active = widget.employee?.active ?? true;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hồ sơ nhân viên'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('employee-name'),
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Họ tên'),
            ),
            TextField(
              key: const Key('employee-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _job,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Công việc'),
              items: [
                for (final job in ['Lễ tân', 'Thu ngân', 'Điều phối'])
                  DropdownMenuItem(value: job, child: Text(job)),
              ],
              onChanged: (v) => setState(() => _job = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đang làm việc'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        key: const Key('employee-save'),
        onPressed: () {
          try {
            Navigator.pop(
              context,
              DemoEmployee.fromJson({
                'id': widget.employee?.id ?? 'NS0001',
                'name': _name.text.trim(),
                'phone': DemoSession.normalize(_phone.text),
                'job': _job,
                'active': _active,
              }),
            );
          } catch (_) {
            setState(() => _error = 'Nhập tên và số điện thoại hợp lệ.');
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
