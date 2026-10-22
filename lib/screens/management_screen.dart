import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_finance.dart';
import '../widgets/design.dart';
import 'finance_screen.dart';
import 'operations_screen.dart';
import 'settlement_screen.dart';
import 'facilities_screen.dart';
import 'workflow_screen.dart';
import 'calendar_screen.dart';
import 'admin_players_screen.dart';
import 'reviews_screen.dart';
import 'customers_screen.dart';
import 'approval_center_screen.dart';
import 'shifts_screen.dart';
import 'dashboard_screen.dart';
import 'play_groups_screen.dart';
import 'activities_screen.dart';
import 'court_types_screen.dart';
import 'tournament_directory_screen.dart';
import 'owner_verification_screen.dart';
import 'payout_screen.dart';
import 'admin_management_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  DemoRole _role = DemoRole.owner;
  bool _busy = false;
  bool _hidden = true;
  String? _error;
  String? _pendingActor;
  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    if (_pendingActor == null &&
        !widget.session.loginStaff(_role, _identifier.text, _password.text)) {
      setState(() => _error = 'Tài khoản, mật khẩu hoặc vai trò chưa đúng.');
      return;
    }
    final actor = _pendingActor ?? widget.session.user?.identifier;
    if (actor == null || widget.session.user?.identifier != actor) {
      setState(() {
        _pendingActor = null;
        _error = 'Phiên tài khoản đã thay đổi. Vui lòng đăng nhập lại.';
      });
      return;
    }
    final retry = _pendingActor != null;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (retry) await widget.session.retrySave();
    final saved = await widget.session.flush();
    if (!mounted) return;
    if (widget.session.user?.identifier != actor) {
      setState(() {
        _busy = false;
        _pendingActor = null;
        _error = 'Phiên tài khoản đã thay đổi. Vui lòng đăng nhập lại.';
      });
      return;
    }
    if (!saved) {
      setState(() {
        _busy = false;
        _pendingActor = actor;
        _error = 'Chưa lưu được phiên đăng nhập. Vui lòng thử lưu lại.';
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: financeBar('Đăng nhập quản lý'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final role in [DemoRole.owner, DemoRole.admin])
              ChoiceChip(
                key: Key('staff-role-${role.name}'),
                label: Text(role == DemoRole.owner ? 'Chủ sân' : 'Admin'),
                selected: _role == role,
                onSelected: _busy || _pendingActor != null
                    ? null
                    : (_) => setState(() {
                        _role = role;
                        _error = null;
                      }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('staff-identifier'),
          controller: _identifier,
          enabled: !_busy && _pendingActor == null,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email quản lý'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('staff-password'),
          controller: _password,
          enabled: !_busy && _pendingActor == null,
          obscureText: _hidden,
          decoration: InputDecoration(
            labelText: 'Mật khẩu',
            suffixIcon: IconButton(
              tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(
                _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        FilledButton(
          key: const Key('staff-submit'),
          onPressed: _busy ? null : _login,
          child: Text(
            _busy
                ? 'Đang lưu...'
                : _pendingActor != null
                ? 'Thử lưu lại'
                : 'Đăng nhập quản lý',
          ),
        ),
      ],
    ),
  );
}

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({
    super.key,
    required this.session,
    this.adminPresentation = false,
    this.embedded = false,
  });
  final DemoSession session;
  final bool adminPresentation, embedded;
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  String _view = 'calendar';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (widget.adminPresentation && s.role == DemoRole.admin) {
        return AdminManagementScreen(session: s, embedded: widget.embedded);
      }
      if (s.user == null || s.role == DemoRole.player) {
        return Scaffold(
          appBar: financeBar('Quản lý'),
          body: const Center(child: Text('Cần tài khoản Chủ sân hoặc Admin.')),
        );
      }
      final bookings = s.managedBookings;
      final pending = bookings
          .where(
            (b) =>
                s.paymentFor(b)?.state == DemoPaymentState.pending &&
                !b.cancelled,
          )
          .length;
      final cancel = bookings
          .where(
            (b) =>
                s.paymentFor(b)?.cancellation ==
                DemoCancellationState.requested,
          )
          .length;
      final approved = bookings
          .where(
            (b) =>
                s.paymentFor(b)?.state == DemoPaymentState.approved &&
                !b.cancelled,
          )
          .fold<int>(0, (sum, b) => sum + b.total);
      final entries = bookings
          .where(
            (b) => _view == 'payments'
                ? s.paymentFor(b) != null
                : _view == 'cancel'
                ? s.paymentFor(b)?.cancellation ==
                      DemoCancellationState.requested
                : true,
          )
          .toList();
      final views = {
        'calendar': 'Lịch đặt',
        'payments': 'Thanh toán',
        'cancel': 'Yêu cầu hủy',
        'disputes': 'Khiếu nại',
        if (s.role == DemoRole.admin) 'users': 'Người dùng',
      };
      return Scaffold(
        appBar: financeBar(
          s.role == DemoRole.admin ? 'Quản trị demo' : 'Chủ sân demo',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            ListTile(
              key: const Key('management-payouts'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Chi trả demo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PayoutScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-owner-verification'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Hồ sơ chủ sân'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OwnerVerificationScreen(session: s),
                ),
              ),
            ),
            ListTile(
              key: const Key('management-activities'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sports_tennis_outlined),
              title: const Text('Quản lý hoạt động'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ActivitiesScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-play-groups'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Quản lý nhóm chơi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlayGroupsScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-tournaments'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Quản lý giải đấu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentDirectoryScreen(session: s),
                ),
              ),
            ),
            ListTile(
              key: const Key('management-court-types'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.category_outlined),
              title: const Text('Loại sân'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CourtTypesScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-dashboard'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Tổng quan'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DashboardScreen(session: s)),
              ),
            ),
            const Text(
              DemoBooking.venue,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('$pending minh chứng chờ duyệt · $cancel yêu cầu hủy'),
            Text('Tổng xác nhận demo còn hiệu lực: ${bookingMoney(approved)}'),
            const Divider(height: 24),
            ListTile(
              key: const Key('management-calendar-grid'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: const Text('Lịch sân & khóa giờ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CalendarScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-attendance'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Vé, check-in & hoàn tiền'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AttendanceScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-facilities'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(
                s.role == DemoRole.admin
                    ? 'Quản lý & duyệt cơ sở'
                    : 'Sân của tôi',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FacilitiesScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-operations'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Quản lý vận hành'),
              subtitle: const Text('Sân, giá, nhân viên, báo cáo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OperationsScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-shifts'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Nhân viên & ca làm'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeRosterScreen(session: s),
                ),
              ),
            ),
            ListTile(
              key: const Key('management-customers'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.people_outline),
              title: const Text('Khách hàng'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CustomersScreen(session: s)),
              ),
            ),
            ListTile(
              key: const Key('management-settlement'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Đối soát doanh thu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettlementScreen(session: s)),
              ),
            ),
            if (s.role == DemoRole.admin)
              ListTile(
                key: const Key('management-approval-center'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pending_actions),
                title: const Text('Trung tâm xử lý'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApprovalCenterScreen(session: s),
                  ),
                ),
              ),
            if (s.role == DemoRole.admin)
              ListTile(
                key: const Key('management-review-moderation'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rate_review_outlined),
                title: const Text('Kiểm duyệt đánh giá'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewsScreen(session: s, admin: true),
                  ),
                ),
              ),
            if (s.role == DemoRole.admin)
              ListTile(
                key: const Key('management-player-directory'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Quản lý người dùng'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminPlayersScreen(session: s),
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in views.entries)
                  ChoiceChip(
                    key: Key('management-${e.key}'),
                    selected: _view == e.key,
                    label: Text(e.value),
                    onSelected: (_) => setState(() => _view = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_view == 'users') ...[
              for (final user in s.managedUsers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(user.name),
                  subtitle: Text(user.identifier),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminPlayerDetailScreen(
                        session: s,
                        id: user.identifier,
                      ),
                    ),
                  ),
                ),
            ] else if (_view == 'disputes') ...[
              if (s.disputes.isEmpty) const Text('Chưa có khiếu nại.'),
              for (final d in s.disputes)
                ListTile(
                  key: Key('management-dispute-${d.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(d.subject),
                  subtitle: Text('${d.id} · ${d.bookingId}\n${d.label}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DisputeDetailScreen(session: s, dispute: d),
                    ),
                  ),
                ),
            ] else ...[
              if (entries.isEmpty) const Text('Không có lịch trong mục này.'),
              for (final b in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      key: Key('management-booking-${b.id}'),
                      contentPadding: const EdgeInsets.all(12),
                      title: Text('${b.id} · Sân ${b.court}'),
                      subtitle: Text(
                        '${bookingDate(b.start)} · ${bookingTime(b.start)}\n${b.contact}\n${b.cancelled ? 'Đã hủy' : s.paymentFor(b)?.label(s.now) ?? 'Thanh toán tại sân · Chưa thanh toán'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(session: s, booking: b),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Quản lý dữ liệu của một sân demo trên thiết bị, không kết nối ngân hàng hoặc hệ thống quản trị thật.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}
