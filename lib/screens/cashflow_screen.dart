import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_cashflow.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';
import 'workflow_screen.dart';

class CashflowScreen extends StatefulWidget {
  const CashflowScreen({super.key, required this.session, this.initialRange});
  final DemoSession session;
  final DateTimeRange? initialRange;
  @override
  State<CashflowScreen> createState() => _CashflowScreenState();
}

class _CashflowScreenState extends State<CashflowScreen> {
  int _days = 7;
  late DateTimeRange? _range = widget.initialRange;
  String _facility = '*';
  bool? _onsite;
  Future<void> _dates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: bookingDay(widget.session.now),
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    if (picked.duration.inDays > 365) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chọn tối đa 366 ngày.')));
      return;
    }
    setState(() => _range = picked);
  }

  Future<void> _copy(DemoCashflowReport report) async {
    try {
      await Clipboard.setData(ClipboardData(text: report.csv()));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã sao chép CSV demo.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể sao chép. Thử lại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (!s.initialized || s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Doanh thu'),
          body: const Center(child: Text('Chưa có quyền truy cập.')),
        );
      }
      final facilities = {
        '*': 'Toàn hệ thống',
        '': 'Sân chính',
        'EVENTS': 'Vé giao lưu / giải đấu',
        for (final f in s.managedFacilities.where((f) => f.published != null))
          f.id: f.published!.name,
      };
      final selected = facilities.containsKey(_facility) ? _facility : '*';
      final to = _range?.end ?? bookingDay(s.now),
          from = _range?.start ?? to.subtract(Duration(days: _days - 1));
      final report = s.cashflowReport(
        from: from,
        to: to,
        facilityId: selected,
        onsite: _onsite,
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Doanh thu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              key: const Key('cashflow-export'),
              tooltip: 'Sao chép CSV demo',
              onPressed: report.entries.isEmpty ? null : () => _copy(report),
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            DropdownButtonFormField<String>(
              key: ValueKey('cashflow-facility-$selected'),
              initialValue: selected,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Cơ sở'),
              items: [
                for (final e in facilities.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _facility = v!),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in [1, 7, 30])
                  ChoiceChip(
                    key: Key('cashflow-days-$d'),
                    label: Text(d == 1 ? 'Hôm nay' : '$d ngày'),
                    selected: _range == null && _days == d,
                    onSelected: (_) => setState(() {
                      _days = d;
                      _range = null;
                    }),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text('${bookingDate(from)} – ${bookingDate(to)}'),
                ),
                IconButton(
                  key: const Key('cashflow-dates'),
                  tooltip: 'Chọn khoảng ngày',
                  onPressed: _dates,
                  icon: const Icon(Icons.date_range),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in <bool?, String>{
                  null: 'Tất cả kênh',
                  false: 'Chuyển khoản',
                  true: 'Tại sân',
                }.entries)
                  ChoiceChip(
                    key: Key('cashflow-channel-${e.key}'),
                    label: Text(e.value),
                    selected: _onsite == e.key,
                    onSelected: (_) => setState(() => _onsite = e.key),
                  ),
              ],
            ),
            const Divider(height: 28),
            _amount('Đã ghi nhận thu', report.received, 'cashflow-received'),
            _amount('Đã ghi nhận hoàn', report.refunded, 'cashflow-refunded'),
            _amount(
              'Thu trừ hoàn trong kỳ',
              report.balance,
              'cashflow-balance',
            ),
            _amount('Trong đó thu tại sân', report.onsite, 'cashflow-onsite'),
            _amount(
              'Chờ hoàn hiện tại',
              report.pendingRefund,
              'cashflow-pending',
            ),
            if (report.undatedPayments > 0)
              Text(
                '${report.undatedPayments} thanh toán cũ chưa có ngày ghi nhận.',
                key: const Key('cashflow-undated'),
              ),
            const Text(
              'Dữ liệu ghi nhận trong demo, không phải số dư ngân hàng.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const Divider(height: 28),
            const Text(
              'Theo ngày ghi nhận',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            CashflowChart(
              received: report.daily(),
              refunded: report.daily(refund: true),
            ),
            const Wrap(
              spacing: 20,
              children: [
                Text('Thu', style: TextStyle(color: AppColors.darkGreen)),
                Text('Hoàn', style: TextStyle(color: Colors.red)),
              ],
            ),
            const Divider(height: 28),
            const Text(
              'Thu theo cơ sở',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            for (final e in report.byFacility.entries)
              _amount(
                facilities[e.key] ?? e.key,
                e.value,
                'cashflow-venue-${e.key}',
              ),
            const Divider(height: 28),
            if (report.entries.isEmpty)
              const Text(
                'Không có giao dịch trong khoảng ngày này.',
                key: Key('cashflow-empty'),
              ),
            for (final e in report.entries)
              ListTile(
                key: Key('cashflow-entry-${e.id}-${e.refund}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  e.refund ? Icons.north_east : Icons.south_west,
                  color: e.refund ? Colors.red : AppColors.green,
                ),
                title: Text(
                  '${e.refund ? 'Hoàn' : 'Thu'} ${bookingMoney(e.amount)}',
                ),
                subtitle: Text('${e.id} · ${bookingDate(e.date)}\n${e.title}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkflowDetailScreen(session: s, id: e.id),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget _amount(String label, int value, String key) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label),
      Text(
        bookingMoney(value),
        key: Key(key),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: value < 0 ? Colors.red : AppColors.darkGreen,
        ),
      ),
    ],
  ),
);

class CashflowChart extends StatelessWidget {
  const CashflowChart({
    super.key,
    required this.received,
    required this.refunded,
  });
  final Map<DateTime, int> received, refunded;
  @override
  Widget build(BuildContext context) {
    final values = [...received.values, ...refunded.values];
    final max = values.fold<int>(0, (a, b) => a > b ? a : b);
    Widget bar(int value, Color color) => Container(
      width: 16,
      height: max == 0 ? 0 : 140 * value / max,
      color: color,
    );
    return SizedBox(
      height: 210,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final e in received.entries)
              Semantics(
                label:
                    '${bookingDate(e.key)}: thu ${bookingMoney(e.value)}, hoàn ${bookingMoney(refunded[e.key] ?? 0)}',
                child: Tooltip(
                  message:
                      '${bookingDate(e.key)}\nThu ${bookingMoney(e.value)}\nHoàn ${bookingMoney(refunded[e.key] ?? 0)}',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 140,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                bar(e.value, AppColors.green),
                                const SizedBox(width: 4),
                                bar(refunded[e.key] ?? 0, Colors.red.shade400),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 46,
                            child: Center(
                              child: Text(
                                '${e.key.day}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
