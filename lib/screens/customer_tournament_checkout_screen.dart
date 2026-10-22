import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../auth/demo_session.dart';
import '../demo/demo_events.dart';
import '../demo/demo_finance.dart';
import '../widgets/design.dart';
import 'customer_account_views.dart';
import 'events_screen.dart';
import 'home_navigation.dart';

String _amount(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';
String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _date(DateTime d) => '${d.day}/${d.month}/${d.year} • ${_time(d)}';
Widget _panel(List<Widget> children) => Container(
  margin: const EdgeInsets.only(bottom: 14),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xffe7ebee)),
  ),
  child: Material(
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  ),
);
Widget _title(String value) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(
    value,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  ),
);
Widget _line(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 16,
    runSpacing: 4,
    children: [
      Text(label, style: const TextStyle(color: Color(0xff75818b))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  ),
);
Widget _notice(String text, {bool success = false}) => Container(
  margin: const EdgeInsets.symmetric(vertical: 8),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: success ? const Color(0xffe5f6ed) : const Color(0xfffff6e4),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    text,
    style: TextStyle(
      color: success ? AppColors.darkGreen : const Color(0xff845211),
    ),
  ),
);
Widget _button(String key, String label, VoidCallback? action) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: FilledButton(
    key: Key(key),
    onPressed: action,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label, textAlign: TextAlign.center),
  ),
);
Widget _shell(
  BuildContext context,
  String title,
  int step,
  List<Widget> body,
) => Scaffold(
  backgroundColor: const Color(0xfff4f6f8),
  appBar: AppBar(
    backgroundColor: AppColors.green,
    foregroundColor: Colors.white,
    toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 27 ? 90 : 56,
    title: Text(
      title,
      maxLines: 2,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  ),
  body: ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: i <= step
                          ? AppColors.green
                          : const Color(0xffe4e9ed),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: i <= step ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ['Thông tin', 'Thanh toán', 'Hoàn tất'][i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ...body,
    ],
  ),
  bottomNavigationBar: const CustomerAccountNavigation(selectedIndex: 2),
);
Widget _event(DemoEvent event, DateTime start, {bool photo = false}) => _panel([
  if (photo) ...[
    ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/figma/badminton-event-demo.png',
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    ),
    const Text(
      'Ảnh minh họa',
      style: TextStyle(fontSize: 10, color: Colors.grey),
    ),
    const SizedBox(height: 12),
  ],
  _title(event.title),
  const Text('Ban tổ chức demo SportMatch'),
  const Divider(height: 24),
  _line('Ngày thi đấu', _date(start)),
  _line('Kết thúc', _time(event.end(start))),
  const ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(Icons.location_on_outlined, color: AppColors.green),
    title: Text('Sân Cầu Lông Đại Học Công Thương'),
    subtitle: Text('73/1 Nguyễn Đỗ Cung, Tây Thạnh, TP.HCM'),
  ),
  _notice('Lệ phí tham dự: ${_amount(event.fee)} / đội', success: true),
]);

class CustomerTournamentRegistrationScreen extends StatefulWidget {
  const CustomerTournamentRegistrationScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  @override
  State<CustomerTournamentRegistrationScreen> createState() =>
      _RegistrationState();
}

class _RegistrationState extends State<CustomerTournamentRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _year = TextEditingController(),
      _email = TextEditingController(),
      _team = TextEditingController(),
      _partner = TextEditingController();
  late final String? _actor;
  String _level = '3.5', _error = '';
  bool _accepted = false, _busy = false;
  DemoParticipation? _pending;
  @override
  void initState() {
    super.initState();
    _actor = widget.session.user?.identifier;
    _name.text = widget.session.user?.name ?? '';
    _phone.text = widget.session.contactPhone;
    _email.text = _actor?.contains('@') == true ? _actor! : '';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _year, _email, _team, _partner]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
    String? Function(String)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: Key(key),
      controller: c,
      enabled: _pending == null && !_busy,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          validate?.call((v ?? '').trim()) ??
          ((v ?? '').trim().isEmpty ? 'Vui lòng nhập $label' : null),
    ),
  );
  Future<void> _submit() async {
    if (_busy) return;
    if (_pending == null && (!_form.currentState!.validate() || !_accepted)) {
      setState(() => _error = 'Điền đủ thông tin và đồng ý điều khoản.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final s = widget.session;
      if (_actor == null ||
          s.user?.identifier != _actor ||
          s.role != DemoRole.player) {
        throw StateError('Vui lòng đăng nhập lại đúng tài khoản.');
      }
      if (_pending == null) {
        final current = s.availableEvents
            .where((e) => e.id == widget.event.id)
            .firstOrNull;
        if (current == null ||
            current.fee != widget.event.fee ||
            current.durationMinutes != widget.event.durationMinutes ||
            current.kind != DemoEventKind.tournament ||
            current.start(s.now) != widget.start) {
          throw StateError('Thông tin giải đã thay đổi. Vui lòng mở lại giải.');
        }
        _pending = s.joinEvent(
          eventId: current.id,
          start: widget.start,
          quantity: 1,
          contact: _name.text.trim(),
          contactPhone: _phone.text.trim(),
          team: _team.text.trim(),
          partner: _partner.text.trim(),
          registration: DemoTournamentRegistration(
            birthYear: int.parse(_year.text),
            email: _email.text.trim(),
            level: _level,
            accepted: _accepted,
          ),
        );
      }
      if (s.saveFailed) await s.retrySave();
      if (!await s.flush()) {
        throw StateError(
          'Chưa lưu được đăng ký. Bấm thử lại, không tạo thêm đăng ký.',
        );
      }
      if (!mounted || s.user?.identifier != _actor) return;
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerTournamentPaymentScreen(
            session: s,
            participation: _pending!,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Không thể đăng ký. Vui lòng kiểm tra thông tin.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _shell(context, 'Đăng ký giải đấu', 0, [
    _event(widget.event, widget.start, photo: true),
    _title('Điều lệ giải đấu'),
    _panel([
      Text(widget.event.description),
      const SizedBox(height: 12),
      const Text(
        'Có mặt trước giờ thi đấu 30 phút. Yêu cầu hủy trước ít nhất 24 giờ; chờ ban tổ chức xét duyệt. Hoàn phí chỉ được ghi nhận sau khi chấp thuận.',
      ),
    ]),
    _title('Thông tin đăng ký'),
    _panel([
      Form(
        key: _form,
        child: Column(
          children: [
            _field('event-contact', 'Họ và tên', _name),
            _field(
              'event-phone',
              'Số điện thoại',
              _phone,
              keyboard: TextInputType.phone,
              validate: (v) => RegExp(r'^0[35789]\d{8}$').hasMatch(v)
                  ? null
                  : 'Nhập số điện thoại 10 chữ số',
            ),
            _field(
              'tournament-year',
              'Năm sinh',
              _year,
              keyboard: TextInputType.number,
              validate: (v) {
                final n = int.tryParse(v);
                return n != null && n >= 1900 && n <= widget.session.now.year
                    ? null
                    : 'Năm sinh không hợp lệ';
              },
            ),
            _field(
              'tournament-email',
              'Email nhận xác nhận',
              _email,
              keyboard: TextInputType.emailAddress,
              validate: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                  ? null
                  : 'Email không hợp lệ',
            ),
            _field('event-team', 'Tên đội', _team),
            _field('event-partner', 'Tên đồng đội', _partner),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Trình độ hiện tại'),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final level in ['3.0', '3.5', '4.0'])
                  ChoiceChip(
                    label: Text(level),
                    selected: level == _level,
                    onSelected: _pending != null || _busy
                        ? null
                        : (_) => setState(() => _level = level),
                  ),
              ],
            ),
          ],
        ),
      ),
    ]),
    _title('Xác nhận điều khoản'),
    _panel([
      CheckboxListTile(
        key: const Key('tournament-terms'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'Tôi đồng ý điều lệ giải, điều khoản tham dự và chính sách hoàn lệ phí.',
        ),
        value: _accepted,
        onChanged: _pending != null || _busy
            ? null
            : (v) => setState(() => _accepted = v!),
      ),
      _notice('Email chỉ được lưu trong hồ sơ demo, chưa gửi thư xác nhận.'),
    ]),
    if (_error.isNotEmpty) _notice(_error),
    _button(
      'event-submit',
      _busy
          ? 'Đang lưu…'
          : _pending != null
          ? 'Thử lưu lại đăng ký'
          : 'Tiếp tục thanh toán →',
      _busy ? null : _submit,
    ),
  ]);
}

class CustomerTournamentPaymentScreen extends StatefulWidget {
  const CustomerTournamentPaymentScreen({
    super.key,
    required this.session,
    required this.participation,
  });
  final DemoSession session;
  final DemoParticipation participation;
  @override
  State<CustomerTournamentPaymentScreen> createState() => _PaymentState();
}

class _PaymentState extends State<CustomerTournamentPaymentScreen> {
  String _method = 'qr', _error = '';
  bool _busy = false;
  Future<void> _pay() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final s = widget.session, p = widget.participation;
      s.payTournamentDemo(p, _method);
      if (s.saveFailed) await s.retrySave();
      if (!await s.flush()) {
        throw StateError(
          'Chưa lưu được biên nhận. Bấm thử lại để lưu, không thu phí lần nữa.',
        );
      }
      if (!mounted || s.user?.identifier != p.owner) return;
      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CustomerTournamentSuccessScreen(session: s, participation: p),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Thanh toán demo chưa hoàn tất.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final p = widget.participation, s = widget.session;
      if (s.user?.identifier != p.owner) {
        return _shell(context, 'Thanh toán lệ phí', 1, [
          _notice('Vui lòng đăng nhập đúng tài khoản.'),
        ]);
      }
      final payment = s.workflowPayment(p.id);
      final available =
          !p.cancelled &&
          p.start.isAfter(s.now) &&
          s.eventCancellation(p.eventId, p.start) == null &&
          (payment == null || payment.simulatedGateway);
      return _shell(context, 'Thanh toán lệ phí', 1, [
        _event(p.event, p.start),
        _title('Người đăng ký'),
        _panel([
          _title(p.contact),
          Text('${p.phone} • Trình độ ${p.registration?.level ?? ''}'),
          _line('Đội', p.team),
          _line('Đồng đội', p.partner),
        ]),
        _title('Phương thức thanh toán'),
        RadioGroup<String>(
          groupValue: _method,
          onChanged: (v) {
            if (!_busy && v != null) setState(() => _method = v);
          },
          child: Column(
            children: [
              for (final option in [
                ('qr', Icons.qr_code_scanner, 'Quét mã QR demo'),
                (
                  'wallet',
                  Icons.account_balance_wallet_outlined,
                  'Ví điện tử demo',
                ),
                (
                  'bank',
                  Icons.account_balance_outlined,
                  'Tài khoản ngân hàng demo',
                ),
              ])
                _panel([
                  RadioListTile<String>(
                    key: Key('tournament-method-${option.$1}'),
                    contentPadding: EdgeInsets.zero,
                    value: option.$1,
                    enabled: !_busy,
                    secondary: Icon(option.$2),
                    title: Text(option.$3),
                  ),
                ]),
            ],
          ),
        ),
        _panel([
          _title('Tài khoản ban tổ chức • DEMO'),
          if (_method == 'qr')
            Center(
              child: QrImageView(
                data: 'nvh-demo://event-payment?id=${p.id}&amount=${p.total}',
                size: 160,
              ),
            ),
          if (_method == 'wallet')
            const Text('Mô phỏng ví điện tử, không mở ứng dụng hay trừ tiền.'),
          _line('Chủ tài khoản', 'BAN TỔ CHỨC DEMO'),
          _line('Số tài khoản', 'DEMO - KHÔNG CHUYỂN TIỀN'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nội dung thanh toán'),
            subtitle: Text('DEMO-${p.id}'),
            trailing: IconButton(
              tooltip: 'Sao chép nội dung',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: 'DEMO-${p.id}')),
            ),
          ),
          _notice(
            'Đây là thanh toán mô phỏng. Mã QR không phải VietQR ngân hàng; không chuyển tiền thật.',
          ),
        ]),
        _panel([
          _line('Lệ phí giải đấu', _amount(p.total)),
          _line('Phí thanh toán', 'Miễn phí'),
          const Divider(),
          _title('Tổng thanh toán: ${_amount(p.total)}'),
        ]),
        if (!available)
          _notice(
            'Đăng ký không còn khả dụng hoặc đang có giao dịch cần xử lý.',
          ),
        if (_error.isNotEmpty) _notice(_error),
        _button(
          'tournament-pay',
          _busy ? 'Đang lưu…' : 'Thanh toán demo ${_amount(p.total)} →',
          available && !_busy ? _pay : null,
        ),
        TextButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ParticipationDetailScreen(session: s, participation: p),
            ),
          ),
          child: const Text('Xem đăng ký & yêu cầu hủy'),
        ),
      ]);
    },
  );
}

class CustomerTournamentSuccessScreen extends StatelessWidget {
  const CustomerTournamentSuccessScreen({
    super.key,
    required this.session,
    required this.participation,
  });
  final DemoSession session;
  final DemoParticipation participation;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final p = participation;
      if (session.user?.identifier != p.owner) {
        return _shell(context, 'Hoàn tất đăng ký', 2, [
          _notice('Vui lòng đăng nhập đúng tài khoản.'),
        ]);
      }
      final payment = session.workflowPayment(p.id);
      if (payment?.simulatedGateway != true ||
          payment?.state != DemoPaymentState.approved ||
          p.cancelled ||
          session.saveFailed) {
        return _shell(context, 'Trạng thái đăng ký', 2, [
          _notice(
            p.cancelled
                ? 'Đăng ký đã hủy.'
                : 'Chưa có biên nhận demo được lưu thành công.',
          ),
        ]);
      }
      return _shell(context, 'Hoàn tất đăng ký', 2, [
        _panel([
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.green,
              child: Icon(Icons.check, size: 32, color: Colors.white),
            ),
          ),
          const Text(
            'Thanh toán thành công!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text('Bạn đã đăng ký ${p.event.title}.', textAlign: TextAlign.center),
          _notice(
            'Biên nhận mô phỏng đã lưu trên thiết bị. Không trừ tiền thật và chưa gửi email xác nhận.',
            success: true,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mã đăng ký'),
            subtitle: Text(p.id),
            trailing: IconButton(
              tooltip: 'Sao chép mã đăng ký',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: p.id)),
            ),
          ),
        ]),
        _panel([
          _title('Thông tin xác nhận'),
          _line('Người đăng ký', p.contact),
          _line('Ngày thi đấu', _date(p.start)),
          _line('Đội / đồng đội', '${p.team} / ${p.partner}'),
          _line('Email hồ sơ', p.registration!.email),
          const Text('Địa điểm: Sân Cầu Lông Đại Học Công Thương'),
          _line('Lệ phí demo đã ghi nhận', _amount(p.total)),
          _notice('Đã xác nhận suất thi đấu • DEMO', success: true),
        ]),
        _notice(
          'Có mặt trước ${_time(p.start.subtract(const Duration(minutes: 30)))} ngày ${p.start.day}/${p.start.month}/${p.start.year}. Mang theo giấy tờ tùy thân để check-in.',
        ),
        _button(
          'tournament-schedule',
          'Xem lịch thi đấu đã đăng ký',
          () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => MyEventsScreen(session: session)),
          ),
        ),
        OutlinedButton(
          onPressed: () => HomeNavigation.openTab(context, 2),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Về trang Khám phá'),
          ),
        ),
      ]);
    },
  );
}
