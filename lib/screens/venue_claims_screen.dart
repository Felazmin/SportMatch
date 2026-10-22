import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../demo/demo_finance.dart' show encodeProof, decodeProof;
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';
import 'venue_map_screen.dart';
import 'facilities_screen.dart';

AppBar _claimBar(
  BuildContext context,
  String title, {
  PreferredSizeWidget? bottom,
}) => AppBar(
  title: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 96 : 56,
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
  bottom: bottom,
);

class VenueClaimsScreen extends StatefulWidget {
  const VenueClaimsScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<VenueClaimsScreen> createState() => _VenueClaimsScreenState();
}

class _VenueClaimsScreenState extends State<VenueClaimsScreen> {
  String _query = '', _state = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final admin = s.role == DemoRole.admin;
      if (!s.initialized ||
          s.user == null ||
          (!admin && s.role != DemoRole.owner)) {
        return Scaffold(
          appBar: financeBar('Quyền quản lý sân'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final claims = s.venueClaims
          .where(
            (c) =>
                (_state == 'all' || c.state == _state) &&
                venueSearchText(
                  '${c.venueName} ${c.address} ${c.contact} ${c.phone}',
                ).contains(venueSearchText(_query)),
          )
          .toList();
      final venues = filterVenues(
        venues: s.currentVenues.where((v) => v.isImported),
        query: _query,
        maxPrice: 1000000,
        sort: VenueSort.name,
      );
      void open(String venueId, [String? claimKey]) => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => VenueClaimScreen(
            session: s,
            venueId: venueId,
            claimKey: claimKey,
          ),
        ),
      );
      final history = ListView.builder(
        itemCount: claims.isEmpty ? 1 : claims.length,
        itemBuilder: (context, i) => claims.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có yêu cầu phù hợp.'),
              )
            : ListTile(
                key: Key('venue-claim-${claims[i].key}'),
                leading: Icon(
                  claims[i].state == 'approved'
                      ? Icons.verified_outlined
                      : Icons.assignment_outlined,
                ),
                title: Text(claims[i].venueName),
                subtitle: Text(
                  '${claims[i].label}\n${claims[i].contact} · ${claims[i].phone}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(claims[i].venueId, claims[i].key),
              ),
      );
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: _claimBar(
            context,
            'Quyền quản lý sân',
            bottom: admin
                ? null
                : TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(
                        height: MediaQuery.textScalerOf(context).scale(1) > 1.4
                            ? 88
                            : 48,
                        child: const Text(
                          'Yêu cầu của tôi',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Tab(
                        height: MediaQuery.textScalerOf(context).scale(1) > 1.4
                            ? 88
                            : 48,
                        child: const Text(
                          'Sân có sẵn',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    FinanceSaveNotice(session: s),
                    TextField(
                      key: const Key('venue-claims-search'),
                      decoration: const InputDecoration(
                        labelText: 'Tìm tên sân, địa chỉ',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _state,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái yêu cầu',
                      ),
                      items: [
                        for (final e in const {
                          'all': 'Tất cả',
                          'pending': 'Chờ duyệt',
                          'approved': 'Đã duyệt',
                          'rejected': 'Đã từ chối',
                          'withdrawn': 'Đã rút',
                        }.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _state = v ?? 'all'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: admin
                    ? history
                    : TabBarView(
                        children: [
                          history,
                          ListView.builder(
                            itemCount: venues.isEmpty ? 1 : venues.length,
                            itemBuilder: (context, i) {
                              if (venues.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Không tìm thấy sân.'),
                                );
                              }
                              final v = venues[i], own = s.ownVenueClaim(v.id);
                              final occupied =
                                  s.venueHasClaim(v.id) && own == null;
                              return ListTile(
                                key: Key('claim-catalog-${v.id}'),
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(v.name),
                                subtitle: Text(
                                  '${v.addressLabel}\n${own?.label ?? (occupied ? 'Đã có hồ sơ quản lý' : 'Chưa có hồ sơ quản lý')}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                enabled: !occupied,
                                onTap: () => open(v.id),
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class VenueClaimScreen extends StatefulWidget {
  const VenueClaimScreen({
    super.key,
    required this.session,
    required this.venueId,
    this.claimKey,
    this.pickImage,
  });
  final DemoSession session;
  final String venueId;
  final String? claimKey;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<VenueClaimScreen> createState() => _VenueClaimScreenState();
}

class _VenueClaimScreenState extends State<VenueClaimScreen> {
  final _contact = TextEditingController(),
      _phone = TextEditingController(),
      _explanation = TextEditingController(),
      _note = TextEditingController(),
      _password = TextEditingController();
  late final String? _actor;
  String _proof = '', _error = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _actor = s.user?.identifier;
    if (s.initialized && s.user != null && s.role == DemoRole.owner) {
      final c = s.ownVenueClaim(widget.venueId);
      _contact.text = c?.contact ?? s.user!.name;
      _phone.text = c?.phone ?? '';
      _explanation.text = c?.explanation ?? '';
      _proof = c?.proof ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_contact, _phone, _explanation, _note, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.pickImage?.call() ?? ProofPicker.pick());
      if (mounted &&
          bytes != null &&
          widget.session.user?.identifier == _actor) {
        setState(() => _proof = encodeProof(bytes));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể đọc ảnh. Chọn ảnh khác.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _perform(String action, int revision, String? key) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final confirmed = await financeConfirm(
        context,
        switch (action) {
          'submit' => 'Gửi yêu cầu quản lý sân?',
          'withdraw' => 'Rút yêu cầu quản lý sân?',
          'approve' => 'Duyệt quyền quản lý sân?',
          _ => 'Từ chối yêu cầu quản lý sân?',
        },
        'Thay đổi được lưu trong bản demo trên thiết bị này. '
        'Không thay thế việc xác minh quyền quản lý cơ sở ngoài thực tế.',
      );
      if (!confirmed || !mounted) return;
      final s = widget.session;
      if (s.user?.identifier != _actor) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      if (action == 'submit') {
        s.submitVenueClaim(
          venueId: widget.venueId,
          contact: _contact.text,
          phone: _phone.text,
          explanation: _explanation.text,
          proof: _proof,
          expectedRevision: revision,
        );
      } else if (action == 'withdraw') {
        s.withdrawVenueClaim(widget.venueId, expectedRevision: revision);
      } else {
        s.reviewVenueClaim(
          key!,
          approve: action == 'approve',
          expectedRevision: revision,
          password: _password.text,
          note: _note.text,
        );
      }
      await s.flush();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final admin = s.role == DemoRole.admin;
      if (!s.initialized ||
          s.user == null ||
          s.user!.identifier != _actor ||
          (!admin && s.role != DemoRole.owner)) {
        return Scaffold(
          appBar: financeBar('Hồ sơ quản lý sân'),
          body: const Center(child: Text('Không có quyền xem hồ sơ.')),
        );
      }
      final claim = admin
          ? s.venueClaims
                .where(
                  (c) =>
                      c.key == widget.claimKey && c.venueId == widget.venueId,
                )
                .firstOrNull
          : s.ownVenueClaim(widget.venueId);
      final venue = s.currentVenues
          .where((v) => v.id == widget.venueId && v.isImported)
          .firstOrNull;
      if ((venue == null && claim == null) || (admin && claim == null)) {
        return Scaffold(
          appBar: financeBar('Hồ sơ quản lý sân'),
          body: const Center(
            child: Text('Không tìm thấy hồ sơ hoặc địa điểm.'),
          ),
        );
      }
      final editable =
          !admin &&
          venue != null &&
          (claim == null || ['rejected', 'withdrawn'].contains(claim.state)) &&
          !s.venueHasClaim(widget.venueId);
      final proof = editable ? _proof : claim?.proof ?? '';
      final revision = claim?.revision ?? 0;
      final facility = claim?.state == 'approved'
          ? s.claimedFacility(widget.venueId)
          : null;
      return Scaffold(
        appBar: _claimBar(
          context,
          admin ? 'Duyệt quyền quản lý' : 'Yêu cầu quản lý sân',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              claim?.venueName ?? venue!.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(claim?.address ?? venue!.addressLabel),
            TextButton.icon(
              icon: const Icon(Icons.near_me_outlined),
              label: const Text('Đối chiếu vị trí sân'),
              onPressed: () => openVenueMap(
                context,
                venue?.mapQuery ?? '${claim!.latitude},${claim.longitude}',
              ),
            ),
            const Divider(height: 24),
            Text(
              claim?.label ??
                  (editable ? 'Chưa gửi yêu cầu' : 'Đã có hồ sơ quản lý'),
              key: const Key('venue-claim-state'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (claim != null) ...[
              Text(
                'Cập nhật: ${claim.updated.day}/${claim.updated.month}/${claim.updated.year}',
              ),
              if (claim.note.isNotEmpty) Text('Lý do từ chối: ${claim.note}'),
              if (claim.state == 'approved')
                Text(
                  facility?.published != null && !facility!.suspended
                      ? 'Sân đã mở nhận lịch trong bản demo.'
                      : 'Đã duyệt quyền quản lý. Hồ sơ vận hành cần được duyệt trước khi nhận lịch.',
                ),
              if (!admin && claim.state == 'approved')
                FilledButton.icon(
                  key: const Key('venue-claim-configure'),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(
                    facility == null
                        ? 'Cấu hình sân để nhận lịch'
                        : 'Mở hồ sơ vận hành',
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => facility == null
                          ? FacilityFormScreen(
                              session: s,
                              claimVenueId: widget.venueId,
                            )
                          : FacilityDetailScreen(
                              session: s,
                              facility: facility,
                            ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (editable) ...[
              TextField(
                key: const Key('venue-claim-contact'),
                controller: _contact,
                enabled: !_busy,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Người đại diện *',
                ),
              ),
              TextField(
                key: const Key('venue-claim-phone'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại liên hệ *',
                ),
              ),
              TextField(
                key: const Key('venue-claim-explanation'),
                controller: _explanation,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Căn cứ quản lý sân *',
                ),
              ),
            ] else if (claim != null) ...[
              Text('Người đại diện: ${claim.contact}'),
              Text('Liên hệ: ${claim.phone}'),
              const SizedBox(height: 12),
              Text(claim.explanation),
            ],
            const SizedBox(height: 12),
            if (proof.isNotEmpty)
              Image.memory(
                decodeProof(proof),
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Text('Không thể hiển thị ảnh minh chứng.'),
              ),
            if (editable) ...[
              OutlinedButton.icon(
                key: const Key('venue-claim-proof'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Ảnh giấy tờ / minh chứng *'),
              ),
              const Text(
                'Ảnh JPG/PNG tối đa 400 KB. Không gửi giấy tờ cá nhân nhạy cảm trong bản demo.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('venue-claim-submit'),
                onPressed: _busy
                    ? null
                    : () => _perform('submit', revision, null),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Gửi yêu cầu quản lý'),
              ),
            ],
            if (!admin && claim?.state == 'pending')
              OutlinedButton.icon(
                key: const Key('venue-claim-withdraw'),
                icon: const Icon(Icons.undo),
                label: const Text('Rút yêu cầu'),
                onPressed: _busy
                    ? null
                    : () => _perform('withdraw', revision, null),
              ),
            if (admin && claim?.state == 'pending') ...[
              const Divider(height: 24),
              TextField(
                key: const Key('venue-claim-note'),
                controller: _note,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Lý do từ chối'),
              ),
              TextField(
                key: const Key('venue-claim-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu Admin *',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('venue-claim-approve'),
                onPressed: _busy
                    ? null
                    : () => _perform('approve', revision, claim!.key),
                icon: const Icon(Icons.check),
                label: const Text('Duyệt quyền quản lý'),
              ),
              OutlinedButton.icon(
                key: const Key('venue-claim-reject'),
                onPressed: _busy
                    ? null
                    : () => _perform('reject', revision, claim!.key),
                icon: const Icon(Icons.close),
                label: const Text('Từ chối yêu cầu'),
              ),
            ],
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error,
                  key: const Key('venue-claim-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      );
    },
  );
}
