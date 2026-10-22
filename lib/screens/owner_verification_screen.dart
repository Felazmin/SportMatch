import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../auth/demo_session.dart';
import '../demo/demo_finance.dart';
import 'finance_screen.dart';

class OwnerVerificationScreen extends StatefulWidget {
  const OwnerVerificationScreen({
    super.key,
    required this.session,
    this.pickImage,
  });
  final DemoSession session;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<OwnerVerificationScreen> createState() =>
      _OwnerVerificationScreenState();
}

class _OwnerVerificationScreenState extends State<OwnerVerificationScreen> {
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _note = TextEditingController(),
      _password = TextEditingController();
  String _proof = '', _error = '';
  int _revision = 0;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final s = widget.session;
    if (s.initialized && s.user != null && s.role != DemoRole.player) {
      final v = s.ownerVerification;
      _name.text = v?.name ?? s.user!.name;
      _phone.text = v?.phone ?? DemoSession.phone;
      _proof = v?.proof ?? '';
      _revision = v?.revision ?? 0;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _note, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    final actor = widget.session.user?.identifier;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.pickImage?.call() ?? ProofPicker.pick());
      if (mounted &&
          bytes != null &&
          widget.session.user?.identifier == actor) {
        setState(() => _proof = encodeProof(bytes));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể chọn ảnh. Thử ảnh khác.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _perform({bool? approve}) async {
    if (_busy) return;
    final s = widget.session, actor = s.user?.identifier;
    final revision = s.role == DemoRole.admin
        ? s.ownerVerification?.revision ?? 0
        : _revision;
    final confirmed = await financeConfirm(
      context,
      approve == null
          ? 'Gửi hồ sơ?'
          : approve
          ? 'Xác minh chủ sân?'
          : 'Yêu cầu bổ sung hồ sơ?',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (s.user?.identifier != actor) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      if (approve == null) {
        s.submitOwnerVerification(
          name: _name.text,
          phone: _phone.text,
          proof: _proof,
          expectedRevision: revision,
        );
      } else {
        s.reviewOwnerVerification(
          approve: approve,
          expectedRevision: revision,
          password: _password.text,
          note: _note.text,
        );
      }
      _revision = s.ownerVerification!.revision;
      _password.clear();
      _note.clear();
      await s.flush();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      _password.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!s.initialized || s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Hồ sơ chủ sân'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final v = s.ownerVerification, admin = s.role == DemoRole.admin;
      final editable = !admin && (v == null || v.state == 'rejected');
      final proof = editable ? _proof : v?.proof ?? '';
      return Scaffold(
        appBar: financeBar('Hồ sơ chủ sân'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            const Text(
              'Chủ sân demo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const Text(DemoSession.ownerEmail),
            Text(
              v?.label ?? 'Chưa gửi hồ sơ',
              key: const Key('owner-verification-state'),
            ),
            if (v?.note.isNotEmpty ?? false) Text('Lý do: ${v!.note}'),
            const SizedBox(height: 16),
            if (editable) ...[
              TextField(
                key: const Key('owner-verification-name'),
                controller: _name,
                enabled: !_busy,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Người đại diện'),
              ),
              TextField(
                key: const Key('owner-verification-phone'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
            ] else if (v != null) ...[
              Text(v.name),
              Text(v.phone),
            ],
            const SizedBox(height: 16),
            if (proof.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  decodeProof(proof),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 200,
                    child: Center(child: Text('Không thể mở ảnh hồ sơ.')),
                  ),
                ),
              ),
            if (editable) ...[
              OutlinedButton.icon(
                key: const Key('owner-verification-proof'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Ảnh hồ sơ demo'),
              ),
              FilledButton.icon(
                key: const Key('owner-verification-submit'),
                onPressed: _busy ? null : () => _perform(),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Gửi xác minh'),
              ),
            ],
            if (admin &&
                v != null &&
                ['pending', 'verified'].contains(v.state)) ...[
              const Divider(height: 32),
              TextField(
                key: const Key('owner-verification-note'),
                controller: _note,
                enabled: !_busy,
                maxLength: 300,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Lý do yêu cầu bổ sung',
                ),
              ),
              TextField(
                key: const Key('owner-verification-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu Admin'),
              ),
              const SizedBox(height: 16),
              if (v.state == 'pending')
                FilledButton.icon(
                  key: const Key('owner-verification-approve'),
                  onPressed: _busy ? null : () => _perform(approve: true),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Xác minh demo'),
                ),
              OutlinedButton.icon(
                key: const Key('owner-verification-reject'),
                onPressed: _busy ? null : () => _perform(approve: false),
                icon: const Icon(Icons.edit_note),
                label: const Text('Yêu cầu bổ sung'),
              ),
            ],
            if (_error.isNotEmpty)
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}
