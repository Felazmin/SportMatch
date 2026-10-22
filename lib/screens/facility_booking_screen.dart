import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_cancellation_policy.dart';
import 'customer_checkout_screen.dart';
import 'finance_screen.dart';

class FacilityBookingScreen extends StatefulWidget {
  const FacilityBookingScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  State<FacilityBookingScreen> createState() => _FacilityBookingScreenState();
}

class _FacilityBookingScreenState extends State<FacilityBookingScreen> {
  late DateTime _day = bookingDay(widget.session.now)
      .add(const Duration(days: 1));
  int _court = 1, _hour = 18, _hours = 1;
  late final _name = TextEditingController(
    text: widget.session.user?.name ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.session.user?.identifier ?? '',
  );
  String? _error;
  bool _busy = false;
  late final String? _actor;
  bool get _locked => _busy;
  @override
  void initState() {
    super.initState();
    _actor = widget.session.user?.identifier;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _reserve(List<int> rates, CancellationPolicy policy) async {
    if (_busy) return;
    if (_actor == null || widget.session.user?.identifier != _actor) {
      setState(
        () => _error = 'Tài khoản đã thay đổi. Vui lòng mở lại lịch đặt.',
      );
      return;
    }
    final start = _day.add(Duration(hours: _hour));
    setState(() => _busy = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerCheckoutConfirmScreen(
            session: widget.session,
            facilityId: widget.id,
            court: _court,
            start: start,
            hours: _hours,
            initialName: _name.text,
            initialPhone: _phone.text,
          ),
        ),
      );
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final f = s.publicFacilities.where((f) => f.id == widget.id).firstOrNull;
      if (f == null) {
        return Scaffold(
          appBar: financeBar('Đặt sân'),
          body: const Center(child: Text('Cơ sở không còn nhận lịch mới.')),
        );
      }
      final p = f.profile;
      final rates = s.bookingRates(
        _court <= p.courtCount ? _court : 1,
        _day.add(Duration(hours: _hour)),
        _hours,
        facilityId: widget.id,
      );
      return Scaffold(
        appBar: financeBar('Đặt sân'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text('${p.sport} · ${p.address}'),
            Text('${bookingMoney(p.baseRate)}/giờ'),
            const SizedBox(height: 16),
            DropdownButtonFormField<DateTime>(
              key: const Key('facility-book-day'),
              initialValue:
                  !_day.isBefore(bookingDay(s.now)) &&
                      !_day.isAfter(
                        bookingDay(s.now).add(const Duration(days: 6)),
                      )
                  ? _day
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ngày'),
              items: [
                for (var i = 0; i < 7; i++)
                  DropdownMenuItem(
                    value: bookingDay(s.now).add(Duration(days: i)),
                    child: Text(
                      bookingDate(bookingDay(s.now).add(Duration(days: i))),
                    ),
                  ),
              ],
              onChanged: _locked ? null : (v) => setState(() => _day = v!),
            ),
            DropdownButtonFormField<int>(
              key: const Key('facility-book-court'),
              initialValue: _court <= p.courtCount ? _court : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sân'),
              items: [
                for (var i = 1; i <= p.courtCount; i++)
                  DropdownMenuItem(value: i, child: Text('Sân $i')),
              ],
              onChanged: _locked ? null : (v) => setState(() => _court = v!),
            ),
            DropdownButtonFormField<int>(
              key: const Key('facility-book-hour'),
              initialValue: _hour >= p.openHour && _hour < p.closeHour
                  ? _hour
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Giờ bắt đầu'),
              items: [
                for (var i = p.openHour; i < p.closeHour; i++)
                  DropdownMenuItem(value: i, child: Text('$i:00')),
              ],
              onChanged: _locked ? null : (v) => setState(() => _hour = v!),
            ),
            DropdownButtonFormField<int>(
              initialValue: _hours,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Số giờ'),
              items: [
                for (var i = 1; i <= 3; i++)
                  DropdownMenuItem(value: i, child: Text('$i giờ')),
              ],
              onChanged: _locked ? null : (v) => setState(() => _hours = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('facility-book-name'),
              enabled: !_locked,
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên liên hệ'),
            ),
            TextField(
              key: const Key('facility-book-phone'),
              enabled: !_locked,
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
            ),
            const SizedBox(height: 16),
            Text(
              'Tổng: ${bookingMoney(rates.fold<int>(0, (sum, r) => sum + r))}',
            ),
            for (var i = 0; i < rates.length; i++)
              Text('${_hour + i}:00: ${bookingMoney(rates[i])}'),
            Text(
              p.cancellationPolicy.summary,
              key: const Key('facility-book-policy'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton.icon(
              key: const Key('facility-book-submit'),
              onPressed:
                  !_busy &&
                      s.user != null &&
                      s.role == DemoRole.player &&
                      s.available(
                        _court,
                        _day.add(Duration(hours: _hour)),
                        _hours,
                        facilityId: widget.id,
                      )
                  ? () => _reserve(rates, p.cancellationPolicy)
                  : null,
              icon: const Icon(Icons.event_available),
              label: const Text('Tiếp tục'),
            ),
            if (s.user == null || s.role != DemoRole.player)
              const Text('Cần đăng nhập tài khoản người chơi.'),
            const Divider(),
            const Text(
              'Khung giờ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = p.openHour; i < p.closeHour; i++)
                  ChoiceChip(
                    label: Text('$i:00'),
                    selected: _hour == i,
                    onSelected:
                        !_locked &&
                            s.available(
                              _court,
                              _day.add(Duration(hours: i)),
                              _hours,
                              facilityId: widget.id,
                            )
                        ? (_) => setState(() => _hour = i)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
