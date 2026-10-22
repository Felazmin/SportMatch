import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/demo_session.dart';
import '../demo/demo_operations.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import 'admin_review_widgets.dart';
import 'approval_center_screen.dart';
import 'finance_screen.dart';

class AdminAccountScreen extends StatefulWidget {
  const AdminAccountScreen({
    super.key,
    required this.session,
    this.onExport,
    this.embedded = false,
  });
  final DemoSession session;
  final Future<void> Function(Uint8List)? onExport;
  final bool embedded;
  @override
  State<AdminAccountScreen> createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<AdminAccountScreen> {
  int _tab = 0, _limit = 10;
  String _query = '', _result = '';
  DateTime? _date;
  bool _busy = false;
  String? _error;
  final _notifications = GlobalKey(), _security = GlobalKey();
  bool get _allowed =>
      widget.session.user != null && widget.session.role == DemoRole.admin;
  List<DemoAuditEntry> get _entries => !_allowed
      ? []
      : widget.session.operationAudit
            .where(
              (e) =>
                  e.actor == '__admin__' &&
                  (_date == null ||
                      adminDate(e.created) == adminDate(_date!)) &&
                  (_result.isEmpty || e.decision == _result) &&
                  venueSearchText(
                    '${e.actor} ${e.actor == widget.session.user?.identifier ? widget.session.user!.name : ''} ${e.action} ${e.subject} ${e.note}',
                  ).contains(venueSearchText(_query)),
            )
            .toList();

  Future<void> _export() async {
    if (_busy || !_allowed) return;
    final actor = widget.session.user!.identifier;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String cell(String value) {
        final safe = RegExp(r'^\s*[=+@-]').hasMatch(value) ? "'$value" : value;
        return '"${safe.replaceAll('"', '""')}"';
      }

      final rows = [
        [
          'Thời gian',
          'Người xử lý',
          'Quyết định',
          'Đối tượng',
          'Kết quả',
          'Lý do',
        ],
        for (final e in _entries)
          [
            adminTime(e.created),
            e.actor,
            e.action,
            e.subject,
            adminDecision(e.decision),
            e.note,
          ],
      ];
      final bytes = Uint8List.fromList([
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(rows.map((r) => r.map(cell).join(',')).join('\r\n')),
      ]);
      if (!_allowed || widget.session.user!.identifier != actor) return;
      if (widget.onExport != null) {
        await widget.onExport!(bytes);
      } else {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            title: 'Nhật ký quản trị',
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'text/csv',
                name: 'nhat-ky-quan-tri.csv',
              ),
            ],
            fileNameOverrides: ['nhat-ky-quan-tri.csv'],
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      }
    } catch (_) {
      if (mounted && _allowed) {
        setState(() => _error = 'Chưa xuất được nhật ký. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preferences(String kind, bool value) async {
    final s = widget.session, actor = widget.session.user?.identifier;
    final password = await _passwordDialog(context);
    if (!mounted ||
        password == null ||
        !_allowed ||
        s.user?.identifier != actor) {
      return;
    }
    try {
      final p = s.adminNotificationPreferences;
      setState(() => _error = null);
      s.updateAdminNotifications(
        password: password,
        requests: kind == 'requests' ? value : p.requests,
        overdue: kind == 'overdue' ? value : p.overdue,
        weekly: kind == 'weekly' ? value : p.weekly,
      );
      await s.flush();
    } on StateError catch (e) {
      if (mounted && _allowed) setState(() => _error = e.message);
    }
  }

  void _jump(int tab) {
    setState(() => _tab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = (tab == 1 ? _notifications : _security).currentContext;
      if (c != null) {
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!_allowed) {
        return Scaffold(
          appBar: financeBar('Tài khoản quản trị'),
          body: const Center(child: Text('Chỉ Admin được truy cập.')),
        );
      }
      final entries = _entries, prefs = s.adminNotificationPreferences;
      return Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: widget.embedded
            ? null
            : const AdminReviewNavigation(selected: 4),
        appBar: adminReviewBar(
          context,
          'Nhật ký & cài đặt',
          'Quản trị viên · Tài khoản quản trị',
          onNotifications: () => _jump(1),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            AdminReviewCard(
              children: [
                Text(
                  s.user!.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  s.user!.identifier == '__admin__'
                      ? DemoSession.adminEmail
                      : s.user!.identifier,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Quản trị viên · Đang hoạt động',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Quyền vận hành & kiểm duyệt toàn hệ thống',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('admin-account-info'),
                    onPressed: () => _jump(2),
                    child: const Text('Thông tin tài khoản →'),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < 3; i++)
                  AdminReviewChip(
                    key: Key('admin-account-tab-$i'),
                    label: Text(const ['Nhật ký', 'Thông báo', 'Bảo mật'][i]),
                    selected: _tab == i,
                    onSelected: (_) =>
                        i == 0 ? setState(() => _tab = 0) : _jump(i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin-audit-search'),
              decoration: InputDecoration(
                hintText: 'Tìm đối tượng hoặc người xử lý',
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(
                  tooltip: 'Lọc kết quả',
                  onPressed: _filter,
                  icon: const Icon(Icons.tune, size: 20),
                ),
              ),
              onChanged: (v) => setState(() {
                _query = v;
                _limit = 10;
              }),
            ),
            const SizedBox(height: 12),
            const Text(
              'Thời gian / kết quả',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            OutlinedButton.icon(
              key: const Key('admin-audit-filter'),
              onPressed: _filter,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(
                '${_date == null ? 'Tất cả thời gian' : adminDate(_date!)} · ${_result.isEmpty ? 'Tất cả quyết định' : adminDecision(_result)}',
              ),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Nhật ký quyết định',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  key: const Key('admin-audit-export'),
                  onPressed: _busy ? null : _export,
                  child: Text(_busy ? 'Đang xuất…' : 'Xuất nhật ký'),
                ),
              ],
            ),
            if (entries.isEmpty)
              const AdminReviewCard(
                children: [Text('Chưa có nhật ký phù hợp.')],
              ),
            for (final e in entries.take(_limit))
              AdminReviewCard(
                children: [
                  Text(
                    e.action,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (e.subject.isNotEmpty)
                    Text(
                      e.subject,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  Text(
                    adminDecision(e.decision),
                    style: TextStyle(
                      fontSize: 11,
                      color: e.decision == 'rejected'
                          ? Colors.red
                          : e.decision == 'supplement'
                          ? const Color(0xFF855200)
                          : AppColors.darkGreen,
                    ),
                  ),
                  Text(
                    '${e.actor} · ${adminTime(e.created)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  if (e.note.isNotEmpty)
                    Text(
                      'Lý do: ${e.note}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminAuditDetailScreen(session: s, entry: e),
                        ),
                      ),
                      child: const Text('Xem quyết định →'),
                    ),
                  ),
                ],
              ),
            if (entries.length > _limit)
              OutlinedButton(
                onPressed: () => setState(() => _limit += 10),
                child: const Text('Xem thêm nhật ký'),
              ),
            AdminReviewCard(
              key: _notifications,
              title: 'Thông báo quản trị',
              children: [
                SwitchListTile(
                  key: const Key('admin-notify-requests'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yêu cầu mới'),
                  value: prefs.requests,
                  onChanged: (v) => _preferences('requests', v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hồ sơ quá hạn · Sau 48 giờ'),
                  key: const Key('admin-notify-overdue'),
                  value: prefs.overdue,
                  onChanged: (v) => _preferences('overdue', v),
                ),
                const Text(
                  'Cảnh báo bảo mật: Chưa kết nối dịch vụ',
                  style: TextStyle(fontSize: 12),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Báo cáo tuần · Thứ Hai, 08:00'),
                  key: const Key('admin-notify-weekly'),
                  value: prefs.weekly,
                  onChanged: (v) => _preferences('weekly', v),
                ),
                const Text(
                  'Tùy chọn lưu trên thiết bị. Chưa kết nối dịch vụ gửi thông báo hoặc báo cáo tự động.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ApprovalCenterScreen(session: s),
                    ),
                  ),
                  child: const Text('Xem yêu cầu đang chờ →'),
                ),
              ],
            ),
            AdminReviewCard(
              key: _security,
              title: 'Bảo mật & quyền quản trị',
              children: [
                const Text(
                  'Xác thực hai bước: Chưa được hỗ trợ',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Phiên đăng nhập: Trên thiết bị hiện tại',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tài khoản: ${s.user!.identifier}',
                  style: const TextStyle(fontSize: 12),
                ),
                TextButton(
                  key: const Key('admin-password-change'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AdminPasswordScreen(session: s),
                    ),
                  ),
                  child: const Text('Đổi mật khẩu →'),
                ),
                const Text(
                  'Quyền được cấp: Vận hành · Kiểm duyệt · Báo cáo',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cấp / thu hồi quyền: Không khả dụng trong bản demo',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                const AdminReviewNote(
                  'Thay đổi tùy chọn quản trị yêu cầu xác thực mật khẩu và được lưu vào nhật ký.',
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('admin-account-error'),
                style: const TextStyle(color: Colors.red),
              ),
            TextButton(
              key: const Key('admin-account-logout'),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFFEFEF),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: () async {
                final actor = s.user?.identifier;
                final ok = await financeConfirm(
                  context,
                  'Đăng xuất?',
                  'Bạn muốn đăng xuất khỏi tài khoản quản trị này?',
                );
                if (ok && mounted && _allowed && s.user?.identifier == actor) {
                  s.logout();
                }
              },
              child: const Text('Đăng xuất'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bạn sẽ được yêu cầu xác nhận trước khi kết thúc phiên quản trị.\nSportMatch · Phiên bản 1.0.0 · Giờ Việt Nam',
              style: TextStyle(
                fontSize: 10,
                height: 1.8,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _filter() async {
    final actor = widget.session.user?.identifier;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Chọn ngày'),
                leading: const Icon(Icons.calendar_month),
                onTap: () => Navigator.pop(context, 'date'),
              ),
              for (final r in ['', 'approved', 'supplement', 'rejected'])
                ListTile(
                  title: Text(r.isEmpty ? 'Tất cả kết quả' : adminDecision(r)),
                  selected: _result == r,
                  onTap: () => Navigator.pop(context, r),
                ),
              ListTile(
                title: const Text('Xóa bộ lọc'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted ||
        selected == null ||
        !_allowed ||
        widget.session.user?.identifier != actor) {
      return;
    }
    if (selected == 'date') {
      final d = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: widget.session.now,
        initialDate: _date ?? widget.session.now,
      );
      if (mounted &&
          d != null &&
          _allowed &&
          widget.session.user?.identifier == actor) {
        setState(() {
          _date = d;
          _limit = 10;
        });
      }
    } else {
      setState(() {
        if (selected == 'clear') {
          _date = null;
          _result = '';
        } else {
          _result = selected;
        }
        _limit = 10;
      });
    }
  }
}

Future<String?> _passwordDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Xác thực quản trị'),
      content: TextField(
        key: const Key('admin-confirm-password'),
        controller: controller,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
  // The route may still be animating when its result completes.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}

class AdminAuditDetailScreen extends StatelessWidget {
  const AdminAuditDetailScreen({
    super.key,
    required this.session,
    required this.entry,
  });
  final DemoSession session;
  final DemoAuditEntry entry;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Scaffold(
      appBar: adminReviewBar(
        context,
        'Chi tiết quyết định',
        'Nhật ký quản trị',
      ),
      body: session.role != DemoRole.admin || session.user == null
          ? const Center(child: Text('Chỉ Admin được truy cập.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AdminReviewCard(
                  title: entry.action,
                  children: [
                    Text(
                      'Đối tượng: ${entry.subject.isEmpty ? 'Chưa có mã trong nhật ký cũ' : entry.subject}',
                    ),
                    Text('Kết quả: ${adminDecision(entry.decision)}'),
                    Text('Người xử lý: ${entry.actor}'),
                    Text(adminTime(entry.created)),
                    const SizedBox(height: 12),
                    Text(
                      'Lý do: ${entry.note.isEmpty ? 'Không có lý do được lưu' : entry.note}',
                    ),
                  ],
                ),
              ],
            ),
    ),
  );
}

class AdminPasswordScreen extends StatefulWidget {
  const AdminPasswordScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<AdminPasswordScreen> createState() => _AdminPasswordScreenState();
}

class _AdminPasswordScreenState extends State<AdminPasswordScreen> {
  final _current = TextEditingController(),
      _next = TextEditingController(),
      _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => Scaffold(
      appBar: adminReviewBar(context, 'Đổi mật khẩu', 'Tài khoản quản trị'),
      body: widget.session.role != DemoRole.admin || widget.session.user == null
          ? const Center(child: Text('Chỉ Admin được truy cập.'))
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    key: const Key('admin-password-current'),
                    controller: _current,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Nhập mật khẩu hiện tại' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('admin-password-next'),
                    controller: _next,
                    obscureText: true,
                    maxLength: 128,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới',
                    ),
                    validator: (v) =>
                        (v ?? '').length < 8 ||
                            !RegExp(r'[A-Za-z]').hasMatch(v!) ||
                            !RegExp(r'\d').hasMatch(v)
                        ? 'Tối thiểu 8 ký tự, có chữ và số'
                        : null,
                  ),
                  TextFormField(
                    key: const Key('admin-password-confirm'),
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu mới',
                    ),
                    validator: (v) =>
                        v != _next.text ? 'Mật khẩu chưa khớp' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_message != null)
                    Text(_message!, key: const Key('admin-password-result')),
                  FilledButton(
                    key: const Key('admin-password-save'),
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!_form.currentState!.validate()) return;
                            setState(() => _busy = true);
                            try {
                              if (!widget.session.changePassword(
                                _current.text,
                                _next.text,
                              )) {
                                throw StateError(
                                  'Mật khẩu hiện tại không đúng.',
                                );
                              }
                              final saved = await widget.session.flush();
                              if (mounted) {
                                setState(() {
                                  _message = saved ? 'Đã đổi mật khẩu.' : 'Đã đổi mật khẩu nhưng chưa lưu được. Thử lưu lại trước khi đóng ứng dụng.';
                                  _current.clear();
                                  _next.clear();
                                  _confirm.clear();
                                });
                              }
                            } on StateError catch (e) {
                              if (mounted) setState(() => _message = e.message);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Lưu mật khẩu'),
                  ),
                  FinanceSaveNotice(session: widget.session),
                ],
              ),
            ),
    ),
  );
}
