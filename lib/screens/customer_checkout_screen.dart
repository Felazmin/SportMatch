import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_cancellation_policy.dart';
import '../demo/demo_finance.dart';
import '../widgets/design.dart';
import 'customer_account_views.dart';
import 'demo_account_screens.dart';
import 'finance_screen.dart';
import 'home_navigation.dart';

part 'customer_cancellation_screen.dart';

const _yellow = Color(0xFFFFCC00);
const _background = Color(0xFFF4F6F8);
const _greenTint = Color(0xFFE5F6ED);

AppBar _header(
  BuildContext context,
  String title,
  String subtitle, {
  String? step,
}) => AppBar(
  toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 27 ? 128 : 64,
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
  centerTitle: true,
  title: Column(
    children: [
      Text(
        title,
        maxLines: 2,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
    ],
  ),
  actions: [
    if (step != null)
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(child: Text(step)),
      ),
  ],
);

Widget _section(String title, List<Widget> children) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Material(
    type: MaterialType.transparency,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  ),
);

Widget _row(String label, String value, {bool total = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final texts = [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: total ? 18 : 13,
            fontWeight: FontWeight.w700,
            color: total ? AppColors.darkGreen : null,
          ),
        ),
      ];
      if (MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: texts,
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: texts[0]),
          const SizedBox(width: 12),
          Flexible(child: texts[1]),
        ],
      );
    },
  ),
);

Widget _notice(String text, {bool warning = false}) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: warning ? const Color(0xFFFFF6E4) : _greenTint,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        warning ? Icons.info_outline : Icons.check_circle_outline,
        size: 18,
        color: warning ? const Color(0xFF9A6200) : AppColors.darkGreen,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5)),
      ),
    ],
  ),
);

Widget _yellowButton(String key, String text, VoidCallback? action) =>
    FilledButton(
      key: Key(key),
      style: FilledButton.styleFrom(
        backgroundColor: _yellow,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onPressed: action,
      child: Text(text, textAlign: TextAlign.center),
    );

Widget _footer(List<Widget> children) => Material(
  color: Colors.white,
  child: SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  ),
);

String _hours(DemoBooking b) =>
    '${bookingTime(b.start)} – ${bookingTime(b.start.add(Duration(hours: b.hours)))}';

Widget _bookingSummary(DemoBooking b) => _section(b.venueName, [
  Text(
    'Sân ${b.court} · ${b.sport}',
    style: const TextStyle(color: AppColors.muted),
  ),
  _row('Ngày đặt', bookingDate(b.start)),
  _row('Giờ đặt', _hours(b)),
  _row('Thời lượng', '${b.hours} giờ'),
]);

class CustomerCheckoutConfirmScreen extends StatefulWidget {
  const CustomerCheckoutConfirmScreen({
    super.key,
    required this.session,
    required this.court,
    required this.start,
    required this.hours,
    this.facilityId = '',
    this.initialName,
    this.initialPhone,
  });
  final DemoSession session;
  final int court, hours;
  final DateTime start;
  final String facilityId;
  final String? initialName, initialPhone;
  @override
  State<CustomerCheckoutConfirmScreen> createState() => _CheckoutConfirmState();
}

class _CheckoutConfirmState extends State<CustomerCheckoutConfirmScreen> {
  final _form = GlobalKey<FormState>();
  late final String? _actor;
  late final _name = TextEditingController(
    text: widget.initialName ?? widget.session.user?.name ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.initialPhone ?? widget.session.contactPhone,
  );
  final _note = TextEditingController();
  late final _rates = widget.session.bookingRates(
    widget.court,
    widget.start,
    widget.hours,
    facilityId: widget.facilityId,
  );
  late final _profile = widget.session.publicFacilities
      .where((f) => f.id == widget.facilityId)
      .firstOrNull
      ?.profile;
  late final CancellationPolicy _policy =
      _profile?.cancellationPolicy ?? widget.session.primaryCancellationPolicy;
  bool _terms = false, _busy = false;
  DemoBooking? _pending;
  String? _error, _voucher;
  int get _subtotal => _rates.fold(0, (a, b) => a + b);
  int get _discount =>
      widget.session.vouchers
          .where((v) => v.code == _voucher)
          .firstOrNull
          ?.discount(_subtotal) ??
      0;

  @override
  void initState() {
    super.initState();
    _actor = widget.session.user?.identifier;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    if (_actor == null ||
        widget.session.user?.identifier != _actor ||
        widget.session.role != DemoRole.player) {
      setState(
        () => _error = 'Tài khoản đã thay đổi. Vui lòng mở lại lịch đặt.',
      );
      return;
    }
    if (_pending == null && (!_form.currentState!.validate() || !_terms)) {
      setState(
        () => _error =
            'Kiểm tra thông tin và đồng ý điều khoản trước khi tiếp tục.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final b = _pending ??= widget.session.reserve(
        court: widget.court,
        start: widget.start,
        hours: widget.hours,
        facilityId: widget.facilityId,
        contact: _name.text,
        contactPhone: _phone.text,
        quotedRates: _rates,
        quotedCancellationPolicy: _policy,
        voucherCode: _voucher,
      );
      widget.session.startTransfer(b, checkout: true, customerNote: _note.text);
      await widget.session.retrySave();
      if (!await widget.session.flush()) {
        throw StateError('Đơn đã tạo nhưng chưa lưu được. Hãy thử lưu lại.');
      }
      if (!mounted) return;
      if (widget.session.user?.identifier != _actor) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CustomerCheckoutPaymentScreen(
            session: widget.session,
            booking: b,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Chưa tạo được lịch. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseVoucher() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VoucherWalletScreen(session: widget.session, subtotal: _subtotal),
      ),
    );
    if (mounted && code != null) {
      setState(() => _voucher = code.isEmpty ? null : code);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: _header(
      context,
      'Thông tin đặt lịch',
      _profile?.name ?? DemoBooking.venue,
      step: '2/3',
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FinanceSaveNotice(session: widget.session),
          _section('Sân đã chọn', [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.location_on_outlined,
                color: AppColors.green,
              ),
              title: Text(
                'Sân ${widget.court} · ${_profile?.sport ?? 'Cầu lông'}',
              ),
              subtitle: Text(_profile?.name ?? DemoBooking.venue),
              trailing: IconButton(
                tooltip: 'Đổi giờ chơi',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _busy || _pending != null
                    ? null
                    : () => Navigator.pop(context),
              ),
            ),
            const Divider(),
            _row('Ngày đặt', bookingDate(widget.start)),
            _row(
              'Khung giờ',
              '${bookingTime(widget.start)} – ${bookingTime(widget.start.add(Duration(hours: widget.hours)))}',
            ),
            _row('Thời lượng', '${widget.hours} giờ'),
            _row('Giá sân', bookingMoney(_subtotal), total: true),
          ]),
          _section('Thông tin người đặt', [
            const Text(
              'Thông tin này được gửi cho chủ sân để xác nhận lịch đặt.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('booking-name'),
              controller: _name,
              enabled: !_busy && _pending == null,
              maxLength: 60,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Họ và tên *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nhập họ và tên' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('booking-phone'),
              controller: _phone,
              enabled: !_busy && _pending == null,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại *',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  RegExp(r'^0[35789]\d{8}$')
                      .hasMatch(DemoSession.normalize(v ?? ''))
                  ? null
                  : 'Nhập số điện thoại hợp lệ',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('checkout-note'),
              controller: _note,
              enabled: !_busy && _pending == null,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Ghi chú cho chủ sân',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
          _section('Lưu ý trước khi thanh toán', [
            Text(
              '${_policy.summary} Yêu cầu hủy cần gửi trước ít nhất ${_policy.minimumHours < 2 ? 2 : _policy.minimumHours} giờ.',
              key: const Key('booking-policy-summary'),
            ),
            _notice(
              'Gửi đủ giấy tờ trong 15 phút. Lịch chỉ được xác nhận sau khi chủ sân kiểm tra.',
              warning: true,
            ),
            TextButton.icon(
              key: const Key('booking-voucher'),
              onPressed: _busy || _pending != null ? null : _chooseVoucher,
              icon: const Icon(Icons.local_offer_outlined),
              label: Text(_voucher ?? 'Chọn ưu đãi'),
            ),
          ]),
          CheckboxListTile(
            key: const Key('checkout-terms'),
            value: _terms,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: _busy || _pending != null
                ? null
                : (v) => setState(() => _terms = v!),
            title: const Text(
              'Tôi đồng ý với Điều khoản đặt sân và Chính sách hoàn tiền / hủy lịch.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              key: const Key('booking-error'),
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
    ),
    bottomNavigationBar: _footer([
      if (_discount > 0) _row('Ưu đãi', '-${bookingMoney(_discount)}'),
      _row('Phí dịch vụ', bookingMoney(0)),
      _row('Tổng thanh toán', bookingMoney(_subtotal - _discount), total: true),
      _yellowButton(
        'booking-confirm',
        _pending == null ? 'TIẾP TỤC THANH TOÁN  →' : 'Thử lưu lại',
        _busy ? null : _continue,
      ),
    ]),
  );
}

class CustomerCheckoutPaymentScreen extends StatefulWidget {
  const CustomerCheckoutPaymentScreen({
    super.key,
    required this.session,
    required this.booking,
    this.pickImage,
  });
  final DemoSession session;
  final DemoBooking booking;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<CustomerCheckoutPaymentScreen> createState() => _CheckoutPaymentState();
}

class _CheckoutPaymentState extends State<CustomerCheckoutPaymentScreen> {
  late final _actor = widget.session.user?.identifier;
  Timer? _timer;
  bool _busy = false, _expiryShown = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _authorized =>
      widget.session.role == DemoRole.player &&
      _actor != null &&
      widget.session.user?.identifier == _actor &&
      widget.booking.owner == _actor;

  Future<bool> _perform(FutureOr<void> Function() action) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_authorized) {
        throw StateError('Tài khoản đã thay đổi. Mở lại lịch đặt.');
      }
      await action();
      if (!await widget.session.flush()) {
        throw StateError('Chưa lưu được giấy tờ. Hãy thử lưu lại.');
      }
      if (!_authorized) throw StateError('Tài khoản đã thay đổi.');
      return true;
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : e is FormatException
              ? e.message.toString()
              : 'Không thể chọn ảnh. Hãy thử lại.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(bool student) async {
    await _perform(() async {
      final b = widget.booking;
      final revision = b.revision;
      final bytes = await (widget.pickImage ?? ProofPicker.pick)();
      if (!_authorized || revision != b.revision) {
        throw StateError('Lịch hoặc tài khoản đã thay đổi.');
      }
      if (bytes != null) {
        if (student) {
          widget.session.saveStudentDraft(b, bytes);
        } else {
          widget.session.saveProofDraft(b, bytes);
        }
      }
    });
  }

  Future<void> _complete() async {
    final s = widget.session, b = widget.booking;
    final ok = await _perform(() async {
      final p = s.paymentFor(b)!;
      // A failed disk write can be retried without submitting the order twice.
      if (p.state == DemoPaymentState.pending) {
        await s.retrySave();
      } else {
        s.submitProof(b, b.id);
      }
    });
    if (ok && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CustomerCheckoutHistoryScreen(session: s, booking: b),
        ),
      );
    }
  }

  Future<void> _expired() async {
    if (!mounted || !_authorized) return;
    final s = widget.session, b = widget.booking;
    if (s.paymentFor(b)?.expired(s.now) != true || b.cancelled) return;
    final retry = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: AppColors.green,
      builder: (context) => PopScope(
        canPop: false,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Chưa gửi chứng từ đúng hạn nên phiên thanh toán đã hết hạn. Đã gửi đúng hạn: chờ xác nhận, không tự hủy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                _yellowButton(
                  'checkout-timeout-home',
                  'VỀ TRANG CHỦ',
                  () => Navigator.pop(context, false),
                ),
                const SizedBox(height: 12),
                _yellowButton(
                  'checkout-timeout-retry',
                  'TIẾP TỤC THANH TOÁN',
                  () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (!_authorized) {
      setState(() => _error = 'Tài khoản đã thay đổi.');
      return;
    }
    if (retry != true) {
      HomeNavigation.returnHome(context);
      return;
    }
    final ok = await _perform(() => s.startTransfer(b, checkout: true));
    if (ok && mounted) setState(() => _expiryShown = false);
  }

  Widget _upload(
    String label,
    String proof,
    bool student,
    bool editable,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('$label *', style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: !editable || _busy ? null : () => _pick(student),
        key: Key(student ? 'checkout-pick-student' : 'payment-pick-proof'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(20),
          backgroundColor: const Color(0xFFF8FBFA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          children: [
            Icon(
              proof.isEmpty
                  ? Icons.add_photo_alternate_outlined
                  : Icons.check_circle_outline,
            ),
            const SizedBox(height: 8),
            Text(
              proof.isEmpty ? 'Chọn ảnh để tải lên' : 'Đã chọn ảnh · Chọn lại',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'JPG, PNG · Tối đa 400KB',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
      if (proof.isNotEmpty)
        TextButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(label),
              content: Image.memory(decodeProof(proof), fit: BoxFit.contain),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Xem ảnh đã chọn'),
        ),
      const SizedBox(height: 16),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session, b = widget.booking;
      if (!_authorized) {
        return Scaffold(
          appBar: financeBar('Thanh toán'),
          body: const Center(child: Text('Không có quyền truy cập lịch này.')),
        );
      }
      final p = s.paymentFor(b);
      if (p == null) {
        return Scaffold(
          appBar: financeBar('Thanh toán'),
          body: const Center(child: Text('Chưa có phiên thanh toán.')),
        );
      }
      final editable =
          !b.cancelled &&
          b.start.isAfter(s.now) &&
          !p.expired(s.now) &&
          p.cancellation != DemoCancellationState.requested &&
          (p.state == DemoPaymentState.awaitingProof ||
              p.state == DemoPaymentState.rejected);
      final remaining = p.deadline.difference(s.now).inSeconds.clamp(0, 900);
      if (p.expired(s.now) &&
          !_expiryShown &&
          !b.cancelled &&
          p.cancellation != DemoCancellationState.requested) {
        _expiryShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _expired());
      }
      return Scaffold(
        backgroundColor: _background,
        appBar: _header(context, 'Thanh toán', b.venueName, step: '3/3'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            if (editable || p.expired(s.now))
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EF),
                  border: Border.all(color: const Color(0xFFFFD9D6)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'HOÀN TẤT THANH TOÁN TRONG',
                      style: TextStyle(
                        color: Color(0xFFBD2920),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
                      key: const Key('checkout-countdown'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBD2920),
                      ),
                    ),
                    const Text(
                      'Hết hạn nếu chưa gửi đủ giấy tờ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            _section('Thông tin đơn đặt sân', [
              _row('Khách hàng', b.contact),
              _row('Điện thoại', b.phone),
              _row('Mã đơn', b.id),
              const Divider(),
              _row('Ngày đặt', bookingDate(b.start)),
              _row('Sân đã chọn', 'Sân ${b.court} · ${b.sport}'),
              _row('Giờ đặt', _hours(b)),
              const Divider(),
              _row('Tổng đơn', bookingMoney(b.total)),
              _row('Phí dịch vụ', bookingMoney(0)),
              _row('Cần thanh toán', bookingMoney(b.total), total: true),
              if (p.customerNote.isNotEmpty) _row('Ghi chú', p.customerNote),
            ]),
            _bank(b),
            if (p.reviewNote.isNotEmpty)
              _notice('Cần gửi lại: ${p.reviewNote}', warning: true),
            _section('Tải lên giấy tờ xác nhận', [
              _upload(
                'Hình ảnh thanh toán',
                p.draft.isNotEmpty ? p.draft : p.proof,
                false,
                editable,
              ),
              _upload(
                'Thẻ học sinh / sinh viên',
                p.studentDraft.isNotEmpty ? p.studentDraft : p.studentProof,
                true,
                editable,
              ),
              _notice(
                'Chỉ dùng ảnh thử nghiệm. Ảnh lưu mã hóa trên thiết bị; chưa gửi lên máy chủ.',
              ),
            ]),
            if (_error != null)
              Text(
                _error!,
                key: const Key('payment-error'),
                style: const TextStyle(color: Colors.red),
              ),
            if (!editable)
              _notice(b.cancelled ? 'Lịch đã hủy.' : p.label(s.now)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CustomerCheckoutDetailScreen(session: s, booking: b),
                ),
              ),
              child: const Text('Chi tiết lịch đặt'),
            ),
          ],
        ),
        bottomNavigationBar: _footer([
          _row('Số tiền cần thanh toán', bookingMoney(b.total), total: true),
          _yellowButton(
            'payment-submit-proof',
            p.state == DemoPaymentState.pending ? 'XEM LỊCH ĐẶT' : 'HOÀN THÀNH',
            _busy || (!editable && p.state != DemoPaymentState.pending)
                ? null
                : _complete,
          ),
        ]),
      );
    },
  );
}

Widget _bank(DemoBooking b) => _section('Thông tin chuyển khoản', [
  const Text(
    'Ngân hàng MÔ PHỎNG · Không chuyển tiền thật.',
    style: TextStyle(fontSize: 12, color: AppColors.muted),
  ),
  if (b.receivingAccount case final account?) ...[
    _row('Ngân hàng cấu hình (mô phỏng)', account.bank),
    _row('Chủ tài khoản (mô phỏng)', account.holder),
    _row('Số tài khoản (mô phỏng)', account.masked),
  ] else ...[
    _row('Chủ tài khoản', 'TÀI KHOẢN DEMO'),
    _copyRow('Số tài khoản', 'DEMO-KHÔNG-CHUYỂN-TIỀN'),
  ],
  _copyRow('Nội dung CK', b.id),
  _notice(
    'Số tiền mô phỏng: ${bookingMoney(b.total)}. Gửi ảnh thử nghiệm để chủ sân kiểm tra.',
    warning: true,
  ),
]);

Widget _copyRow(String label, String value) => Row(
  children: [
    Expanded(child: _row(label, value)),
    Builder(
      builder: (context) => IconButton(
        tooltip: 'Sao chép $label',
        icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.green),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Đã sao chép')));
          }
        },
      ),
    ),
  ],
);

Widget _dates(DemoBooking b) => Container(
  color: Colors.white,
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Row(
    children: [
      for (var i = -3; i <= 3; i++)
        Expanded(
          child: Column(
            children: [
              Text(
                [
                  'T2',
                  'T3',
                  'T4',
                  'T5',
                  'T6',
                  'T7',
                  'CN',
                ][b.start.add(Duration(days: i)).weekday - 1],
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: i == 0 ? AppColors.green : null,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${b.start.add(Duration(days: i)).day}',
                  style: TextStyle(
                    fontSize: 12,
                    color: i == 0 ? Colors.white : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

class CustomerCheckoutHistoryScreen extends StatelessWidget {
  const CustomerCheckoutHistoryScreen({
    super.key,
    required this.session,
    required this.booking,
  });
  final DemoSession session;
  final DemoBooking booking;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      if (session.user?.identifier != booking.owner ||
          session.role != DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Lịch đặt sân'),
          body: const Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final p = session.paymentFor(booking);
      final sent =
          p?.state == DemoPaymentState.pending ||
          p?.state == DemoPaymentState.approved;
      return Scaffold(
        backgroundColor: _background,
        appBar: _header(context, 'Lịch đặt sân', bookingDate(booking.start)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _dates(booking),
            if (sent)
              _notice(
                'Đã gửi thông tin thanh toán. ${p!.state == DemoPaymentState.approved ? 'Chủ sân đã xác nhận.' : 'Lịch đặt đang chờ chủ sân xác nhận.'}',
              ),
            _section('Lịch đặt của bạn', [
              Text(
                booking.venueName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _row('Mã lịch đặt', booking.id),
              _notice(
                booking.cancelled
                    ? 'Đã hủy'
                    : p?.label(session.now) ?? 'Chưa thanh toán',
                warning: p?.state != DemoPaymentState.approved,
              ),
              _row(
                bookingDate(booking.start),
                'Sân ${booking.court} · ${_hours(booking)}',
              ),
              _row('Tổng thanh toán', bookingMoney(booking.total), total: true),
              _row('Phương thức', 'Chuyển khoản · Mô phỏng'),
              _row('Nội dung CK', booking.id),
              _yellowButton(
                'checkout-booking-detail',
                'Xem chi tiết  ›',
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerCheckoutDetailScreen(
                      session: session,
                      booking: booking,
                    ),
                  ),
                ),
              ),
              if (!booking.cancelled &&
                  p != null &&
                  p.cancellation != DemoCancellationState.requested)
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CustomerCheckoutDetailScreen(
                        session: session,
                        booking: booking,
                        requestCancellation: true,
                      ),
                    ),
                  ),
                  child: const Text('Yêu cầu hủy lịch'),
                ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerBookingsScreen(session: session),
                  ),
                ),
                child: const Text('Tất cả lịch đặt'),
              ),
            ]),
          ],
        ),
        bottomNavigationBar: const CustomerAccountNavigation(),
      );
    },
  );
}

class CustomerCheckoutDetailScreen extends StatefulWidget {
  const CustomerCheckoutDetailScreen({
    super.key,
    required this.session,
    required this.booking,
    this.requestCancellation = false,
  });
  final DemoSession session;
  final DemoBooking booking;
  final bool requestCancellation;
  @override
  State<CustomerCheckoutDetailScreen> createState() => _CheckoutDetailState();
}

class _CheckoutDetailState extends State<CustomerCheckoutDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.requestCancellation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cancel();
      });
    }
  }

  Future<void> _cancel() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerCancellationScreen(
          session: widget.session,
          booking: widget.booking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session, b = widget.booking;
      if (s.user?.identifier != b.owner || s.role != DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Chi tiết lịch đặt'),
          body: const Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final p = s.paymentFor(b);
      final sent =
          p?.state == DemoPaymentState.pending ||
          p?.state == DemoPaymentState.approved;
      return Scaffold(
        backgroundColor: _background,
        appBar: _header(context, 'Chi tiết lịch đặt', b.id),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            _dates(b),
            if (sent)
              _notice(
                p!.state == DemoPaymentState.approved
                    ? 'Chủ sân đã xác nhận thanh toán.'
                    : 'Đã gửi thông tin thanh toán. Sẽ có cập nhật sau khi chủ sân xác nhận.',
              ),
            _bookingSummary(b),
            _notice(
              b.cancelled
                  ? 'Lịch đã hủy.'
                  : p?.label(s.now) ?? 'Chưa thanh toán',
              warning: p?.state != DemoPaymentState.approved,
            ),
            _section('Thông tin khách hàng', [
              _row(b.contact, b.phone),
              if (p?.customerNote.isNotEmpty == true)
                _row('Ghi chú', p!.customerNote),
            ]),
            _section('Thông tin thanh toán', [
              _row('Tổng đơn', bookingMoney(b.total)),
              _row('Phí dịch vụ', bookingMoney(0)),
              _row('Tổng thanh toán', bookingMoney(b.total), total: true),
              if (p?.cancellation != DemoCancellationState.none && p != null)
                _notice(p.cancellationLabel, warning: true),
              if (p?.cancellationReason.isNotEmpty == true)
                _row('Lý do hủy', p!.cancellationReason),
              Text(
                '${b.cancellationPolicy.summary} Yêu cầu hủy cần gửi trước ít nhất ${s.bookingCancellationMinimumHours(b)} giờ.',
              ),
            ]),
            _bank(b),
            _section('Giấy tờ đã gửi', [
              _row(
                'Hình ảnh thanh toán',
                p?.proof.isNotEmpty == true ? 'Đã gửi' : 'Chưa gửi',
              ),
              _row(
                'Thẻ học sinh / sinh viên',
                p?.studentProof.isNotEmpty == true ? 'Đã gửi' : 'Chưa gửi',
              ),
            ]),
            if (!b.cancelled &&
                b.start.isAfter(s.now) &&
                p != null &&
                (p.state == DemoPaymentState.awaitingProof ||
                    p.state == DemoPaymentState.rejected))
              _yellowButton(
                'booking-payment',
                'Tiếp tục thanh toán',
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CustomerCheckoutPaymentScreen(session: s, booking: b),
                  ),
                ),
              ),
            if (p != null &&
                (!b.cancelled || p.cancellation != DemoCancellationState.none))
              OutlinedButton(
                key: const Key('payment-request-cancel'),
                onPressed: _cancel,
                child: Text(
                  p.cancellation == DemoCancellationState.none
                      ? 'Yêu cầu hủy lịch'
                      : 'Trạng thái yêu cầu hủy',
                ),
              ),
          ],
        ),
      );
    },
  );
}
