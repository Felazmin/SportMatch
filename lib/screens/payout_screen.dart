import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_payout.dart';
import '../demo/demo_finance.dart';
import 'finance_screen.dart';

class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  final _amount = TextEditingController(), _password = TextEditingController();
  String _error = '';
  bool _busy = false;
  @override
  void dispose() {
    _amount.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy) return;
    final s = widget.session, actor = s.user?.identifier;
    final balance = s.payoutBalance, revision = s.payoutAccount?.revision ?? 0;
    final amount = int.tryParse(_amount.text) ?? 0;
    if (!await financeConfirm(
          context,
          'Gửi yêu cầu chi trả demo?',
          bookingMoney(amount),
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (s.user?.identifier != actor) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      s.requestPayout(
        amount,
        expectedBalance: balance,
        expectedAccountRevision: revision,
        password: _password.text,
      );
      _amount.clear();
      _password.clear();
      await s.flush();
    } on StateError catch (e) {
      _error = e.message;
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
        return _denied();
      }
      final account = s.payoutAccount, balance = s.payoutBalance;
      return Scaffold(
        appBar: financeBar('Chi trả demo'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              balance < 0 ? 'Thiếu hụt demo' : 'Khả dụng demo',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              bookingMoney(balance.abs()),
              key: const Key('payout-balance'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const Divider(height: 32),
            if (account == null)
              const Text('Chưa có tài khoản nhận tiền.')
            else ...[
              Text(account.bank),
              Text(account.holder),
              Text(account.masked),
            ],
            if (s.role == DemoRole.owner) ...[
              OutlinedButton.icon(
                key: const Key('payout-account-edit'),
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('Tài khoản nhận tiền'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayoutAccountScreen(session: s),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('payout-amount'),
                controller: _amount,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số tiền yêu cầu'),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('payout-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu Chủ sân',
                ),
              ),
              FilledButton.icon(
                key: const Key('payout-request'),
                onPressed: _busy || account == null || balance < 1000
                    ? null
                    : _request,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Yêu cầu chi trả demo'),
              ),
            ],
            if (_error.isNotEmpty)
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Divider(height: 32),
            const Text(
              'Lịch sử chi trả',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (s.payouts.isEmpty) const Text('Chưa có yêu cầu chi trả.'),
            for (final p in s.payouts)
              ListTile(
                key: Key('payout-${p.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text('${p.id} · ${bookingMoney(p.amount)}'),
                subtitle: Text(
                  '${p.label}\n${p.account.bank} · ${p.account.masked}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayoutDetailScreen(session: s, id: p.id),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget _denied() => Scaffold(
  appBar: financeBar('Chi trả demo'),
  body: const Center(child: Text('Cần tài khoản quản lý.')),
);

class PayoutAccountScreen extends StatefulWidget {
  const PayoutAccountScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<PayoutAccountScreen> createState() => _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends State<PayoutAccountScreen> {
  final _bank = TextEditingController(),
      _holder = TextEditingController(),
      _number = TextEditingController(),
      _password = TextEditingController();
  int _revision = 0;
  String _error = '';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final s = widget.session;
    if (s.initialized && s.user != null && s.role == DemoRole.owner) {
      final a = s.payoutAccount;
      _bank.text = a?.bank ?? '';
      _holder.text = a?.holder ?? '';
      _number.text = a?.number ?? '';
      _revision = a?.revision ?? 0;
    }
  }

  @override
  void dispose() {
    for (final c in [_bank, _holder, _number, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      widget.session.savePayoutAccount(
        _bank.text,
        _holder.text,
        _number.text,
        expectedRevision: _revision,
        password: _password.text,
      );
      _revision++;
      _password.clear();
      final saved = await widget.session.flush();
      if (mounted && saved) Navigator.pop(context);
    } on StateError catch (e) {
      _error = e.message;
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
      if (!s.initialized || s.user == null || s.role != DemoRole.owner) {
        return _denied();
      }
      return Scaffold(
        appBar: financeBar('Tài khoản nhận tiền'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            TextField(
              key: const Key('payout-bank'),
              controller: _bank,
              enabled: !_busy,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Ngân hàng'),
            ),
            TextField(
              key: const Key('payout-holder'),
              controller: _holder,
              enabled: !_busy,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Chủ tài khoản'),
            ),
            TextField(
              key: const Key('payout-number'),
              controller: _number,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tài khoản'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('payout-account-password'),
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu Chủ sân'),
            ),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton.icon(
              key: const Key('payout-account-save'),
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu tài khoản'),
            ),
          ],
        ),
      );
    },
  );
}

class PayoutDetailScreen extends StatefulWidget {
  const PayoutDetailScreen({
    super.key,
    required this.session,
    required this.id,
    this.pickImage,
  });
  final DemoSession session;
  final String id;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<PayoutDetailScreen> createState() => _PayoutDetailScreenState();
}

class _PayoutDetailScreenState extends State<PayoutDetailScreen> {
  final _reference = TextEditingController(),
      _note = TextEditingController(),
      _password = TextEditingController();
  String _proof = '', _error = '';
  bool _busy = false;
  @override
  void dispose() {
    for (final c in [_reference, _note, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final actor = widget.session.user?.identifier;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.pickImage?.call() ?? ProofPicker.pick());
      if (mounted && bytes != null && widget.session.user?.identifier == actor) {
        setState(() => _proof = encodeProof(bytes));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể chọn ảnh chứng từ.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _review(DemoPayout p, bool approve) async {
    if (_busy) return;
    final actor = widget.session.user?.identifier;
    if (!await financeConfirm(
          context,
          approve ? 'Ghi nhận chứng từ chi trả demo?' : 'Từ chối chi trả?',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (widget.session.user?.identifier != actor) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      widget.session.reviewPayout(
        p.id,
        p.revision,
        approve: approve,
        password: _password.text,
        reference: _reference.text,
        proof: _proof,
        note: _note.text,
      );
      await widget.session.flush();
    } on StateError catch (e) {
      _error = e.message;
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
        return _denied();
      }
      final p = s.payouts.where((p) => p.id == widget.id).firstOrNull;
      if (p == null) {
        return Scaffold(
          appBar: financeBar('Chi trả demo'),
          body: const Center(child: Text('Không có yêu cầu.')),
        );
      }
      final proof = p.state == 'recorded' ? p.proof : _proof;
      return Scaffold(
        appBar: financeBar(p.id),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              bookingMoney(p.amount),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            Text(p.label, key: const Key('payout-status')),
            Text(p.account.bank),
            Text(p.account.holder),
            SelectableText(
              s.role == DemoRole.admin ? p.account.number : p.account.masked,
            ),
            if (p.reference.isNotEmpty) Text('Mã chứng từ: ${p.reference}'),
            if (p.note.isNotEmpty) Text('Lý do: ${p.note}'),
            const SizedBox(height: 16),
            if (proof.isNotEmpty)
              Image.memory(
                decodeProof(proof),
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 200,
                  child: Center(child: Text('Không thể mở ảnh chứng từ.')),
                ),
              ),
            if (s.role == DemoRole.admin && p.state == 'pending') ...[
              TextField(
                key: const Key('payout-reference'),
                controller: _reference,
                enabled: !_busy,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Mã chứng từ'),
              ),
              OutlinedButton.icon(
                key: const Key('payout-proof'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Ảnh chứng từ demo'),
              ),
              TextField(
                key: const Key('payout-note'),
                controller: _note,
                enabled: !_busy,
                maxLength: 300,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Lý do từ chối'),
              ),
              TextField(
                key: const Key('payout-admin-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu Admin'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('payout-record'),
                onPressed: _busy ? null : () => _review(p, true),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ghi nhận chứng từ demo'),
              ),
              OutlinedButton.icon(
                key: const Key('payout-reject'),
                onPressed: _busy ? null : () => _review(p, false),
                icon: const Icon(Icons.close),
                label: const Text('Từ chối'),
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
