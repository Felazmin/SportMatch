import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/admin_report_data.dart';
import '../reports/admin_report_export.dart';
import '../widgets/design.dart';
import 'admin_dashboard_screen.dart' show AdminTransactionChart;
import 'approval_center_screen.dart';
import 'cashflow_screen.dart';
import 'finance_screen.dart';
import 'home_navigation.dart';

class AdminSystemReportScreen extends StatefulWidget {
  const AdminSystemReportScreen({
    super.key,
    required this.session,
    this.initialRange,
    this.onExport,
  });
  final DemoSession session;
  final DateTimeRange? initialRange;
  final Future<void> Function(AdminReportFile)? onExport;
  @override
  State<AdminSystemReportScreen> createState() =>
      _AdminSystemReportScreenState();
}

class _AdminSystemReportScreenState extends State<AdminSystemReportScreen> {
  int _period = 0;
  late DateTimeRange? _custom = widget.initialRange;
  String? _sport, _region;
  bool _busy = false;
  String? _error;

  DateTimeRange get _range {
    if (_custom != null) return _custom!;
    final today = bookingDay(widget.session.now);
    if (_period == 1) {
      return DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      );
    }
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return DateTimeRange(
      start: monday.subtract(const Duration(days: 7)),
      end: monday.subtract(const Duration(days: 1)),
    );
  }

  Future<void> _pickRange() async {
    final s = widget.session, actor = widget.session.user?.identifier;
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: bookingDay(s.now),
      initialDateRange: _range,
    );
    if (!mounted ||
        selected == null ||
        s.role != DemoRole.admin ||
        s.user?.identifier != actor) {
      return;
    }
    if (selected.duration.inDays > 365) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chọn tối đa 366 ngày.')));
      return;
    }
    setState(() {
      _custom = selected;
      _period = 2;
    });
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _export(AdminReportData report) async {
    if (_busy) return;
    final s = widget.session, actor = widget.session.user?.identifier;
    final pdf = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Xuất báo cáo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              key: const Key('system-report-export-pdf'),
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              key: const Key('system-report-export-csv'),
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('CSV'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        pdf == null ||
        s.role != DemoRole.admin ||
        s.user?.identifier != actor) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await createAdminReportFile(report, pdf: pdf);
      if (!mounted || s.role != DemoRole.admin || s.user?.identifier != actor) {
        return;
      }
      if (widget.onExport != null) {
        await widget.onExport!(file);
      } else {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            title: 'Báo cáo hệ thống',
            files: [
              XFile.fromData(
                file.bytes,
                mimeType: file.mimeType,
                name: file.name,
              ),
            ],
            fileNameOverrides: [file.name],
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      }
    } catch (_) {
      if (mounted && s.role == DemoRole.admin && s.user?.identifier == actor) {
        setState(() => _error = 'Không thể xuất báo cáo. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(String title, List<Widget> children, {Key? key}) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
  Widget _line(String text, {Key? key}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      key: key,
      style: const TextStyle(fontSize: 11, height: 1.5),
    ),
  );
  Widget _muted(String text) => Text(
    text,
    style: const TextStyle(fontSize: 10, height: 1.5, color: AppColors.muted),
  );
  Widget _notice(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE5F5EC),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        height: 1.5,
        color: AppColors.darkGreen,
      ),
    ),
  );

  Widget _metric(String label, int value, String note, String id) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _muted(label),
        const SizedBox(height: 6),
        Text(
          '$value',
          key: Key('system-report-$id'),
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 6),
        _muted(note),
      ],
    ),
  );

  Widget _distribution(
    String title,
    Map<String, int> values,
    AdminReportData report,
  ) {
    final total = values.values.fold<int>(0, (sum, n) => sum + n);
    final ordered = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _card(title, [
      if (total == 0) _muted('Chưa có lượt đặt sân trong phạm vi này.'),
      for (final e in ordered)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.value} · ${report.percent(e.value, total)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: e.value / total,
                minHeight: 5,
                color: AppColors.green,
                backgroundColor: AppColors.background,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      _muted(
        title == 'Phân bố khu vực'
            ? 'Lịch còn hiệu lực · Theo khu vực cơ sở hiện tại.'
            : 'Lịch còn hiệu lực · Theo ngày sử dụng sân.',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role != DemoRole.admin) {
        return Scaffold(
          appBar: financeBar('Báo cáo hệ thống'),
          body: const Center(
            child: Text('Chỉ Admin được xem báo cáo hệ thống.'),
          ),
        );
      }
      final range = _range;
      final report = AdminReportData.fromSession(
        s,
        from: range.start,
        to: range.end,
        sport: _sport,
        region: _region,
      );
      final previous = AdminReportData.fromSession(
        s,
        from: range.start.subtract(Duration(days: range.duration.inDays + 1)),
        to: range.start.subtract(const Duration(days: 1)),
        sport: _sport,
        region: _region,
      );
      final flow = report.cashflow;
      final sports = {
        'Cầu lông',
        'Pickleball',
        'Bóng đá',
        'Bóng rổ',
        'Quần vợt',
        'Đa năng',
        'Môn khác',
        ...s.managedBookings.map((b) => b.sport),
      }.toList();
      final regions = {
        'TP. Hồ Chí Minh',
        ...s.managedFacilities.map(
          (f) => adminReportRegion((f.published ?? f.draft).city),
        ),
        'Chưa xác định',
      }.toList();
      final reasons = report.cancellationReasons.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final reasonTotal = reasons.fold<int>(0, (sum, e) => sum + e.value);
      final stats = [
        _metric(
          'Tổng lượt đặt',
          report.totalBookings,
          'Theo ngày sử dụng sân',
          'bookings',
        ),
        _metric(
          'Đã xác nhận',
          report.confirmed,
          '${report.percent(report.confirmed, report.totalBookings)} tổng lượt đặt',
          'confirmed',
        ),
        _metric(
          'Đã hủy',
          report.cancelled,
          '${report.percent(report.cancelled, report.totalBookings)} tổng lượt đặt',
          'cancelled',
        ),
        _metric(
          'Chưa xác nhận',
          report.unconfirmed,
          '${report.percent(report.unconfirmed, report.totalBookings)} tổng lượt đặt',
          'unconfirmed',
        ),
      ];
      final large = MediaQuery.textScalerOf(context).scale(10) > 14;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          centerTitle: true,
          toolbarHeight: large ? 132 : 56,
          leading: BackButton(
            onPressed: () => Navigator.canPop(context)
                ? Navigator.pop(context)
                : HomeNavigation.returnHome(context),
          ),
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Báo cáo hệ thống',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Quản trị viên · Thống kê & đối soát',
                maxLines: 3,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: Color(0xFFC5EFDC),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Yêu cầu cần xử lý',
              icon: const Icon(Icons.notifications_outlined, size: 20),
              onPressed: () => _open(ApprovalCenterScreen(session: s)),
            ),
          ],
        ),
        body: ListView(
          key: const Key('system-report-list'),
          padding: const EdgeInsets.all(16),
          children: [
            if (s.saveFailed) FinanceSaveNotice(session: s),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                    key: Key(
                      i == 0
                          ? 'system-report-period-7'
                          : i == 1
                          ? 'system-report-period-30'
                          : 'system-report-custom',
                    ),
                    showCheckmark: false,
                    label: Text(['Tuần', 'Tháng', 'Tùy chỉnh'][i]),
                    selected: (_custom != null ? 2 : _period) == i,
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border),
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.green,
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: (_custom != null ? 2 : _period) == i
                          ? Colors.white
                          : AppColors.muted,
                    ),
                    onSelected: _busy
                        ? null
                        : (_) {
                            if (i == 2) {
                              _pickRange();
                            } else {
                              setState(() {
                                _period = i;
                                _custom = null;
                              });
                            }
                          },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Kỳ báo cáo',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                key: const Key('system-report-date-range'),
                onTap: _busy ? null : _pickRange,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.faint,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${bookingDate(range.start)} – ${bookingDate(range.end)}',
                          key: const Key('system-report-range'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  shape: const StadiumBorder(),
                  key: const Key('system-report-reset-scope'),
                  label: const Text('Toàn hệ thống'),
                  backgroundColor: _sport == null && _region == null
                      ? AppColors.green
                      : Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: _sport == null && _region == null
                        ? Colors.white
                        : AppColors.muted,
                  ),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _sport = null;
                          _region = null;
                        }),
                ),
                _scopeMenu(
                  'system-report-sport',
                  _sport ?? 'Tất cả môn',
                  sports,
                  () => setState(() => _sport = null),
                  (v) => setState(() => _sport = v),
                ),
                _scopeMenu(
                  'system-report-region',
                  _region ?? 'Tất cả khu vực',
                  regions,
                  () => setState(() => _region = null),
                  (v) => setState(() => _region = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card('Giao dịch & phí nền tảng', [
              _line('Giá trị giao dịch không phải doanh thu SportMatch.'),
              Text(
                bookingMoney(flow.received),
                key: const Key('system-report-received'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              _line(
                previous.cashflow.received == 0
                    ? 'Kỳ trước: ${bookingMoney(0)}'
                    : '${flow.received >= previous.cashflow.received ? '↑' : '↓'} ${((flow.received - previous.cashflow.received).abs() * 100 / previous.cashflow.received).toStringAsFixed(1)}% so với kỳ trước',
              ),
              _line(
                'Hoàn tiền: ${bookingMoney(flow.refunded)}',
                key: const Key('system-report-refunded'),
              ),
              _line(
                'Sau hoàn tiền: ${bookingMoney(flow.balance)}',
                key: const Key('system-report-balance'),
              ),
              _line('Phí nền tảng: Chưa có dữ liệu thực thu'),
              _notice(
                'Giao dịch theo ngày thu / hoàn. Thanh toán trực tiếp tại sân không được cộng vào phí nền tảng. Mức 3% hiện chỉ dùng trong đối soát mô phỏng.',
              ),
              if (flow.undatedPayments > 0)
                _muted(
                  '${flow.undatedPayments} khoản thu thiếu ngày ghi nhận, chưa cộng vào kỳ.',
                ),
            ]),
            _card('Giá trị giao dịch theo ngày', [
              _muted('Triệu đồng'),
              const SizedBox(height: 8),
              AdminTransactionChart(values: flow.daily()),
              if (flow.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Không phát sinh thu hoặc hoàn trong kỳ.',
                    key: Key('system-report-empty'),
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
            ]),
            const Text(
              'Hiệu suất đặt sân',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < stats.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: stats[i]),
                      const SizedBox(width: 8),
                      Expanded(child: stats[i + 1]),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            _card('Hủy & hoàn tiền', [
              _line('Yêu cầu hoàn: ${report.refundRequests} giao dịch'),
              _line(
                'Đã ghi nhận: ${report.recordedRefundCount} giao dịch · ${bookingMoney(flow.refunded)}',
              ),
              _line(
                'Chờ hoàn: ${report.pendingRefundCount} giao dịch · ${bookingMoney(report.pendingRefundAmount)}',
              ),
              if (reasons.isNotEmpty)
                _line(
                  'Lý do phổ biến: ${reasons.first.key} · ${report.percent(reasons.first.value, reasonTotal)}',
                ),
              _muted(
                'Yêu cầu hoàn theo ngày yêu cầu; đã hoàn theo ngày ghi nhận. Chỉ khoản hoàn đã ghi nhận được trừ khỏi giao dịch trong kỳ.',
              ),
              if (report.undatedRefunds > 0)
                _muted(
                  '${report.undatedRefunds} khoản hoàn chưa có ngày yêu cầu.',
                ),
            ]),
            _distribution('Đặt sân theo môn', report.bySport, report),
            _distribution('Phân bố khu vực', report.byRegion, report),
            _card('Tăng trưởng người dùng', [
              Text(
                '+${report.newUserCount} người dùng mới',
                key: const Key('system-report-new-users'),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              _muted('Người dùng mới · Toàn hệ thống'),
              const SizedBox(height: 8),
              AdminTransactionChart(values: report.newUsers, money: false),
              const SizedBox(height: 14),
              _line(
                'Tổng hiện tại: ${report.totalUsers} tài khoản',
                key: const Key('system-report-players'),
              ),
              _line(
                'Quay lại trong kỳ: ${report.percent(report.returningUsers, report.bookingUsers)} người đặt sân',
              ),
              if (report.undatedUsers > 0)
                _muted(
                  '${report.undatedUsers} tài khoản cũ chưa có ngày đăng ký, không cộng vào tăng trưởng.',
                ),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  key: const Key('system-report-export-error'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            FilledButton(
              key: const Key('system-report-export'),
              onPressed: _busy ? null : () => _export(report),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                minimumSize: const Size.fromHeight(44),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(
                _busy ? 'Đang tạo báo cáo…' : 'Xuất báo cáo · PDF / CSV',
              ),
            ),
            const SizedBox(height: 10),
            _muted(
              'Dữ liệu chốt lúc ${s.now.hour.toString().padLeft(2, '0')}:${s.now.minute.toString().padLeft(2, '0')} · ${bookingDate(s.now)}. Tệp xuất chỉ chứa dữ liệu trong phạm vi đã chọn.',
            ),
            if (_sport == null && _region == null)
              TextButton(
                key: const Key('system-report-cashflow'),
                onPressed: () =>
                    _open(CashflowScreen(session: s, initialRange: range)),
                child: const Text(
                  'Chi tiết dòng tiền',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _scopeMenu(
    String key,
    String label,
    List<String> values,
    VoidCallback clear,
    ValueChanged<String> select,
  ) => PopupMenuButton<String>(
    key: Key(key),
    enabled: !_busy,
    tooltip: label,
    onSelected: (v) => v.isEmpty ? clear() : select(v),
    itemBuilder: (_) => [
      const PopupMenuItem(value: '', child: Text('Tất cả')),
      for (final v in values) PopupMenuItem(value: v, child: Text(v)),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.muted),
      ),
    ),
  );
}
