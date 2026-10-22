import 'package:flutter/material.dart';

import 'customer_social_screen.dart';

import 'owner_management_views.dart';

import '../auth/demo_session.dart';
import '../widgets/design.dart';
import 'demo_account_screens.dart';
import 'events_screen.dart';
import 'community_screen.dart';
import 'management_screen.dart';
import 'finance_screen.dart';
import 'facilities_screen.dart';
import 'employee_access_screen.dart';
import 'customer_account_views.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.session,
    required this.onLogin,
    required this.onFavorites,
    required this.favoriteCount,
    required this.onMessages,
  });
  final DemoSession session;
  final void Function(bool register) onLogin;
  final VoidCallback onFavorites;
  final int favoriteCount;
  final VoidCallback onMessages;

  void _details(BuildContext context, String title, List<String> values) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final value in values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  void _protected(VoidCallback action) {
    if (session.user == null) {
      onLogin(false);
    } else {
      action();
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm == true) session.logout();
  }

  Future<void> _edit(BuildContext context) async {
    if (session.user == null) {
      onLogin(false);
      return;
    }
    final actor = session.user!.identifier;
    final role = session.role;
    final controller = TextEditingController(text: session.user!.name);
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa hồ sơ'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Nhập họ và tên' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (name != null &&
        session.user?.identifier == actor &&
        session.role == role) {
      session.updateName(name);
      await session.flush();
    }
    // Wait for the dialog's exit transition before releasing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (session.initialized && session.activeEmployee != null) {
      return EmployeePortalScreen(session: session);
    }
    if (session.initialized &&
        session.user != null &&
        session.role == DemoRole.owner) {
      return OwnerProfileView(
        session: session,
        embedded: true,
        onEdit: () => _edit(context),
        onLogout: () => _logout(context),
      );
    }
    final user = session.user;
    final seeded = user?.seeded ?? false;
    void open(Widget screen) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    void showBookings() => _protected(
      () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerBookingsScreen(session: session),
        ),
      ),
    );
    return ListView(
      key: ValueKey('account-${user?.identifier ?? 'guest'}'),
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: AppColors.green,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tài khoản',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _headerAction(
                        '5968b',
                        19,
                        'Cài đặt tài khoản',
                        () => _protected(
                          () => open(AccountSettingsScreen(session: session)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 100),
                  child: Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            user?.initials ?? 'KH',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Khách',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              user == null
                                  ? 'Chưa đăng nhập'
                                  : '${_contact(session.displayIdentifier)} · TP. Hồ Chí Minh',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xD1FFFFFF),
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEB3B),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    user == null
                                        ? 'KHÁCH'
                                        : seeded
                                        ? 'THÀNH VIÊN BẠC'
                                        : 'THÀNH VIÊN MỚI',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (user != null)
                                  Text(
                                    '${session.points} điểm',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _headerAction(
                        'ae747',
                        16,
                        'Sửa hồ sơ',
                        () => _edit(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onLogin(false),
                        child: const Text('Đăng nhập'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onLogin(true),
                        child: const Text('Đăng ký'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  _shortcut(
                    '4f5de',
                    '${session.upcomingCount} sân',
                    'Lịch đặt',
                    showBookings,
                  ),
                  const SizedBox(width: 8),
                  _shortcut(
                    'aaf07',
                    '${session.vouchers.length} mã',
                    'Ví ưu đãi',
                    () => _protected(
                      () => open(VoucherWalletScreen(session: session)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _shortcut(
                    'f21c3',
                    '${session.points}',
                    'Điểm thưởng',
                    () =>
                        _protected(() => open(PointsScreen(session: session))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Tài khoản của tôi',
                style: TextStyle(fontSize: 14, height: 1.2),
              ),
              const SizedBox(height: 10),
              _menu([
                _item(
                  '',
                  'Không gian nhân viên',
                  () => open(EmployeePortalScreen(session: session)),
                  iconData: Icons.badge_outlined,
                ),
                _item(
                  '',
                  'Khiếu nại của tôi',
                  () =>
                      _protected(() => open(DisputesScreen(session: session))),
                  iconData: Icons.report_problem_outlined,
                ),
                if (user != null && user.role != DemoRole.player)
                  _item(
                    '',
                    user.role == DemoRole.admin
                        ? 'Không gian Admin'
                        : 'Không gian Chủ sân',
                    () => open(ManagementScreen(session: session)),
                    iconData: Icons.admin_panel_settings_outlined,
                  ),
                _item(
                  '',
                  'Cộng đồng & chia tiền',
                  () => open(CommunityScreen(session: session)),
                  iconData: Icons.forum_outlined,
                ),
                _item(
                  '',
                  'Cơ sở đã duyệt',
                  () => open(
                    FacilitiesScreen(session: session, publicOnly: true),
                  ),
                  iconData: Icons.storefront_outlined,
                ),
                _item(
                  '',
                  'Vé social đã mua',
                  () => _protected(
                    () => open(SocialTicketsScreen(session: session)),
                  ),
                  iconData: Icons.local_activity_outlined,
                ),
                _item(
                  '',
                  'Vé & lịch tham gia',
                  () =>
                      _protected(() => open(MyEventsScreen(session: session))),
                  iconData: Icons.confirmation_number_outlined,
                ),
                _item(
                  '',
                  'Tin nhắn',
                  onMessages,
                  iconData: Icons.chat_bubble_outline,
                  detail: '${session.unreadMessages} chưa đọc',
                ),
                _item(
                  'b4407',
                  'Lịch đặt sân',
                  showBookings,
                  detail: '${session.upcomingCount} lịch sắp tới',
                ),
                _item(
                  'ef1d9',
                  'Sân yêu thích',
                  onFavorites,
                  detail: '$favoriteCount sân',
                ),
                _item(
                  'b4407',
                  'Lịch học',
                  () => open(AcademyScreen(session: session)),
                  detail:
                      '${session.enrollments.where((e) => !e.cancelled && e.start.isAfter(session.now)).length} buổi',
                ),
                _item(
                  '4f432',
                  'Phương thức thanh toán',
                  () => _protected(
                    () => open(CustomerPaymentMethodsScreen(session: session)),
                  ),
                  last: true,
                ),
              ]),
              const SizedBox(height: 10),
              const Text(
                'Hỗ trợ & thông tin',
                style: TextStyle(fontSize: 14, height: 1.2),
              ),
              const SizedBox(height: 10),
              _menu([
                _item(
                  '3e659',
                  'Trung tâm trợ giúp',
                  () => open(SupportScreen(session: session)),
                ),
                _item(
                  '1b9d4',
                  'Điều khoản sử dụng',
                  () => _details(context, 'Điều khoản sử dụng', [
                    'Đây là bản dùng thử. Các thao tác không tạo đặt sân hoặc giao dịch thực tế.',
                  ]),
                ),
                _item(
                  '7253f',
                  'Chính sách quyền riêng tư',
                  () => _details(context, 'Chính sách quyền riêng tư', [
                    'Tài khoản, thông tin liên hệ và lịch demo được lưu mã hóa trên thiết bị, không gửi đến máy chủ. Chỉ sử dụng thông tin và mật khẩu dùng thử.',
                  ]),
                ),
                _item(
                  '42eb7',
                  'Thông tin ứng dụng',
                  () => _details(context, 'NVH Sports', [
                    'Phiên bản 1.0.0 · Bản demo',
                  ]),
                  detail: 'v1.0.0',
                  last: true,
                ),
              ]),
              if (user != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 213,
                    height:
                        33 +
                        (MediaQuery.textScalerOf(context).scale(12) - 12) * 1.5,
                    child: TextButton(
                      key: const Key('account-logout'),
                      onPressed: () => _logout(context),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0x91BDBDBD),
                        foregroundColor: const Color(0xFFF05757),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DesignAsset('5de56', folder: 'account', size: 15),
                          SizedBox(width: 6),
                          Text('Đăng xuất', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _contact(String identifier) {
    if (identifier.length == 10 && !identifier.contains('@')) {
      return '${identifier.substring(0, 3)} ${identifier.substring(3, 6)} ${identifier.substring(6)}';
    }
    return identifier;
  }

  Widget _headerAction(
    String icon,
    double size,
    String tooltip,
    VoidCallback onTap,
  ) => IconButton(
    onPressed: onTap,
    tooltip: tooltip,
    icon: DesignAsset(icon, folder: 'account', size: size),
    style: IconButton.styleFrom(
      backgroundColor: const Color(0x2EFFFFFF),
      minimumSize: const Size(34, 34),
      fixedSize: const Size(34, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  Widget _shortcut(
    String icon,
    String value,
    String label,
    VoidCallback onTap,
  ) => Expanded(
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DesignAsset(icon, folder: 'account', size: 20),
                const SizedBox(height: 6),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.2),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _menu(List<Widget> items) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: items),
  );

  Widget _item(
    String icon,
    String label,
    VoidCallback onTap, {
    String? detail,
    IconData? iconData,
    bool last = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F6EC),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: iconData == null
                  ? DesignAsset(icon, folder: 'account', size: 18)
                  : Icon(iconData, size: 18, color: AppColors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  border: last
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 14, height: 1.3),
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          detail,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.faint,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    const DesignAsset('dc4a4', folder: 'account', size: 14),
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
