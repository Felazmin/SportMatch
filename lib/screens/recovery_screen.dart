import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../auth/demo_recovery.dart';
import '../widgets/design.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    required this.session,
    this.identifier = '',
  });
  final DemoSession session;
  final String identifier;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  late final _id = TextEditingController(text: widget.identifier);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  DemoRecovery? _recovery;
  int _step = 0;
  bool _busy = false;
  bool _hidden = true;
  String? _error;
  Timer? _timer;
  late final String? _openingActor;
  String? _resultActor;
  bool _committed = false;
  bool get _sameActor =>
      widget.session.user?.identifier ==
      (_committed ? _resultActor : _openingActor);
  @override
  void initState() {
    super.initState();
    _openingActor = widget.session.user?.identifier;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _step == 1) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_id, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _request() {
    if (!_sameActor || _busy) return;
    try {
      final recovery = widget.session.beginDemoRecovery(_id.text);
      setState(() {
        _recovery = recovery;
        _step = 1;
        _error = null;
        _code.clear();
      });
      FocusScope.of(context).unfocus();
    } on StateError catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _verify() {
    if (!_sameActor || _busy) return;
    try {
      widget.session.verifyDemoRecovery(_recovery!, _code.text);
      setState(() {
        _step = 2;
        _error = null;
      });
    } on StateError catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _reset() async {
    if (_busy || !_sameActor) return;
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Mật khẩu xác nhận chưa khớp.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.resetDemoPassword(_recovery!, _password.text);
      _committed = true;
      _resultActor = widget.session.user?.identifier;
      await widget.session.flush();
      if (mounted && _sameActor) setState(() => _step = 3);
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retrySave() async {
    if (_busy || !_sameActor) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await widget.session.retrySave();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_sameActor && widget.session.saveFailed) {
        _error = 'Chưa lưu được mật khẩu mới. Vui lòng thử lưu lại.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      if (!_sameActor) {
        return Scaffold(
          appBar: AppBar(title: const Text('Khôi phục mật khẩu')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Phiên tài khoản đã thay đổi. Vui lòng mở lại khôi phục mật khẩu.',
              ),
            ),
          ),
        );
      }
      final seconds = _recovery == null
          ? 0
          : _recovery!.resendAt
                .difference(widget.session.now)
                .inSeconds
                .clamp(0, 60);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Khôi phục mật khẩu'),
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              [
                'Tài khoản cần khôi phục',
                'Xác nhận mã demo',
                'Mật khẩu mới',
                'Đã đổi mật khẩu',
              ][_step],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mô phỏng trên thiết bị, không gửi SMS/email và không xác minh danh tính thực. Chỉ dùng tài khoản thử nghiệm.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (_step == 0) ...[
              TextField(
                key: const Key('recovery-identifier'),
                controller: _id,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại hoặc email',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('recovery-request'),
                onPressed: _request,
                child: const Text('Tạo mã demo'),
              ),
            ],
            if (_step == 1) ...[
              const Text(
                'Mã thử nghiệm: ${DemoRecovery.code}',
                key: Key('recovery-demo-code'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              Text(
                widget.session.now.isBefore(_recovery!.expires)
                    ? 'Mã có hiệu lực 5 phút.'
                    : 'Mã đã hết hạn.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('recovery-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(labelText: 'Mã 6 số'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('recovery-verify'),
                onPressed: _verify,
                child: const Text('Xác nhận mã'),
              ),
              TextButton(
                key: const Key('recovery-resend'),
                onPressed: seconds > 0 ? null : _request,
                child: Text(
                  seconds > 0 ? 'Tạo mã mới sau $seconds giây' : 'Tạo mã mới',
                ),
              ),
            ],
            if (_step == 2) ...[
              TextField(
                key: const Key('recovery-password'),
                enabled: !_busy && !_committed,
                controller: _password,
                obscureText: _hidden,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  helperText: '8–128 ký tự, có chữ và số',
                  helperMaxLines: 3,
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('recovery-confirm'),
                enabled: !_busy && !_committed,
                controller: _confirm,
                obscureText: _hidden,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('recovery-reset'),
                onPressed: _busy ? null : _reset,
                child: Text(_busy ? 'Đang lưu...' : 'Đổi mật khẩu'),
              ),
              TextButton(
                onPressed: _busy || _committed
                    ? null
                    : () => setState(() {
                        _step = 1;
                        _error = null;
                      }),
                child: const Text('Quay lại mã xác nhận'),
              ),
            ],
            if (_step == 3) ...[
              if (widget.session.saveFailed) ...[
                const Text(
                  'Mật khẩu đã cập nhật nhưng chưa lưu được. Đừng đóng ứng dụng.',
                  style: TextStyle(color: Colors.red),
                ),
                TextButton.icon(
                  key: const Key('recovery-retry-save'),
                  onPressed: _busy ? null : _retrySave,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lưu lại'),
                ),
              ] else
                const Text(
                  'Mật khẩu mới đã được lưu trên thiết bị. Dùng mật khẩu mới để đăng nhập.',
                ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('recovery-done'),
                onPressed: _busy || !_sameActor
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Về đăng nhập'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  key: const Key('recovery-error'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      );
    },
  );
}
