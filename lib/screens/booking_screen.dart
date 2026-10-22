import 'package:flutter/material.dart';

import 'customer_social_screen.dart';

import 'owner_booking_views.dart';
import 'customer_checkout_screen.dart';

import '../demo/demo_events.dart';
import 'home_navigation.dart';
import 'finance_screen.dart';
import 'workflow_screen.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import '../widgets/venue_favorite_button.dart';
import 'auth_screen.dart';
import 'demo_account_screens.dart';
import 'venue_map_screen.dart';
import 'reviews_screen.dart';

AppBar _bar(String title, {List<Widget>? actions}) => AppBar(
  actions: actions,
  title: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
);

Widget _heading(String text) => Padding(
  padding: const EdgeInsets.only(top: 24, bottom: 12),
  child: Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  ),
);

Widget _footer(Widget child) => Material(
  color: Colors.white,
  child: SafeArea(
    top: false,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

class VenueDetailScreen extends StatelessWidget {
  const VenueDetailScreen({super.key, required this.session});
  final DemoSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _bar(
      'Chi tiết sân',
      actions: [
        VenueFavoriteButton(
          session: session,
          venueId: demoVenueId,
          color: Colors.white,
        ),
      ],
    ),
    body: ListView(
      children: [
        Image.asset(
          'assets/figma/c0697.png',
          height: 240,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                DemoBooking.venue,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: session,
                builder: (context, _) => Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFFE6AB00), size: 18),
                    SizedBox(width: 6),
                    Text(session.venueRating.toStringAsFixed(1)),
                    SizedBox(width: 16),
                    Icon(Icons.sports_tennis, color: AppColors.green, size: 18),
                    SizedBox(width: 6),
                    Text('Cầu lông'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                DemoBooking.address,
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              TextButton.icon(
                onPressed: () => openVenueMap(
                  context,
                  DemoBooking.address,
                  directions: true,
                ),
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Chỉ đường'),
              ),
              _heading('Thông tin sân'),
              TextButton.icon(
                key: const Key('venue-reviews'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewsScreen(session: session),
                  ),
                ),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Xem đánh giá'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule, color: AppColors.green),
                title: Text('06:00 - 22:00'),
                subtitle: Text('Thứ hai đến Chủ nhật'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.sports_tennis, color: AppColors.green),
                title: Text('3 sân cầu lông'),
                subtitle: Text('Trong nhà'),
              ),
              _heading('Tiện ích'),
              const Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _Amenity(Icons.local_parking, 'Bãi đỗ xe'),
                  _Amenity(Icons.wc, 'Nhà vệ sinh'),
                  _Amenity(Icons.local_drink, 'Nước uống'),
                ],
              ),
              _heading('Đặt sân'),
              Text(
                'Từ ${bookingMoney(session.minimumCourtRate)} / giờ',
                style: const TextStyle(
                  color: AppColors.darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chưa thanh toán',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: _footer(
      FilledButton.icon(
        key: const Key('venue-book'),
        onPressed: () => showBookingMethod(
          context,
          session,
          demoVenueId,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingScheduleScreen(session: session),
            ),
          ),
        ),
        icon: const Icon(Icons.calendar_month),
        label: const Text('Chọn lịch đặt sân'),
      ),
    ),
  );
}

class _Amenity extends StatelessWidget {
  const _Amenity(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AppColors.green, size: 20),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}

class BookingScheduleScreen extends StatefulWidget {
  const BookingScheduleScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<BookingScheduleScreen> createState() => _BookingScheduleScreenState();
}

class _BookingScheduleScreenState extends State<BookingScheduleScreen> {
  late DateTime _date;
  int _court = 1;
  int _hours = 1;
  int? _hour;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    final now = widget.session.now;
    _date = DateTime(now.year, now.month, now.day);
  }

  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _hour ?? 6);
  void _change(VoidCallback action) => setState(() {
    action();
    _hour = null;
  });
  Future<void> _continue() async {
    if (_opening || _hour == null) return;
    setState(() => _opening = true);
    try {
      if (widget.session.user == null) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AuthScreen(session: widget.session),
          ),
        );
      }
      if (!mounted || widget.session.user == null) return;
      if (!widget.session.available(_court, _start, _hours)) {
        setState(() => _hour = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Khung giờ không còn khả dụng. Vui lòng chọn lại.'),
          ),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerCheckoutConfirmScreen(
            session: widget.session,
            court: _court,
            start: _start,
            hours: _hours,
          ),
        ),
      );
      if (mounted && !widget.session.available(_court, _start, _hours)) {
        setState(() => _hour = null);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final now = widget.session.now;
      final today = DateTime(now.year, now.month, now.day);
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final largeText = textScale > 1.5;
      final valid =
          _hour != null && widget.session.available(_court, _start, _hours);
      return Scaffold(
        appBar: _bar('Chọn lịch đặt sân'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text(
              DemoBooking.venue,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            _heading('Ngày đặt sân'),
            SizedBox(
              height: 78 * textScale,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = today.add(Duration(days: index));
                  final selected = day == _date;
                  return SizedBox(
                    width: 68 * textScale,
                    child: OutlinedButton(
                      key: Key('booking-day-$index'),
                      onPressed: () => _change(() => _date = day),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: selected
                            ? Colors.white
                            : AppColors.ink,
                        backgroundColor: selected
                            ? AppColors.green
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            index == 0
                                ? 'Hôm nay'
                                : [
                                    'T2',
                                    'T3',
                                    'T4',
                                    'T5',
                                    'T6',
                                    'T7',
                                    'CN',
                                  ][day.weekday - 1],
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${day.day}/${day.month}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _heading('Sân'),
            SegmentedButton<int>(
              showSelectedIcon: !largeText,
              segments: [
                for (final court in [1, 2, 3])
                  ButtonSegment(value: court, label: Text('Sân $court')),
              ],
              selected: {_court},
              onSelectionChanged: (values) =>
                  _change(() => _court = values.first),
            ),
            _heading('Thời lượng'),
            SegmentedButton<int>(
              showSelectedIcon: !largeText,
              segments: [
                for (final hours in [1, 2, 3])
                  ButtonSegment(value: hours, label: Text('$hours giờ')),
              ],
              selected: {_hours},
              onSelectionChanged: (values) =>
                  _change(() => _hours = values.first),
            ),
            _heading('Giờ bắt đầu'),
            const Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _Legend(Colors.white, 'Còn trống'),
                _Legend(AppColors.green, 'Đang chọn'),
                _Legend(AppColors.border, 'Không khả dụng'),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 16,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: largeText ? 3 : 4,
                mainAxisExtent: 46 * textScale,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final hour = index + 6;
                final available = widget.session.available(
                  _court,
                  DateTime(_date.year, _date.month, _date.day, hour),
                  _hours,
                );
                final selected = valid && _hour == hour;
                return OutlinedButton(
                  key: Key('booking-hour-$hour'),
                  onPressed: available
                      ? () => setState(() => _hour = hour)
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: selected
                        ? AppColors.green
                        : available
                        ? Colors.white
                        : AppColors.border,
                    foregroundColor: selected ? Colors.white : AppColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              },
            ),
            if (valid) ...[
              const SizedBox(height: 20),
              Text(
                '${bookingDate(_start)} · ${bookingTime(_start)} - ${bookingTime(_start.add(Duration(hours: _hours)))}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        bottomNavigationBar: _footer(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (largeText)
                _line(
                  'Tổng tiền',
                  bookingMoney(
                    widget.session.bookingSubtotal(_court, _start, _hours),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng tiền'),
                    Text(
                      bookingMoney(
                        widget.session.bookingSubtotal(_court, _start, _hours),
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('booking-continue'),
                onPressed: valid && !_opening ? _continue : null,
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: AppColors.faint),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
    ],
  );
}

class BookingConfirmScreen extends StatefulWidget {
  const BookingConfirmScreen({
    super.key,
    required this.session,
    required this.court,
    required this.start,
    required this.hours,
  });
  final DemoSession session;
  final int court;
  final DateTime start;
  final int hours;
  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  late final _quotedPolicy = widget.session.primaryCancellationPolicy;
  late final List<int> _quotedRates = widget.session.bookingRates(
    widget.court,
    widget.start,
    widget.hours,
  );
  int get _quotedRate => _quotedRates.first;
  int get _subtotal => _quotedRates.fold(0, (a, b) => a + b);
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _submitted = false;
  late final String? _actor;
  DemoBooking? _pendingBooking;
  String? _voucher;
  int get _discount {
    final vouchers = widget.session.vouchers.where((v) => v.code == _voucher);
    return vouchers.isEmpty ? 0 : vouchers.first.discount(_subtotal);
  }

  Future<void> _chooseVoucher() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VoucherWalletScreen(session: widget.session, subtotal: _subtotal),
      ),
    );
    if (mounted && value != null) {
      setState(() => _voucher = value.isEmpty ? null : value);
    }
  }

  String? _error;
  @override
  void initState() {
    super.initState();
    _actor = widget.session.user?.identifier;
    _name = TextEditingController(text: widget.session.user?.name ?? '');
    final identifier = widget.session.contactPhone;
    _phone = TextEditingController(
      text: identifier.contains('@') ? '' : identifier,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_submitted) return;
    if (_actor == null || widget.session.user?.identifier != _actor) {
      setState(
        () => _error = 'Tài khoản đã thay đổi. Vui lòng mở lại lịch đặt.',
      );
      return;
    }
    if (_pendingBooking == null && !_form.currentState!.validate()) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    try {
      final retry = _pendingBooking != null;
      final booking = _pendingBooking ??= widget.session.reserve(
        court: widget.court,
        start: widget.start,
        hours: widget.hours,
        contact: _name.text,
        contactPhone: _phone.text,
        voucherCode: _voucher,
        quotedRate: _quotedRate,
        quotedRates: _quotedRates,
        quotedCancellationPolicy: _quotedPolicy,
      );
      if (retry) await widget.session.retrySave();
      final saved = await widget.session.flush();
      if (!mounted) return;
      if (widget.session.user?.identifier != _actor) {
        throw StateError('Tài khoản đã thay đổi. Vui lòng mở lại lịch đặt.');
      }
      if (!saved) {
        throw StateError('Đơn đã tạo nhưng chưa lưu được. Hãy thử lưu lại.');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BookingSuccessScreen(session: widget.session, booking: booking),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _submitted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _bar('Xác nhận đặt sân'),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _heading('Thông tin đặt sân'),
          _BookingSummary(
            court: widget.court,
            start: widget.start,
            hours: widget.hours,
          ),
          _heading('Thông tin liên hệ'),
          TextFormField(
            key: const Key('booking-name'),
            enabled: !_submitted && _pendingBooking == null,
            controller: _name,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Họ và tên',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Nhập họ và tên' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('booking-phone'),
            enabled: !_submitted && _pendingBooking == null,
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                RegExp(r'^0[35789]\d{8}$')
                    .hasMatch(DemoSession.normalize(value ?? ''))
                ? null
                : 'Nhập số điện thoại hợp lệ',
          ),
          _heading('Thanh toán'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.payments_outlined, color: AppColors.green),
            title: Text('Thanh toán tại sân'),
            subtitle: Text('Chưa thanh toán'),
          ),
          const Divider(),
          ListTile(
            key: const Key('booking-voucher'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.local_offer_outlined,
              color: AppColors.green,
            ),
            title: Text(_voucher ?? 'Chọn ưu đãi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _submitted || _pendingBooking != null
                ? null
                : _chooseVoucher,
          ),
          for (var i = 0; i < _quotedRates.length; i++)
            _line(
              bookingTime(widget.start.add(Duration(hours: i))),
              '${bookingMoney(_quotedRates[i])} / giờ',
            ),
          _line('Thời lượng', '${widget.hours} giờ'),
          const Divider(),
          Text(_quotedPolicy.summary, key: const Key('booking-policy-summary')),
          if (_discount > 0) _line('Ưu đãi', '-${bookingMoney(_discount)}'),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                key: const Key('booking-error'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: _footer(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line('Tổng tiền', bookingMoney(_subtotal - _discount)),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('booking-confirm'),
            onPressed: _submitted ? null : _confirm,
            child: Text(
              _pendingBooking == null ? 'Xác nhận đặt sân' : 'Thử lưu lại',
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _line(String label, String value) => Builder(
  builder: (context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: MediaQuery.textScalerOf(context).scale(14) > 21
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
  ),
);

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    required this.court,
    required this.start,
    required this.hours,
    this.name = DemoBooking.venue,
    this.address = DemoBooking.address,
    this.sport = 'Cầu lông',
  });
  final int court;
  final DateTime start;
  final int hours;
  final String name, address, sport;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        address,
        style: const TextStyle(color: AppColors.muted, height: 1.4),
      ),
      const SizedBox(height: 16),
      _line('Sân', 'Sân $court · $sport'),
      _line('Ngày', bookingDate(start)),
      _line(
        'Khung giờ',
        '${bookingTime(start)} - ${bookingTime(start.add(Duration(hours: hours)))}',
      ),
    ],
  );
}

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.session,
    required this.booking,
  });
  final DemoSession session;
  final DemoBooking booking;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _bar('Đặt sân thành công'),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.check_circle, color: AppColors.green, size: 76),
        const SizedBox(height: 16),
        const Text(
          'Đặt sân thành công',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Mã đặt sân: ${booking.id}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 28),
        _BookingSummary(
          court: booking.court,
          start: booking.start,
          hours: booking.hours,
          name: booking.venueName,
          address: booking.venueAddress,
          sport: booking.sport,
        ),
        _line('Tổng tiền', bookingMoney(booking.total)),
        if (booking.discount > 0)
          _line(
            'Ưu đãi ${booking.voucherCode}',
            '-${bookingMoney(booking.discount)}',
          ),
        _line('Thanh toán', 'Chưa thanh toán'),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('booking-history'),
          onPressed: () {
            final navigator = Navigator.of(context);
            navigator.popUntil((route) => route.isFirst);
            navigator.push(
              MaterialPageRoute(
                builder: (_) => BookingsScreen(session: session),
              ),
            );
          },
          child: const Text('Xem lịch đặt sân'),
        ),
        TextButton(
          onPressed: () => HomeNavigation.returnHome(context),
          child: const Text('Về trang chủ'),
        ),
      ],
    ),
  );
}

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key, required this.session});
  final DemoSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final bookings = session.bookings;
      return Scaffold(
        appBar: _bar('Lịch đặt sân'),
        body: bookings.isEmpty
            ? const Center(
                child: Text(
                  'Bạn chưa có lịch đặt sân.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  final state = booking.cancelled
                      ? 'Đã hủy'
                      : scheduleState(booking.start, booking.end, session.now);
                  return Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingDetailScreen(
                            session: session,
                            booking: booking,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    booking.id,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  state,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: booking.cancelled
                                        ? AppColors.muted
                                        : AppColors.darkGreen,
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              booking.venueName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${bookingDate(booking.start)} · Sân ${booking.court}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${bookingTime(booking.start)} - ${bookingTime(booking.end)} · ${bookingMoney(booking.total)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      );
    },
  );
}

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({
    super.key,
    required this.session,
    required this.booking,
  });
  final DemoSession session;
  final DemoBooking booking;
  Future<void> _cancel(BuildContext context) async {
    if (session.paymentFor(booking) != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(session: session, booking: booking),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch đặt sân?'),
        content: const Text('Khung giờ này sẽ được mở lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lịch'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted && !session.cancel(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể hủy lịch đã bắt đầu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      if (session.user == null ||
          (session.role == DemoRole.player &&
              session.user!.identifier != booking.owner)) {
        return Scaffold(
          appBar: _bar('Chi tiết lịch đặt'),
          body: const Center(child: Text('Không có quyền xem lịch đặt này.')),
        );
      }
      if (session.role == DemoRole.owner) {
        return OwnerBookingView(session: session, id: booking.id);
      }
      if (session.role == DemoRole.player &&
          session.paymentFor(booking)?.checkout == true) {
        return CustomerCheckoutDetailScreen(session: session, booking: booking);
      }
      return Scaffold(
        appBar: _bar('Chi tiết lịch đặt'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heading(booking.id),
            _BookingSummary(
              court: booking.court,
              start: booking.start,
              hours: booking.hours,
              name: booking.venueName,
              address: booking.venueAddress,
              sport: booking.sport,
            ),
            _line(
              'Trạng thái',
              booking.cancelled
                  ? 'Đã hủy'
                  : scheduleState(booking.start, booking.end, session.now),
            ),
            _line('Liên hệ', booking.contact),
            _line('Số điện thoại', booking.phone),
            _line('Tổng tiền', bookingMoney(booking.total)),
            TextButton.icon(
              key: const Key('booking-workflow'),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Điểm danh & khoản hoàn'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      WorkflowDetailScreen(session: session, id: booking.id),
                ),
              ),
            ),
            if (booking.discount > 0)
              _line(
                'Ưu đãi ${booking.voucherCode}',
                '-${bookingMoney(booking.discount)}',
              ),
            if (!booking.cancelled)
              _line(
                'Thanh toán',
                session.paymentFor(booking)?.label(session.now) ??
                    'Chưa thanh toán',
              ),
            TextButton.icon(
              key: const Key('booking-payment'),
              icon: const Icon(Icons.payments_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PaymentScreen(session: session, booking: booking),
                ),
              ),
              label: const Text('Thanh toán / minh chứng'),
            ),
            TextButton.icon(
              key: const Key('booking-dispute'),
              icon: const Icon(Icons.report_problem_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DisputeFormScreen(session: session, booking: booking),
                ),
              ),
              label: const Text('Khiếu nại lịch đặt'),
            ),
            if (!booking.cancelled && booking.start.isAfter(session.now)) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                key: const Key('booking-cancel'),
                onPressed: () => _cancel(context),
                child: Text(
                  session.paymentFor(booking) == null
                      ? 'Hủy lịch đặt sân'
                      : 'Yêu cầu hủy lịch đặt sân',
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
