import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../widgets/design.dart';
import 'recovery_screen.dart';
import 'management_screen.dart';
import 'registration_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session, this.register = false});
  final DemoSession session;
  final bool register;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool get _stackSocial => MediaQuery.textScalerOf(context).scale(12) > 18;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late bool _register = widget.register;
  bool _email = false;
  bool _obscure = true;
  bool _obscureConfirmation = true;
  bool _consent = false;
  bool _submitting = false;
  String? _pendingActor;
  bool get _locked => _submitting || _pendingActor != null;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _identifier, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_pendingActor != null) {
      await _saveLogin(_pendingActor!, retry: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (_register && !_consent) {
      setState(
        () => _error =
            'Vui lòng đồng ý với điều khoản và chính sách quyền riêng tư.',
      );
      return;
    }
    if (_register) {
      setState(() => _submitting = true);
      try {
        final challenge = widget.session.beginDemoRegistration(
          _name.text,
          _identifier.text,
          _password.text,
        );
        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationScreen(
              session: widget.session,
              challenge: challenge,
            ),
          ),
        );
        if (mounted && success == true) Navigator.pop(context, true);
      } on StateError catch (e) {
        if (mounted) setState(() => _error = e.message);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }
    final success = widget.session.login(_identifier.text, _password.text);
    if (success) {
      await _saveLogin(widget.session.user!.identifier);
    } else {
      setState(
        () => _error = _register
            ? 'Số điện thoại hoặc email này đã được đăng ký.'
            : 'Số điện thoại, email hoặc mật khẩu chưa đúng.',
      );
    }
  }

  Future<void> _saveLogin(String actor, {bool retry = false}) async {
    if (widget.session.user?.identifier != actor) {
      setState(() {
        _pendingActor = null;
        _error = 'Phiên tài khoản đã thay đổi. Vui lòng đăng nhập lại.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    if (retry) await widget.session.retrySave();
    final saved = await widget.session.flush();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (widget.session.user?.identifier != actor) {
      setState(() {
        _pendingActor = null;
        _error = 'Phiên tài khoản đã thay đổi. Vui lòng đăng nhập lại.';
      });
      return;
    }
    if (!saved) {
      setState(() {
        _pendingActor = actor;
        _error = 'Chưa lưu được phiên đăng nhập. Vui lòng thử lưu lại.';
      });
      return;
    }
    Navigator.pop(context, true);
  }

  void _notice(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  Transform.translate(
                    offset: const Offset(0, -41),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _formCard(),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          _register ? 'Đã có tài khoản?' : 'Chưa có tài khoản?',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                          ),
                        ),
                        TextButton(
                          onPressed: _locked
                              ? null
                              : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                  _form.currentState?.reset();
                                }),
                          child: Text(
                            _register ? 'Đăng nhập' : 'Đăng ký ngay',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Container(
    color: AppColors.green,
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned(right: -34, top: 22, child: SvgHeaderDecoration()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 41),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Quay lại',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x1FFFFFFF),
                        fixedSize: const Size(36, 36),
                        minimumSize: const Size(36, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const DesignAsset('99550', size: 19),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DesignAsset('b7a43', size: 14),
                          SizedBox(width: 6),
                          Text(
                            'BẢO MẬT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Text(
                _register ? 'Tạo tài khoản' : 'Chào mừng trở lại',
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _register
                    ? 'Đăng ký để đặt sân nhanh hơn và nhận ưu đãi dành riêng cho bạn.'
                    : 'Đăng nhập để tiếp tục đặt sân và quản lý lịch chơi của bạn.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xD9FFFFFF),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _formCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x17162019),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 44 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final email in [false, true])
                  Expanded(
                    child: Material(
                      color: _email == email
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _locked
                            ? null
                            : () => setState(() {
                                _email = email;
                                _identifier.clear();
                                _error = null;
                                _form.currentState?.reset();
                              }),
                        child: Flex(
                          direction:
                              MediaQuery.textScalerOf(context).scale(14) > 21
                              ? Axis.vertical
                              : Axis.horizontal,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DesignAsset(
                              email ? 'bba20' : 'bc1f9',
                              size: 16,
                              color: _email == email
                                  ? AppColors.green
                                  : AppColors.muted,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                email ? 'Email' : 'Số điện thoại',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _email == email
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _email == email
                                      ? AppColors.green
                                      : AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _register
                ? (_email
                      ? 'Sử dụng email để quản lý tài khoản và lịch đặt sân.'
                      : 'Sử dụng số điện thoại chính để xác minh và quản lý lịch đặt sân.')
                : 'Nhập ${_email ? 'email' : 'số điện thoại'} và mật khẩu đã đăng ký để tiếp tục.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          if (_register) ...[
            _field(
              'Họ và tên',
              '2b6a2',
              _name,
              keyName: 'auth-name',
              hint: 'Nguyễn Minh Anh',
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Nhập họ và tên'
                  : value!.trim().length > 60
                  ? 'Họ tên tối đa 60 ký tự'
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          _field(
            _email ? 'Email' : 'Số điện thoại',
            _email ? 'bba20' : '15c58',
            _identifier,
            keyName: 'auth-identifier',
            hint: _email ? 'demo@nvh.vn' : '090 123 4567',
            keyboard: _email ? TextInputType.emailAddress : TextInputType.phone,
            validator: (value) {
              final normalized = DemoSession.normalize(value ?? '');
              if (_email) {
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(normalized)
                    ? null
                    : 'Nhập email hợp lệ';
              }
              return RegExp(r'^0[35789][0-9]{8}$').hasMatch(normalized)
                  ? null
                  : 'Nhập số điện thoại hợp lệ';
            },
            phone: !_email,
          ),
          const SizedBox(height: 12),
          _field(
            'Mật khẩu',
            '3f761',
            _password,
            keyName: 'auth-password',
            hint: '••••••••',
            obscure: _obscure,
            helper: _register ? 'Tối thiểu 8 ký tự' : null,
            suffix: IconButton(
              tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: _obscure
                  ? const DesignAsset('6117a', size: 18)
                  : const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.faint,
                    ),
            ),
            validator: (value) => (value ?? '').length < 8
                ? 'Mật khẩu cần ít nhất 8 ký tự'
                : _register && value!.length > 128
                ? 'Mật khẩu tối đa 128 ký tự'
                : null,
          ),
          const SizedBox(height: 12),
          if (_register) ...[
            _field(
              'Xác nhận mật khẩu',
              '7253f',
              _confirmation,
              keyName: 'auth-confirmation',
              hint: '••••••••',
              obscure: _obscureConfirmation,
              suffix: IconButton(
                tooltip: _obscureConfirmation
                    ? 'Hiện mật khẩu xác nhận'
                    : 'Ẩn mật khẩu xác nhận',
                onPressed: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                icon: _obscureConfirmation
                    ? const DesignAsset('6117a', size: 18)
                    : const Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.faint,
                      ),
              ),
              validator: (value) => value != _password.text
                  ? 'Mật khẩu xác nhận chưa khớp'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    key: const Key('auth-consent'),
                    value: _consent,
                    activeColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onChanged: (value) =>
                        setState(() => _consent = value ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    children: [
                      const Text(
                        'Tôi đồng ý với ',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () => _notice(
                          'Điều khoản sử dụng',
                          'Đây là bản dùng thử. Các thao tác trong ứng dụng không tạo giao dịch hoặc đặt sân thực tế.',
                        ),
                        child: const Text(
                          'Điều khoản sử dụng',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        ' và ',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.muted,
                        ),
                      ),
                      InkWell(
                        onTap: () => _notice(
                          'Chính sách quyền riêng tư',
                          'Tài khoản và dữ liệu demo được lưu mã hóa trên thiết bị, không gửi lên máy chủ. Chỉ sử dụng thông tin và mật khẩu dùng thử.',
                        ),
                        child: const Text(
                          'Chính sách quyền riêng tư.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            Text(
              _error!,
              key: const Key('auth-error'),
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const Key('auth-submit'),
              onPressed: _submitting ? null : _submit,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _submitting
                        ? 'Đang lưu...'
                        : _pendingActor != null
                        ? 'Thử lưu lại'
                        : _register
                        ? 'Đăng ký'
                        : 'Đăng nhập',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const DesignAsset('09ffc', size: 17),
                ],
              ),
            ),
          ),
          if (!_register) ...[
            TextButton(
              key: const Key('auth-staff-login'),
              onPressed: _locked
                  ? null
                  : () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StaffLoginScreen(session: widget.session),
                        ),
                      );
                      if (mounted && result == true) {
                        Navigator.pop(context, true);
                      }
                    },
              child: const Text('Dành cho Chủ sân / Admin'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height:
                  46 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 3,
              child: FilledButton(
                onPressed: () => _notice(
                  'Face ID',
                  'Đăng nhập sinh trắc học chưa được hỗ trợ trong bản demo.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE6F6EC),
                  foregroundColor: AppColors.green,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DesignAsset('88c7b', size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Đăng nhập bằng Face ID',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecoveryScreen(
                    session: widget.session,
                    identifier: _identifier.text,
                  ),
                ),
              ),
              child: const Text(
                'Quên mật khẩu?',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Row(
              children: [
                Expanded(child: Divider(color: AppColors.border)),
                SizedBox(width: 12),
                Text(
                  'HOẶC TIẾP TỤC VỚI',
                  style: TextStyle(fontSize: 10, color: AppColors.faint),
                ),
                SizedBox(width: 12),
                Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 12),
            Flex(
              direction: _stackSocial ? Axis.vertical : Axis.horizontal,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final provider in ['Apple', 'Google', 'Facebook']) ...[
                  if (provider != 'Apple')
                    SizedBox(
                      width: _stackSocial ? 0 : 8,
                      height: _stackSocial ? 8 : 0,
                    ),
                  Flexible(
                    flex: _stackSocial ? 0 : 1,
                    fit: FlexFit.tight,
                    child: SizedBox(
                      width: _stackSocial ? double.infinity : null,
                      height:
                          50 +
                          (MediaQuery.textScalerOf(context).scale(12) - 12) * 4,
                      child: OutlinedButton(
                        onPressed: () => _notice(
                          provider,
                          'Đăng nhập $provider chưa được hỗ trợ trong bản demo.',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          side: const BorderSide(color: Color(0xFFE3E8EC)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _socialContent(provider),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _socialContent(String provider) => LayoutBuilder(
    builder: (context, constraints) {
      final icon = provider == 'Google'
          ? const Text(
              'G',
              style: TextStyle(
                fontSize: 18,
                height: 1,
                color: Color(0xFF4285F4),
                fontWeight: FontWeight.w800,
              ),
            )
          : DesignAsset(provider == 'Apple' ? '17b7c' : '0a9d8', size: 18);
      final label = Text(
        provider,
        style: const TextStyle(
          fontSize: 12,
          height: 1.2,
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
      );
      if (constraints.maxWidth <
          94 * MediaQuery.textScalerOf(context).scale(12) / 12) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 4),
            Flexible(child: label),
          ],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(child: label),
        ],
      );
    },
  );

  Widget _field(
    String label,
    String icon,
    TextEditingController controller, {
    required String keyName,
    required String hint,
    String? helper,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    Widget? suffix,
    bool obscure = false,
    bool phone = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (helper != null)
            Flexible(
              child: Text(
                helper,
                style: const TextStyle(fontSize: 11, color: AppColors.faint),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      TextFormField(
        key: Key(keyName),
        enabled: !_locked,
        controller: controller,
        validator: validator,
        obscureText: obscure,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 15, height: 1.2),
        inputFormatters: phone
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]'))]
            : null,
        decoration: InputDecoration(
          errorMaxLines: 4,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 15, color: AppColors.faint),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 15,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DesignAsset(icon, size: 18),
                if (phone) ...[
                  const SizedBox(width: 12),
                  Image.asset('assets/auth/vietnam.png', width: 16, height: 16),
                  const SizedBox(width: 6),
                  const Text(
                    '+84',
                    style: TextStyle(fontSize: 14, color: AppColors.ink),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 22,
                    color: const Color(0xFFE3E8EC),
                  ),
                ],
              ],
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minHeight: 48),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3E8EC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3E8EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.green),
          ),
        ),
      ),
    ],
  );
}

class SvgHeaderDecoration extends StatelessWidget {
  const SvgHeaderDecoration({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 126,
    height: 126,
    child: Stack(
      children: [
        DesignAsset('2dab5', size: 126),
        Positioned(left: 29, top: 29, child: DesignAsset('dace7', size: 68)),
      ],
    ),
  );
}
