import 'package:flutter/material.dart';

import '../demo/demo_events.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_extras.dart';
import '../widgets/design.dart';
import 'auth_screen.dart';
import 'booking_screen.dart';

AppBar _bar(String title) => AppBar(
  title: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
);
Widget _note(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Text(
    text,
    style: const TextStyle(color: AppColors.muted, height: 1.5),
  ),
);
Widget _empty(String text, IconData icon) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 40),
  child: Column(
    children: [
      Icon(icon, size: 40, color: AppColors.faint),
      const SizedBox(height: 16),
      Text(text, textAlign: TextAlign.center),
    ],
  ),
);

class VoucherWalletScreen extends StatelessWidget {
  const VoucherWalletScreen({super.key, required this.session, this.subtotal});
  final DemoSession session;
  final int? subtotal;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Scaffold(
      appBar: _bar(subtotal == null ? 'Ví ưu đãi' : 'Chọn ưu đãi'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _note(
            'Ưu đãi demo · Mỗi mã dùng cho một lịch đặt. Hủy lịch trước giờ bắt đầu sẽ trả lại mã. Không quy đổi thành tiền.',
          ),
          if (subtotal != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Không dùng ưu đãi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, ''),
            ),
          if (session.vouchers.isEmpty)
            _empty('Bạn đã dùng hết ưu đãi.', Icons.local_offer_outlined),
          for (final voucher in session.vouchers)
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      voucher.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      voucher.code,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    _note(
                      voucher.minimum == 0
                          ? 'Áp dụng cho mọi lịch đặt sân.'
                          : 'Đơn tối thiểu ${bookingMoney(voucher.minimum)}.',
                    ),
                    if (subtotal != null)
                      FilledButton(
                        key: Key('voucher-${voucher.code}'),
                        onPressed: voucher.discount(subtotal!) > 0
                            ? () => Navigator.pop(context, voucher.code)
                            : null,
                        child: Text(
                          voucher.discount(subtotal!) > 0
                              ? 'Áp dụng · -${bookingMoney(voucher.discount(subtotal!))}'
                              : 'Chưa đủ điều kiện',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (subtotal == null && session.user != null)
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VenueDetailScreen(session: session),
                ),
              ),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Đặt sân'),
            ),
        ],
      ),
    ),
  );
}

class PointsScreen extends StatelessWidget {
  const PointsScreen({super.key, required this.session});
  final DemoSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Scaffold(
      appBar: _bar('Điểm thưởng'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${session.points} điểm',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          _note(
            'Điểm demo: 1 điểm / 1.000đ sau giảm giá khi tạo lịch. Hủy lịch sẽ thu hồi điểm. Không có giá trị thanh toán hay đổi quà thực tế.',
          ),
          if (session.user?.seeded == true)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.stars_outlined),
              title: Text('Số dư demo ban đầu'),
              trailing: Text('+1040'),
            ),
          for (final booking in session.bookings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                booking.cancelled ? Icons.undo : Icons.add_circle_outline,
                color: AppColors.green,
              ),
              title: Text(booking.id),
              subtitle: Text(
                '${bookingDate(booking.start)} · ${booking.cancelled ? 'Đã thu hồi' : 'Điểm đặt sân demo'}',
              ),
              trailing: Text(
                booking.cancelled ? '0' : '+${booking.total ~/ 1000}',
              ),
            ),
          if (session.bookings.isEmpty)
            _empty('Chưa có lịch sử điểm.', Icons.stars_outlined),
        ],
      ),
    ),
  );
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _phone;
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _hidden = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.session.contactPhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_next.text.isNotEmpty &&
          !widget.session.changePassword(_current.text, _next.text)) {
        setState(() => _error = 'Mật khẩu hiện tại không đúng.');
        return;
      }
      if (_phone.text.trim().isEmpty) {
        widget.session.clearContactPhone();
      } else {
        widget.session.updateContactPhone(_phone.text);
      }
      final saved = await widget.session.flush();
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Đã lưu cài đặt.'
                : 'Chưa lưu được. Vui lòng thử lại trước khi đóng ứng dụng.',
          ),
        ),
      );
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _bar('Cài đặt tài khoản'),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _note('Tài khoản demo · Dữ liệu chỉ lưu trên thiết bị này.'),
          Text(
            widget.session.user?.identifier ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('settings-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại liên hệ',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ||
                    RegExp(r'^0[35789]\d{8}$')
                        .hasMatch(DemoSession.normalize(v!))
                ? null
                : 'Nhập số điện thoại hợp lệ',
          ),
          _note('Đổi mật khẩu'),
          TextFormField(
            key: const Key('settings-current'),
            controller: _current,
            obscureText: _hidden,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu hiện tại',
              border: OutlineInputBorder(),
            ),
            validator: (v) => _next.text.isNotEmpty && (v ?? '').isEmpty
                ? 'Nhập mật khẩu hiện tại'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('settings-next'),
            controller: _next,
            obscureText: _hidden,
            maxLength: 128,
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              border: const OutlineInputBorder(),
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
            validator: (v) =>
                (v ?? '').isEmpty ||
                    (v!.length >= 8 &&
                        RegExp(r'[A-Za-z]').hasMatch(v) &&
                        RegExp(r'\d').hasMatch(v))
                ? null
                : 'Tối thiểu 8 ký tự, có chữ và số',
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('settings-confirm'),
            controller: _confirm,
            obscureText: _hidden,
            decoration: const InputDecoration(
              labelText: 'Nhập lại mật khẩu mới',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '') == _next.text ? null : 'Mật khẩu chưa khớp',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('settings-save'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu cài đặt'),
          ),
        ],
      ),
    ),
  );
}

class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  bool _mine = false;
  bool _busy = false;
  late final _starts = {
    for (final c in demoCourses) c.id: c.start(widget.session.now),
  };
  Future<void> _enroll(DemoCourse course) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.session.user == null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AuthScreen(session: widget.session),
          ),
        );
      }
      if (!mounted || widget.session.user == null) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(course.title),
          content: Text(
            '${bookingDate(_starts[course.id]!)} · ${bookingTime(_starts[course.id]!)}\n90 phút · ${bookingMoney(DemoCourse.fee)}\nThanh toán tại sân · Đăng ký demo',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đăng ký'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      widget.session.enroll(course.id, _starts[course.id]!);
      await widget.session.flush();
      if (mounted) setState(() => _mine = true);
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(DemoEnrollment enrollment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy buổi học?'),
        content: const Text('Chỗ của bạn sẽ được mở lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lịch'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy buổi học'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) widget.session.cancelEnrollment(enrollment);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => Scaffold(
      appBar: _bar('NVH Academy'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Image.asset(
            'assets/figma/07380.png',
            height: 140,
            fit: BoxFit.contain,
          ),
          _note('Lớp học demo · Chưa phải lịch đào tạo hay đăng ký thực tế.'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Lớp học')),
              ButtonSegment(value: true, label: Text('Lịch của tôi')),
            ],
            selected: {_mine},
            onSelectionChanged: (v) => setState(() => _mine = v.first),
          ),
          const SizedBox(height: 16),
          if (!_mine)
            for (final course in demoCourses)
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      _note('${course.level}\n${course.description}'),
                      Text(
                        '${bookingDate(_starts[course.id]!)} · ${bookingTime(_starts[course.id]!)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${bookingMoney(DemoCourse.fee)} · Còn ${widget.session.courseSeats(course.id, _starts[course.id]!)} chỗ',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: Key('course-${course.id}'),
                        onPressed:
                            _busy ||
                                widget.session.courseSeats(
                                      course.id,
                                      _starts[course.id]!,
                                    ) ==
                                    0 ||
                                widget.session.enrollments.any(
                                  (e) =>
                                      e.courseId == course.id &&
                                      e.start == _starts[course.id] &&
                                      !e.cancelled,
                                )
                            ? null
                            : () => _enroll(course),
                        icon: const Icon(Icons.school_outlined),
                        label: Text(
                          widget.session.enrollments.any(
                                (e) =>
                                    e.courseId == course.id &&
                                    e.start == _starts[course.id] &&
                                    !e.cancelled,
                              )
                              ? 'Đã đăng ký'
                              : 'Đăng ký buổi học',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (_mine && widget.session.enrollments.isEmpty)
            _empty('Chưa có lịch học.', Icons.school_outlined),
          if (_mine)
            for (final enrollment in widget.session.enrollments)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      demoCourses
                          .firstWhere((c) => c.id == enrollment.courseId)
                          .title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    _note(
                      '${enrollment.id} · ${bookingDate(enrollment.start)} · ${bookingTime(enrollment.start)}\n${enrollment.cancelled ? 'Đã hủy' : '${scheduleState(enrollment.start, enrollment.start.add(const Duration(minutes: 90)), widget.session.now)} · Chưa thanh toán'}',
                    ),
                    if (!enrollment.cancelled &&
                        enrollment.start.isAfter(widget.session.now))
                      OutlinedButton(
                        key: Key('course-cancel-${enrollment.id}'),
                        onPressed: () => _cancel(enrollment),
                        child: const Text('Hủy buổi học'),
                      ),
                    const Divider(),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, required this.session});
  final DemoSession session;
  Future<void> _compose(BuildContext context) async {
    if (session.user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AuthScreen(session: session)),
      );
    }
    if (!context.mounted || session.user == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TicketForm(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Scaffold(
      appBar: _bar('Trung tâm trợ giúp'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Tài khoản dùng thử'),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  '0901234567 hoặc demo@nvh.vn\nMật khẩu ban đầu: Demo1234\nNếu đã đổi mật khẩu, dùng mật khẩu mới.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Đặt sân và thanh toán'),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Lịch đặt chỉ là dữ liệu demo. Thanh toán tại sân được ghi nhận là chưa thanh toán. Không có giao dịch ngân hàng.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Hủy lịch và ưu đãi'),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Có thể hủy trước giờ bắt đầu. Khung giờ và voucher được mở lại; điểm demo của lịch đó được thu hồi.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Quên mật khẩu'),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Bản demo chưa có OTP hoặc email khôi phục. Khi còn đăng nhập, vào Cài đặt tài khoản và dùng mật khẩu hiện tại để đổi mật khẩu.',
                ),
              ),
            ],
          ),
          _note(
            'Yêu cầu demo chỉ lưu trên thiết bị, chưa gửi tới nhân viên hỗ trợ.',
          ),
          FilledButton.icon(
            key: const Key('support-create'),
            onPressed: () => _compose(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Tạo yêu cầu demo'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Yêu cầu của tôi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          if (session.tickets.isEmpty)
            _empty('Chưa có yêu cầu.', Icons.support_agent),
          for (final ticket in session.tickets)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(ticket.subject),
              subtitle: Text(
                '${ticket.id} · ${bookingDate(ticket.created)} · ${ticket.closed ? 'Đã đóng' : 'Lưu cục bộ'}',
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(ticket.message),
                ),
                if (!ticket.closed)
                  TextButton.icon(
                    key: Key('ticket-close-${ticket.id}'),
                    onPressed: () => session.closeTicket(ticket),
                    icon: const Icon(Icons.check),
                    label: const Text('Đóng yêu cầu'),
                  ),
                const SizedBox(height: 16),
              ],
            ),
        ],
      ),
    ),
  );
}

class _TicketForm extends StatefulWidget {
  const _TicketForm({required this.session});
  final DemoSession session;
  @override
  State<_TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends State<_TicketForm> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      widget.session.createTicket(_subject.text, _message.text);
      await widget.session.flush();
      if (mounted) Navigator.pop(context);
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _bar('Yêu cầu demo'),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            key: const Key('support-subject'),
            controller: _subject,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Tiêu đề',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập tiêu đề' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('support-message'),
            controller: _message,
            maxLength: 1000,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Nội dung',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v ?? '').trim().length < 10 ? 'Nhập ít nhất 10 ký tự' : null,
          ),
          _note('Chỉ lưu cục bộ trên thiết bị. Không gửi thông tin nhạy cảm.'),
          FilledButton.icon(
            key: const Key('support-save'),
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu yêu cầu'),
          ),
        ],
      ),
    ),
  );
}
