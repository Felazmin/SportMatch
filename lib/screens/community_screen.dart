import 'package:flutter/material.dart';

import 'play_groups_screen.dart' show PlayGroupPhoto;

import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_community.dart';
import '../widgets/design.dart';
import 'auth_screen.dart';
import 'events_screen.dart';

AppBar _bar(String title) => AppBar(
  title: Text(title, style: const TextStyle(fontSize: 18)),
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
);
Future<bool> _login(BuildContext context, DemoSession s) async {
  if (s.user != null) return true;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AuthScreen(session: s)),
  );
  return context.mounted && s.user != null;
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _mode = 0;
  String _group = 'public';
  Future<void> _compose() async {
    if (!await _login(context, widget.session) || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _mode == 2
            ? ExpenseFormScreen(session: widget.session)
            : PostFormScreen(session: widget.session, groupId: _group),
      ),
    );
  }

  Future<void> _delete(DemoPost p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài đăng?'),
        content: const Text(
          'Bài viết sẽ bị xóa khỏi dữ liệu demo trên thiết bị này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            key: const Key('community-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (yes == true) {
      widget.session.deletePost(p);
      await widget.session.flush();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (_group != 'public' && !s.publicGroups.containsKey(_group)) {
        _group = 'public';
      }
      final posts = s.posts.where((p) => p.groupId == _group).toList();
      return Scaffold(
        appBar: _bar('Cộng đồng'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (s.saveFailed) ...[
              const Text(
                'Chưa lưu được dữ liệu. Đừng đóng ứng dụng.',
                style: TextStyle(color: Colors.red),
              ),
              TextButton.icon(
                key: const Key('community-retry'),
                onPressed: s.retrySave,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lưu lại'),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                    key: Key('community-mode-$i'),
                    selected: _mode == i,
                    label: Text(['Diễn đàn', 'Nhóm chơi', 'Chia tiền'][i]),
                    onSelected: (_) => setState(() => _mode = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_mode == 0) ...[
              DropdownButtonFormField<String>(
                key: ValueKey('community-group-$_group'),
                initialValue: _group,
                decoration: const InputDecoration(labelText: 'Bảng tin'),
                isExpanded: true,
                itemHeight: null,
                selectedItemBuilder: (_) => [
                  const Text('Chung'),
                  for (final e in s.publicGroups.entries)
                    Text(
                      e.key == 'badminton'
                          ? 'Cầu lông'
                          : e.key == 'morning'
                          ? 'Buổi sáng'
                          : e.key,
                    ),
                ],
                items: [
                  const DropdownMenuItem(
                    value: 'public',
                    child: Text('Diễn đàn chung'),
                  ),
                  for (final e in s.publicGroups.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (value) => setState(() => _group = value!),
              ),
              if (_group != 'public')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    s.publicGroups[_group]!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (s.publicPlayGroup(_group)?.photo.isNotEmpty ?? false)
                PlayGroupPhoto(encoded: s.publicPlayGroup(_group)!.photo),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('community-compose'),
                onPressed: _compose,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Viết bài'),
              ),
              if (posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Chưa có bài đăng trong mục này.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final p in posts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.author,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (s.user?.identifier == p.owner)
                                IconButton(
                                  key: Key('post-delete-${p.id}'),
                                  tooltip: 'Xóa bài đăng',
                                  onPressed: () => _delete(p),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                          Text(
                            bookingDate(p.created),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            p.message,
                            key: Key('post-${p.id}'),
                            style: const TextStyle(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            if (_mode == 1) ...[
              for (final e in s.publicGroups.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        e.value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Nhóm demo trên thiết bị',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      if (s.ownGroupRequest(e.key)?.state == 'removed')
                        Text(
                          'Đã thu hồi tư cách: ${s.ownGroupRequest(e.key)!.note}',
                          key: Key('group-removal-notice-${e.key}'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: Key('group-join-${e.key}'),
                            icon: Icon(
                              s.joinedGroups.contains(e.key)
                                  ? Icons.person_remove_outlined
                                  : Icons.person_add_outlined,
                            ),
                            label: Text(
                              s.joinedGroups.contains(e.key)
                                  ? 'Rời nhóm'
                                  : s.ownGroupRequest(e.key)?.state == 'pending'
                                  ? 'Rút yêu cầu'
                                  : 'Tham gia',
                            ),
                            onPressed: () async {
                              if (await _login(context, s)) {
                                try {
                                  s.toggleGroup(e.key);
                                  await s.flush();
                                } on StateError catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.message)),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                          TextButton(
                            key: Key('group-posts-${e.key}'),
                            onPressed: () => setState(() {
                              _mode = 0;
                              _group = e.key;
                            }),
                            child: const Text('Bảng tin nhóm'),
                          ),
                          for (final event in s.eventsForGroup(e.key))
                            TextButton.icon(
                              key: Key('group-event-${event.id}'),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(event.title),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(
                                    session: s,
                                    event: event,
                                    start: event.start(s.now),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                    ],
                  ),
                ),
            ],
            if (_mode == 2) ...[
              FilledButton.icon(
                key: const Key('expense-create'),
                onPressed: _compose,
                icon: const Icon(Icons.add),
                label: const Text('Thêm khoản chi'),
              ),
              if (s.expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Chưa có khoản chia chi phí.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final e in s.expenses)
                ListTile(
                  key: Key('expense-${e.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.title),
                  subtitle: Text(
                    '${bookingDate(e.created)} · ${e.names.length} người · ${bookingMoney(e.amount)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ExpenseDetailScreen(session: s, expense: e),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Dữ liệu cộng đồng chỉ lưu trên thiết bị. Chia tiền là bảng tính chi phí, không ghi nhận chuyển tiền hay thanh toán.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PostFormScreen extends StatefulWidget {
  const PostFormScreen({
    super.key,
    required this.session,
    required this.groupId,
  });
  final DemoSession session;
  final String groupId;
  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.createPost(widget.groupId, _text.text);
      await widget.session.flush();
      if (mounted) Navigator.pop(context);
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _bar('Viết bài'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.groupId == 'public'
              ? 'Diễn đàn chung'
              : widget.session.publicGroups[widget.groupId] ??
                    'Nhóm không hoạt động',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('post-message'),
          controller: _text,
          maxLines: 8,
          minLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Nội dung'),
        ),
        if (_error != null)
          Text(
            _error!,
            key: const Key('post-error'),
            style: const TextStyle(color: Colors.red),
          ),
        FilledButton(
          key: const Key('post-submit'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu...' : 'Đăng bài'),
        ),
      ],
    ),
  );
}

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _names = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_title, _amount, _names]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final e = widget.session.createExpense(
        _title.text,
        int.tryParse(_amount.text) ?? 0,
        _names.text
            .split('\n')
            .map((n) => n.trim())
            .where((n) => n.isNotEmpty)
            .toList(),
      );
      await widget.session.flush();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ExpenseDetailScreen(session: widget.session, expense: e),
          ),
        );
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _bar('Chia chi phí'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          key: const Key('expense-title'),
          controller: _title,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Khoản chi'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('expense-amount'),
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
          decoration: const InputDecoration(labelText: 'Tổng tiền (đ)'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('expense-names'),
          controller: _names,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Người tham gia',
            helperText: 'Mỗi tên một dòng, từ 2 đến 20 người',
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(
            _error!,
            key: const Key('expense-error'),
            style: const TextStyle(color: Colors.red),
          ),
        FilledButton(
          key: const Key('expense-submit'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu...' : 'Chia đều và lưu'),
        ),
      ],
    ),
  );
}

class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.session,
    required this.expense,
  });
  final DemoSession session;
  final DemoExpense expense;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      if (session.user?.identifier != expense.owner) {
        return Scaffold(
          appBar: _bar('Khoản chi'),
          body: const Center(child: Text('Vui lòng đăng nhập đúng tài khoản.')),
        );
      }
      return Scaffold(
        appBar: _bar('Chi tiết chia tiền'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (session.saveFailed) ...[
              const Text(
                'Chưa lưu được dữ liệu. Đừng đóng ứng dụng.',
                style: TextStyle(color: Colors.red),
              ),
              TextButton(
                key: const Key('expense-retry-save'),
                onPressed: session.retrySave,
                child: const Text('Thử lưu lại'),
              ),
            ],
            Text(
              expense.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              '${bookingMoney(expense.amount)} · ${expense.names.length} người',
            ),
            const Divider(height: 32),
            for (var i = 0; i < expense.names.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(expense.names[i])),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        bookingMoney(expense.shares[i]),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32),
            const Text(
              'Chia đều theo số người. Phần dư 1đ được phân bổ lần lượt theo thứ tự tên. Đây là bảng tính demo, không phải khoản nợ hoặc giao dịch đã thanh toán.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      );
    },
  );
}
