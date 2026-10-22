import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_employee_access.dart';
import '../demo/demo_finance.dart';
import 'finance_screen.dart';

class EmployeeAccessScreen extends StatefulWidget {
  const EmployeeAccessScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  State<EmployeeAccessScreen> createState() => _EmployeeAccessScreenState();
}

class _EmployeeAccessScreenState extends State<EmployeeAccessScreen> {
  final _secret = TextEditingController(), _manager = TextEditingController();
  late Set<String> _permissions;
  late Set<String> _facilityIds;
  late int _revision;
  String? _error;
  late final String? _actor;
  bool _busy = false, _pendingSave = false;
  bool get _locked => _busy || _pendingSave;
  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _actor = s.user?.identifier;
    final a = s.user != null && s.role != DemoRole.player
        ? s.employeeAccess(widget.id)
        : null;
    _permissions = {...?a?.permissions};
    _facilityIds = {...?a?.facilityIds};
    if (_facilityIds.isEmpty) _facilityIds.add('*');
    _revision = a?.revision ?? 0;
  }

  @override
  void dispose() {
    _secret.dispose();
    _manager.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _actor == null || widget.session.user?.identifier != _actor) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_pendingSave) {
        if (widget.session.employeeAccess(widget.id)?.revision != _revision) {
          throw StateError(
            'Quyền đã thay đổi ở màn khác. Vui lòng mở lại màn cấp quyền.',
          );
        }
        await widget.session.retrySave();
      } else {
        widget.session.configureEmployeeAccess(
          widget.id,
          _permissions,
          _secret.text,
          expectedRevision: _revision,
          managerPassword: _manager.text,
          facilityIds: _facilityIds,
        );
        _revision++;
        _secret.clear();
        _manager.clear();
        _pendingSave = true;
      }
      final saved = await widget.session.flush();
      if (!mounted || widget.session.user?.identifier != _actor) return;
      if (!saved) {
        throw StateError(
          'Quyền đã cập nhật nhưng chưa lưu được. Hãy thử lưu lại.',
        );
      }
      if (mounted) {
        setState(() {
          _error = null;
          _pendingSave = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu quyền nhân viên.')),
        );
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
      if (_actor == null ||
          s.user?.identifier != _actor ||
          s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Quyền nhân viên'),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Cần tài khoản quản lý ban đầu. Vui lòng mở lại màn cấp quyền.',
              ),
            ),
          ),
        );
      }
      final e = s.shiftEmployee(widget.id);
      return Scaffold(
        appBar: financeBar('Quyền nhân viên'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              e.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '${e.id} · ${e.phone} · ${e.active ? 'Đang làm' : 'Ngừng làm'}',
            ),
            const SizedBox(height: 16),
            for (final p in employeePermissionLabels.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                key: Key('employee-permission-${p.key}'),
                title: Text(p.value),
                value: _permissions.contains(p.key),
                onChanged: !e.active || _locked
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _permissions.add(p.key);
                          if (p.key != 'schedule') _permissions.add('schedule');
                        } else {
                          _permissions.remove(p.key);
                          if (p.key == 'schedule') _permissions.clear();
                        }
                      }),
              ),
            TextField(
              key: const Key('employee-new-password'),
              enabled: !_locked,
              controller: _secret,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                helperText: 'Để trống nếu giữ mật khẩu cũ',
                helperMaxLines: 2,
              ),
            ),
            const Divider(height: 32),
            const Text(
              'Cơ sở được giao',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            CheckboxListTile(
              key: const Key('employee-scope-all'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Tất cả cơ sở'),
              value: _facilityIds.contains('*'),
              onChanged: !e.active || _locked
                  ? null
                  : (v) =>
                        setState(() => _facilityIds = v == true ? {'*'} : {''}),
            ),
            for (final entry in <String, String>{
              '': DemoBooking.venue,
              for (final f in s.managedFacilities.where(
                (f) => f.published != null,
              ))
                f.id: f.published!.name,
            }.entries)
              CheckboxListTile(
                key: Key(
                  'employee-scope-${entry.key.isEmpty ? 'primary' : entry.key}',
                ),
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value:
                    _facilityIds.contains('*') ||
                    _facilityIds.contains(entry.key),
                onChanged: !e.active || _locked || _facilityIds.contains('*')
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _facilityIds.add(entry.key);
                        } else {
                          _facilityIds.remove(entry.key);
                        }
                      }),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('employee-manager-password'),
              enabled: !_locked,
              controller: _manager,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu quản lý'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton.icon(
              key: const Key('employee-access-save'),
              onPressed: e.active && !_busy ? _save : null,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                _busy
                    ? 'Đang lưu...'
                    : _pendingSave
                    ? 'Thử lưu lại'
                    : 'Lưu quyền',
              ),
            ),
          ],
        ),
      );
    },
  );
}

class EmployeePortalScreen extends StatefulWidget {
  const EmployeePortalScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<EmployeePortalScreen> createState() => _EmployeePortalScreenState();
}

class _EmployeePortalScreenState extends State<EmployeePortalScreen> {
  final _identifier = TextEditingController(),
      _password = TextEditingController();
  String? _error;
  bool _busy = false, _pendingSave = false;
  String? _pendingUser, _pendingEmployee;
  bool get _locked => _busy || _pendingSave;
  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_locked) return;
    if (!widget.session.loginEmployee(_identifier.text, _password.text)) {
      setState(
        () => _error =
            'Tài khoản hoặc mật khẩu chưa đúng, bị ngừng hoặc đang tạm khóa.',
      );
      return;
    }
    _password.clear();
    setState(() => _error = null);
    await _persist();
  }

  bool _sameSession(String? user, String? employee) =>
      widget.session.user?.identifier == user &&
      widget.session.activeEmployee?.id == employee;

  Future<void> _persist({bool retry = false}) async {
    if (retry && !_sameSession(_pendingUser, _pendingEmployee)) {
      setState(() {
        _pendingSave = false;
        _error = 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại không gian nhân viên.';
      });
      return;
    }
    final user = widget.session.user?.identifier;
    final employee = widget.session.activeEmployee?.id;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (retry) await widget.session.retrySave();
    final saved = await widget.session.flush();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!_sameSession(user, employee)) {
        _pendingSave = false;
        _error = 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại không gian nhân viên.';
      } else {
        _pendingSave = !saved;
        _pendingUser = user;
        _pendingEmployee = employee;
        _error = saved ? null : 'Thay đổi chưa lưu được. Hãy thử lưu lại, không thực hiện lại thao tác.';
      }
    });
  }

  Future<void> _logout() async {
    if (_busy) return;
    widget.session.logout();
    await _persist();
  }

  Future<void> _action(DemoWorkflowRecord r, {DemoAttendance? next}) async {
    if (_locked) return;
    setState(() => _busy = true);
    final employeeId = widget.session.activeEmployee?.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          next == null
              ? 'Xác nhận thu tại sân?'
              : '${widget.session.attendanceLabel(next)}?',
        ),
        content: Text(
          '${r.id}\n${r.title}\n${bookingDate(r.start)} · ${bookingMoney(r.total)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            key: const Key('employee-action-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }
    try {
      if (widget.session.activeEmployee?.id != employeeId) {
        throw StateError('Phiên đăng nhập đã thay đổi.');
      }
      if (next == null) {
        widget.session.employeeConfirmPayment(r.id);
      } else {
        widget.session.employeeSetAttendance(r.id, next, r.attendance);
      }
      await _persist();
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
      final s = widget.session, e = s.initialized ? s.activeEmployee : null;
      return Scaffold(
        appBar: financeBar(
          e == null ? 'Đăng nhập nhân viên' : 'Không gian nhân viên',
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_pendingSave)
              TextButton.icon(
                key: const Key('employee-retry-save'),
                onPressed: _busy ? null : () => _persist(retry: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lưu lại'),
              ),
            if (e == null) ...[
              TextField(
                key: const Key('employee-login-id'),
                enabled: !_locked,
                controller: _identifier,
                decoration: const InputDecoration(
                  labelText: 'Mã nhân viên / Số điện thoại',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('employee-login-password'),
                enabled: !_locked,
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('employee-login-submit'),
                onPressed: s.initialized && !_locked ? _login : null,
                child: const Text('Đăng nhập'),
              ),
            ] else ...[
              Text(
                e.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('${e.id} · ${e.job}'),
              TextButton.icon(
                key: const Key('employee-logout'),
                onPressed: _busy ? null : _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
              const Divider(),
              const Text(
                'Ca của tôi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              if (s.ownEmployeeShifts.isEmpty) const Text('Chưa có ca làm.'),
              for (final shift in s.ownEmployeeShifts)
                Text(
                  '${bookingDate(shift.start)} · ${shift.start.hour}:00–${shift.end.hour}:00 · ${shift.label}',
                ),
              const Divider(),
              const Text(
                'Lịch sân và vé',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              if (s.employeeCan('schedule')) ...[
                if (s.employeeSchedule.isEmpty)
                  const Text('Chưa có lịch trong 7 ngày tới.'),
                for (final r in s.employeeSchedule)
                  Padding(
                    key: Key('employee-record-${r.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.id} · ${r.title}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${bookingDate(r.start)} · ${r.start.hour}:00–${r.end.hour}:00',
                        ),
                        Text(
                          r.cancelled
                              ? 'Đã hủy'
                              : s.attendanceLabel(r.attendance),
                        ),
                        Text(
                          s.employeeRecordPaid(r.id)
                              ? 'Đã thanh toán'
                              : 'Chưa thanh toán',
                        ),
                        if (!r.cancelled)
                          Wrap(
                            spacing: 6,
                            children: [
                              if (s.employeeCan('onsite') &&
                                  r.id.startsWith('NVH') &&
                                  !s.employeeRecordPaid(r.id))
                                TextButton.icon(
                                  key: Key('employee-pay-${r.id}'),
                                  onPressed: _locked ? null : () => _action(r),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text('Thu tại sân'),
                                ),
                              if (s.employeeCan('attendance') &&
                                  s.employeeRecordPaid(r.id) &&
                                  ![
                                    DemoAttendance.absent,
                                    DemoAttendance.completed,
                                  ].contains(r.attendance)) ...[
                                if (r.attendance == DemoAttendance.pending)
                                  TextButton.icon(
                                    key: Key('employee-checkin-${r.id}'),
                                    onPressed: _locked
                                        ? null
                                        : () => _action(
                                            r,
                                            next: DemoAttendance.checkedIn,
                                          ),
                                    icon: const Icon(Icons.login),
                                    label: const Text('Check-in'),
                                  ),
                                if (!s.now.isBefore(r.end))
                                  TextButton.icon(
                                    key: Key('employee-finish-${r.id}'),
                                    onPressed: _locked
                                        ? null
                                        : () => _action(
                                            r,
                                            next:
                                                r.attendance ==
                                                    DemoAttendance.pending
                                                ? DemoAttendance.absent
                                                : DemoAttendance.completed,
                                          ),
                                    icon: const Icon(Icons.task_alt),
                                    label: Text(
                                      r.attendance == DemoAttendance.pending
                                          ? 'Vắng mặt'
                                          : 'Hoàn thành',
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        const Divider(),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      );
    },
  );
}
