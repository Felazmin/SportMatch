import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import '../demo/demo_events.dart';
import '../demo/demo_payment_method.dart';
import '../widgets/design.dart';
import '../widgets/venue_favorite_button.dart';
import '../widgets/venue_image.dart';
import 'booking_screen.dart';
import 'customer_checkout_screen.dart';
import 'customer_venue_detail_screen.dart';
import 'finance_screen.dart';
import 'home_navigation.dart';
import 'venue_browse_screen.dart';

AppBar _bar(String title, {Widget? action}) => AppBar(
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
  title: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  actions: [?action],
);

class CustomerAccountNavigation extends StatelessWidget {
  const CustomerAccountNavigation({super.key, this.selectedIndex = 4});
  final int selectedIndex;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: Colors.white,
      child: Row(
        children: [
          for (final item in const [
            (Icons.home_outlined, 'Trang chủ'),
            (Icons.map_outlined, 'Bản đồ'),
            (Icons.explore_outlined, 'Khám phá'),
            (Icons.star_border, 'Nổi bật'),
            (Icons.person_outline, 'Tài khoản'),
          ].indexed)
            Expanded(
              child: InkWell(
                onTap: () => HomeNavigation.openTab(context, item.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$2.$1,
                        size: 21,
                        color: item.$1 == selectedIndex
                            ? AppColors.green
                            : AppColors.faint,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: item.$1 == selectedIndex
                              ? AppColors.green
                              : AppColors.muted,
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
  );
}

Widget _card(List<Widget> children) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.border),
  ),
  child: Material(
    type: MaterialType.transparency,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  ),
);
Widget _title(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(
    text,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  ),
);
Widget _tag(String text, {bool amber = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
  decoration: BoxDecoration(
    color: amber ? const Color(0xFFFFF3DC) : const Color(0xFFE4F6EC),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 10,
      color: amber ? const Color(0xFF955900) : AppColors.green,
    ),
  ),
);
Widget _empty(String text, IconData icon) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 40),
  child: Column(
    children: [
      Icon(icon, color: AppColors.faint, size: 40),
      const SizedBox(height: 12),
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
    ],
  ),
);

class CustomerFavoritesScreen extends StatelessWidget {
  const CustomerFavoritesScreen({super.key, required this.session});
  final DemoSession session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final venues = session.currentVenues
          .where((v) => session.isFavorite(v.id))
          .toList();
      return Scaffold(
        appBar: _bar('Sân yêu thích'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: session),
            _title('Sân đã thích (${venues.length})'),
            if (venues.isEmpty)
              _empty('Bạn chưa lưu sân yêu thích.', Icons.favorite_border),
            for (final v in venues)
              Container(
                key: Key('saved-venue-${v.id}'),
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 2.15,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => CustomerVenueDetailScreen(
                                  session: session,
                                  venueId: v.id,
                                ),
                              ),
                            ),
                            child: VenueImage(venue: v),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: _tag(v.ratingLabel),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: VenueFavoriteButton(
                              session: session,
                              venueId: v.id,
                            ),
                          ),
                        ),
                        Positioned(left: 10, bottom: 8, child: _tag(v.sport)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            v.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            v.addressLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (v.price ?? 0) > 0
                                        ? 'Giá chỉ từ'
                                        : v.priceReference != null
                                        ? 'Giá tham khảo'
                                        : 'Giá thuê',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  Text(
                                    v.priceLabel,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.green,
                                    ),
                                  ),
                                ],
                              ),
                              FilledButton(
                                onPressed: () =>
                                    openCustomerBooking(context, session, v.id),
                                child: Text(
                                  v.bookingEnabled
                                      ? 'Đặt sân ngay'
                                      : 'Xem chi tiết',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

class CustomerPaymentMethodsScreen extends StatefulWidget {
  const CustomerPaymentMethodsScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<CustomerPaymentMethodsScreen> createState() =>
      _CustomerPaymentMethodsScreenState();
}

class _CustomerPaymentMethodsScreenState
    extends State<CustomerPaymentMethodsScreen> {
  bool _busy = false;
  Future<void> _save(VoidCallback action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      action();
      final saved = await widget.session.flush();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? 'Đã lưu phương thức demo.'
                  : 'Chưa lưu được. Vui lòng thử lưu lại.',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add({bool wallet = false, String? fixedProvider}) async {
    final actor = widget.session.user?.identifier;
    final draft = await showDialog<(String, String)>(
      context: context,
      builder: (_) =>
          _PaymentMethodForm(wallet: wallet, fixedProvider: fixedProvider),
    );
    if (!mounted || draft == null || widget.session.user?.identifier != actor) {
      return;
    }
    await _save(() => widget.session.savePaymentMethod(draft.$1, draft.$2));
  }

  Future<void> _details(DemoPaymentMethod method) async {
    final actor = widget.session.user?.identifier;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${method.provider} •••• ${method.last4}'),
        content: const Text(
          'Phương thức mô phỏng, chưa liên kết ngân hàng hoặc ví điện tử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'remove'),
            child: const Text('Xóa phương thức'),
          ),
          if (!method.isDefault)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'default'),
              child: const Text('Đặt mặc định'),
            ),
        ],
      ),
    );
    if (!mounted ||
        result == null ||
        widget.session.user?.identifier != actor) {
      return;
    }
    await _save(
      () => widget.session.updatePaymentMethod(
        method.id,
        remove: result == 'remove',
      ),
    );
  }

  Widget _method(DemoPaymentMethod m) => ListTile(
    contentPadding: EdgeInsets.zero,
    key: Key('payment-method-${m.id}'),
    leading: Icon(
      m.isCard ? Icons.credit_card : Icons.account_balance_wallet_outlined,
      color: m.provider == 'Mastercard'
          ? Colors.red
          : m.provider == 'MoMo'
          ? const Color(0xFFA50064)
          : Colors.blue,
    ),
    title: Text(
      m.provider,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('•••• ${m.last4} · Demo', style: const TextStyle(fontSize: 12)),
        if (m.isDefault) _tag('Mặc định'),
      ],
    ),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: _busy ? null : () => _details(m),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final methods = s.savedPaymentMethods;
      return Scaffold(
        appBar: _bar(
          'Phương thức thanh toán',
          action: IconButton(
            tooltip: 'Thông tin thanh toán',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('Thanh toán demo'),
                content: Text(
                  'Chỉ lưu tên nhà cung cấp và 4 số cuối. Không nhập số thẻ đầy đủ, CVV, OTP hoặc mật khẩu ví. Chưa phát sinh giao dịch thật.',
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: const CustomerAccountNavigation(),
        body: s.user == null || s.role != DemoRole.player
            ? _empty(
                'Vui lòng đăng nhập tài khoản khách hàng.',
                Icons.lock_outline,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FinanceSaveNotice(session: s),
                  _title('Thẻ liên kết (Visa / Mastercard)'),
                  if (methods.any((m) => m.isCard))
                    _card([
                      for (final m in methods.where((m) => m.isCard))
                        _method(m),
                    ])
                  else
                    _empty('Chưa có thẻ demo.', Icons.credit_card),
                  OutlinedButton.icon(
                    key: const Key('payment-add-card'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _busy || methods.length >= 5
                        ? null
                        : () => _add(),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm thẻ thanh toán mới'),
                  ),
                  const SizedBox(height: 20),
                  _title('Ví điện tử'),
                  _card([
                    for (final provider in ['MoMo', 'ZaloPay'])
                      if (methods.any((m) => m.provider == provider))
                        _method(
                          methods.firstWhere((m) => m.provider == provider),
                        )
                      else
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            provider,
                            style: const TextStyle(fontSize: 14),
                          ),
                          leading: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: provider == 'MoMo'
                                ? const Color(0xFFA50064)
                                : Colors.blue,
                          ),
                          subtitle: const Text(
                            'Chưa thêm ví demo',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: _busy || methods.length >= 5
                              ? null
                              : () =>
                                    _add(wallet: true, fixedProvider: provider),
                        ),
                  ]),
                  OutlinedButton.icon(
                    key: const Key('payment-add-wallet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _busy || methods.length >= 5
                        ? null
                        : () => _add(wallet: true),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm ví điện tử demo'),
                  ),
                  const SizedBox(height: 20),
                  _card([
                    const Icon(Icons.shield_outlined, color: AppColors.green),
                    const SizedBox(height: 8),
                    const Text(
                      'Chế độ demo · Chưa liên kết ngân hàng',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chỉ lưu nhà cung cấp và 4 số cuối trên thiết bị. Không nhập thông tin thanh toán nhạy cảm.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ]),
                ],
              ),
      );
    },
  );
}

class _PaymentMethodForm extends StatefulWidget {
  const _PaymentMethodForm({required this.wallet, this.fixedProvider});
  final bool wallet;
  final String? fixedProvider;
  @override
  State<_PaymentMethodForm> createState() => _PaymentMethodFormState();
}

class _PaymentMethodFormState extends State<_PaymentMethodForm> {
  final _form = GlobalKey<FormState>();
  final _last4 = TextEditingController();
  late String _provider =
      widget.fixedProvider ?? (widget.wallet ? 'MoMo' : 'Visa');
  @override
  void dispose() {
    _last4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.wallet ? 'Thêm ví demo' : 'Thêm thẻ demo'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _provider,
              isExpanded: true,
              items: [
                for (final p
                    in widget.wallet
                        ? ['MoMo', 'ZaloPay']
                        : ['Visa', 'Mastercard'])
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: widget.fixedProvider != null
                  ? null
                  : (v) => setState(() => _provider = v!),
              decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('payment-last4'),
              controller: _last4,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(labelText: '4 số cuối (demo)'),
              validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '')
                  ? null
                  : 'Nhập đúng 4 chữ số.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        key: const Key('payment-save-method'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (_provider, _last4.text));
          }
        },
        child: const Text('Lưu demo'),
      ),
    ],
  );
}

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  DateTime? _day;
  String? _sport;
  bool _all = false, _busy = false;
  void _details(DemoBooking b) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => widget.session.paymentFor(b)?.checkout == true
          ? CustomerCheckoutDetailScreen(session: widget.session, booking: b)
          : BookingDetailScreen(session: widget.session, booking: b),
    ),
  );
  Future<void> _cancel(DemoBooking b) async {
    final s = widget.session;
    if (s.paymentFor(b) != null) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PaymentScreen(session: s, booking: b),
        ),
      );
      return;
    }
    final actor = s.user?.identifier;
    final revision = b.revision;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch đặt sân?'),
        content: Text(
          '${b.venueName}\n${bookingDate(b.start)} · ${bookingTime(b.start)}',
        ),
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
    if (!mounted ||
        confirmed != true ||
        actor != s.user?.identifier ||
        revision != b.revision) {
      return;
    }
    setState(() => _busy = true);
    final cancelled = s.cancel(b);
    final saved = await s.flush();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !cancelled
              ? 'Không thể hủy lịch này.'
              : saved
              ? 'Đã hủy lịch đặt sân.'
              : 'Chưa lưu được. Vui lòng thử lưu lại.',
        ),
      ),
    );
  }

  Future<void> _change(DemoBooking b) async {
    final actor = widget.session.user?.identifier;
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _ChangeRequestForm(booking: b),
    );
    if (!mounted ||
        message == null ||
        actor != widget.session.user?.identifier ||
        !widget.session.bookings.contains(b) ||
        b.cancelled ||
        !b.start.isAfter(widget.session.now)) {
      return;
    }
    setState(() => _busy = true);
    try {
      widget.session.createTicket('Đổi lịch ${b.id}', message);
      final saved = await widget.session.flush();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? 'Đã lưu yêu cầu hỗ trợ demo. Lịch cũ vẫn giữ nguyên.'
                  : 'Chưa lưu được. Vui lòng thử lưu lại.',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDay() async {
    final today = bookingDay(widget.session.now);
    final day = await showDatePicker(
      context: context,
      initialDate: _day ?? today,
      firstDate: today.subtract(const Duration(days: 3650)),
      lastDate: today.add(const Duration(days: 3650)),
    );
    if (mounted && day != null) {
      setState(() {
        _day = day;
        _all = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final today = bookingDay(s.now);
      final days = [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];
      final records =
          s.bookings
              .where(
                (b) =>
                    (_all || (!b.cancelled && b.end.isAfter(s.now))) &&
                    (_day == null || bookingDay(b.start) == _day) &&
                    (_sport == null || b.sport == _sport),
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      return Scaffold(
        appBar: _bar(
          'Lịch đặt sân',
          action: IconButton(
            tooltip: 'Chọn ngày',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ),
        body: s.user == null || s.role != DemoRole.player
            ? _empty(
                'Vui lòng đăng nhập tài khoản khách hàng.',
                Icons.lock_outline,
              )
            : Column(
                children: [
                  Material(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          for (final d in days)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: TextButton(
                                key: Key('customer-booking-day-${d.day}'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _day == d
                                      ? Colors.white
                                      : AppColors.ink,
                                  backgroundColor: _day == d
                                      ? AppColors.green
                                      : Colors.white,
                                  minimumSize: const Size(44, 52),
                                ),
                                onPressed: () =>
                                    setState(() => _day = _day == d ? null : d),
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
                                      ][d.weekday - 1],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    Text(
                                      '${d.day}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        FinanceSaveNotice(session: s),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              '${_all ? 'Lịch đặt' : 'Lịch sắp diễn ra'} (${records.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            PopupMenuButton<String>(
                              key: const Key('customer-booking-sport'),
                              tooltip: 'Lọc môn thể thao',
                              onSelected: (v) =>
                                  setState(() => _sport = v.isEmpty ? null : v),
                              itemBuilder: (_) => [
                                for (final v in {
                                  '',
                                  ...s.bookings.map((b) => b.sport),
                                })
                                  PopupMenuItem(
                                    value: v,
                                    child: Text(v.isEmpty ? 'Tất cả môn' : v),
                                  ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  _sport ?? 'Lọc môn thể thao',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Tất cả lịch'),
                              selected: _all,
                              onSelected: (v) => setState(() => _all = v),
                            ),
                            if (_day != null)
                              InputChip(
                                label: Text(bookingDate(_day!)),
                                onDeleted: () => setState(() => _day = null),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (records.isEmpty)
                          _empty(
                            'Không có lịch đặt phù hợp.',
                            Icons.event_available_outlined,
                          ),
                        for (final b in records)
                          _card([
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4F6EC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.sports_tennis,
                                    color: AppColors.green,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.venueName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${bookingTime(b.start)} – ${bookingTime(b.end)} · ${bookingDate(b.start)} · Sân ${b.court}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        bookingMoney(b.total),
                                        style: const TextStyle(
                                          color: AppColors.green,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _tag(
                                b.cancelled
                                    ? 'Đã hủy'
                                    : b.start.isBefore(s.now)
                                    ? scheduleState(b.start, b.end, s.now)
                                    : s.paymentFor(b)?.state ==
                                          DemoPaymentState.approved
                                    ? 'Đã xác nhận'
                                    : 'Chờ xác nhận',
                                amber:
                                    !b.cancelled &&
                                    b.start.isAfter(s.now) &&
                                    s.paymentFor(b)?.state !=
                                        DemoPaymentState.approved,
                              ),
                            ),
                            const Divider(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                if (!b.cancelled && b.start.isAfter(s.now)) ...[
                                  TextButton(
                                    key: Key('customer-booking-change-${b.id}'),
                                    onPressed: _busy ? null : () => _change(b),
                                    child: const Text('Đổi lịch'),
                                  ),
                                  TextButton(
                                    key: Key('customer-booking-cancel-${b.id}'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      backgroundColor: const Color(0xFFFFEFEF),
                                    ),
                                    onPressed: _busy ? null : () => _cancel(b),
                                    child: const Text('Hủy sân'),
                                  ),
                                ],
                                TextButton(
                                  key: Key('customer-booking-detail-${b.id}'),
                                  onPressed: () => _details(b),
                                  child: const Text('Chi tiết ›'),
                                ),
                              ],
                            ),
                          ]),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.icon(
                        key: const Key('customer-booking-new'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => VenueBrowseScreen(session: s),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Đặt sân mới'),
                      ),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class _ChangeRequestForm extends StatefulWidget {
  const _ChangeRequestForm({required this.booking});
  final DemoBooking booking;
  @override
  State<_ChangeRequestForm> createState() => _ChangeRequestFormState();
}

class _ChangeRequestFormState extends State<_ChangeRequestForm> {
  final _message = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Yêu cầu đổi lịch'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.booking.venueName}\n${bookingDate(widget.booking.start)} · ${bookingTime(widget.booking.start)}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Lịch hiện tại vẫn giữ nguyên. Yêu cầu được lưu vào mục hỗ trợ demo, chưa gửi ra ngoài ứng dụng.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('customer-booking-change-message'),
              controller: _message,
              maxLength: 1000,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Lịch mong muốn và lý do',
              ),
              validator: (v) => (v?.trim().length ?? 0) >= 10
                  ? null
                  : 'Nhập tối thiểu 10 ký tự.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        key: const Key('customer-booking-send-change'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _message.text.trim());
          }
        },
        child: const Text('Lưu yêu cầu'),
      ),
    ],
  );
}
