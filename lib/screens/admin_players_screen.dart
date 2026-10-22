import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import 'finance_screen.dart';
import 'workflow_screen.dart';

class AdminPlayersScreen extends StatefulWidget {
  const AdminPlayersScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<AdminPlayersScreen> createState() => _AdminPlayersScreenState();
}

class _AdminPlayersScreenState extends State<AdminPlayersScreen> {
  final _search = TextEditingController();
  bool? _blocked;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.admin) {
        return _denied('Người dùng');
      }
      final q = removeDiacritics(_search.text.trim()).toLowerCase();
      final users =
          s.managedUsers
              .where(
                (u) =>
                    (_blocked == null ||
                        s.isBlocked(u.identifier) == _blocked) &&
                    removeDiacritics(
                      '${u.name} ${u.identifier} ${s.managedContactPhone(u.identifier)}',
                    ).toLowerCase().contains(q),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return Scaffold(
        appBar: financeBar('Người dùng'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            TextField(
              key: const Key('admin-player-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Tìm kiếm',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('admin-player-clear'),
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in <bool?, String>{
                  null: 'Tất cả',
                  false: 'Hoạt động',
                  true: 'Đã khóa',
                }.entries)
                  ChoiceChip(
                    key: Key('admin-player-filter-${e.key}'),
                    label: Text(e.value),
                    selected: _blocked == e.key,
                    onSelected: (_) => setState(() => _blocked = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${users.length} tài khoản'),
            if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Không có người dùng phù hợp.',
                  key: Key('admin-player-empty'),
                ),
              ),
            for (final u in users)
              ListTile(
                key: Key('admin-player-${u.identifier}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.isBlocked(u.identifier)
                      ? Icons.lock_outline
                      : Icons.person_outline,
                ),
                title: Text(u.name),
                subtitle: Text(
                  '${u.identifier}\n${s.isBlocked(u.identifier) ? 'Đã khóa đăng nhập' : 'Hoạt động'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminPlayerDetailScreen(session: s, id: u.identifier),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget _denied(String title) => Scaffold(
  appBar: financeBar(title),
  body: const Center(child: Text('Chỉ Admin được truy cập.')),
);

class AdminPlayerDetailScreen extends StatelessWidget {
  const AdminPlayerDetailScreen({
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
      if (s.user == null || s.role != DemoRole.admin) return _denied('Hồ sơ');
      if (!s.managedUsers.any((u) => u.identifier == id)) {
        return Scaffold(
          appBar: financeBar('Hồ sơ'),
          body: const Center(child: Text('Không có người dùng.')),
        );
      }
      final u = s.managedPlayer(id), decision = s.playerAccessDecision(id);
      final records = s.playerRecords(id), phone = s.managedContactPhone(id);
      final paid = records
          .where(
            (r) => s.workflowPayment(r.id)?.state == DemoPaymentState.approved,
          )
          .fold<int>(0, (a, r) => a + r.total);
      final cases = s.disputes.where((d) => d.owner == id).toList();
      return Scaffold(
        appBar: financeBar('Hồ sơ'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              u.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(id),
            if (phone.isNotEmpty && phone != id) Text(phone),
            const SizedBox(height: 12),
            Text(
              s.isBlocked(id) ? 'Đã khóa đăng nhập' : 'Hoạt động',
              key: const Key('admin-player-status'),
            ),
            if (decision != null) ...[
              Text('Lý do: ${decision.reason}'),
              Text('Cập nhật: ${bookingDate(decision.created)}'),
            ],
            FilledButton.icon(
              key: const Key('admin-player-access'),
              icon: Icon(
                s.isBlocked(id) ? Icons.lock_open : Icons.lock_outline,
              ),
              label: Text(s.isBlocked(id) ? 'Mở khóa' : 'Khóa tài khoản'),
              onPressed: () => showPlayerAccess(context, s, id),
            ),
            const Divider(height: 24),
            Text(
              '${records.where((r) => r.id.startsWith('NVH')).length} lịch sân · ${records.where((r) => r.id.startsWith('VE')).length} vé',
            ),
            Text('Thanh toán đã xác nhận demo: ${bookingMoney(paid)}'),
            Text('${cases.length} khiếu nại'),
            const Divider(height: 24),
            const Text(
              'Lịch sử đặt sân & vé',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (records.isEmpty) const Text('Chưa có lịch đặt.'),
            for (final r in records)
              ListTile(
                key: Key('admin-player-record-${r.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text('${r.id} · ${bookingMoney(r.total)}'),
                subtitle: Text(
                  '${r.title}\n${bookingDate(r.start)} · ${r.cancelled ? 'Đã hủy' : s.workflowPayment(r.id)?.label(s.now) ?? 'Chưa thanh toán'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkflowDetailScreen(session: s, id: r.id),
                  ),
                ),
              ),
            if (cases.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Khiếu nại',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final d in cases)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(d.subject),
                  subtitle: Text('${d.id} · ${d.label}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DisputeDetailScreen(session: s, dispute: d),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

Future<void> showPlayerAccess(
  BuildContext context,
  DemoSession session,
  String id,
) async {
  if (session.role != DemoRole.admin ||
      !session.managedUsers.any((u) => u.identifier == id)) {
    return;
  }
  final expected = session.isBlocked(id);
  final revision = session.playerAccessRevision(id);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AccessDialog(
      session: session,
      id: id,
      expected: expected,
      revision: revision,
    ),
  );
}

class _AccessDialog extends StatefulWidget {
  const _AccessDialog({
    required this.session,
    required this.id,
    required this.expected,
    required this.revision,
  });
  final DemoSession session;
  final String id;
  final bool expected;
  final int revision;
  @override
  State<_AccessDialog> createState() => _AccessDialogState();
}

class _AccessDialogState extends State<_AccessDialog> {
  final _password = TextEditingController(), _reason = TextEditingController();
  bool _busy = false, _committed = false, _show = false;
  String? _error;
  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!_committed) {
        widget.session.setPlayerBlocked(
          widget.id,
          !widget.expected,
          password: _password.text,
          reason: _reason.text,
          expectedBlocked: widget.expected,
          expectedRevision: widget.revision,
        );
        _committed = true;
        _password.clear();
      } else {
        await widget.session.retrySave();
      }
      final saved = await widget.session.flush();
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context);
      } else {
        setState(() => _error = 'Đã thay đổi trong demo, chưa lưu được.');
      }
    } catch (e) {
      _password.clear();
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Không thể cập nhật tài khoản.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_committed &&
        widget.session.saveFailed &&
        !await financeConfirm(
          context,
          'Đóng khi chưa lưu?',
          'Thay đổi có thể mất khi khởi động lại.',
        )) {
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final allowed =
          widget.session.user != null && widget.session.role == DemoRole.admin;
      return PopScope(
        canPop: !_busy && (!_committed || !widget.session.saveFailed),
        child: AlertDialog(
          title: Text(widget.expected ? 'Mở khóa' : 'Khóa tài khoản'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!allowed)
                    const Text('Chỉ Admin được thực hiện.')
                  else ...[
                    Text(widget.id),
                    const SizedBox(height: 12),
                    if (!_committed) ...[
                      TextField(
                        key: const Key('player-access-reason'),
                        controller: _reason,
                        maxLength: 300,
                        minLines: 2,
                        maxLines: 4,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Lý do'),
                      ),
                      TextField(
                        key: const Key('player-access-password'),
                        controller: _password,
                        obscureText: !_show,
                        maxLength: 128,
                        enableSuggestions: false,
                        autocorrect: false,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          suffixIcon: IconButton(
                            tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _show = !_show),
                            icon: Icon(
                              _show ? Icons.visibility_off : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_committed) FinanceSaveNotice(session: widget.session),
                    if (_error != null)
                      Text(
                        _error!,
                        key: const Key('player-access-error'),
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : _close,
              child: Text(_committed ? 'Đóng' : 'Hủy'),
            ),
            if (allowed)
              FilledButton(
                key: const Key('player-access-confirm'),
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? 'Đang lưu…'
                      : _committed
                      ? 'Lưu lại'
                      : 'Xác nhận',
                ),
              ),
          ],
        ),
      );
    },
  );
}
