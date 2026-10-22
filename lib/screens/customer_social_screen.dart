import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_events.dart';
import '../demo/demo_finance.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import 'auth_screen.dart';
import 'demo_account_screens.dart';
import 'finance_screen.dart';
import 'venue_map_screen.dart';

Future<void> showBookingMethod(
  BuildContext context,
  DemoSession session,
  String venueId,
  VoidCallback onCourtBooking,
) async {
  final venue = session.currentVenues.where((v) => v.id == venueId).firstOrNull;
  if (venue == null || !venue.bookingEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Địa điểm chưa nhận đặt sân trên SportMatch.'),
      ),
    );
    return;
  }
  final choice = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HÌNH THỨC ĐẶT SÂN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: AppColors.green),
              title: const Text('Đặt lịch theo sân'),
              subtitle: const Text('Chọn sân và khung giờ chơi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 1),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.confirmation_number_outlined,
                color: AppColors.green,
              ),
              title: const Text('Mua vé social'),
              subtitle: const Text('Tham gia buổi giao lưu tại sân'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, 2),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 1) onCourtBooking();
  if (choice == 2) {
    _push(context, SocialVenueEventsScreen(session: session, venueId: venueId));
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));
void _error(BuildContext context, Object error) => ScaffoldMessenger.of(context)
    .showSnackBar(
      SnackBar(
        content: Text(
          error is StateError ? error.message.toString() : '$error',
        ),
      ),
    );
Widget _section(String title, List<Widget> children) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      const SizedBox(height: 12),
      ...children,
    ],
  ),
);
Widget _row(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: AppColors.muted)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  ),
);
Widget _notice(String text, {bool warning = false}) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: warning ? const Color(0xFFFFF5DF) : const Color(0xFFE5F6ED),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    text,
    style: TextStyle(
      color: warning ? const Color(0xFF805016) : AppColors.darkGreen,
    ),
  ),
);
Widget _button(
  String text,
  VoidCallback? onPressed, {
  bool yellow = false,
  Key? key,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: FilledButton(
    key: key,
    style: FilledButton.styleFrom(
      backgroundColor: yellow ? const Color(0xFFFFCC00) : AppColors.green,
      foregroundColor: yellow ? Colors.black : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    onPressed: onPressed,
    child: Text(text, textAlign: TextAlign.center),
  ),
);
Widget _footer(List<Widget> children) => SafeArea(
  top: false,
  child: Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  ),
);
AppBar _header(String title, {List<Widget>? actions}) => AppBar(
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
  title: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  ),
  actions: actions,
);
const _background = Color(0xFFF3F5F7);
String _time(DemoEvent event, DateTime start) =>
    '${bookingTime(start)}–${bookingTime(event.end(start))}';
bool _player(DemoSession session) =>
    session.user != null && session.role == DemoRole.player;
String _status(DemoParticipation ticket, DemoPayment? payment, DateTime now) {
  if (ticket.cancelled) return 'Đã hủy';
  if (payment?.cancellation == DemoCancellationState.requested) {
    return 'Chờ phản hồi yêu cầu hủy';
  }
  if (ticket.attendance == DemoAttendance.checkedIn ||
      ticket.attendance == DemoAttendance.completed) {
    return 'Đã tham gia';
  }
  if (!ticket.event.end(ticket.start).isAfter(now)) {
    return 'Hết hạn · Chưa sử dụng';
  }
  return switch (payment?.state) {
    DemoPaymentState.approved => 'Đã xác nhận thanh toán',
    DemoPaymentState.pending => 'Chờ xác nhận thanh toán',
    DemoPaymentState.rejected => 'Chứng từ cần bổ sung',
    _ => 'Chờ gửi chứng từ',
  };
}

class SocialVenueEventsScreen extends StatefulWidget {
  const SocialVenueEventsScreen({
    super.key,
    required this.session,
    this.venueId = demoVenueId,
  });
  final DemoSession session;
  final String venueId;
  @override
  State<SocialVenueEventsScreen> createState() => _SocialVenueEventsState();
}

class _SocialVenueEventsState extends State<SocialVenueEventsScreen> {
  late DateTime _day;
  @override
  void initState() {
    super.initState();
    final events =
        widget.session.availableEvents
            .where((e) => e.kind == DemoEventKind.social)
            .toList()
          ..sort(
            (a, b) => a
                .start(widget.session.now)
                .compareTo(b.start(widget.session.now)),
          );
    _day = bookingDay(
      events.isEmpty
          ? widget.session.now
          : events.first.start(widget.session.now),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      final venue = session.currentVenues
          .where((v) => v.id == widget.venueId)
          .firstOrNull;
      final events = widget.venueId == demoVenueId && venue != null
          ? session.availableEvents
                .where(
                  (e) =>
                      e.kind == DemoEventKind.social &&
                      bookingDay(e.start(session.now)) == _day,
                )
                .toList()
          : <DemoEvent>[];
      return Scaffold(
        backgroundColor: _background,
        appBar: _header(
          'Vé social',
          actions: [
            IconButton(
              tooltip: 'Vé social đã mua',
              onPressed: () =>
                  _push(context, SocialTicketsScreen(session: session)),
              icon: const Icon(Icons.confirmation_number_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tháng ${_day.month}, ${_day.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Tuần trước',
                  onPressed: () => setState(
                    () => _day = _day.subtract(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Tuần sau',
                  onPressed: () =>
                      setState(() => _day = _day.add(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Builder(
                      builder: (context) {
                        final date = _day
                            .subtract(Duration(days: _day.weekday - 1))
                            .add(Duration(days: i));
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 48,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: date == _day
                                    ? AppColors.green
                                    : Colors.white,
                                foregroundColor: date == _day
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              onPressed: () => setState(() => _day = date),
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
                                    ][i],
                                  ),
                                  Text(
                                    '${date.day}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(venue?.name ?? 'Sân không còn khả dụng', [
              Text(venue?.address ?? 'Cơ sở chưa được công bố.'),
            ]),
            const Text(
              'Sự kiện tại sân',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              _notice('Chưa có sự kiện social tại sân trong ngày đã chọn.'),
            for (final event in events)
              Builder(
                builder: (context) {
                  final start = event.start(session.now);
                  final seats = session.eventSeats(event.id, start);
                  final ended = !event.end(start).isAfter(session.now);
                  final cancelled =
                      session.eventCancellation(event.id, start) != null;
                  return _section(event.title, [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/figma/badminton-event-demo.png',
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      cancelled
                          ? 'Đã hủy sự kiện'
                          : ended
                          ? 'Đã kết thúc'
                          : start.isAfter(session.now)
                          ? 'Sắp diễn ra'
                          : 'Đang diễn ra',
                      style: const TextStyle(color: AppColors.green),
                    ),
                    _row('Thời gian', _time(event, start)),
                    _row('Còn vé', '$seats vé'),
                    _row('Giá vé', bookingMoney(event.fee)),
                    TextButton(
                      onPressed: () => _push(
                        context,
                        SocialEventDetailScreen(
                          session: session,
                          event: event,
                          start: start,
                        ),
                      ),
                      child: const Text('Xem chi tiết sự kiện'),
                    ),
                    _button(
                      'Mua vé',
                      seats > 0 && !ended && !cancelled
                          ? () => _selectTickets(context, session, event, start)
                          : null,
                    ),
                  ]);
                },
              ),
          ],
        ),
      );
    },
  );
}

Future<void> _selectTickets(
  BuildContext context,
  DemoSession session,
  DemoEvent event,
  DateTime start,
) async {
  if (session.user == null) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => AuthScreen(session: session)),
    );
  }
  if (!context.mounted) return;
  if (!_player(session)) {
    _error(context, StateError('Vui lòng đăng nhập tài khoản người chơi.'));
    return;
  }
  final owner = session.user!.identifier;
  var quantity = 1;
  final selected = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final seats = session.eventSeats(event.id, start);
        final max = seats < 2 ? seats : 2;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(_time(event, start)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('social-minus'),
                      tooltip: 'Giảm số vé',
                      onPressed: quantity > 1
                          ? () => update(() => quantity--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text('$quantity vé', textAlign: TextAlign.center),
                    ),
                    IconButton(
                      key: const Key('social-plus'),
                      tooltip: 'Tăng số vé',
                      onPressed: quantity < max
                          ? () => update(() => quantity++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (quantity == 2)
                  _notice('Giảm 10% khi mua 2 vé trong cùng đơn.'),
                _row(
                  'Tổng tiền',
                  bookingMoney(
                    event.fee * quantity * (quantity == 2 ? 90 : 100) ~/ 100,
                  ),
                ),
                _button(
                  'Tiếp theo',
                  max > 0 ? () => Navigator.pop(context, quantity) : null,
                  yellow: true,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (!context.mounted || selected == null) return;
  if (session.user?.identifier != owner) {
    _error(context, StateError('Tài khoản đã thay đổi. Vui lòng chọn vé lại.'));
    return;
  }
  _push(
    context,
    SocialCheckoutConfirmScreen(
      session: session,
      event: event,
      start: start,
      quantity: selected,
    ),
  );
}

class SocialEventDetailScreen extends StatelessWidget {
  const SocialEventDetailScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final venue = demoVenues.first;
      final seats = session.eventSeats(event.id, start);
      final available =
          seats > 0 &&
          event.end(start).isAfter(session.now) &&
          session.eventCancellation(event.id, start) == null;
      return Scaffold(
        backgroundColor: _background,
        appBar: _header('Chi tiết sự kiện'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(event.title, [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/figma/badminton-event-demo.png',
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              _row('Ngày', bookingDate(start)),
              _row('Thời gian', _time(event, start)),
              Text(venue.name),
              _row('Vé còn lại', '$seats vé'),
            ]),
            _section('Hình thức tham gia', [
              Text(event.description),
              const SizedBox(height: 12),
              const Text(
                '1. Đăng ký cá nhân: đi một mình hoặc cùng bạn bè.\n\n2. Ghép đôi tại sân: ban tổ chức hỗ trợ ghép cặp.\n\n3. Cùng chơi, cùng kết nối: ưu tiên giao lưu và luân phiên sân.',
              ),
            ]),
            _section('Ưu đãi dành cho bạn', [
              _notice(
                'Giảm 10% khi mua 2 vé trong cùng đơn. Không cộng dồn ưu đãi khác.',
              ),
            ]),
            _section('Địa điểm & đường đi', [
              Text(venue.name),
              Text(venue.address),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(venue.image, height: 150, fit: BoxFit.cover),
              ),
              TextButton.icon(
                onPressed: () =>
                    openVenueMap(context, venue.address, directions: true),
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('Xem đường đi đến sân'),
              ),
            ]),
            _section('Quy định ban tổ chức', [
              const Text(
                'Check-in trước 15 phút. Mang giày thể thao và dụng cụ cá nhân. Tuân thủ hướng dẫn ghép đôi, luân phiên sân và đảm bảo an toàn khi chơi.',
              ),
            ]),
            _section('Điều khoản sự kiện', [
              const Text(
                'Mỗi vé dành cho một người, chỉ dùng trong khung giờ sự kiện. Vé đã check-in không được hủy. Yêu cầu hủy trước ít nhất 24 giờ và chờ ban tổ chức xác nhận. Gửi yêu cầu không đồng nghĩa đã được hủy hoặc hoàn tiền.',
              ),
            ]),
            TextButton.icon(
              onPressed: () => _push(context, SupportScreen(session: session)),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Liên hệ hỗ trợ sự kiện'),
            ),
          ],
        ),
        bottomNavigationBar: _footer([
          _row('Giá mỗi vé', bookingMoney(event.fee)),
          _button(
            'Mua vé',
            available
                ? () => _selectTickets(context, session, event, start)
                : null,
          ),
        ]),
      );
    },
  );
}

class SocialCheckoutConfirmScreen extends StatefulWidget {
  const SocialCheckoutConfirmScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
    required this.quantity,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  final int quantity;
  @override
  State<SocialCheckoutConfirmScreen> createState() => _SocialConfirmState();
}

class _SocialConfirmState extends State<SocialCheckoutConfirmScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.session.user?.name ?? '',
  );
  final _phone = TextEditingController();
  final _note = TextEditingController();
  late final String? _owner = widget.session.user?.identifier;
  bool _terms = false;
  bool _busy = false;
  DemoParticipation? _created;
  int get _subtotal => widget.event.fee * widget.quantity;
  int get _discount => widget.quantity == 2 ? _subtotal ~/ 10 : 0;
  @override
  void initState() {
    super.initState();
    final id = _owner ?? '';
    if (RegExp(r'^0\d{9}$').hasMatch(id)) _phone.text = id;
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
    if (!_form.currentState!.validate()) return;
    if (!_terms) {
      _error(
        context,
        StateError('Vui lòng đồng ý điều khoản trước khi tiếp tục.'),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.session.user?.identifier != _owner ||
          !_player(widget.session)) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      final ticket = _created ??= widget.session.joinEvent(
        eventId: widget.event.id,
        start: widget.start,
        quantity: widget.quantity,
        contact: _name.text,
        contactPhone: _phone.text,
        socialCheckout: true,
        note: _note.text,
      );
      widget.session.startTicketTransfer(ticket);
      if (widget.session.saveFailed) await widget.session.retrySave();
      if (!await widget.session.flush()) {
        throw StateError(
          'Chưa lưu được đơn. Vui lòng thử lại, không tạo đơn mới.',
        );
      }
      if (mounted && widget.session.user?.identifier == _owner) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SocialCheckoutPaymentScreen(
              session: widget.session,
              ticket: ticket,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: _header('Thông tin đặt vé · 2/3'),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Vé social đã chọn', [
            Text(widget.event.title),
            Text(demoVenues.first.name),
            _row('Ngày đặt', bookingDate(widget.start)),
            _row('Khung giờ', _time(widget.event, widget.start)),
            _row(
              'Thời lượng',
              '${widget.event.durationMinutes ~/ 60} giờ ${widget.event.durationMinutes % 60} phút',
            ),
            _row('Số vé', '${widget.quantity}'),
            _row('Giá mỗi vé', bookingMoney(widget.event.fee)),
          ]),
          _notice('Vui lòng nhập thông tin liên hệ để tiếp tục thanh toán.'),
          _section('Thông tin người đặt vé', [
            TextFormField(
              key: const Key('social-name'),
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Họ và tên *'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nhập họ và tên.' : null,
            ),
            TextFormField(
              key: const Key('social-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 14,
              decoration: const InputDecoration(labelText: 'Số điện thoại *'),
              validator: (v) =>
                  RegExp(r'^0[35789]\d{8}$')
                      .hasMatch(DemoSession.normalize(v ?? ''))
                  ? null
                  : 'Nhập số điện thoại hợp lệ.',
            ),
            TextFormField(
              controller: _note,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú cho chủ sân',
              ),
            ),
          ]),
          _section('Lưu ý trước khi thanh toán', [
            const Text(
              'Đơn giữ chỗ tối đa 15 phút để gửi chứng từ. Hết hạn khi chưa gửi chứng từ, vé tự hủy và trả chỗ.\n\nChỉ yêu cầu hủy trước ít nhất 24 giờ. Ban tổ chức xét duyệt yêu cầu trước khi xử lý hoàn tiền.',
            ),
          ]),
          CheckboxListTile(
            key: const Key('social-terms'),
            value: _terms,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _busy
                ? null
                : (v) => setState(() => _terms = v ?? false),
            title: const Text(
              'Tôi đồng ý điều khoản sự kiện và chính sách hủy vé.',
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _footer([
      _row('Tổng tiền vé', bookingMoney(_subtotal)),
      if (_discount > 0) _row('Ưu đãi 10%', '-${bookingMoney(_discount)}'),
      _row('Tổng thanh toán', bookingMoney(_subtotal - _discount)),
      _button(
        _busy ? 'Đang lưu…' : 'Tiếp tục thanh toán',
        _busy ? null : _continue,
        yellow: true,
        key: const Key('social-continue'),
      ),
    ]),
  );
}

class SocialCheckoutPaymentScreen extends StatefulWidget {
  const SocialCheckoutPaymentScreen({
    super.key,
    required this.session,
    required this.ticket,
    this.pickImage,
  });
  final DemoSession session;
  final DemoParticipation ticket;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<SocialCheckoutPaymentScreen> createState() => _SocialPaymentState();
}

class _SocialPaymentState extends State<SocialCheckoutPaymentScreen> {
  Timer? _timer;
  bool _busy = false;
  bool _expiryShown = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.session.user?.identifier == widget.ticket.owner &&
          !widget.ticket.cancelled) {
        try {
          widget.session.startTicketTransfer(widget.ticket);
        } catch (e) {
          _error(context, e);
        }
      }
      _tick();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    widget.session.expireSocialTickets();
    setState(() {});
    final own = widget.session.user?.identifier == widget.ticket.owner;
    final payment = own
        ? widget.session.workflowPayment(widget.ticket.id)
        : null;
    if (!_expiryShown &&
        own &&
        widget.ticket.cancelled &&
        payment?.cancellationReason.startsWith('Tự hủy') == true) {
      _expiryShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Đã hết thời gian thanh toán'),
          content: const Text(
            'Chưa gửi chứng từ trong thời hạn. Vé social đã tự hủy và chỗ đã được trả lại. Bạn có thể chọn mua vé mới nếu còn chỗ.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(this.context).popUntil((r) => r.isFirst);
              },
              child: const Text('Về trang chủ'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  this.context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SocialVenueEventsScreen(session: widget.session),
                  ),
                );
              },
              child: const Text('Chọn mua vé mới'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _upload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.pickImage ?? ProofPicker.pick)();
      if (bytes != null) {
        widget.session.saveTicketProof(widget.ticket, bytes);
        if (!await widget.session.flush()) {
          throw StateError('Chưa lưu được ảnh. Vui lòng thử lại.');
        }
      }
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final payment = widget.session.workflowPayment(widget.ticket.id);
      if (payment?.state != DemoPaymentState.pending) {
        widget.session.submitTicketProof(widget.ticket, widget.ticket.id);
      }
      if (widget.session.saveFailed) await widget.session.retrySave();
      if (!await widget.session.flush()) {
        throw StateError('Chưa lưu được chứng từ. Vui lòng thử lại.');
      }
      if (mounted && widget.session.user?.identifier == widget.ticket.owner) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SocialTicketsScreen(
              session: widget.session,
              submittedId: widget.ticket.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final ticket = widget.ticket;
      if (!_player(widget.session) ||
          widget.session.user?.identifier != ticket.owner) {
        return Scaffold(
          appBar: _header('Thanh toán'),
          body: const Center(
            child: Text('Vui lòng đăng nhập đúng tài khoản đã đặt vé.'),
          ),
        );
      }
      final p = widget.session.workflowPayment(ticket.id);
      final seconds = p == null
          ? 0
          : p.deadline.difference(widget.session.now).inSeconds.clamp(0, 900);
      final editable =
          !ticket.cancelled &&
          p != null &&
          !p.expired(widget.session.now) &&
          p.cancellation != DemoCancellationState.requested &&
          (p.state == DemoPaymentState.awaitingProof ||
              p.state == DemoPaymentState.rejected);
      return Scaffold(
        backgroundColor: _background,
        appBar: _header('Thanh toán · 3/3'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (editable)
              _section('Gửi chứng từ trong', [
                Text(
                  '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Hết hạn khi chưa gửi chứng từ: tự hủy vé và trả chỗ.',
                ),
              ]),
            _notice(_status(ticket, p, widget.session.now)),
            _section('Thông tin đơn đặt vé', [
              _row('Người mua', ticket.contact),
              _row('Mã đơn', ticket.id),
              Text(ticket.event.title),
              _row('Ngày', bookingDate(ticket.start)),
              _row('Giờ', _time(ticket.event, ticket.start)),
              _row('Số vé', '${ticket.quantity}'),
              _row('Cần thanh toán', bookingMoney(ticket.total)),
            ]),
            _bank(ticket),
            if (p?.reviewNote.isNotEmpty == true)
              _notice(p!.reviewNote, warning: true),
            _section('Tải lên giấy tờ xác nhận', [
              const Text('Ảnh thanh toán * · JPG, PNG · Tối đa 400 KB'),
              const SizedBox(height: 12),
              if ((p?.draft ?? '').isNotEmpty)
                Image.memory(
                  decodeProof(p!.draft),
                  height: 160,
                  fit: BoxFit.contain,
                ),
              if ((p?.proof ?? '').isNotEmpty)
                const Text('Đã gửi chứng từ cho chủ sân.'),
              OutlinedButton.icon(
                key: const Key('social-upload'),
                onPressed: editable && !_busy ? _upload : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  (p?.draft ?? '').isEmpty ? 'Chọn ảnh để tải lên' : 'Đổi ảnh',
                ),
              ),
            ]),
            FinanceSaveNotice(session: widget.session),
          ],
        ),
        bottomNavigationBar: _footer([
          _row('Số tiền cần thanh toán', bookingMoney(ticket.total)),
          _button(
            _busy ? 'Đang lưu…' : 'Hoàn thành',
            !_busy && (editable || p?.state == DemoPaymentState.pending)
                ? _complete
                : null,
            yellow: true,
            key: const Key('social-complete'),
          ),
        ]),
      );
    },
  );
}

Widget _bank(DemoParticipation ticket) => _section('Thông tin chuyển khoản', [
  const Text('Ngân hàng MÔ PHỎNG · Không chuyển tiền thật.'),
  _row('Chủ tài khoản', 'TÀI KHOẢN DEMO'),
  _copy('Số tài khoản', 'DEMO-KHÔNG-CHUYỂN-TIỀN'),
  _copy('Nội dung chuyển khoản', ticket.id),
  _notice(
    'Số tiền mô phỏng: ${bookingMoney(ticket.total)}. Dùng ảnh thử nghiệm để kiểm tra luồng xác nhận.',
    warning: true,
  ),
]);
Widget _copy(String label, String value) => Row(
  children: [
    Expanded(child: _row(label, value)),
    IconButton(
      tooltip: 'Sao chép $label',
      onPressed: () => Clipboard.setData(ClipboardData(text: value)),
      icon: const Icon(Icons.copy_outlined, size: 18),
    ),
  ],
);

class SocialTicketsScreen extends StatefulWidget {
  const SocialTicketsScreen({
    super.key,
    required this.session,
    this.submittedId,
  });
  final DemoSession session;
  final String? submittedId;
  @override
  State<SocialTicketsScreen> createState() => _SocialTicketsState();
}

class _SocialTicketsState extends State<SocialTicketsScreen> {
  String _filter = 'Tất cả';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.session.expireSocialTickets();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      final tickets = session.participations
          .where((t) => t.event.kind == DemoEventKind.social)
          .where((t) {
            final state = _status(
              t,
              session.workflowPayment(t.id),
              session.now,
            );
            return _filter == 'Tất cả' ||
                (_filter == 'Đã hủy'
                    ? t.cancelled
                    : _filter == 'Đã tham gia'
                    ? state == 'Đã tham gia'
                    : state.startsWith('Hết hạn'));
          })
          .toList();
      return Scaffold(
        backgroundColor: _background,
        appBar: _header('Vé social đã mua'),
        body: !_player(session)
            ? Center(
                child: _button(
                  'Đăng nhập',
                  () => _push(context, AuthScreen(session: session)),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.submittedId != null &&
                      tickets.any((t) => t.id == widget.submittedId))
                    _notice(
                      'Đã gửi chứng từ ${widget.submittedId}. Vé đang chờ chủ sân xác nhận thanh toán.',
                    ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final label in [
                        'Tất cả',
                        'Đã tham gia',
                        'Hết hạn',
                        'Đã hủy',
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _filter == label,
                          onSelected: (_) => setState(() => _filter = label),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tickets.isEmpty)
                    _notice('Chưa có vé social trong mục này.'),
                  for (final ticket in tickets)
                    _section(ticket.event.title, [
                      Text(
                        _status(
                          ticket,
                          session.workflowPayment(ticket.id),
                          session.now,
                        ),
                        style: const TextStyle(color: AppColors.green),
                      ),
                      const SizedBox(height: 8),
                      Text(demoVenues.first.name),
                      Text('Mã vé: ${ticket.id}'),
                      _row('Ngày', bookingDate(ticket.start)),
                      _row('Giờ', _time(ticket.event, ticket.start)),
                      _row('${ticket.quantity} vé', bookingMoney(ticket.total)),
                      TextButton(
                        onPressed: () => _push(
                          context,
                          SocialTicketDetailScreen(
                            session: session,
                            ticket: ticket,
                          ),
                        ),
                        child: const Text('Xem chi tiết'),
                      ),
                    ]),
                ],
              ),
      );
    },
  );
}

class SocialTicketDetailScreen extends StatefulWidget {
  const SocialTicketDetailScreen({
    super.key,
    required this.session,
    required this.ticket,
  });
  final DemoSession session;
  final DemoParticipation ticket;
  @override
  State<SocialTicketDetailScreen> createState() => _SocialTicketDetailState();
}

class _SocialTicketDetailState extends State<SocialTicketDetailScreen> {
  bool _busy = false;
  Future<void> _cancel() async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu hủy vé'),
        content: TextField(
          controller: reason,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Lý do hủy (ít nhất 5 ký tự)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().length >= 5) {
                Navigator.pop(context, reason.text);
              }
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
    // The dialog route may still be animating while its text field is disposed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    reason.dispose();
    if (value == null || !mounted) return;
    setState(() => _busy = true);
    try {
      widget.session.requestTicketCancellation(widget.ticket, value);
      if (!await widget.session.flush()) {
        throw StateError(
          'Chưa lưu được yêu cầu. Vui lòng kiểm tra trạng thái lưu.',
        );
      }
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      final ticket = widget.ticket;
      if (!_player(session) || !session.participations.contains(ticket)) {
        return Scaffold(
          appBar: _header('Chi tiết vé social'),
          body: const Center(
            child: Text('Không thể truy cập vé của tài khoản khác.'),
          ),
        );
      }
      final p = session.workflowPayment(ticket.id);
      final eligible =
          !ticket.cancelled &&
          ticket.attendance == DemoAttendance.pending &&
          ticket.start.difference(session.now) >= const Duration(hours: 24) &&
          p != null &&
          p.cancellation != DemoCancellationState.requested;
      final canPay =
          ticket.socialCheckout &&
          !ticket.cancelled &&
          p != null &&
          (!p.expired(session.now) || p.state == DemoPaymentState.rejected) &&
          (p.state == DemoPaymentState.awaitingProof ||
              p.state == DemoPaymentState.rejected);
      return Scaffold(
        backgroundColor: _background,
        appBar: _header('Chi tiết vé social'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _notice(_status(ticket, p, session.now)),
            _section(ticket.event.title, [
              Text(demoVenues.first.name),
              Text(demoVenues.first.address),
              _row('Mã vé', ticket.id),
              _row('Ngày', bookingDate(ticket.start)),
              _row('Giờ', _time(ticket.event, ticket.start)),
              _row('Người mua', ticket.contact),
              _row('Số vé', '${ticket.quantity}'),
              if (ticket.note.isNotEmpty) _row('Ghi chú', ticket.note),
            ]),
            if (!ticket.cancelled && p?.state == DemoPaymentState.approved)
              _section('Mã vé check-in', [
                Center(child: QrImageView(data: ticket.qrPayload, size: 200)),
                Text(ticket.id, textAlign: TextAlign.center),
              ]),
            _section('Thông tin thanh toán', [
              _row('Tiền vé', bookingMoney(ticket.quantity * ticket.event.fee)),
              if (ticket.discount > 0)
                _row('Ưu đãi', '-${bookingMoney(ticket.discount)}'),
              _row('Phí dịch vụ', '0 VND'),
              _row(
                p?.state == DemoPaymentState.approved
                    ? 'Đã thanh toán'
                    : 'Tổng tiền',
                bookingMoney(ticket.total),
              ),
              if (p?.reviewNote.isNotEmpty == true)
                _notice(p!.reviewNote, warning: true),
              if (canPay)
                _button(
                  'Tiếp tục thanh toán',
                  () => _push(
                    context,
                    SocialCheckoutPaymentScreen(
                      session: session,
                      ticket: ticket,
                    ),
                  ),
                ),
            ]),
            _section('Điều kiện hủy vé', [
              const Text(
                'Yêu cầu hủy trước ít nhất 24 giờ và chưa check-in. Ban tổ chức phải xác nhận; gửi yêu cầu không đồng nghĩa đã hủy hoặc đã hoàn tiền.',
              ),
              _row(
                'Hạn yêu cầu hủy',
                '${bookingTime(ticket.start.subtract(const Duration(hours: 24)))} · ${bookingDate(ticket.start.subtract(const Duration(hours: 24)))}',
              ),
              if (p?.cancellation == DemoCancellationState.requested)
                _notice(
                  'Đã gửi yêu cầu · Chờ ban tổ chức phản hồi. Vé chưa bị hủy.',
                ),
              if (p?.cancellationNote.isNotEmpty == true)
                _notice(p!.cancellationNote),
              _button(
                eligible
                    ? 'Yêu cầu hủy vé'
                    : 'Không thể yêu cầu hủy ở trạng thái này',
                eligible && !_busy ? _cancel : null,
              ),
            ]),
            FinanceSaveNotice(session: session),
            TextButton.icon(
              onPressed: () => _push(context, SupportScreen(session: session)),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Liên hệ hỗ trợ sự kiện'),
            ),
          ],
        ),
      );
    },
  );
}
