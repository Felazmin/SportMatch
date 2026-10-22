import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../demo/demo_court_types.dart';
import '../demo/demo_facilities.dart';
import 'finance_screen.dart';

class CourtTypesScreen extends StatefulWidget {
  const CourtTypesScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<CourtTypesScreen> createState() => _CourtTypesScreenState();
}

class _CourtTypesScreenState extends State<CourtTypesScreen> {
  String _query = '', _state = 'all';
  Future<void> _edit([DemoCourtType? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final description = TextEditingController(text: old?.description ?? '');
    var sport = old?.sport ?? facilitySports.first;
    String? error;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(old == null ? 'Đề xuất loại sân' : 'Sửa loại sân'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const Key('court-type-name'),
                      controller: name,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Tên loại sân',
                      ),
                      validator: (v) => (v ?? '').trim().length < 3
                          ? 'Nhập ít nhất 3 ký tự.'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: sport,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Môn thể thao',
                      ),
                      items: [
                        for (final s in facilitySports)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => sport = v!,
                    ),
                    TextFormField(
                      key: const Key('court-type-description'),
                      controller: description,
                      maxLength: 1000,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Đặc điểm / mặt sân',
                      ),
                      validator: (v) => (v ?? '').trim().length < 5
                          ? 'Nhập ít nhất 5 ký tự.'
                          : null,
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              key: const Key('court-type-save'),
              onPressed: () {
                if (!form.currentState!.validate()) return;
                try {
                  widget.session.saveCourtType(
                    id: old?.id,
                    expectedRevision: old?.revision,
                    name: name.text,
                    sport: sport,
                    description: description.text,
                  );
                  Navigator.pop(context);
                } on StateError catch (e) {
                  update(() => error = e.message);
                }
              },
              child: const Text('Lưu nháp'),
            ),
          ],
        ),
      ),
    );
    // Dialog fields remain mounted until the closing animation finishes.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    name.dispose();
    description.dispose();
    await widget.session.flush();
  }

  Future<void> _transition(DemoCourtType t, String state, String label) async {
    final actor = widget.session.user?.identifier;
    final reason = TextEditingController();
    final needsReason = ['rejected', 'suspended'].contains(state);
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label?'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name),
                if (needsReason)
                  TextFormField(
                    key: const Key('court-type-reason'),
                    controller: reason,
                    maxLength: 300,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Lý do'),
                    validator: (v) => (v ?? '').trim().length < 5
                        ? 'Nhập 5–300 ký tự.'
                        : null,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            key: const Key('court-type-confirm'),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    final note = reason.text;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    reason.dispose();
    if (confirmed != true || !mounted) return;
    try {
      if (widget.session.user?.identifier != actor) {
        throw StateError('Tài khoản đã thay đổi. Mở lại hồ sơ.');
      }
      widget.session.transitionCourtType(t.id, state, t.revision, note: note);
      if (!await widget.session.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!s.initialized || s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Loại sân'),
          body: const Center(child: Text('Chưa có quyền truy cập.')),
        );
      }
      final items = s.managedCourtTypes
          .where(
            (t) =>
                (_state == 'all' || t.state == _state) &&
                '${t.name} ${t.sport} ${t.id}'.toLowerCase().contains(
                  _query.toLowerCase(),
                ),
          )
          .toList();
      return Scaffold(
        appBar: financeBar('Loại sân'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            if (s.role == DemoRole.owner)
              FilledButton.icon(
                key: const Key('court-type-add'),
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Đề xuất loại sân'),
              ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm loại sân',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in const {
                  'all': 'Tất cả',
                  'draft': 'Nháp',
                  'pending': 'Chờ duyệt',
                  'approved': 'Đã duyệt',
                  'rejected': 'Bổ sung',
                  'suspended': 'Tạm ngưng',
                }.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _state == e.key,
                    onSelected: (_) => setState(() => _state = e.key),
                  ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có loại sân phù hợp.'),
              ),
            for (final t in items)
              Padding(
                key: Key('court-type-${t.id}'),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('${t.id} · ${t.sport} · ${t.label}'),
                    const SizedBox(height: 6),
                    Text(t.description),
                    if (t.note.isNotEmpty) Text('Lý do: ${t.note}'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (s.role == DemoRole.owner &&
                            ['draft', 'rejected'].contains(t.state))
                          TextButton.icon(
                            onPressed: () => _edit(t),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Chỉnh sửa'),
                          ),
                        if (s.role == DemoRole.owner && t.state == 'draft')
                          TextButton.icon(
                            key: Key('court-type-pending-${t.id}'),
                            onPressed: () =>
                                _transition(t, 'pending', 'Gửi duyệt'),
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('Gửi duyệt'),
                          ),
                        if (s.role == DemoRole.admin &&
                            t.state == 'pending') ...[
                          TextButton.icon(
                            key: Key('court-type-approved-${t.id}'),
                            onPressed: () =>
                                _transition(t, 'approved', 'Duyệt loại sân'),
                            icon: const Icon(Icons.check),
                            label: const Text('Duyệt'),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _transition(t, 'rejected', 'Yêu cầu bổ sung'),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Yêu cầu bổ sung'),
                          ),
                        ],
                        if (s.role == DemoRole.admin &&
                            ['approved', 'suspended'].contains(t.state))
                          TextButton.icon(
                            onPressed: () => _transition(
                              t,
                              t.state == 'approved' ? 'suspended' : 'approved',
                              t.state == 'approved'
                                  ? 'Tạm ngưng loại sân'
                                  : 'Mở lại loại sân',
                            ),
                            icon: Icon(
                              t.state == 'approved'
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              t.state == 'approved' ? 'Tạm ngưng' : 'Mở lại',
                            ),
                          ),
                      ],
                    ),
                    const Divider(),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
