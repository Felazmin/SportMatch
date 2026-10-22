import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_shifts.dart';
import '../venues/venue_catalog.dart';
import 'finance_screen.dart';
import 'owner_management_views.dart';
import 'operations_screen.dart';
import 'employee_access_screen.dart';

bool _manager(DemoSession s) => s.user != null && s.role != DemoRole.player;
Widget _denied() => Scaffold(
  appBar: financeBar('Nhân viên'),
  body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
);
String _time(DemoShift s) =>
    '${bookingDate(s.start)} · ${s.start.hour}:00–${s.end.hour}:00';

class EmployeeRosterScreen extends StatefulWidget {
  const EmployeeRosterScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<EmployeeRosterScreen> createState() => _EmployeeRosterScreenState();
}

class _EmployeeRosterScreenState extends State<EmployeeRosterScreen> {
  String _query = '', _filter = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!_manager(s)) return _denied();
      if (s.role == DemoRole.owner) return OwnerStaffView(session: s);
      final items = s.employees
          .where(
            (e) =>
                (_filter == 'all' ||
                    (_filter == 'active' ? e.active : !e.active)) &&
                venueSearchText('${e.name} ${e.phone} ${e.job}')
                    .contains(venueSearchText(_query)),
          )
          .toList();
      return Scaffold(
        appBar: financeBar('Nhân viên & ca làm'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              '${s.employees.length} nhân viên · ${s.employeeShifts.length} ca làm',
            ),
            TextField(
              key: const Key('roster-search'),
              decoration: const InputDecoration(
                labelText: 'Tìm kiếm',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final e in {
                  'all': 'Tất cả',
                  'active': 'Đang làm',
                  'inactive': 'Ngừng làm',
                }.entries)
                  ChoiceChip(
                    key: Key('roster-${e.key}'),
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => setState(() => _filter = e.key),
                  ),
              ],
            ),
            TextButton.icon(
              key: const Key('roster-edit'),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Thêm / sửa hồ sơ'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      OperationsScreen(session: s, initialView: 'employees'),
                ),
              ),
            ),
            if (items.isEmpty) const Text('Không có nhân viên phù hợp.'),
            for (final e in items)
              ListTile(
                key: Key('roster-${e.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(e.name),
                subtitle: Text(
                  '${e.phone} · ${e.job}\n${e.active ? 'Đang làm' : 'Ngừng làm'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmployeeDetailScreen(session: s, id: e.id),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final s = session;
      if (!_manager(s)) return _denied();
      final e = s.employees.where((e) => e.id == id).firstOrNull;
      if (e == null) {
        return Scaffold(
          appBar: financeBar('Nhân viên'),
          body: const Center(child: Text('Hồ sơ không tồn tại.')),
        );
      }
      final shifts = s.employeeShifts
          .where((shift) => shift.employeeId == id)
          .toList();
      return Scaffold(
        appBar: financeBar('Hồ sơ nhân viên'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              e.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(e.phone),
            Text('${e.job} · ${e.active ? 'Đang làm' : 'Ngừng làm'}'),
            TextButton.icon(
              key: const Key('employee-access'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeAccessScreen(session: s, id: id),
                ),
              ),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Tài khoản & quyền'),
            ),
            const Divider(height: 32),
            Text(
              '${shifts.length} ca · ${shifts.where((s) => s.state == DemoShiftState.completed).fold<int>(0, (sum, s) => sum + s.hours)} giờ đã hoàn thành',
            ),
            if (e.active)
              FilledButton.icon(
                key: const Key('shift-add'),
                icon: const Icon(Icons.add),
                label: const Text('Phân ca'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShiftFormScreen(session: s, employeeId: id),
                  ),
                ),
              ),
            if (shifts.isEmpty) const Text('Chưa có ca làm.'),
            for (final shift in shifts.reversed)
              ListTile(
                key: Key('shift-${shift.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(_time(shift)),
                subtitle: Text('${shift.id} · ${shift.label}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShiftDetailScreen(session: s, id: shift.id),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class ShiftFormScreen extends StatefulWidget {
  const ShiftFormScreen({
    super.key,
    required this.session,
    required this.employeeId,
  });
  final DemoSession session;
  final String employeeId;
  @override
  State<ShiftFormScreen> createState() => _ShiftFormScreenState();
}

class _ShiftFormScreenState extends State<ShiftFormScreen> {
  late DateTime _day = bookingDay(widget.session.now)
      .add(const Duration(days: 1));
  int _hour = 8, _hours = 4;
  bool _busy = false, _committed = false;
  String? _error;
  Future<void> _pickDay() async {
    final today = bookingDay(widget.session.now);
    final day = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(today) ? today : _day,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );
    if (mounted && day != null) setState(() => _day = day);
  }

  Future<void> _submit() async {
    if (_busy || _committed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.scheduleEmployeeShift(
        widget.employeeId,
        _day.add(Duration(hours: _hour)),
        _hours,
      );
      _committed = true;
      final saved = await widget.session.flush();
      if (mounted && saved) Navigator.pop(context);
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
      if (!_manager(s)) return _denied();
      final e = s.employees.where((e) => e.id == widget.employeeId).firstOrNull;
      if (e == null || !e.active) {
        return Scaffold(
          appBar: financeBar('Phân ca'),
          body: const Center(child: Text('Nhân viên không còn khả dụng.')),
        );
      }
      return Scaffold(
        appBar: financeBar('Phân ca'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              e.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (_committed) ...[
              const Text('Đã ghi nhận ca. Không cần gửi lại.'),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại'),
              ),
            ] else ...[
              ListTile(
                key: const Key('shift-date'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: Text(bookingDate(_day)),
                onTap: _busy ? null : _pickDay,
              ),
              DropdownButtonFormField<int>(
                key: const Key('shift-hour'),
                initialValue: _hour,
                decoration: const InputDecoration(labelText: 'Giờ bắt đầu'),
                items: [
                  for (var h = 6; h <= 21; h++)
                    DropdownMenuItem(value: h, child: Text('$h:00')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _hour = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('shift-hours'),
                initialValue: _hours,
                decoration: const InputDecoration(labelText: 'Số giờ'),
                items: [
                  for (var h = 1; h <= 12; h++)
                    DropdownMenuItem(value: h, child: Text('$h giờ')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _hours = v!),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('shift-save'),
                onPressed: _busy ? null : _submit,
                child: const Text('Lưu ca làm'),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class ShiftDetailScreen extends StatefulWidget {
  const ShiftDetailScreen({super.key, required this.session, required this.id});
  final DemoSession session;
  final String id;
  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _act(DemoShift old, DemoShiftState next) async {
    if (_busy) return;
    final reason = next == DemoShiftState.cancelled
        ? await financeText(context, 'Lý do hủy ca', minimum: 5, maximum: 300)
        : '';
    if (!mounted || reason == null) return;
    if (!await financeConfirm(
          context,
          'Xác nhận ca làm?',
          'Ghi nhận trạng thái nội bộ bởi quản lý; không phải chấm công GPS.',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.setEmployeeShiftState(
        old.id,
        next,
        expectedRevision: old.revision,
        reason: reason,
      );
      await widget.session.flush();
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
      if (!_manager(s)) return _denied();
      final shift = s.employeeShifts
          .where((s) => s.id == widget.id)
          .firstOrNull;
      if (shift == null) {
        return Scaffold(
          appBar: financeBar('Ca làm'),
          body: const Center(child: Text('Ca làm không tồn tại.')),
        );
      }
      final e = s.shiftEmployee(shift.employeeId);
      final actions = <DemoShiftState, String>{
        if (shift.state == DemoShiftState.scheduled &&
            e.active &&
            !s.now.isBefore(
              shift.start.subtract(const Duration(minutes: 15)),
            ) &&
            s.now.isBefore(shift.end))
          DemoShiftState.checkedIn: 'Ghi nhận vào ca',
        if (shift.state == DemoShiftState.scheduled &&
            !s.now.isBefore(shift.end))
          DemoShiftState.absent: 'Ghi nhận vắng mặt',
        if (shift.state == DemoShiftState.checkedIn &&
            !s.now.isBefore(shift.end))
          DemoShiftState.completed: 'Hoàn thành ca',
        if (shift.state == DemoShiftState.scheduled &&
            s.now.isBefore(shift.start))
          DemoShiftState.cancelled: 'Hủy ca',
      };
      return Scaffold(
        appBar: financeBar('Ca làm'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              e.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(e.job),
            Text(_time(shift)),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('shift-refresh'),
                tooltip: 'Cập nhật thời gian',
                icon: const Icon(Icons.refresh),
                onPressed: _busy ? null : () => setState(() {}),
              ),
            ),
            Text(shift.label),
            if (shift.reason.isNotEmpty) Text('Lý do: ${shift.reason}'),
            const Divider(height: 32),
            for (final a in actions.entries)
              FilledButton.icon(
                key: Key('shift-${a.key.name}'),
                icon: Icon(
                  a.key == DemoShiftState.cancelled
                      ? Icons.cancel_outlined
                      : Icons.fact_check_outlined,
                ),
                label: Text(a.value),
                onPressed: _busy || s.saveFailed
                    ? null
                    : () => _act(shift, a.key),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    },
  );
}
