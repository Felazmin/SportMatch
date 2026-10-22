import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import 'calendar_screen.dart';
import 'home_navigation.dart';
import 'finance_screen.dart';
import 'workflow_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';
  int _filter = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Khách hàng'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final all = s.venueCustomers;
      final history = <String, DemoWorkflowRecord>{};
      for (final record in s.managedAttendance) {
        final previous = history[record.owner];
        if (previous == null || record.start.isAfter(previous.start)) {
          history[record.owner] = record;
        }
      }
      final bookings = {for (final b in s.managedBookings) b.id: b};
      final returning = all.where((c) => c.count > 1).length;
      final items =
          all
              .where(
                (c) =>
                    (_filter == 0 ||
                        (_filter == 1 ? c.count > 1 : c.count == 1)) &&
                    venueSearchText('${c.name} ${c.phone}')
                        .contains(venueSearchText(_query)),
              )
              .toList()
            ..sort(
              (a, b) => history[b.id]!.start.compareTo(history[a.id]!.start),
            );
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight:
              56 +
              (MediaQuery.textScalerOf(context).scale(25) - 25).clamp(0, 100) *
                  1.5,
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x33FFFFFF),
            ),
          ),
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Khách hàng',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Danh sách & lịch sử đặt sân',
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
              key: const Key('customers-create-booking'),
              tooltip: 'Tạo lịch cho khách',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CalendarScreen(session: s),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_outlined, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0x33FFFFFF),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: s.role == DemoRole.owner
            ? const _CustomersNavigation()
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            const Text(
              'Tìm kiếm khách hàng',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('customers-search'),
              decoration: const InputDecoration(
                hintText: 'Tên hoặc số điện thoại',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.muted),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.faint,
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: AppColors.green),
                ),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CustomerMetric(
                    title: 'Tổng khách hàng',
                    value: '${all.length}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CustomerMetric(
                    title: 'Khách quay lại',
                    value:
                        '${all.isEmpty ? 0 : (returning * 100 / all.length).round()}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                    key: Key(
                      [
                        'customers-all',
                        'customers-returning',
                        'customers-new',
                      ][i],
                    ),
                    label: Text(
                      ['Tất cả', 'Khách quen', 'Khách mới'][i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: _filter == i ? Colors.white : AppColors.muted,
                      ),
                    ),
                    selected: _filter == i,
                    showCheckmark: false,
                    selectedColor: AppColors.green,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _filter == i ? AppColors.green : AppColors.border,
                    ),
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _filter = i),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Khách hàng gần đây',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length} khách',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Không có khách hàng phù hợp.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            for (final c in items)
              _CustomerCard(
                key: Key('customer-${c.id}'),
                customer: c,
                latest: history[c.id]!,
                booking: bookings[history[c.id]!.id],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(session: s, id: c.id),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'Thông tin chỉ sử dụng để quản lý và hỗ trợ lịch đặt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      );
    },
  );
}

class _CustomerMetric extends StatelessWidget {
  const _CustomerMetric({required this.title, required this.value});
  final String title, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreen,
          ),
        ),
      ],
    ),
  );
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    super.key,
    required this.customer,
    required this.latest,
    required this.booking,
    required this.onTap,
  });
  final DemoCustomer customer;
  final DemoWorkflowRecord latest;
  final DemoBooking? booking;
  final VoidCallback onTap;
  String get initials {
    final words = customer.name.trim().split(RegExp(r'\s+'));
    return words
        .skip(words.length > 1 ? words.length - 2 : 0)
        .map((w) => w.characters.first)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(12) > 17;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: customer.count > 1
            ? const Color(0xFFE5F6ED)
            : AppColors.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        customer.count > 1 ? 'Khách quen' : 'Thành viên',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: customer.count > 1 ? AppColors.darkGreen : AppColors.muted,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 1,
        shadowColor: const Color(0x18000000),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFE5F6ED),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customer.phone,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!large) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 90),
                        child: badge,
                      ),
                    ],
                  ],
                ),
                if (large) ...[const SizedBox(height: 8), badge],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${customer.count} lịch đặt',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        bookingMoney(customer.paid),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20, color: AppColors.border),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${bookingDate(latest.start)} · ${booking == null ? latest.title : 'Sân ${booking!.court} · ${booking!.sport}'}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.faint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomersNavigation extends StatelessWidget {
  const _CustomersNavigation();
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: InkWell(
                  key: Key('customers-nav-$i'),
                  onTap: () => HomeNavigation.openTab(context, i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FigmaIcon(
                        ['70656', 'ae34c', '8c511', '96aba', 'd96ab'][i],
                        size: 20,
                        color: i == 0 ? AppColors.green : AppColors.faint,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'Trang chủ',
                          'Bản đồ',
                          'Khám phá',
                          'Nổi bật',
                          'Tài khoản',
                        ][i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: i == 0 ? AppColors.green : AppColors.faint,
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
  );
}

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({
    super.key,
    required this.session,
    required this.id,
  });
  final DemoSession session;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final s = session;
      final c = s.user == null || s.role == DemoRole.player
          ? null
          : s.venueCustomers.where((c) => c.id == id).firstOrNull;
      if (c == null) {
        return Scaffold(
          appBar: financeBar('Khách hàng'),
          body: const Center(
            child: Text('Khách hàng không khả dụng hoặc không có quyền xem.'),
          ),
        );
      }
      final records = s.customerRecords(id);
      return Scaffold(
        appBar: financeBar('Khách hàng'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              c.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(c.phone),
            const Divider(height: 32),
            Text('${c.count} lịch/vé · ${c.cancelled} đã hủy'),
            Text('Tổng thanh toán đã xác nhận: ${bookingMoney(c.paid)}'),
            const Text('Tổng trước hoàn tiền, không phải doanh thu ròng.'),
            const Divider(height: 32),
            const Text(
              'Lịch sử tại sân',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final r in records)
              ListTile(
                key: Key('customer-record-${r.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(r.title),
                subtitle: Text(
                  '${r.id} · ${bookingDate(r.start)}\n${r.cancelled ? 'Đã hủy' : s.attendanceLabel(r.attendance)} · ${bookingMoney(r.total)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkflowDetailScreen(session: s, id: r.id),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
