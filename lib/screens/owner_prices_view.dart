import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_facility_tariffs.dart';
import '../demo/demo_operations.dart';
import '../widgets/design.dart';
import 'owner_booking_views.dart';
import 'owner_management_widgets.dart';
import 'finance_screen.dart';

class OwnerPricesView extends StatefulWidget {
  const OwnerPricesView({
    super.key,
    required this.session,
    this.facilityId = '',
  });
  final DemoSession session;
  final String facilityId;
  @override
  State<OwnerPricesView> createState() => _OwnerPricesViewState();
}

class _OwnerPricesViewState extends State<OwnerPricesView> {
  late String _venue = widget.facilityId;
  String? _loaded;
  List<FacilityTariffBand> _bands = [];
  Set<FacilityTariffBand> _editingBands = {};
  Set<int> _courts = {1};
  int _from = 6, _to = 11;
  late DateTime _effective = bookingDay(widget.session.now);
  final _weekday = TextEditingController(), _weekend = TextEditingController();
  int? _revision;
  CourtSettings? _primarySnapshot, _draftSnapshot;
  bool _busy = false, _dirty = false, _formDirty = true;
  String? _error, _notice;
  @override
  void dispose() {
    _weekday.dispose();
    _weekend.dispose();
    super.dispose();
  }

  void _load(DemoSession s, int open, int close, int rate) {
    _loaded = _venue;
    _primarySnapshot = s.publishedCourts;
    _draftSnapshot = s.draftCourts;
    if (_venue.isEmpty) {
      _bands = [
        for (final t in (s.draftCourts ?? s.publishedCourts).tariffs)
          FacilityTariffBand(
            court: t.court,
            weekend: t.weekend,
            fromHour: t.fromHour,
            toHour: t.toHour,
            rate: t.rate,
            effectiveFrom: t.effectiveFrom,
            effectiveUntil: t.effectiveUntil,
            surcharge: t.surcharge,
          ),
      ];
    } else {
      final plan = s.facilityTariffPlan(_venue);
      _revision = plan.revision;
      _bands = List.of(plan.draft ?? plan.published);
    }
    _courts = {1};
    _editingBands.clear();
    _from = open;
    _to = (open + 5).clamp(open + 1, close);
    _weekday.text = bookingMoney(rate).replaceAll('đ', '');
    _weekend.text = bookingMoney(rate).replaceAll('đ', '');
    _effective = bookingDay(s.now);
    _dirty = false;
    _formDirty = true;
    _error = null;
  }

  bool _stale(DemoSession s) => _venue.isEmpty
      ? s.publishedCourts != _primarySnapshot || s.draftCourts != _draftSnapshot
      : s.facilityTariffPlan(_venue).revision != _revision;

  void _add() {
    try {
      final weekday = int.parse(_weekday.text.replaceAll('.', '').trim());
      final weekend = int.parse(_weekend.text.replaceAll('.', '').trim());
      if (_courts.isEmpty) throw const FormatException('Chọn sân áp dụng.');
      final next = [
        for (final c in _courts)
          for (final end in [false, true])
            FacilityTariffBand.fromJson(
              FacilityTariffBand(
                court: c,
                weekend: end,
                fromHour: _from,
                toHour: _to,
                rate: end ? weekend : weekday,
                effectiveFrom: _effective,
                effectiveUntil: _editingBands
                    .where((b) => b.weekend == end)
                    .firstOrNull
                    ?.effectiveUntil,
                surcharge:
                    _editingBands
                        .where((b) => b.weekend == end)
                        .firstOrNull
                        ?.surcharge ??
                    0,
              ).toJson(),
            ),
      ];
      final merged = [
        ..._bands.where((b) => !_editingBands.contains(b)),
        ...next,
      ];
      for (var i = 0; i < merged.length; i++) {
        for (var j = i + 1; j < merged.length; j++) {
          final a = merged[i], b = merged[j];
          if (a.court == b.court &&
              a.weekend == b.weekend &&
              a.fromHour < b.toHour &&
              b.fromHour < a.toHour &&
              (a.effectiveUntil == null ||
                  !a.effectiveUntil!.isBefore(b.effectiveFrom)) &&
              (b.effectiveUntil == null ||
                  !b.effectiveUntil!.isBefore(a.effectiveFrom))) {
            throw const FormatException(
              'Khung giá bị trùng. Xóa khung cũ trước khi thay thế.',
            );
          }
        }
      }
      setState(() {
        _bands = merged;
        _dirty = true;
        _formDirty = false;
        _editingBands.clear();
        _error = null;
        _notice = 'Đã thêm khung giá. Lưu để gửi duyệt.';
      });
    } on FormatException catch (e) {
      setState(
        () => _error =
            e.message == 'Invalid facility tariff' ||
                e.message.startsWith('Invalid radix')
            ? 'Giá từ 10.000 đến 1.000.000, bước 1.000; giờ bắt đầu phải trước giờ kết thúc.'
            : e.message,
      );
    }
  }

  Future<void> _save() async {
    final s = widget.session, actor = widget.session.user?.identifier;
    if (_busy || _stale(s)) return;
    // Include the visible form when the user has not added a band yet.
    if (_formDirty || !_dirty) {
      _add();
      if (_error != null) return;
    }
    final venue = _venue, bands = List<FacilityTariffBand>.of(_bands);
    if (!await financeConfirm(
          context,
          'Lưu bảng giá & gửi duyệt?',
          'Giá mới áp dụng sau khi được duyệt. Lịch đã xác nhận giữ nguyên giá.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (s.user?.identifier != actor ||
          s.role != DemoRole.owner ||
          venue != _venue ||
          _stale(s)) {
        throw StateError('Dữ liệu đã thay đổi. Mở lại bảng giá.');
      }
      if (venue.isEmpty) {
        s.submitCourtSettings(
          CourtSettings(
            rates: _primarySnapshot!.rates,
            enabled: _primarySnapshot!.enabled,
            tariffs: [
              for (final b in bands)
                CourtTariff(
                  court: b.court,
                  weekend: b.weekend,
                  fromHour: b.fromHour,
                  toHour: b.toHour,
                  rate: b.rate,
                  effectiveFrom: b.effectiveFrom,
                  effectiveUntil: b.effectiveUntil,
                  surcharge: b.surcharge,
                ),
            ],
          ),
        );
        _draftSnapshot = s.draftCourts;
      } else {
        s.submitFacilityTariffs(venue, bands, expectedRevision: _revision!);
        _revision = s.facilityTariffPlan(venue).revision;
      }
      if (!await s.flush()) {
        throw StateError('Chưa lưu được vào thiết bị. Hãy thử lưu lại.');
      }
      if (mounted) {
        setState(() {
          _error = null;
          _notice = 'Đã gửi bảng giá, chờ Admin duyệt.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : e is FormatException
              ? e.message
              : 'Không thể lưu bảng giá.',
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
      if (s.user == null || s.role != DemoRole.owner) {
        return const Scaffold(
          body: Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final names = ownerVenueNames(s);
      if (!names.containsKey(_venue)) {
        return const Scaffold(body: Center(child: Text('Cơ sở chưa công bố.')));
      }
      final facility = s.managedFacilities
          .where((f) => f.id == _venue)
          .firstOrNull;
      final p = facility?.published;
      final count = p?.courtCount ?? 3,
          open = p?.openHour ?? 6,
          close = p?.closeHour ?? 22;
      final sport = p?.sport ?? 'Cầu lông';
      final plan = _venue.isEmpty ? null : s.facilityTariffPlan(_venue);
      final pending = _venue.isEmpty
          ? s.courtReviewState == 'pending'
          : plan!.state == 'pending';
      if (_loaded != _venue) {
        _load(s, open, close, p?.baseRate ?? s.courtRate(1));
      }
      final editable =
          !pending && !_busy && !_stale(s) && facility?.suspended != true;
      final published = _venue.isEmpty
          ? [
              for (final b in s.publishedCourts.tariffs)
                FacilityTariffBand(
                  court: b.court,
                  weekend: b.weekend,
                  fromHour: b.fromHour,
                  toHour: b.toHour,
                  rate: b.rate,
                  effectiveFrom: b.effectiveFrom,
                  effectiveUntil: b.effectiveUntil,
                  surcharge: b.surcharge,
                ),
            ]
          : plan!.published;
      final primaryCourt = _courts.isEmpty ? 1 : _courts.first;
      final visible = published.where((b) => b.court == primaryCourt).toList();
      final ranges = <(int, int)>{
        for (final b in visible) (b.fromHour, b.toHour),
      }.toList()..sort((a, b) => a.$1.compareTo(b.$1));
      int base() => p?.baseRate ?? s.courtRate(primaryCourt);
      Widget title(String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      );
      Widget hour(
        String label,
        int value,
        String key,
        ValueChanged<int> change,
        int max,
      ) => DropdownButtonFormField<int>(
        key: ValueKey('$key-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var h = open; h <= max; h++)
            DropdownMenuItem(
              value: h,
              child: Text(
                '${h.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
        onChanged: editable
            ? (v) => setState(() {
                change(v!);
                _formDirty = true;
              })
            : null,
      );
      return OwnerOperationsScaffold(
        appBar: OwnerBar(
          title: 'Bảng giá',
          subtitle: 'Giá thuê theo sân & khung giờ',
          large: ownerLarge(context),
          icon: Icons.payments_outlined,
        ),
        bottomNavigationBar: const OwnerNavigation(),
        body: Builder(
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                FinanceSaveNotice(session: s),
                OwnerVenuePicker(
                  session: s,
                  value: _venue,
                  onChanged: (v) async {
                    if (_busy) return;
                    if (_dirty &&
                        !pending &&
                        !await financeConfirm(
                          context,
                          'Bỏ thay đổi chưa lưu?',
                          'Chuyển cơ sở sẽ bỏ các khung giá đang sửa.',
                        )) {
                      return;
                    }
                    if (mounted) {
                      setState(() {
                        _venue = v;
                        _loaded = null;
                        _notice = null;
                      });
                    }
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OwnerBadge(sport),
                ),
                const SizedBox(height: 12),
                const Text('Sân áp dụng', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                OutlinedButton(
                  key: const Key('owner-prices-courts'),
                  onPressed: _busy
                      ? null
                      : () async {
                          final chosen = Set<int>.of(_courts);
                          final result = await showDialog<Set<int>>(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, refresh) => AlertDialog(
                                title: const Text('Sân áp dụng'),
                                content: SizedBox(
                                  width: 280,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var c = 1; c <= count; c++)
                                          CheckboxListTile(
                                            title: Text('Sân $c'),
                                            value: chosen.contains(c),
                                            onChanged: (v) => refresh(() {
                                              if (v == true) {
                                                chosen.add(c);
                                              } else {
                                                chosen.remove(c);
                                              }
                                            }),
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
                                    onPressed: chosen.isEmpty
                                        ? null
                                        : () => Navigator.pop(context, chosen),
                                    child: const Text('Áp dụng'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (result != null && mounted) {
                            setState(() {
                              _courts = result;
                              _formDirty = true;
                            });
                          }
                        },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (_courts.toList()..sort())
                          .map((c) => 'Sân $c')
                          .join(', '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OwnerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title('Giá hiện tại · VND / giờ'),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          horizontalMargin: 8,
                          columnSpacing: 18,
                          headingRowHeight: 32,
                          dataRowMinHeight: 36,
                          dataRowMaxHeight: ownerLarge(context) ? 90 : 44,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Khung giờ',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'T2–T6',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'T7–CN',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                          rows: [
                            for (final r
                                in ranges.isEmpty ? [(open, close)] : ranges)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '${r.$1.toString().padLeft(2, '0')}:00 – ${r.$2.toString().padLeft(2, '0')}:00',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  for (final end in [false, true])
                                    DataCell(
                                      Text(
                                        bookingMoney(
                                          visible
                                                  .where(
                                                    (b) =>
                                                        b.weekend == end &&
                                                        b.fromHour == r.$1 &&
                                                        b.toHour == r.$2,
                                                  )
                                                  .firstOrNull
                                                  ?.quotedRate ??
                                              base(),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.darkGreen,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Giá đã chốt trên lịch đặt được giữ nguyên.',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                OwnerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title('Chỉnh sửa khung giá'),
                      if (pending)
                        const OwnerBadge('Chờ Admin duyệt', warning: true),
                      if (_stale(s))
                        const Text(
                          'Bảng giá đã thay đổi. Quay lại và mở lại để tiếp tục.',
                          style: TextStyle(color: Colors.red),
                        ),
                      for (var i = 0; i < _bands.length; i++)
                        ListTile(
                          key: Key('owner-prices-band-$i'),
                          onTap: editable
                              ? () {
                                  final b = _bands[i];
                                  setState(() {
                                    _editingBands = _bands
                                        .where(
                                          (other) =>
                                              other.court == b.court &&
                                              other.fromHour == b.fromHour &&
                                              other.toHour == b.toHour &&
                                              other.effectiveFrom ==
                                                  b.effectiveFrom &&
                                              other.effectiveUntil ==
                                                  b.effectiveUntil,
                                        )
                                        .toSet();
                                    _courts = {b.court};
                                    _from = b.fromHour;
                                    _to = b.toHour;
                                    _effective = b.effectiveFrom;
                                    _weekday.text =
                                        '${_editingBands.where((v) => !v.weekend).firstOrNull?.rate ?? b.rate}';
                                    _weekend.text =
                                        '${_editingBands.where((v) => v.weekend).firstOrNull?.rate ?? b.rate}';
                                    _dirty = true;
                                    _formDirty = true;
                                    _error = null;
                                  });
                                }
                              : null,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Sân ${_bands[i].court} · ${_bands[i].weekend ? 'Cuối tuần' : 'Ngày thường'} · ${_bands[i].fromHour}:00–${_bands[i].toHour}:00',
                            style: const TextStyle(fontSize: 11),
                          ),
                          subtitle: Text(
                            '${bookingMoney(_bands[i].quotedRate)} · ${bookingDate(_bands[i].effectiveFrom)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: IconButton(
                            key: Key('owner-prices-remove-$i'),
                            tooltip: 'Xóa khung giá',
                            onPressed: editable
                                ? () => setState(() {
                                    _bands.removeAt(i);
                                    _editingBands.clear();
                                    _dirty = true;
                                  })
                                : null,
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: ownerLarge(context)
                                ? double.infinity
                                : (MediaQuery.sizeOf(context).width - 66) / 2,
                            child: hour(
                              'Từ giờ *',
                              _from,
                              'owner-prices-from',
                              (v) => _from = v,
                              close - 1,
                            ),
                          ),
                          SizedBox(
                            width: ownerLarge(context)
                                ? double.infinity
                                : (MediaQuery.sizeOf(context).width - 66) / 2,
                            child: hour(
                              'Đến giờ *',
                              _to,
                              'owner-prices-to',
                              (v) => _to = v,
                              close,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 16,
                        children: [
                          for (final end in [false, true])
                            SizedBox(
                              width: ownerLarge(context)
                                  ? double.infinity
                                  : (MediaQuery.sizeOf(context).width - 66) / 2,
                              child: TextField(
                                key: Key(
                                  end
                                      ? 'owner-prices-weekend'
                                      : 'owner-prices-weekday',
                                ),
                                controller: end ? _weekend : _weekday,
                                onChanged: (_) {
                                  _formDirty = true;
                                  _dirty = true;
                                },
                                enabled: editable,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: end
                                      ? 'Cuối tuần *'
                                      : 'Ngày thường *',
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('owner-prices-date'),
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 16,
                        ),
                        onPressed: editable
                            ? () async {
                                final today = bookingDay(s.now);
                                final d = await showDatePicker(
                                  context: context,
                                  firstDate: today,
                                  lastDate: today.add(
                                    const Duration(days: 365),
                                  ),
                                  initialDate: _effective.isBefore(today)
                                      ? today
                                      : _effective,
                                );
                                if (d != null && mounted) {
                                  setState(() {
                                    _effective = d;
                                    _formDirty = true;
                                  });
                                }
                              }
                            : null,
                        label: Text(
                          'Áp dụng từ ${bookingDate(_effective)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('owner-prices-add'),
                        onPressed: editable ? _add : null,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          _editingBands.isEmpty
                              ? 'Thêm khung giá'
                              : 'Cập nhật khung giá',
                        ),
                      ),
                    ],
                  ),
                ),
                OwnerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title('Ưu đãi & phụ thu'),
                      const Text(
                        'Phụ thu theo từng khung giá đang áp dụng:',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      if (visible.every((b) => b.surcharge == 0))
                        const Text(
                          'Không có phụ thu.',
                          style: TextStyle(fontSize: 12),
                        ),
                      for (final b in visible.where((b) => b.surcharge > 0))
                        ownerLine(
                          '${b.fromHour}:00 – ${b.toHour}:00',
                          bookingMoney(b.surcharge),
                        ),
                      const Divider(),
                      Text(
                        _venue.isEmpty
                            ? s.primaryCancellationPolicy.summary
                            : p!.cancelPolicy,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _notice!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    key: const Key('owner-prices-error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                FilledButton(
                  key: const Key('owner-prices-save'),
                  onPressed: editable ? _save : null,
                  child: const Text('Lưu bảng giá'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
