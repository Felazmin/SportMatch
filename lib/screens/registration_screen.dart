import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../auth/demo_registration.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.session,
    required this.challenge,
  });
  final DemoSession session;
  final DemoRegistration challenge;
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late DemoRegistration _challenge = widget.challenge;
  final _code = TextEditingController();
  late final Timer _timer;
  bool _busy = false;
  bool _done = false;
  String? _error;
  late final String? _openingActor;
  String? _completedActor;
  bool get _sameActor =>
      widget.session.user?.identifier == (_completedActor ?? _openingActor);
  @override
  void initState() {
    super.initState();
    _openingActor = widget.session.user?.identifier;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_done) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _code.dispose();
    widget.session.cancelDemoRegistration(_challenge);
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _done) return;
    if (!_sameActor) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.completeDemoRegistration(_challenge, _code.text);
      _completedActor = widget.session.user?.identifier;
      _timer.cancel();
      await widget.session.flush();
      if (mounted && _sameActor) setState(() => _done = true);
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resend() {
    if (!_sameActor || _busy) return;
    try {
      final challenge = widget.session.resendDemoRegistration(_challenge);
      setState(() {
        _challenge = challenge;
        _error = null;
        _code.clear();
      });
    } on StateError catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _continue() async {
    if (_busy || !_sameActor) return;
    if (widget.session.saveFailed &&
        !await financeConfirm(
          context,
          'Tiếp tục khi chưa lưu?',
          'Tài khoản chỉ còn trong phiên hiện tại. Đóng ứng dụng có thể mất thay đổi chưa lưu.',
        )) {
      return;
    }
    if (mounted && _sameActor) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!_sameActor) {
        return Scaffold(
          appBar: AppBar(title: const Text('Xác nhận đăng ký')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Phiên tài khoản đã thay đổi. Vui lòng mở lại đăng ký.',
              ),
            ),
          ),
        );
      }
      final expired = !s.now.isBefore(_challenge.expires);
      final seconds =
          ((_challenge.resendAt.difference(s.now).inMilliseconds + 999) ~/ 1000)
              .clamp(0, 60);
      return PopScope<bool>(
        canPop: !_busy && !_done,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 24
                ? 104
                : 56,
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            title: Text(
              _done
                  ? 'Xác nhận thành công'
                  : expired
                  ? 'Mã OTP đã hết hạn'
                  : 'Xác nhận đăng ký',
              maxLines: 2,
              style: const TextStyle(fontSize: 18, height: 1.2),
            ),
            leading: IconButton(
              tooltip: 'Quay lại',
              icon: const Icon(Icons.arrow_back),
              onPressed: _busy
                  ? null
                  : _done
                  ? _continue
                  : () => Navigator.pop(context, false),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FinanceSaveNotice(session: s),
              const Text(
                'OTP demo trên thiết bị, không gửi SMS/email và không xác minh danh tính thật. Chỉ dùng thông tin thử nghiệm.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              Text(
                _challenge.identifier,
                key: const Key('registration-target'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              if (!_done) ...[
                const Text(
                  'Mã thử nghiệm: ${DemoRegistration.code}',
                  key: Key('registration-demo-code'),
                  style: TextStyle(
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  expired
                      ? 'Mã đã hết hạn. Tạo mã mới để tiếp tục.'
                      : 'Mã có hiệu lực 5 phút. Tối đa 5 lần nhập sai.',
                  key: const Key('registration-status'),
                ),
                const SizedBox(height: 20),
                const Text('Mã 6 số'),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('registration-code'),
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verify(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(hintText: '123456'),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(
                    _error!,
                    key: const Key('registration-error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('registration-verify'),
                  onPressed: _busy || expired || _challenge.attempts >= 5
                      ? null
                      : _verify,
                  child: Text(_busy ? 'Đang xác nhận...' : 'Xác nhận mã demo'),
                ),
                OutlinedButton(
                  key: const Key('registration-resend'),
                  onPressed: _busy || seconds > 0 ? null : _resend,
                  child: Text(
                    seconds > 0
                        ? 'Tạo mã mới sau ${seconds}s'
                        : 'Tạo mã demo mới',
                  ),
                ),
                TextButton(
                  key: const Key('registration-change'),
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Sửa thông tin đăng ký'),
                ),
              ] else ...[
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.green,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  s.saveFailed
                      ? 'Đã xác nhận, tài khoản đang chờ lưu.'
                      : 'Tài khoản demo đã được tạo và lưu.',
                  key: const Key('registration-success'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('registration-continue'),
                  onPressed: _continue,
                  child: Text(
                    s.saveFailed
                        ? 'Tiếp tục trong phiên hiện tại'
                        : 'Tiếp tục trải nghiệm',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
