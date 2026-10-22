part of 'customer_checkout_screen.dart';

class CustomerCancellationScreen extends StatefulWidget {
  const CustomerCancellationScreen({
    super.key,
    required this.session,
    required this.booking,
    this.pickImage,
    this.retry = false,
  });
  final DemoSession session;
  final DemoBooking booking;
  final Future<Uint8List?> Function()? pickImage;
  final bool retry;
  @override
  State<CustomerCancellationScreen> createState() => _CancellationState();
}

class _CancellationState extends State<CustomerCancellationScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _account = TextEditingController();
  late final TextEditingController _holder;
  late final String? _actor;
  late final int _revision, _quotedRefund;
  Timer? _timer;
  String _bank = 'Vietcombank', _qr = '';
  bool _qrMode = false, _consent = false, _busy = false, _newRequest = false;
  bool _submittedHere = false;
  String? _error;

  DemoSession get s => widget.session;
  DemoBooking get b => widget.booking;
  bool get _authorized =>
      _actor != null &&
      s.user?.identifier == _actor &&
      s.role == DemoRole.player &&
      b.owner == _actor;

  @override
  void initState() {
    super.initState();
    _actor = s.user?.identifier;
    _newRequest = widget.retry;
    _revision = b.revision;
    _holder = TextEditingController(text: b.contact.toUpperCase());
    _quotedRefund = _authorized ? s.estimatedBookingRefund(b) : 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reason.dispose();
    _account.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _pickQr() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await (widget.pickImage ?? ProofPicker.pick)();
      if (!mounted) return;
      if (!_authorized ||
          b.revision != _revision ||
          !s.canRequestBookingCancellation(b)) {
        throw StateError('Lịch, tài khoản hoặc điều kiện hủy đã thay đổi.');
      }
      if (bytes != null) setState(() => _qr = encodeProof(bytes));
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object e) => e is StateError
      ? e.message.toString()
      : e is FormatException
      ? e.message.toString()
      : 'Chưa xử lý được. Hãy thử lại.';

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!_consent || (_quotedRefund > 0 && _qrMode && _qr.isEmpty)) {
      setState(
        () => _error = !_consent
            ? 'Xác nhận điều kiện và phí hủy trước khi gửi.'
            : 'Chọn ảnh QR nhận tiền.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_authorized || _revision != b.revision) {
        throw StateError('Lịch hoặc tài khoản đã thay đổi. Mở lại yêu cầu.');
      }
      s.requestCancellation(
        b,
        _reason.text,
        quotedRefund: _quotedRefund,
        acceptFee: _consent,
        destination: _quotedRefund == 0
            ? null
            : _qrMode
            ? DemoRefundDestination.qr(_qr)
            : DemoRefundDestination.bank(
                bank: _bank,
                account: _account.text.replaceAll(RegExp(r'\s'), ''),
                holder: _holder.text.trim(),
              ),
      );
      _submittedHere = true;
      if (!await s.flush()) {
        throw StateError('Yêu cầu chưa lưu được. Hãy thử lưu lại.');
      }
      if (!mounted) return;
      if (!_authorized) throw StateError('Tài khoản đã thay đổi.');
      setState(() => _newRequest = false);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _contact() async {
    if (_busy) return;
    final revision = b.revision;
    final text = await financeText(
      context,
      'Nhắn tin cho chủ sân',
      maximum: 500,
    );
    if (!mounted || text == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_authorized || revision != b.revision) {
        throw StateError('Lịch hoặc tài khoản đã thay đổi.');
      }
      s.sendBookingMessage(b, text);
      if (!await s.flush()) {
        throw StateError('Tin nhắn chưa lưu được. Hãy thử lưu lại.');
      }
      if (mounted && _authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã lưu tin nhắn demo cho chủ sân trong hồ sơ lịch đặt.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _history() => Navigator.pushReplacement(
    context,
    MaterialPageRoute<void>(builder: (_) => CustomerBookingsScreen(session: s)),
  );

  Widget _greenButton(String key, String label, VoidCallback? action) =>
      FilledButton(
        key: Key(key),
        onPressed: action,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, textAlign: TextAlign.center),
      );
  Widget _redNotice(String text) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEC),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFBC3030),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
  String _stamp(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} · ${bookingDate(date)}';
  String _remaining(DateTime deadline) {
    final minutes = deadline.difference(s.now).inMinutes.clamp(0, 99999);
    return '${minutes ~/ 60} giờ ${minutes % 60} phút';
  }

  Widget _refundSummary(DemoPayment p, {bool sent = false}) {
    final paid = p.state == DemoPaymentState.approved;
    final estimate = sent
        ? p.cancellationEstimate ??
              s.estimatedBookingRefund(
                b,
                requestedAt: p.cancellationRequestedAt,
              )
        : _quotedRefund;
    final fee = paid ? b.total - estimate : 0;
    final percent = paid
        ? 100 -
              b.cancellationPolicy.refundPercent(
                b.start,
                sent ? p.cancellationRequestedAt ?? s.now : s.now,
              )
        : 0;
    return _section(sent ? 'Thông tin hoàn tiền' : 'Số tiền dự kiến hoàn', [
      _row('Phí đặt sân', bookingMoney(b.total)),
      _row('Phí hủy ($percent%)', '-${bookingMoney(fee)}'),
      _row('Phí dịch vụ', bookingMoney(0)),
      const Divider(),
      _row('Dự kiến hoàn', bookingMoney(estimate), total: true),
      Text(
        paid ? 'Chỉ hoàn tiền sau khi chủ sân chấp thuận yêu cầu hủy.' : 'Chưa xác nhận thanh toán nên chưa có khoản hoàn tiền. Chủ sân sẽ kiểm tra trước khi xử lý.',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.muted,
          height: 1.5,
        ),
      ),
      if (sent && p.refundDestination != null) ...[
        const SizedBox(height: 12),
        const Text(
          'Thông tin nhận tiền đã gửi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        if (p.refundDestination!.qr.isNotEmpty) ...[
          const SizedBox(height: 8),
          Image.memory(
            decodeProof(p.refundDestination!.qr),
            height: 120,
            fit: BoxFit.contain,
          ),
        ] else ...[
          _row('Ngân hàng', p.refundDestination!.bank),
          _row('Chủ tài khoản', p.refundDestination!.holder),
          _row('Số tài khoản', p.refundDestination!.account),
        ],
      ],
    ]);
  }

  List<Widget> _request(DemoPayment p) => [
    _notice(
      'Đủ điều kiện gửi yêu cầu. Còn ${_remaining(b.start)} tới giờ chơi. '
      'Hạn gửi: ${_stamp(s.bookingCancellationDeadline(b))} (trước ít nhất ${s.bookingCancellationMinimumHours(b)} giờ).',
    ),
    _bookingSummary(b),
    _section('Lý do hủy lịch', [
      TextFormField(
        key: const Key('cancellation-reason'),
        controller: _reason,
        enabled: !_busy,
        minLines: 2,
        maxLines: 5,
        maxLength: 300,
        decoration: const InputDecoration(
          hintText: 'Nhập lý do hủy lịch',
          border: OutlineInputBorder(),
        ),
        validator: (v) =>
            (v ?? '').trim().length < 5 ? 'Lý do cần ít nhất 5 ký tự.' : null,
      ),
    ]),
    _refundSummary(p),
    if (_quotedRefund > 0)
      _section('Thông tin nhận hoàn tiền', [
        const Text(
          'Chọn một cách nhận tiền. Kiểm tra kỹ thông tin trước khi gửi.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        RadioGroup<bool>(
          groupValue: _qrMode,
          onChanged: _busy ? (_) {} : (v) => setState(() => _qrMode = v!),
          child: Column(
            children: [
              const RadioListTile<bool>(
                key: Key('cancellation-mode-qr'),
                value: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Gửi mã QR nhận tiền'),
              ),
              if (_qrMode)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('cancellation-pick-qr'),
                      onPressed: _busy ? null : _pickQr,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                        _qr.isEmpty ? 'Chọn ảnh QR' : 'Chọn lại ảnh QR',
                      ),
                    ),
                    if (_qr.isNotEmpty)
                      Image.memory(
                        decodeProof(_qr),
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    const Text(
                      'Ảnh QR thử nghiệm · JPG, PNG · Tối đa 400KB',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              const RadioListTile<bool>(
                key: Key('cancellation-mode-bank'),
                value: false,
                contentPadding: EdgeInsets.zero,
                title: Text('Nhập tài khoản ngân hàng'),
              ),
            ],
          ),
        ),
        if (!_qrMode) ...[
          DropdownButtonFormField<String>(
            initialValue: _bank,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ngân hàng *',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final bank in [
                'Vietcombank',
                'VietinBank',
                'BIDV',
                'MB Bank',
                'Techcombank',
                'ACB',
              ])
                DropdownMenuItem(value: bank, child: Text(bank)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _bank = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('cancellation-account'),
            controller: _account,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: 'Số tài khoản *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                RegExp(r'^\d{6,19}$')
                    .hasMatch((v ?? '').replaceAll(RegExp(r'\s'), ''))
                ? null
                : 'Số tài khoản cần 6–19 chữ số.',
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('cancellation-holder'),
            controller: _holder,
            enabled: !_busy,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Tên chủ tài khoản *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').trim().length < 2 ? 'Nhập tên chủ tài khoản.' : null,
          ),
        ],
        _notice(
          'Chỉ dùng thông tin thử nghiệm. Chưa có giao dịch hoàn tiền ngân hàng thật.',
        ),
      ]),
    CheckboxListTile(
      key: const Key('cancellation-consent'),
      value: _consent,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      onChanged: _busy ? null : (v) => setState(() => _consent = v!),
      title: Text(
        'Tôi xác nhận ${p.state == DemoPaymentState.approved ? 'phí hủy ${bookingMoney(b.total - _quotedRefund)} và ' : ''}chờ chủ sân phản hồi yêu cầu hủy.',
        style: const TextStyle(fontSize: 12),
      ),
    ),
    _greenButton(
      'cancellation-submit',
      'Gửi yêu cầu hủy lịch',
      _busy ? null : _send,
    ),
  ];

  Widget _step(String title, String subtitle, IconData icon, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  List<Widget> _status(DemoPayment p) {
    final accepted = p.cancellation == DemoCancellationState.accepted;
    final rejected = p.cancellation == DemoCancellationState.rejected;
    final refunded = p.refund == DemoRefundState.recorded;
    return [
      if (rejected)
        _redNotice('Yêu cầu hủy bị từ chối. ${p.cancellationNote}')
      else
        _notice(
          accepted
              ? 'Chủ sân đã chấp thuận hủy lịch. ${refunded
                    ? 'Đã ghi nhận hoàn tiền demo.'
                    : p.refund == DemoRefundState.pending
                    ? 'Khoản hoàn đang chờ xử lý.'
                    : 'Không có khoản hoàn đã xác nhận.'}'
              : 'Đã gửi yêu cầu · Chờ phản hồi. Lịch chưa được hủy và tiền chưa được hoàn.',
          warning: !accepted,
        ),
      _bookingSummary(b),
      _section('Tiến trình xử lý', [
        _step(
          'Đã gửi yêu cầu hủy',
          p.cancellationRequestedAt == null
              ? 'Yêu cầu đã được ghi nhận.'
              : _stamp(p.cancellationRequestedAt!),
          Icons.check_circle_outline,
          AppColors.green,
        ),
        const Divider(),
        _step(
          rejected
              ? 'Chủ sân từ chối'
              : accepted
              ? 'Chủ sân đã chấp thuận'
              : 'Đang chờ chủ sân phản hồi',
          rejected
              ? p.cancellationNote
              : accepted
              ? 'Lịch đã hủy.'
              : 'Lịch vẫn giữ nguyên trong lúc chờ xử lý.',
          accepted ? Icons.check_circle_outline : Icons.schedule,
          accepted ? AppColors.green : const Color(0xFFAE7300),
        ),
        const Divider(),
        _step(
          refunded ? 'Đã ghi nhận hoàn tiền demo' : 'Hoàn tiền chưa hoàn tất',
          refunded && p.refundRecordedAt != null
              ? _stamp(p.refundRecordedAt!)
              : 'Chỉ xử lý hoàn tiền sau khi yêu cầu hủy được chấp thuận.',
          Icons.receipt_long_outlined,
          refunded ? AppColors.green : AppColors.muted,
        ),
      ]),
      _section('Lý do hủy lịch', [Text(p.cancellationReason)]),
      _refundSummary(p, sent: true),
      if (_submittedHere && s.saveFailed)
        _greenButton(
          'cancellation-retry-save',
          'Thử lưu lại yêu cầu',
          _busy
              ? null
              : () async {
                  await s.retrySave();
                  if (mounted) setState(() {});
                },
        ),
      if (rejected && s.canRequestBookingCancellation(b))
        OutlinedButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => CustomerCancellationScreen(
                session: s,
                booking: b,
                retry: true,
              ),
            ),
          ),
          child: const Text('Mở lại yêu cầu hủy'),
        ),
      _greenButton(
        'cancellation-history',
        'Về danh sách lịch đã đặt',
        _history,
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('cancellation-contact'),
        onPressed: _busy ? null : _contact,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Nhắn tin cho chủ sân'),
      ),
    ];
  }

  List<Widget> _blocked(DemoPayment p) {
    final deadline = s.bookingCancellationDeadline(b);
    final late = s.now.isAfter(deadline);
    return [
      _redNotice(
        b.cancelled
            ? 'Lịch đã hủy.'
            : late
            ? 'Không thể yêu cầu hủy lịch. Thời gian còn lại không đủ điều kiện gửi yêu cầu.'
            : 'Không thể yêu cầu hủy ở trạng thái hiện tại.',
      ),
      _bookingSummary(b),
      _section('Thông tin khách hàng', [_row(b.contact, b.phone)]),
      _section('Điều kiện hủy lịch', [
        Text(
          'Chỉ cho phép gửi yêu cầu khi còn ít nhất ${s.bookingCancellationMinimumHours(b)} giờ trước giờ bắt đầu.',
        ),
        _row('Hạn gửi yêu cầu', _stamp(deadline)),
        _row('Thời điểm hiện tại', _stamp(s.now)),
        _row('Giờ bắt đầu', _stamp(b.start)),
        if (late)
          _redNotice(
            'Đã quá hạn gửi yêu cầu ${_remainingFrom(deadline)}. ${b.cancelled ? 'Lịch đã hủy.' : 'Lịch đặt vẫn giữ nguyên.'}',
          ),
      ]),
      _section('Thông tin thanh toán', [
        _row('Trạng thái', p.label(s.now)),
        _row('Tổng đơn', bookingMoney(b.total)),
        _row('Phí dịch vụ', bookingMoney(0)),
        _row('Tổng thanh toán', bookingMoney(b.total), total: true),
        const Text(
          'Chưa gửi yêu cầu hủy. Không phát sinh phí hủy hay khoản hoàn tiền.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ]),
      const OutlinedButton(
        onPressed: null,
        child: Text('Yêu cầu hủy lịch · Không đủ điều kiện'),
      ),
      _section('Bạn cần hỗ trợ?', [
        const Text(
          'Có thể nhắn chủ sân về lịch đặt. Liên hệ hỗ trợ không thay thế yêu cầu hủy và không đảm bảo hoàn tiền.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('cancellation-contact'),
          onPressed: _busy ? null : _contact,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Nhắn tin cho chủ sân'),
        ),
      ]),
      _greenButton(
        'cancellation-history',
        'Về danh sách lịch đã đặt',
        _history,
      ),
    ];
  }

  String _remainingFrom(DateTime deadline) {
    final minutes = s.now.difference(deadline).inMinutes.clamp(0, 99999);
    return '${minutes ~/ 60} giờ ${minutes % 60} phút';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      if (!_authorized) {
        return Scaffold(
          appBar: financeBar('Yêu cầu hủy lịch'),
          body: const Center(child: Text('Không có quyền truy cập lịch này.')),
        );
      }
      final p = s.paymentFor(b);
      if (p == null) {
        return Scaffold(
          appBar: financeBar('Yêu cầu hủy lịch'),
          body: const Center(
            child: Text('Chưa có thông tin thanh toán của lịch này.'),
          ),
        );
      }
      final status =
          p.cancellation != DemoCancellationState.none &&
          (!_newRequest || p.cancellation != DemoCancellationState.rejected);
      final valid = s.canRequestBookingCancellation(b);
      return Scaffold(
        backgroundColor: _background,
        appBar: _header(
          context,
          status
              ? 'Trạng thái yêu cầu hủy'
              : valid
              ? 'Yêu cầu hủy lịch'
              : 'Chi tiết lịch đặt',
          b.id,
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FinanceSaveNotice(session: s),
              if (status)
                ..._status(p)
              else if (valid)
                ..._request(p)
              else
                ..._blocked(p),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    key: const Key('cancellation-error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (p.customerMessages.isNotEmpty)
                _section('Tin nhắn đã gửi', [
                  for (final message in p.customerMessages)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(message.text),
                      subtitle: Text(_stamp(message.created)),
                    ),
                ]),
            ],
          ),
        ),
      );
    },
  );
}
