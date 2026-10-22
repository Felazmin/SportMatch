import 'dart:async';
import 'dart:typed_data';

import 'owner_booking_views.dart';

import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';
import 'reviews_screen.dart';
import 'calendar_screen.dart';

AppBar workflowBar(BuildContext context, String title) => AppBar(
  toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 24 ? 104 : 56,
  title: Text(title, maxLines: 2, style: const TextStyle(fontSize: 18)),
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
);

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _code = TextEditingController();
  String _filter = 'all';
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _open(String id) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WorkflowDetailScreen(
        session: widget.session,
        id: id,
        ownerPresentation: false,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: workflowBar(context, 'Quản lý lịch'),
          body: const Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final entries = s.managedAttendance
          .where(
            (r) =>
                _filter == 'all' ||
                (_filter == 'active' &&
                    !r.cancelled &&
                    r.attendance == DemoAttendance.pending) ||
                (_filter == 'checkedIn' &&
                    !r.cancelled &&
                    r.attendance == DemoAttendance.checkedIn) ||
                (_filter == 'cancelled' && r.cancelled) ||
                (_filter == 'completed' &&
                    r.attendance == DemoAttendance.completed) ||
                (_filter == 'absent' && r.attendance == DemoAttendance.absent),
          )
          .toList();
      return Scaffold(
        appBar: workflowBar(context, 'Check-in & quản lý lịch'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            TextField(
              key: const Key('attendance-code'),
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Mã lịch / nội dung QR demo',
              ),
              maxLines: 3,
              minLines: 1,
            ),
            FilledButton.icon(
              key: const Key('attendance-lookup'),
              icon: const Icon(Icons.search),
              label: const Text('Kiểm tra mã'),
              onPressed: () {
                try {
                  final r = s.checkAttendanceCode(_code.text);
                  setState(() => _error = null);
                  _open(r.id);
                } on StateError catch (e) {
                  setState(() => _error = e.message);
                }
              },
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const Divider(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in {
                  'all': 'Tất cả',
                  'active': 'Chưa check-in',
                  'checkedIn': 'Đã check-in',
                  'completed': 'Hoàn thành',
                  'absent': 'Vắng mặt',
                  'cancelled': 'Đã hủy',
                }.entries)
                  ChoiceChip(
                    key: Key('attendance-filter-${e.key}'),
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => setState(() => _filter = e.key),
                  ),
              ],
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Không có lịch phù hợp.'),
              ),
            for (final r in entries)
              ListTile(
                key: Key('attendance-${r.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: Text('${r.id} · ${r.title}'),
                subtitle: Text(
                  '${bookingDate(r.start)} · ${bookingTime(r.start)}\n${r.cancelled ? 'Đã hủy' : s.attendanceLabel(r.attendance)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(r.id),
              ),
          ],
        ),
      );
    },
  );
}

class WorkflowDetailScreen extends StatefulWidget {
  const WorkflowDetailScreen({
    super.key,
    required this.session,
    required this.id,
    this.pickImage,
    this.ownerPresentation = false,
  });
  final DemoSession session;
  final String id;
  final Future<Uint8List?> Function()? pickImage;
  final bool ownerPresentation;
  @override
  State<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends State<WorkflowDetailScreen> {
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

  final _reference = TextEditingController();
  Uint8List? _refundProof;
  Timer? _timer;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
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
              : 'Chưa xử lý được. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String title, void Function() action) async {
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
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: OutlinedButton.icon(
      key: Key(key),
      onPressed: _busy ? null : action,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
  Widget _proof(String value) => SizedBox(
    height: 180,
    child: Image.memory(
      decodeProof(value),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Center(child: Text('Không đọc được ảnh.')),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      DemoWorkflowRecord r;
      try {
        r = s.workflowRecord(widget.id);
      } on StateError {
        return Scaffold(
          appBar: workflowBar(context, 'Hồ sơ'),
          body: const Center(child: Text('Không có quyền truy cập hồ sơ.')),
        );
      }
      final manager = s.role != DemoRole.player;
      if (s.role == DemoRole.owner &&
          widget.ownerPresentation &&
          s.managedBookings.any((b) => b.id == widget.id)) {
        return OwnerBookingView(session: s, id: widget.id);
      }
      final ticket = (manager ? s.managedParticipations : s.participations)
          .where((p) => p.id == r.id)
          .firstOrNull;
      final p = s.workflowPayment(r.id);
      final editable =
          !manager &&
          ticket != null &&
          !r.cancelled &&
          r.start.isAfter(s.now) &&
          (p == null ||
              (!p.expired(s.now) &&
                  p.cancellation != DemoCancellationState.requested &&
                  (p.state == DemoPaymentState.awaitingProof ||
                      p.state == DemoPaymentState.rejected)));
      return Scaffold(
        appBar: workflowBar(context, 'Hồ sơ ${r.id}'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              r.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              '${bookingDate(r.start)} · ${bookingTime(r.start)} – ${bookingTime(r.end)}',
            ),
            Text('Tổng: ${bookingMoney(r.total)}'),
            Text(
              r.cancelled ? 'Đã hủy' : s.attendanceLabel(r.attendance),
              key: const Key('workflow-attendance'),
            ),
            const Divider(height: 32),
            Text(
              p?.label(s.now) ?? 'Chưa xác nhận thanh toán',
              key: const Key('workflow-payment'),
            ),
            if (p?.atVenue == true)
              const Text(
                'Thanh toán tại sân được ghi nhận trong demo, không thu tiền thật.',
              ),
            if (manager &&
                ticket == null &&
                !r.cancelled &&
                r.attendance == DemoAttendance.pending) ...[
              if (p == null && s.now.isBefore(r.end))
                _button(
                  'calendar-onsite',
                  'Xác nhận thanh toán tại sân',
                  Icons.payments_outlined,
                  () => _confirm(
                    'Ghi nhận thanh toán tại sân demo?',
                    () => s.confirmVenuePayment(
                      s.managedBookings.firstWhere((b) => b.id == r.id),
                    ),
                  ),
                ),
              if (r.start.isAfter(s.now) &&
                  (p == null ||
                      (p.state == DemoPaymentState.approved &&
                          p.cancellation != DemoCancellationState.requested &&
                          p.refund == DemoRefundState.none)))
                _button(
                  'calendar-reschedule',
                  'Đổi lịch đặt sân',
                  Icons.edit_calendar_outlined,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) {
                        final b = s.managedBookings.firstWhere(
                          (b) => b.id == r.id,
                        );
                        return CalendarEditorScreen(
                          session: s,
                          court: b.court,
                          start: b.start,
                          booking: b,
                        );
                      },
                    ),
                  ),
                ),
            ],
            if (p != null) ...[
              if (p.reviewNote.isNotEmpty)
                Text('Yêu cầu gửi lại: ${p.reviewNote}'),
              if (p.cancellation != DemoCancellationState.none)
                Text(p.cancellationLabel),
              if (p.cancellationReason.isNotEmpty)
                Text('Lý do hủy: ${p.cancellationReason}'),
              if (p.cancellationNote.isNotEmpty)
                Text('Phản hồi: ${p.cancellationNote}'),
              if (p.proof.isNotEmpty) _proof(p.proof),
              if (p.reference.isNotEmpty) Text('Tham chiếu: ${p.reference}'),
            ],
            if (editable && p == null)
              _button(
                'ticket-start',
                'Chuyển khoản demo',
                Icons.account_balance_outlined,
                () => _perform(() {
                  s.startTicketTransfer(ticket);
                }),
              ),
            if (editable && p != null) ...[
              const Text(
                'Ngân hàng: MÔ PHỎNG\nTài khoản: DEMO-KHÔNG-CHUYỂN-TIỀN',
              ),
              Text(
                'Hạn gửi: ${bookingDate(p.deadline)} ${p.deadline.hour}:${p.deadline.minute.toString().padLeft(2, '0')}',
              ),
              _button(
                'ticket-proof',
                'Chọn minh chứng',
                Icons.image_outlined,
                () => _perform(() async {
                  final bytes = await (widget.pickImage ?? ProofPicker.pick)();
                  if (bytes != null) s.saveTicketProof(ticket, bytes);
                }),
              ),
              if (p.draft.isNotEmpty) _proof(p.draft),
              TextField(
                key: const Key('workflow-reference'),
                controller: _reference,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Mã tham chiếu demo',
                ),
              ),
              _button(
                'ticket-submit',
                'Gửi minh chứng',
                Icons.send_outlined,
                () => _confirm(
                  'Gửi minh chứng vé?',
                  () => s.submitTicketProof(ticket, _reference.text),
                ),
              ),
            ],
            if (!manager &&
                ticket != null &&
                p?.expired(s.now) == true &&
                !r.cancelled &&
                r.start.isAfter(s.now) &&
                p!.cancellation != DemoCancellationState.requested)
              _button(
                'ticket-restart',
                'Tạo phiên thanh toán mới',
                Icons.refresh,
                () => _perform(() {
                  s.startTicketTransfer(ticket);
                }),
              ),
            if (manager &&
                ticket != null &&
                p?.state == DemoPaymentState.pending &&
                !r.cancelled &&
                p!.cancellation != DemoCancellationState.requested) ...[
              _button(
                'ticket-received-date',
                'Ngày ghi nhận: ${bookingDate(_receivedDay ?? s.now)}',
                Icons.date_range,
                _pickReceivedDay,
              ),
              _button(
                'ticket-approve',
                'Xác nhận thanh toán',
                Icons.check_circle_outline,
                () => _confirm(
                  'Xác nhận minh chứng vé?',
                  () => s.reviewTicketPayment(
                    ticket,
                    approve: true,
                    receivedAt: _receivedDay,
                  ),
                ),
              ),
              _button(
                'ticket-reject',
                'Yêu cầu gửi lại',
                Icons.undo,
                () => _reason(
                  'Lý do từ chối minh chứng',
                  (note) =>
                      s.reviewTicketPayment(ticket, approve: false, note: note),
                ),
              ),
            ],
            if (!manager &&
                ticket != null &&
                p != null &&
                !r.cancelled &&
                r.attendance == DemoAttendance.pending &&
                p.cancellation != DemoCancellationState.requested &&
                r.start.difference(s.now) >= const Duration(hours: 24))
              _button(
                'ticket-cancel',
                'Yêu cầu hủy vé',
                Icons.cancel_outlined,
                () => _reason(
                  'Lý do hủy vé',
                  (reason) => s.requestTicketCancellation(ticket, reason),
                ),
              ),
            if (ticket != null)
              const Text(
                'Chính sách demo: yêu cầu hủy trước 24 giờ, chưa check-in; vé đã xác nhận được hoàn 100% sau duyệt.',
              ),
            if (manager &&
                ticket != null &&
                p?.cancellation == DemoCancellationState.requested) ...[
              _button(
                'ticket-cancel-approve',
                'Chấp thuận hủy',
                Icons.check,
                () => _confirm(
                  'Duyệt hủy và trả chỗ?',
                  () => s.reviewTicketCancellation(ticket, approve: true),
                ),
              ),
              _button(
                'ticket-cancel-reject',
                'Từ chối hủy',
                Icons.close,
                () => _reason(
                  'Lý do từ chối hủy',
                  (note) => s.reviewTicketCancellation(
                    ticket,
                    approve: false,
                    note: note,
                  ),
                ),
              ),
            ],
            if (p != null && p.refund != DemoRefundState.none) ...[
              const Divider(height: 32),
              Text(p.refundLabel, key: const Key('workflow-refund')),
              Text(
                'Số tiền hoàn demo: ${bookingMoney(p.refundAmount ?? r.total)}',
              ),
              if (p.refundReference.isNotEmpty)
                Text('Tham chiếu hoàn: ${p.refundReference}'),
              if (p.refundProof.isNotEmpty) _proof(p.refundProof),
              if (manager && p.refund == DemoRefundState.pending) ...[
                TextField(
                  key: const Key('refund-reference'),
                  controller: _reference,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Tham chiếu hoàn demo',
                  ),
                ),
                _button(
                  'refund-proof',
                  'Chọn chứng từ hoàn demo',
                  Icons.image_outlined,
                  () => _perform(() async {
                    final bytes =
                        await (widget.pickImage ?? ProofPicker.pick)();
                    if (bytes != null) {
                      encodeProof(bytes);
                      if (mounted) setState(() => _refundProof = bytes);
                    }
                  }),
                ),
                if (_refundProof != null) const Text('Đã chọn chứng từ nháp'),
                _button(
                  'refund-record',
                  'Xác nhận đã hoàn demo',
                  Icons.currency_exchange,
                  () => _confirm('Ghi nhận khoản hoàn demo?', () {
                    if (_refundProof == null) {
                      throw StateError('Chọn chứng từ hoàn trước.');
                    }
                    s.recordWorkflowRefund(
                      r.id,
                      _reference.text,
                      _refundProof!,
                    );
                  }),
                ),
              ],
            ],
            if (!manager &&
                ticket == null &&
                s.reviewableBookings.any((b) => b.id == r.id))
              _button(
                'workflow-review',
                'Đánh giá sân',
                Icons.rate_review_outlined,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReviewFormScreen(session: s, bookingId: r.id),
                  ),
                ),
              ),
            if (manager && !r.cancelled) ...[
              const Divider(height: 32),
              if (r.attendance == DemoAttendance.pending &&
                  !s.now.isBefore(
                    r.start.subtract(const Duration(minutes: 30)),
                  ) &&
                  s.now.isBefore(r.end))
                _button(
                  'attendance-checkin',
                  'Xác nhận check-in',
                  Icons.fact_check_outlined,
                  () => _confirm(
                    'Xác nhận check-in?',
                    () => s.setAttendance(r.id, DemoAttendance.checkedIn),
                  ),
                ),
              if (r.attendance == DemoAttendance.pending &&
                  !s.now.isBefore(r.end))
                _button(
                  'attendance-absent',
                  'Ghi nhận vắng mặt',
                  Icons.person_off_outlined,
                  () => _confirm(
                    'Ghi nhận vắng mặt?',
                    () => s.setAttendance(r.id, DemoAttendance.absent),
                  ),
                ),
              if (r.attendance == DemoAttendance.checkedIn &&
                  !s.now.isBefore(r.end))
                _button(
                  'attendance-complete',
                  'Xác nhận hoàn thành',
                  Icons.task_alt,
                  () => _confirm(
                    'Xác nhận hoàn thành lịch?',
                    () => s.setAttendance(r.id, DemoAttendance.completed),
                  ),
                ),
            ],
            if (!manager && ticket != null)
              _button(
                'ticket-dispute',
                'Gửi khiếu nại',
                Icons.report_outlined,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DisputeFormScreen(session: s, participation: ticket),
                  ),
                ),
              ),
            if (ticket == null)
              _button(
                'workflow-booking-payment',
                'Chi tiết thanh toán đặt sân',
                Icons.receipt_long_outlined,
                () {
                  final b = (manager ? s.managedBookings : s.bookings)
                      .firstWhere((b) => b.id == r.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(session: s, booking: b),
                    ),
                  );
                },
              ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('workflow-error'),
                style: const TextStyle(color: Colors.red),
              ),
            if (s.workflowHistory(r.id).isNotEmpty) ...[
              const Divider(height: 32),
              const Text(
                'Lịch sử xử lý',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final entry in s.workflowHistory(r.id).take(20))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(entry.action),
                  subtitle: Text(
                    '${bookingDate(entry.created)} ${entry.created.hour.toString().padLeft(2, '0')}:${entry.created.minute.toString().padLeft(2, '0')}',
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Dữ liệu demo trên thiết bị. Không chuyển tiền thật hoặc xác nhận tại sân thật. Chỉ dùng ảnh thử nghiệm PNG/JPEG dưới 400KB.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}
