import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_facility_tariffs.dart';
import '../demo/demo_facilities.dart';
import 'finance_screen.dart';
import 'owner_prices_view.dart';

class FacilityTariffsScreen extends StatefulWidget {
  const FacilityTariffsScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  State<FacilityTariffsScreen> createState() => _FacilityTariffsScreenState();
}

class _FacilityTariffsScreenState extends State<FacilityTariffsScreen> {
  int? _revision;
  List<FacilityTariffBand> _bands = [];
  String _error = '';
  bool _busy = false;
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _act(FacilityTariffPlan plan, {bool? approve}) async {
    if (_busy) return;
    final s = widget.session, actor = s.user?.identifier;
    final bands = List<FacilityTariffBand>.of(_bands),
        revision = approve == null ? _revision! : plan.revision;
    if (!await financeConfirm(
          context,
          approve == null
              ? 'Gửi bảng giá?'
              : approve
              ? 'Duyệt bảng giá?'
              : 'Từ chối bảng giá?',
          'Giá đã chốt trên lịch đặt cũ không thay đổi.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (actor != s.user?.identifier) {
        throw StateError('Tài khoản đã thay đổi.');
      }
      if (approve == null) {
        s.submitFacilityTariffs(widget.id, bands, expectedRevision: revision);
      } else {
        s.reviewFacilityTariffs(
          widget.id,
          expectedRevision: revision,
          approve: approve,
          note: _note.text,
        );
      }
      _revision = s.facilityTariffPlan(widget.id).revision;
      await s.flush();
      if (mounted) setState(() => _error = '');
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _band(FacilityTariffBand b, {int? index}) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      'Sân ${b.court} · ${b.weekend ? 'Cuối tuần' : 'Ngày thường'} · ${b.fromHour}:00–${b.toHour}:00',
    ),
    subtitle: Text(
      '${bookingMoney(b.quotedRate)}/giờ · ${bookingDate(b.effectiveFrom)}${b.effectiveUntil == null ? '' : ' → ${bookingDate(b.effectiveUntil!)}'}\nPhụ thu: ${bookingMoney(b.surcharge)}',
    ),
    trailing: index == null
        ? null
        : IconButton(
            key: Key('facility-tariff-remove-$index'),
            tooltip: 'Xóa khung giá',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy
                ? null
                : () => setState(() => _bands.removeAt(index)),
          ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user != null && s.role == DemoRole.owner) {
        return OwnerPricesView(session: s, facilityId: widget.id);
      }
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Bảng giá cơ sở'),
          body: const Center(child: Text('Cần tài khoản quản lý.')),
        );
      }
      final f = s.managedFacilities.where((f) => f.id == widget.id).firstOrNull;
      if (f?.published == null) {
        return Scaffold(
          appBar: financeBar('Bảng giá cơ sở'),
          body: const Center(child: Text('Cơ sở chưa công bố.')),
        );
      }
      final plan = s.facilityTariffPlan(widget.id);
      if (_revision == null) {
        _revision = plan.revision;
        _bands = List.of(plan.draft ?? plan.published);
      }
      final editable =
          s.role == DemoRole.owner && plan.state != 'pending' && !f!.suspended;
      return Scaffold(
        appBar: financeBar('Bảng giá cơ sở'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              f!.published!.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text('Giá cơ bản: ${bookingMoney(f.published!.baseRate)}/giờ'),
            Text(switch (plan.state) {
              'pending' => 'Chờ duyệt',
              'approved' => 'Đã duyệt',
              'rejected' => 'Bị từ chối',
              _ => 'Chưa đề xuất',
            }, key: const Key('facility-tariff-state')),
            if (plan.note.isNotEmpty) Text('Lý do: ${plan.note}'),
            const Divider(),
            const Text(
              'Bảng giá đang áp dụng',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (plan.published.isEmpty) const Text('Áp dụng giá cơ bản.'),
            for (final b in plan.published) _band(b),
            const Divider(),
            Text(
              editable ? 'Đề xuất bảng giá' : 'Bảng giá đề xuất',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (editable) ...[
              for (var i = 0; i < _bands.length; i++)
                _band(_bands[i], index: i),
              OutlinedButton.icon(
                key: const Key('facility-tariff-add'),
                icon: const Icon(Icons.add),
                label: const Text('Thêm khung giá'),
                onPressed: _busy
                    ? null
                    : () async {
                        final actor = s.user?.identifier;
                        final band = await Navigator.push<FacilityTariffBand>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FacilityTariffBandScreen(
                              profile: f.published!,
                              now: s.now,
                            ),
                          ),
                        );
                        if (mounted &&
                            actor == s.user?.identifier &&
                            band != null) {
                          setState(() => _bands.add(band));
                        }
                      },
              ),
              FilledButton.icon(
                key: const Key('facility-tariff-submit'),
                onPressed: _busy ? null : () => _act(plan),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Gửi duyệt'),
              ),
            ] else ...[
              for (final b in plan.draft ?? <FacilityTariffBand>[]) _band(b),
            ],
            if (s.role == DemoRole.admin && plan.state == 'pending') ...[
              TextField(
                key: const Key('facility-tariff-note'),
                controller: _note,
                maxLength: 300,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Lý do từ chối'),
              ),
              FilledButton.icon(
                key: const Key('facility-tariff-approve'),
                onPressed: _busy ? null : () => _act(plan, approve: true),
                icon: const Icon(Icons.check),
                label: const Text('Duyệt bảng giá'),
              ),
              OutlinedButton.icon(
                key: const Key('facility-tariff-reject'),
                onPressed: _busy ? null : () => _act(plan, approve: false),
                icon: const Icon(Icons.close),
                label: const Text('Từ chối'),
              ),
            ],
            if (_error.isNotEmpty)
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}

class FacilityTariffBandScreen extends StatefulWidget {
  const FacilityTariffBandScreen({
    super.key,
    required this.profile,
    required this.now,
  });
  final FacilityProfile profile;
  final DateTime now;
  @override
  State<FacilityTariffBandScreen> createState() =>
      _FacilityTariffBandScreenState();
}

class _FacilityTariffBandScreenState extends State<FacilityTariffBandScreen> {
  int _court = 1;
  late int _from = widget.profile.openHour, _to = widget.profile.closeHour;
  bool _weekend = false;
  late DateTime _date = bookingDay(widget.now);
  DateTime? _until;
  late final _rate = TextEditingController(
    text: widget.profile.baseRate.toString(),
  );
  final _surcharge = TextEditingController(text: '0');
  String _error = '';
  @override
  void dispose() {
    _rate.dispose();
    _surcharge.dispose();
    super.dispose();
  }

  Future<void> _pick(bool until) async {
    final d = await showDatePicker(
      context: context,
      initialDate: until ? (_until ?? _date) : _date,
      firstDate: until ? _date : bookingDay(widget.now),
      lastDate: bookingDay(widget.now).add(const Duration(days: 365)),
    );
    if (d != null && mounted) {
      setState(() {
        if (until) {
          _until = d;
        } else {
          _date = d;
          if (_until != null && _until!.isBefore(d)) _until = null;
        }
      });
    }
  }

  Widget _dropdown(
    String key,
    String label,
    int value,
    int from,
    int to,
    void Function(int) change,
  ) => DropdownButtonFormField<int>(
    key: Key(key),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (var i = from; i <= to; i++)
        DropdownMenuItem(value: i, child: Text('$i')),
    ],
    onChanged: (v) => setState(() => change(v!)),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: financeBar('Khung giá'),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dropdown(
          'facility-band-court',
          'Sân',
          _court,
          1,
          widget.profile.courtCount,
          (v) => _court = v,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cuối tuần'),
          value: _weekend,
          onChanged: (v) => setState(() => _weekend = v),
        ),
        _dropdown(
          'facility-band-from',
          'Từ giờ',
          _from,
          widget.profile.openHour,
          widget.profile.closeHour - 1,
          (v) => _from = v,
        ),
        _dropdown(
          'facility-band-to',
          'Đến giờ',
          _to,
          widget.profile.openHour + 1,
          widget.profile.closeHour,
          (v) => _to = v,
        ),
        TextField(
          key: const Key('facility-band-rate'),
          controller: _rate,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Giá mỗi giờ (VND)'),
        ),
        TextField(
          key: const Key('facility-band-surcharge'),
          controller: _surcharge,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Phụ thu mỗi giờ (VND)'),
        ),
        OutlinedButton.icon(
          key: const Key('facility-band-date'),
          onPressed: () => _pick(false),
          icon: const Icon(Icons.calendar_month),
          label: Text('Hiệu lực: ${bookingDate(_date)}'),
        ),
        OutlinedButton.icon(
          key: const Key('facility-band-until'),
          onPressed: () => _pick(true),
          icon: const Icon(Icons.event),
          label: Text(
            _until == null ? 'Chọn ngày hết hạn' : bookingDate(_until!),
          ),
        ),
        if (_until != null)
          IconButton(
            tooltip: 'Bỏ ngày hết hạn',
            onPressed: () => setState(() => _until = null),
            icon: const Icon(Icons.clear),
          ),
        if (_error.isNotEmpty)
          Text(
            _error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton.icon(
          key: const Key('facility-band-save'),
          icon: const Icon(Icons.check),
          label: const Text('Thêm khung giá'),
          onPressed: () {
            try {
              final b = FacilityTariffBand.fromJson(
                FacilityTariffBand(
                  court: _court,
                  weekend: _weekend,
                  fromHour: _from,
                  toHour: _to,
                  rate: int.tryParse(_rate.text) ?? 0,
                  surcharge: int.tryParse(_surcharge.text) ?? -1,
                  effectiveFrom: _date,
                  effectiveUntil: _until,
                ).toJson(),
              );
              Navigator.pop(context, b);
            } on FormatException {
              setState(
                () => _error = 'Kiểm tra khung giờ và giá 10.000–1.000.000; phụ thu tối đa 100.000, bội số 1.000.',
              );
            }
          },
        ),
      ],
    ),
  );
}
