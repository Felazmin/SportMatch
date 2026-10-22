import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import '../demo/demo_events.dart';
import 'workflow_screen.dart';
import 'customer_checkout_screen.dart';
import '../widgets/design.dart';

AppBar financeBar(String title) => AppBar(
  title: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
);

class ProofPicker {
  static Future<Uint8List?> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1600,
      imageQuality: 65,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > maxProofBytes) {
      throw const FormatException('Ảnh cần nhỏ hơn 400KB. Chọn ảnh nhỏ hơn.');
    }
    final bytes = await file.readAsBytes();
    encodeProof(bytes);
    return bytes;
  }

  static Future<String?> recover(
    DemoSession session, {
    Future<LostDataResponse> Function()? retrieve,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final response = await (retrieve ?? ImagePicker().retrieveLostData)();
      if (response.isEmpty) {
        if (session.proofPickerBooking != null) {
          session.clearProofPickerTarget();
          await session.flush();
        }
        return null;
      }
      final booking = session.proofPickerBooking;
      if (booking == null || response.files?.isNotEmpty != true) {
        if (booking != null) {
          session.clearProofPickerTarget();
          await session.flush();
        }
        return 'Chưa gắn được ảnh đã chọn. Mở thanh toán và chọn ảnh lại.';
      }
      final file = response.files!.first;
      if (await file.length() > maxProofBytes) {
        throw const FormatException('Ảnh cần nhỏ hơn 400KB.');
      }
      session.saveProofDraft(booking, await file.readAsBytes());
      await session.flush();
      return 'Đã khôi phục ảnh nháp cho ${booking.id}. Ảnh chưa được gửi duyệt.';
    } catch (_) {
      return session.proofPickerBooking == null
          ? null
          : 'Chưa khôi phục được ảnh minh chứng. Hãy chọn ảnh lại.';
    }
  }
}

class FinanceSaveNotice extends StatelessWidget {
  const FinanceSaveNotice({super.key, required this.session});
  final DemoSession session;
  @override
  Widget build(BuildContext context) => !session.saveFailed
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chưa lưu được thay đổi. Đừng đóng ứng dụng.',
                style: TextStyle(color: Colors.red),
              ),
              TextButton.icon(
                key: const Key('finance-retry-save'),
                onPressed: session.retrySave,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lưu lại'),
              ),
            ],
          ),
        );
}

Future<String?> financeText(
  BuildContext context,
  String title, {
  int minimum = 5,
  int maximum = 300,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _ReasonDialog(title: title, minimum: minimum, maximum: maximum),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.minimum,
    required this.maximum,
  });
  final String title;
  final int minimum;
  final int maximum;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: TextField(
        key: const Key('finance-reason'),
        controller: _text,
        minLines: 2,
        maxLines: 5,
        maxLength: widget.maximum,
        decoration: InputDecoration(
          labelText: 'Nội dung',
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        key: const Key('finance-text-confirm'),
        onPressed: () {
          if (_text.text.trim().length < widget.minimum) {
            setState(() => _error = 'Cần ít nhất ${widget.minimum} ký tự.');
            return;
          }
          Navigator.pop(context, _text.text.trim());
        },
        child: const Text('Xác nhận'),
      ),
    ],
  );
}

Future<bool> financeConfirm(
  BuildContext context,
  String title, [
  String? message,
]) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          message ?? 'Chỉ cập nhật dữ liệu demo trên thiết bị. Không phát sinh giao dịch ngân hàng thực tế.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            key: const Key('finance-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ==
    true;

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.session,
    required this.booking,
    this.pickImage,
  });
  final DemoSession session;
  final DemoBooking booking;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  DateTime? _receivedDay;
  Future<void> _pickReceivedDay() async {
    final actor = widget.session.user?.identifier;
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: bookingDay(widget.session.now),
      initialDate: _receivedDay ?? bookingDay(widget.session.now),
    );
    if (selected != null &&
        mounted &&
        actor == widget.session.user?.identifier &&
        widget.session.role != DemoRole.player) {
      setState(() => _receivedDay = selected);
    }
  }

  final _decodedProofs = <String, Uint8List>{};
  final _reference = TextEditingController();
  bool _busy = false;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _perform(FutureOr<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!await widget.session.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : e is FormatException
              ? e.message
              : 'Không thể xử lý. Kiểm tra quyền truy cập ảnh và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() => _perform(() async {
    final s = widget.session;
    s.setProofPickerTarget(widget.booking);
    if (!await s.flush()) {
      throw StateError('Chưa lưu được phiên chọn ảnh. Hãy thử lưu trước.');
    }
    try {
      final bytes = await (widget.pickImage ?? ProofPicker.pick)();
      if (bytes != null) {
        s.saveProofDraft(widget.booking, bytes);
      } else {
        s.clearProofPickerTarget();
      }
    } catch (_) {
      s.clearProofPickerTarget();
      rethrow;
    }
  });
  Future<void> _decision(String title, void Function() action) async {
    if (_busy) return;
    final actor = widget.session.user?.identifier;
    if (!await financeConfirm(context, title) || !mounted) return;
    await _perform(() {
      if (widget.session.user?.identifier != actor) {
        throw StateError('Tài khoản đã thay đổi. Mở lại hồ sơ.');
      }
      action();
    });
  }

  Future<void> _reason(String title, void Function(String) action) async {
    if (_busy) return;
    final actor = widget.session.user?.identifier;
    final text = await financeText(context, title);
    if (mounted && text != null) {
      await _perform(() {
        if (widget.session.user?.identifier != actor) {
          throw StateError('Tài khoản đã thay đổi. Mở lại hồ sơ.');
        }
        action(text);
      });
    }
  }

  Widget _button(
    String key,
    String label,
    IconData icon,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton.icon(
      key: Key(key),
      onPressed: _busy ? null : action,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
  Widget _proof(String proof, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      SizedBox(
        height: 200,
        child: Image.memory(
          _decodedProofs.putIfAbsent(proof, () => decodeProof(proof)),
          cacheWidth: 1200,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Center(
            child: Text('Ảnh không đọc được. Hãy chọn ảnh khác.'),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ],
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final b = widget.booking;
      final manager = s.user != null && s.role != DemoRole.player;
      if (s.user == null || (!manager && s.user!.identifier != b.owner)) {
        return Scaffold(
          appBar: financeBar('Thanh toán'),
          body: const Center(child: Text('Không có quyền truy cập lịch này.')),
        );
      }
      final p = s.paymentFor(b);
      if (!manager && p?.checkout == true) {
        return p!.state == DemoPaymentState.awaitingProof ||
                p.state == DemoPaymentState.rejected
            ? CustomerCheckoutPaymentScreen(
                session: s,
                booking: b,
                pickImage: widget.pickImage,
              )
            : CustomerCheckoutDetailScreen(session: s, booking: b);
      }
      _decodedProofs.removeWhere(
        (key, _) => key != p?.proof && key != p?.draft,
      );
      final editable =
          !manager &&
          !b.cancelled &&
          b.start.isAfter(s.now) &&
          p != null &&
          !p.expired(s.now) &&
          p.cancellation != DemoCancellationState.requested &&
          (p.state == DemoPaymentState.awaitingProof ||
              p.state == DemoPaymentState.rejected);
      return Scaffold(
        appBar: financeBar('Thanh toán ${b.id}'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              b.venueName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              'Sân ${b.court} · ${bookingDate(b.start)} · ${bookingTime(b.start)}',
            ),
            const SizedBox(height: 12),
            Text(
              'Tổng: ${bookingMoney(b.total)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (p == null) ...[
              Text(
                b.cancellationPolicy.summary,
                key: const Key('payment-policy-summary'),
              ),
              const Text('Thanh toán tại sân · Chưa thanh toán'),
              if (!manager && !b.cancelled && b.start.isAfter(s.now))
                _button(
                  'payment-start-transfer',
                  'Chọn chuyển khoản demo',
                  Icons.account_balance_outlined,
                  () => _perform(() {
                    s.startTransfer(b);
                  }),
                ),
            ] else ...[
              Text(
                b.cancellationPolicy.summary,
                key: const Key('payment-policy-summary'),
              ),
              Text(
                p.label(s.now),
                key: const Key('payment-status'),
                style: const TextStyle(
                  color: AppColors.darkGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (p.cancellation != DemoCancellationState.none)
                Text(p.cancellationLabel),
              if (p.refund != DemoRefundState.none) Text(p.refundLabel),
              if (p.receivedAt != null)
                Text('Ngày ghi nhận thu: ${bookingDate(p.receivedAt!)}'),
              if (p.refund != DemoRefundState.none)
                Text(
                  'Khoản hoàn demo: ${bookingMoney(p.refundAmount ?? b.total)}',
                ),
              if (p.reviewNote.isNotEmpty)
                Text('Lý do cần gửi lại: ${p.reviewNote}'),
              if (p.cancellationReason.isNotEmpty)
                Text('Lý do hủy: ${p.cancellationReason}'),
              if (manager && p.refundDestination != null) ...[
                if (p.cancellationEstimate != null)
                  Text(
                    'Dự kiến hoàn khi gửi yêu cầu: ${bookingMoney(p.cancellationEstimate!)}',
                  ),
                if (p.refundDestination!.qr.isNotEmpty)
                  _proof(
                    p.refundDestination!.qr,
                    'QR nhận hoàn tiền do khách gửi',
                  )
                else
                  Text(
                    'Tài khoản nhận hoàn: ${p.refundDestination!.bank}\n${p.refundDestination!.holder}\n${p.refundDestination!.account}',
                  ),
              ],
              if (manager && p.customerMessages.isNotEmpty) ...[
                const Text(
                  'Tin nhắn của khách về lịch đặt',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final message in p.customerMessages)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(message.text),
                    subtitle: Text(
                      '${bookingDate(message.created)} · ${message.created.hour.toString().padLeft(2, '0')}:${message.created.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
              ],
              if (p.cancellationNote.isNotEmpty)
                Text('Phản hồi hủy: ${p.cancellationNote}'),
              const Divider(height: 32),
              if (editable) ...[
                const Text(
                  'Ngân hàng: MÔ PHỎNG\nTài khoản: DEMO-KHÔNG-CHUYỂN-TIỀN',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('Nội dung tham chiếu: ${b.id}'),
                Text(
                  'Hạn gửi ảnh: ${bookingDate(p.deadline)} ${p.deadline.hour.toString().padLeft(2, '0')}:${p.deadline.minute.toString().padLeft(2, '0')}',
                ),
                const SizedBox(height: 16),
                _button(
                  'payment-pick-proof',
                  'Chọn ảnh minh chứng',
                  Icons.image_outlined,
                  _pick,
                ),
                if (p.draft.isNotEmpty)
                  _proof(p.draft, 'Ảnh nháp · Chưa gửi duyệt'),
                TextField(
                  key: const Key('payment-reference'),
                  controller: _reference,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Mã tham chiếu demo',
                  ),
                ),
                FilledButton.icon(
                  key: const Key('payment-submit-proof'),
                  onPressed: _busy
                      ? null
                      : () => _perform(() {
                          s.submitProof(b, _reference.text);
                        }),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Gửi minh chứng demo'),
                ),
                const SizedBox(height: 16),
              ],
              if (p.proof.isNotEmpty) ...[
                _proof(p.proof, 'Minh chứng đã gửi'),
                if (p.studentProof.isNotEmpty)
                  _proof(p.studentProof, 'Thẻ học sinh / sinh viên đã gửi'),
                if (p.customerNote.isNotEmpty)
                  Text('Ghi chú của khách: ${p.customerNote}'),
                Text('Mã tham chiếu: ${p.reference}'),
              ],
              if (!manager &&
                  !b.cancelled &&
                  b.start.isAfter(s.now) &&
                  p.expired(s.now) &&
                  p.cancellation != DemoCancellationState.requested)
                _button(
                  'payment-restart',
                  'Tạo phiên chuyển khoản mới',
                  Icons.refresh,
                  () => _perform(() {
                    s.startTransfer(b);
                  }),
                ),
              if (!manager &&
                  !b.cancelled &&
                  b.cancellationPolicy.canRequest(b.start, s.now) &&
                  p.cancellation != DemoCancellationState.requested)
                _button(
                  'payment-request-cancel',
                  'Yêu cầu hủy lịch',
                  Icons.cancel_outlined,
                  () => _reason(
                    'Lý do yêu cầu hủy',
                    (reason) => s.requestCancellation(b, reason),
                  ),
                ),
              if (manager &&
                  !b.cancelled &&
                  p.state == DemoPaymentState.pending &&
                  p.cancellation != DemoCancellationState.requested) ...[
                _button(
                  'payment-received-date',
                  'Ngày ghi nhận: ${bookingDate(_receivedDay ?? s.now)}',
                  Icons.date_range,
                  _pickReceivedDay,
                ),
                _button(
                  'payment-approve',
                  'Xác nhận minh chứng demo',
                  Icons.check_circle_outline,
                  () => _decision('Xác nhận thanh toán demo?', () {
                    s.reviewPayment(b, approve: true, receivedAt: _receivedDay);
                  }),
                ),
                _button(
                  'payment-reject',
                  'Yêu cầu gửi lại',
                  Icons.undo,
                  () => _reason(
                    'Lý do cần gửi lại',
                    (reason) =>
                        s.reviewPayment(b, approve: false, note: reason),
                  ),
                ),
              ],
              if (manager &&
                  p.cancellation == DemoCancellationState.requested) ...[
                if (b.start.isAfter(s.now))
                  _button(
                    'payment-approve-cancel',
                    'Duyệt hủy và trả khung giờ',
                    Icons.check,
                    () => _decision('Duyệt hủy lịch?', () {
                      s.reviewCancellation(b, approve: true);
                    }),
                  ),
                _button(
                  'payment-reject-cancel',
                  'Từ chối yêu cầu hủy',
                  Icons.close,
                  () => _reason(
                    'Lý do từ chối hủy',
                    (reason) =>
                        s.reviewCancellation(b, approve: false, note: reason),
                  ),
                ),
              ],
              if (manager && p.refund == DemoRefundState.pending)
                _button(
                  'payment-refund',
                  'Ghi nhận hoàn tiền demo',
                  Icons.currency_exchange,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkflowDetailScreen(
                        session: s,
                        id: b.id,
                        pickImage: widget.pickImage,
                      ),
                    ),
                  ),
                ),
            ],
            if (_error != null)
              Text(
                _error!,
                key: const Key('payment-error'),
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Điểm danh / chứng từ hoàn'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkflowDetailScreen(session: s, id: b.id),
                ),
              ),
            ),
            const Text(
              'Không chuyển tiền thật. Ảnh được lưu mã hóa trên thiết bị, không gửi ngân hàng hay máy chủ. Chỉ dùng ảnh thử nghiệm PNG/JPEG, tối đa 400KB.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class DisputeFormScreen extends StatefulWidget {
  const DisputeFormScreen({
    super.key,
    required this.session,
    this.booking,
    this.participation,
  }) : assert((booking == null) != (participation == null));
  final DemoSession session;
  final DemoBooking? booking;
  final DemoParticipation? participation;
  @override
  State<DisputeFormScreen> createState() => _DisputeFormScreenState();
}

class DisputesScreen extends StatelessWidget {
  const DisputesScreen({super.key, required this.session});
  final DemoSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Scaffold(
      appBar: financeBar('Khiếu nại của tôi'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FinanceSaveNotice(session: session),
          if (session.disputes.isEmpty) const Text('Chưa có khiếu nại.'),
          for (final d in session.disputes)
            ListTile(
              key: Key('dispute-${d.id}'),
              title: Text(d.subject),
              subtitle: Text('${d.bookingId} · ${d.label}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DisputeDetailScreen(session: session, dispute: d),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _DisputeFormScreenState extends State<DisputeFormScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = widget.booking != null
          ? widget.session.createDispute(
              widget.booking!,
              _subject.text,
              _message.text,
            )
          : widget.session.createTicketDispute(
              widget.participation!,
              _subject.text,
              _message.text,
            );
      await widget.session.flush();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DisputeDetailScreen(session: widget.session, dispute: d),
          ),
        );
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: financeBar(
      'Khiếu nại ${widget.booking?.id ?? widget.participation!.id}',
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          key: const Key('dispute-subject'),
          controller: _subject,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Tiêu đề'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('dispute-message'),
          controller: _message,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Nội dung'),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          key: const Key('dispute-submit'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu...' : 'Tạo khiếu nại demo'),
        ),
      ],
    ),
  );
}

class DisputeDetailScreen extends StatefulWidget {
  const DisputeDetailScreen({
    super.key,
    required this.session,
    required this.dispute,
  });
  final DemoSession session;
  final DemoDispute dispute;
  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  bool _busy = false;
  DemoDisputeDecision _decision = DemoDisputeDecision.uphold;
  String? _error;
  Future<void> _closeCase() async {
    if (_busy) return;
    final confirmed = await financeConfirm(
      context,
      'Đóng khiếu nại?',
      'Lưu kết quả đã thực hiện trong hồ sơ demo. Không thể mở lại hồ sơ này.',
    );
    if (!mounted || !confirmed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.closeDispute(widget.dispute);
      await widget.session.flush();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(bool resolve) async {
    if (_busy) return;
    final text = await financeText(
      context,
      resolve ? 'Kết quả xử lý Admin' : 'Phản hồi Chủ sân',
      minimum: 10,
      maximum: 1000,
    );
    if (!mounted || text == null) return;
    if (resolve &&
        (!await financeConfirm(
              context,
              'Xác nhận quyết định Admin?',
              _decision == DemoDisputeDecision.refund
                  ? 'Duyệt hủy và tạo khoản hoàn demo. Chưa thực hiện chuyển tiền.'
                  : 'Giữ nguyên kết quả; không tạo khoản hoàn.',
            ) ||
            !mounted)) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (resolve) {
        widget.session.decideDispute(widget.dispute, _decision, text);
      } else {
        widget.session.respondToDispute(widget.dispute, text);
      }
      await widget.session.flush();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await ProofPicker.pick();
      if (bytes != null) {
        widget.session.attachDisputeEvidence(widget.dispute, bytes);
        await widget.session.flush();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Chưa bổ sung được ảnh thử nghiệm.',
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
      final s = widget.session;
      final d = widget.dispute;
      if (!s.disputes.contains(d)) {
        return Scaffold(
          appBar: financeBar('Khiếu nại'),
          body: const Center(child: Text('Không có quyền xem khiếu nại này.')),
        );
      }
      return Scaffold(
        appBar: financeBar(d.id),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              d.subject,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text('Lịch ${d.bookingId} · ${bookingDate(d.created)}'),
            const SizedBox(height: 12),
            Text(d.label, style: const TextStyle(color: AppColors.darkGreen)),
            const Divider(height: 32),
            Text(d.message),
            if (d.evidence.isNotEmpty)
              SizedBox(
                height: 180,
                child: Image.memory(
                  decodeProof(d.evidence),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Không đọc được bằng chứng.'),
                ),
              ),
            if (s.role == DemoRole.player && d.resolution.isEmpty)
              OutlinedButton.icon(
                onPressed: _busy ? null : _attach,
                icon: const Icon(Icons.attach_file),
                label: const Text('Bổ sung ảnh bằng chứng'),
              ),
            if (d.response.isNotEmpty) ...[
              const Divider(height: 32),
              const Text(
                'Phản hồi Chủ sân',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(d.response),
            ],
            if (d.resolution.isNotEmpty) ...[
              const Divider(height: 32),
              const Text(
                'Kết quả Admin',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(d.resolution),
              if (d.closedAt != null)
                Text(
                  'Đóng lúc ${bookingDate(d.closedAt!)} '
                  '${d.closedAt!.hour.toString().padLeft(2, '0')}:'
                  '${d.closedAt!.minute.toString().padLeft(2, '0')}',
                  key: const Key('dispute-closed-at'),
                )
              else ...[
                Text(
                  d.decision == null
                      ? 'Hồ sơ cũ chưa có loại quyết định; chưa thể đóng.'
                      : s.disputeReadyToClose(d)
                      ? 'Đã đủ điều kiện đóng hồ sơ.'
                      : 'Chờ ghi nhận khoản hoàn kèm mã tham chiếu và ảnh minh chứng.',
                  key: const Key('dispute-execution-status'),
                ),
                if (s.role == DemoRole.admin && s.disputeReadyToClose(d))
                  FilledButton.icon(
                    key: const Key('dispute-close'),
                    onPressed: _busy || s.saveFailed ? null : _closeCase,
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Đóng hồ sơ'),
                  ),
              ],
              if (d.decision != null)
                Text(
                  d.decision == DemoDisputeDecision.refund
                      ? 'Quyết định: hoàn tiền demo'
                      : 'Quyết định: giữ nguyên kết quả',
                ),
              TextButton.icon(
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Theo dõi hồ sơ / khoản hoàn'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WorkflowDetailScreen(session: s, id: d.bookingId),
                  ),
                ),
              ),
            ],
            if (s.role != DemoRole.player && d.resolution.isEmpty) ...[
              OutlinedButton(
                key: const Key('dispute-respond'),
                onPressed: _busy ? null : () => _respond(false),
                child: const Text('Phản hồi'),
              ),
              if (s.role == DemoRole.admin) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final decision in DemoDisputeDecision.values)
                      ChoiceChip(
                        key: Key('dispute-decision-${decision.name}'),
                        label: Text(
                          decision == DemoDisputeDecision.refund
                              ? 'Chấp thuận hoàn'
                              : 'Giữ nguyên',
                        ),
                        selected: _decision == decision,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _decision = decision),
                      ),
                  ],
                ),
                FilledButton(
                  key: const Key('dispute-resolve'),
                  onPressed: _busy ? null : () => _respond(true),
                  child: const Text('Ghi nhận kết quả Admin'),
                ),
              ],
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            const Text(
              'Hồ sơ demo liên kết lịch đặt. Kết quả chỉ là ghi nhận nội bộ, không tự thực hiện hoàn tiền.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}
