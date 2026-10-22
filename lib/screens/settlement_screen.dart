import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_settlement.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';
import 'workflow_screen.dart';
import 'cashflow_screen.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  DateTimeRange? _range;
  bool? _onsite, _tickets;
  int _fee = 300;
  Future<void> _dates() async {
    final d = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (d != null && mounted) setState(() => _range = d);
  }

  Future<void> _copy(DemoSettlementReport report) async {
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
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Đối soát'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final report = s.settlementReport(
        from: _range?.start,
        to: _range?.end,
        onsite: _onsite,
        tickets: _tickets,
        basisPoints: _fee,
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Đối soát',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              key: const Key('settlement-cashflow'),
              tooltip: 'Doanh thu theo ngày ghi nhận',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CashflowScreen(session: s)),
              ),
              icon: const Icon(Icons.bar_chart_outlined),
            ),
            IconButton(
              key: const Key('settlement-export'),
              tooltip: 'Sao chép CSV demo',
              onPressed: report.rows.isEmpty ? null : () => _copy(report),
              icon: const Icon(Icons.file_copy_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            const Text(
              'Theo ngày sử dụng · Dữ liệu demo',
              style: TextStyle(color: AppColors.muted),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _range == null
                        ? 'Tất cả ngày'
                        : '${bookingDate(_range!.start)} – ${bookingDate(_range!.end)}',
                  ),
                ),
                IconButton(
                  key: const Key('settlement-date'),
                  tooltip: 'Chọn khoảng ngày',
                  onPressed: _dates,
                  icon: const Icon(Icons.date_range),
                ),
                if (_range != null)
                  IconButton(
                    key: const Key('settlement-clear'),
                    tooltip: 'Xóa bộ lọc ngày',
                    onPressed: () => setState(() => _range = null),
                    icon: const Icon(Icons.clear),
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
                    key: Key('settlement-channel-${e.key}'),
                    label: Text(e.value),
                    selected: _onsite == e.key,
                    onSelected: (_) => setState(() => _onsite = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in <bool?, String>{
                  null: 'Tất cả hồ sơ',
                  false: 'Lịch sân',
                  true: 'Vé',
                }.entries)
                  ChoiceChip(
                    key: Key('settlement-kind-${e.key}'),
                    label: Text(e.value),
                    selected: _tickets == e.key,
                    onSelected: (_) => setState(() => _tickets = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: const Key('settlement-fee'),
              initialValue: _fee,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Phí demo'),
              items: [
                for (final rate in [0, 300, 500])
                  DropdownMenuItem(value: rate, child: Text('${rate ~/ 100}%')),
              ],
              onChanged: (v) => setState(() => _fee = v!),
            ),
            const SizedBox(height: 20),
            _amount('Giá trước ưu đãi', report.gross),
            _amount('Ưu đãi đã trừ', report.discount),
            _amount('Thanh toán xác nhận', report.paid, key: 'settlement-paid'),
            _amount('Chờ hoàn', report.pendingRefund),
            _amount('Đã hoàn demo', report.recordedRefund),
            _amount('Còn lại sau khoản hoàn', report.retained),
            _amount('Phí mô phỏng', report.fees),
            _amount(
              'Thực nhận dự kiến',
              report.net,
              key: 'settlement-net',
              strong: true,
            ),
            _amount('Trong đó tại sân', report.onsite),
            _amount('Đang chờ xử lý hủy/khiếu nại', report.held),
            const SizedBox(height: 12),
            const Text(
              'Không phải số dư ngân hàng. Khoản chờ hoàn đã được dự phòng; thanh toán tại sân không tính phí mô phỏng.',
              style: TextStyle(color: AppColors.muted),
            ),
            const Divider(height: 32),
            if (report.rows.isEmpty)
              const Text(
                'Không có thanh toán đã xác nhận trong bộ lọc này.',
                key: Key('settlement-empty'),
              ),
            if (report.rows.isNotEmpty) ...[
              const Text(
                'Theo ngày',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              for (final day in report.dailyNet.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${bookingDate(day.key)} · ${bookingMoney(day.value)}',
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        minHeight: 6,
                        color: AppColors.green,
                        backgroundColor: AppColors.border,
                        value: report.net == 0 ? 0 : day.value / report.net,
                      ),
                    ],
                  ),
                ),
              const Divider(height: 32),
              Text(
                '${report.rows.length} thanh toán đã xác nhận',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final r in report.rows)
                ListTile(
                  key: Key('settlement-row-${r.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    r.onsite
                        ? Icons.payments_outlined
                        : Icons.account_balance_outlined,
                  ),
                  title: Text('${r.id} · ${bookingMoney(r.net(_fee))}'),
                  subtitle: Text(
                    '${bookingDate(r.date)} · ${r.onsite ? 'Tại sân' : 'Chuyển khoản'}${r.held ? '\nChờ xử lý hủy/khiếu nại' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettlementDetailScreen(
                        session: s,
                        id: r.id,
                        fee: _fee,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

Widget _amount(String label, int value, {String? key, bool strong = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          Text(
            bookingMoney(value),
            key: key == null ? null : Key(key),
            style: TextStyle(
              fontSize: strong ? 22 : 18,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: strong ? AppColors.darkGreen : AppColors.ink,
            ),
          ),
        ],
      ),
    );

class SettlementDetailScreen extends StatelessWidget {
  const SettlementDetailScreen({
    super.key,
    required this.session,
    required this.id,
    required this.fee,
  });
  final DemoSession session;
  final String id;
  final int fee;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      if (session.user == null || session.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Chi tiết đối soát'),
          body: const Center(child: Text('Không có quyền truy cập.')),
        );
      }
      final r = session
          .settlementReport(basisPoints: fee)
          .rows
          .where((r) => r.id == id)
          .firstOrNull;
      return Scaffold(
        appBar: financeBar(id),
        body: r == null
            ? const Center(child: Text('Không có thanh toán đã xác nhận.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FinanceSaveNotice(session: session),
                  Text(
                    r.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${bookingDate(r.date)} · ${r.onsite ? 'Tại sân' : 'Chuyển khoản'}',
                  ),
                  const Divider(height: 24),
                  _amount('Giá trước ưu đãi', r.gross),
                  _amount('Ưu đãi', r.discount),
                  _amount('Xác nhận thanh toán demo', r.paid),
                  _amount('Chờ hoàn', r.pendingRefund),
                  _amount('Đã hoàn demo', r.recordedRefund),
                  _amount('Còn lại trước khi hoàn chờ xử lý', r.cashBalance),
                  _amount(
                    'Phí mô phỏng ${r.onsite ? 0 : fee ~/ 100}%',
                    r.fee(fee),
                  ),
                  _amount('Thực nhận dự kiến', r.net(fee), strong: true),
                  if (r.held)
                    const Text('Đang chờ xử lý yêu cầu hủy hoặc khiếu nại.'),
                  const Text(
                    'Số liệu demo, không xác nhận chuyển tiền hoặc quyết toán ngân hàng.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    key: const Key('settlement-open-record'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('Hồ sơ thanh toán'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkflowDetailScreen(session: session, id: id),
                      ),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}
