import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;

import '../auth/demo_session.dart';
import '../demo/demo_play_groups.dart';
import '../demo/demo_finance.dart';
import '../venues/venue_catalog.dart';
import 'finance_screen.dart';

class PlayGroupPhoto extends StatelessWidget {
  const PlayGroupPhoto({super.key, required this.encoded});
  final String encoded;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Image.memory(
      decodeProof(encoded),
      height: 180,
      width: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox(
        height: 180,
        child: Center(child: Text('Không thể mở ảnh nhóm.')),
      ),
    ),
  );
}

class PlayGroupsScreen extends StatefulWidget {
  const PlayGroupsScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<PlayGroupsScreen> createState() => _PlayGroupsScreenState();
}

class _PlayGroupsScreenState extends State<PlayGroupsScreen> {
  String _query = '', _state = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Quản lý nhóm chơi'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final groups = s.managedPlayGroups.where(
        (g) =>
            (_state == 'all' || g.state == _state) &&
            venueSearchText('${g.name} ${g.id}')
                .contains(venueSearchText(_query)),
      );
      return Scaffold(
        appBar: financeBar('Quản lý nhóm chơi'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            if (s.role == DemoRole.owner)
              FilledButton.icon(
                key: const Key('play-group-add'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayGroupFormScreen(session: s),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tạo nhóm'),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('play-group-search'),
              decoration: const InputDecoration(
                labelText: 'Tìm nhóm',
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
                }.entries)
                  ChoiceChip(
                    key: Key('play-group-filter-${e.key}'),
                    label: Text(e.value),
                    selected: _state == e.key,
                    onSelected: (_) => setState(() => _state = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (groups.isEmpty) const Text('Không có nhóm phù hợp.'),
            for (final g in groups)
              ListTile(
                key: Key('play-group-${g.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(g.name),
                subtitle: Text(
                  '${g.id} · ${playGroupSports[g.sport]} · ${g.label}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayGroupDetailScreen(session: s, id: g.id),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class PlayGroupFormScreen extends StatefulWidget {
  const PlayGroupFormScreen({
    super.key,
    required this.session,
    this.group,
    this.pickImage,
  });
  final DemoSession session;
  final DemoPlayGroup? group;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<PlayGroupFormScreen> createState() => _PlayGroupFormScreenState();
}

class _PlayGroupFormScreenState extends State<PlayGroupFormScreen> {
  late final _name = TextEditingController(text: widget.group?.name);
  late final _description = TextEditingController(
    text: widget.group?.description,
  );
  late String _sport = widget.group?.sport ?? 'badminton';
  late bool _requiresApproval = widget.group?.requiresApproval ?? false;
  late String _photo = widget.group?.photo ?? '';
  bool _busy = false, _committed = false;
  String? _error;
  Future<void> _pick() async {
    if (_busy || _committed) return;
    final actor = widget.session.user?.identifier;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.pickImage?.call() ?? ProofPicker.pick());
      if (bytes != null &&
          mounted &&
          actor == widget.session.user?.identifier &&
          widget.session.role == DemoRole.owner) {
        setState(() => _photo = encodeProof(bytes));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể đọc ảnh nhóm PNG/JPEG, tối đa 400 KB.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _committed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.savePlayGroup(
        id: widget.group?.id,
        expectedRevision: widget.group?.revision,
        name: _name.text,
        sport: _sport,
        description: _description.text,
        requiresApproval: _requiresApproval,
        photo: _photo,
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
          appBar: financeBar('Hồ sơ nhóm'),
          body: const Center(child: Text('Chỉ Chủ sân được tạo nhóm.')),
        );
      }
      return Scaffold(
        appBar: financeBar(widget.group == null ? 'Tạo nhóm' : 'Sửa nhóm'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            if (_photo.isNotEmpty) PlayGroupPhoto(encoded: _photo),
            OutlinedButton.icon(
              key: const Key('play-group-photo'),
              onPressed: _busy || _committed ? null : _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Chọn ảnh nhóm'),
            ),
            if (_photo.isNotEmpty)
              IconButton(
                key: const Key('play-group-photo-remove'),
                tooltip: 'Xóa ảnh nhóm',
                onPressed: _busy || _committed
                    ? null
                    : () => setState(() => _photo = ''),
                icon: const Icon(Icons.delete_outline),
              ),
            TextField(
              key: const Key('play-group-name'),
              controller: _name,
              minLines: 1,
              maxLines: 3,
              maxLength: 80,
              enabled: !_busy && !_committed,
              decoration: const InputDecoration(labelText: 'Tên nhóm'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _sport,
              decoration: const InputDecoration(labelText: 'Môn thể thao'),
              isExpanded: true,
              items: [
                for (final e in playGroupSports.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: _busy || _committed
                  ? null
                  : (v) => setState(() => _sport = v!),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              key: const Key('play-group-member-approval'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Duyệt thành viên mới'),
              value: _requiresApproval,
              onChanged: _busy || _committed
                  ? null
                  : (v) => setState(() => _requiresApproval = v),
            ),
            TextField(
              key: const Key('play-group-description'),
              controller: _description,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              enabled: !_busy && !_committed,
              decoration: const InputDecoration(labelText: 'Mô tả nhóm'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_committed) const Text('Đã tạo hồ sơ trong phiên hiện tại.'),
            FilledButton.icon(
              key: const Key('play-group-save'),
              onPressed: _busy || _committed ? null : _save,
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

class PlayGroupDetailScreen extends StatefulWidget {
  const PlayGroupDetailScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  State<PlayGroupDetailScreen> createState() => _PlayGroupDetailScreenState();
}

class _PlayGroupDetailScreenState extends State<PlayGroupDetailScreen> {
  bool _busy = false;
  String? _error;
  String _memberQuery = '', _memberState = 'all';
  final _memberSearch = TextEditingController();
  @override
  void dispose() {
    _memberSearch.dispose();
    super.dispose();
  }

  Future<void> _reviewMember(
    DemoGroupRequest request,
    bool approve, {
    bool remove = false,
  }) async {
    if (_busy) return;
    final actor = widget.session.user?.identifier;
    final note = approve
        ? ''
        : await financeText(
            context,
            remove ? 'Lý do thu hồi tư cách' : 'Lý do từ chối',
          );
    if (note == null ||
        !mounted ||
        !await financeConfirm(
          context,
          remove
              ? 'Thu hồi tư cách?'
              : approve
              ? 'Duyệt thành viên?'
              : 'Từ chối thành viên?',
          remove
              ? 'Lý do: $note\nVé đã đặt vẫn được giữ nguyên.'
              : approve
              ? 'Xác nhận duyệt yêu cầu tham gia nhóm.'
              : 'Lý do: $note',
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
        throw StateError('Tài khoản đã thay đổi.');
      }
      if (remove) {
        widget.session.removeGroupMember(
          request.groupId,
          request.member,
          request.revision,
          reason: note,
        );
      } else {
        widget.session.reviewGroupRequest(
          request.groupId,
          request.member,
          request.revision,
          approve: approve,
          note: note,
        );
      }
      if (!await widget.session.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
    } on StateError catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _change(DemoPlayGroup group, String state, String title) async {
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
              ? 'Dừng tham gia và đăng bài mới. Vé đã đặt vẫn được giữ nguyên.'
              : 'Xác nhận $title cho nhóm ${group.name}.',
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
      widget.session.transitionPlayGroup(
        group.id,
        state,
        group.revision,
        note: reason,
      );
      if (!await widget.session.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
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
          appBar: financeBar('Hồ sơ nhóm'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final g = s.managedPlayGroups.where((g) => g.id == widget.id).firstOrNull;
      if (g == null) {
        return Scaffold(
          appBar: financeBar('Hồ sơ nhóm'),
          body: const Center(child: Text('Không tìm thấy nhóm.')),
        );
      }
      final members = s.groupMembers(g.id);
      final requests = s.groupRequests(g.id);
      final query = venueSearchText(_memberQuery.trim());
      final filteredRequests = requests
          .where(
            (r) =>
                (_memberState == 'all' || r.state == _memberState) &&
                venueSearchText('${s.groupMemberName(r.member)} ${r.member}')
                    .contains(query),
          )
          .toList();
      final filteredMembers = members
          .where(
            (m) => venueSearchText('${m.name} ${m.identifier}').contains(query),
          )
          .toList();
      return Scaffold(
        appBar: financeBar('Hồ sơ nhóm'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              g.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('${g.id} · ${playGroupSports[g.sport]}'),
            Text(g.label, key: const Key('play-group-state')),
            const Divider(height: 32),
            SelectableText(g.description),
            if (g.photo.isNotEmpty) PlayGroupPhoto(encoded: g.photo),
            const Divider(height: 32),
            Text(
              'Thành viên (${members.length})',
              key: const Key('group-member-count'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('group-member-search'),
              controller: _memberSearch,
              decoration: InputDecoration(
                labelText: 'Tìm thành viên',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _memberQuery.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('group-member-search-clear'),
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _memberQuery = '';
                          _memberSearch.clear();
                        }),
                      ),
              ),
              onChanged: (v) => setState(() => _memberQuery = v),
            ),
            if (!g.requiresApproval) ...[
              if (filteredMembers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    members.isEmpty
                        ? 'Chưa có thành viên.'
                        : 'Không có thành viên phù hợp.',
                    key: const Key('group-member-empty'),
                  ),
                ),
              for (final m in filteredMembers)
                ListTile(
                  key: Key('group-member-${m.identifier}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(m.name),
                  subtitle: const Text('Đang tham gia'),
                ),
            ],
            if (g.requiresApproval) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in const {
                    'all': 'Tất cả',
                    'pending': 'Chờ duyệt',
                    'approved': 'Đã duyệt',
                    'rejected': 'Từ chối',
                    'withdrawn': 'Đã rời / rút',
                    'removed': 'Đã thu hồi',
                  }.entries)
                    ChoiceChip(
                      key: Key('group-members-filter-${e.key}'),
                      label: Text(
                        '${e.value} (${e.key == 'all' ? requests.length : requests.where((r) => r.state == e.key).length})',
                      ),
                      selected: _memberState == e.key,
                      onSelected: (_) => setState(() => _memberState = e.key),
                    ),
                ],
              ),
              if (requests.isEmpty) const Text('Chưa có yêu cầu tham gia.'),
              if (requests.isNotEmpty && filteredRequests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Không có thành viên phù hợp.',
                    key: Key('group-member-empty'),
                  ),
                ),
              for (final request in filteredRequests) ...[
                ListTile(
                  key: Key('group-request-${request.member}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.groupMemberName(request.member)),
                  subtitle: Text(
                    '${request.label}${request.note.isEmpty ? '' : '\n${request.note}'}',
                  ),
                ),
                if (['approved', 'suspended'].contains(g.state) &&
                    request.state == 'approved')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: Key('group-member-remove-${request.member}'),
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Thu hồi tư cách'),
                      onPressed: _busy
                          ? null
                          : () => _reviewMember(request, false, remove: true),
                    ),
                  ),
                if (g.state == 'approved' && request.state == 'pending')
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: Key('group-member-approve-${request.member}'),
                        onPressed: _busy
                            ? null
                            : () => _reviewMember(request, true),
                        icon: const Icon(Icons.check),
                        label: const Text('Duyệt'),
                      ),
                      OutlinedButton.icon(
                        key: Key('group-member-reject-${request.member}'),
                        onPressed: _busy
                            ? null
                            : () => _reviewMember(request, false),
                        icon: const Icon(Icons.close),
                        label: const Text('Từ chối'),
                      ),
                    ],
                  ),
              ],
            ],
            if (g.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Lý do: ${g.note}'),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            if (s.role == DemoRole.owner &&
                ['draft', 'rejected'].contains(g.state))
              OutlinedButton.icon(
                key: const Key('play-group-edit'),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlayGroupFormScreen(session: s, group: g),
                        ),
                      ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa'),
              ),
            for (final e
                in (s.role == DemoRole.owner
                        ? (g.state == 'draft'
                              ? {'pending': 'Gửi duyệt'}
                              : <String, String>{})
                        : (g.state == 'pending'
                              ? {
                                  'approved': 'Duyệt nhóm',
                                  'rejected': 'Từ chối',
                                }
                              : g.state == 'approved'
                              ? {'suspended': 'Tạm ngưng nhóm'}
                              : g.state == 'suspended'
                              ? {'approved': 'Mở lại nhóm'}
                              : <String, String>{}))
                    .entries)
              FilledButton(
                key: Key('play-group-action-${e.key}'),
                onPressed: _busy ? null : () => _change(g, e.key, e.value),
                child: Text(e.value),
              ),
          ],
        ),
      );
    },
  );
}
