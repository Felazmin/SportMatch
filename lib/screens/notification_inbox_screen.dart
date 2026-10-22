import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../notifications/notification_center.dart';
import '../notifications/notification_models.dart';
import '../notifications/notification_scope.dart';
import '../widgets/design.dart';
import 'auth_screen.dart';
import 'customer_checkout_screen.dart';

Future<void> openBookingNotice(
  BuildContext context,
  DemoSession session,
  NotificationCenter center,
  InboxNotice notice,
) async {
  final row = await center.resolve(notice.id);
  if (!context.mounted ||
      row == null ||
      session.user?.identifier != row.owner) {
    return;
  }
  await center.markRead(row.id);
  if (!context.mounted ||
      session.user?.identifier != row.owner ||
      session.role != DemoRole.player) {
    return;
  }
  final booking = session.bookings
      .where((b) => b.id == row.bookingId)
      .firstOrNull;
  if (booking == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Không tìm thấy lịch đặt.')));
    return;
  }
  if (!context.mounted) return;
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          CustomerCheckoutDetailScreen(session: session, booking: booking),
    ),
  );
}

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({
    super.key,
    required this.session,
    this.center,
  });
  final DemoSession session;
  final NotificationCenter? center;
  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  bool _busy = false;
  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(NotificationCenter center, InboxNotice row) async {
    final owner = center.owner;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          row.due(center.now) ? 'Xóa thông báo?' : 'Hủy lịch nhắc này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            key: const Key('notification-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && center.owner == owner) {
      await _perform(() => center.delete(row.id));
    }
  }

  void _settings(NotificationCenter center) {
    final owner = center.owner;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: center,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: center.owner != owner
                ? const Text('Tài khoản đã thay đổi.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Cài đặt nhắc lịch',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!center.supported)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Nhắc trên thiết bị hiện chỉ hỗ trợ ứng dụng Android và iOS.',
                          ),
                        ),
                      SwitchListTile(
                        key: const Key('notification-reminders-enabled'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Nhắc trước giờ chơi'),
                        value: center.preferences.enabled,
                        onChanged: center.supported && !center.updating
                            ? (value) => center.setPreferences(
                                value,
                                center.preferences.minutes,
                              )
                            : null,
                      ),
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          'notification-lead-${center.preferences.minutes}',
                        ),
                        initialValue: center.preferences.minutes,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Thời gian nhắc',
                        ),
                        items: [
                          for (final minutes in ReminderPreferences.leadTimes)
                            DropdownMenuItem(
                              value: minutes,
                              child: Text('Trước $minutes phút'),
                            ),
                        ],
                        onChanged: center.updating
                            ? null
                            : (value) {
                                if (value != null) {
                                  center.setPreferences(
                                    center.preferences.enabled,
                                    value,
                                  );
                                }
                              },
                      ),
                      if (center.permissionDenied)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Chưa có quyền thông báo. Kiểm tra quyền SportMatch trong cài đặt thiết bị.',
                          ),
                        ),
                      if (center.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(center.error!),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.center ?? NotificationScope.maybeOf(context);
    if (center == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông báo')),
        body: const Center(child: Text('Thông báo chưa được khởi tạo.')),
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([center, widget.session]),
      builder: (context, _) {
        final signedIn = center.owner != null;
        final due = center.notices.where((n) => n.due(center.now)).toList();
        final pending = center.notices.where((n) => !n.due(center.now)).toList()
          ..sort((a, b) => a.scheduled!.compareTo(b.scheduled!));
        final lists = [
          due,
          due.where((n) => n.readAt == null).toList(),
          pending,
        ];
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Thông báo'),
              actions: [
                if (signedIn)
                  IconButton(
                    key: const Key('notification-settings'),
                    tooltip: 'Cài đặt nhắc lịch',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _busy ? null : () => _settings(center),
                  ),
                if (signedIn)
                  IconButton(
                    key: const Key('notification-mark-all'),
                    tooltip: 'Đánh dấu tất cả đã đọc',
                    icon: const Icon(Icons.done_all),
                    onPressed: _busy || center.unread == 0
                        ? null
                        : () => _perform(center.markAllRead),
                  ),
              ],
              bottom: signedIn
                  ? TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        const Tab(text: 'Tất cả'),
                        Tab(text: 'Chưa đọc (${center.unread})'),
                        const Tab(text: 'Lịch nhắc'),
                      ],
                    )
                  : null,
            ),
            body: !signedIn
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Đăng nhập tài khoản khách hàng để xem thông báo.',
                            textAlign: TextAlign.center,
                          ),
                          if (widget.session.user == null)
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      AuthScreen(session: widget.session),
                                ),
                              ),
                              child: const Text('Đăng nhập'),
                            ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      if (center.error != null)
                        Material(
                          color: const Color(0xFFFFF3CD),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(center.error!),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _perform(center.sync),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (center.loading) const LinearProgressIndicator(),
                      Expanded(
                        child: TabBarView(
                          children: [
                            for (var i = 0; i < lists.length; i++)
                              RefreshIndicator(
                                onRefresh: center.sync,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: lists[i].isEmpty
                                      ? 1
                                      : lists[i].length,
                                  itemBuilder: (context, index) {
                                    if (lists[i].isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 64,
                                        ),
                                        child: Text(
                                          i == 2
                                              ? 'Chưa có lịch nhắc.'
                                              : 'Chưa có thông báo.',
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }
                                    final row = lists[i][index],
                                        unread = lists[i][index].readAt == null;
                                    final time = row.scheduled ?? row.created;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Material(
                                        key: Key('notification-${row.id}'),
                                        color: unread
                                            ? const Color(0xFFE5F6ED)
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          side: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          onTap: _busy
                                              ? null
                                              : () => _perform(
                                                  () => openBookingNotice(
                                                    context,
                                                    widget.session,
                                                    center,
                                                    row,
                                                  ),
                                                ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      row.kind == 'reminder'
                                                          ? Icons
                                                                .notifications_active_outlined
                                                          : Icons
                                                                .event_available_outlined,
                                                      size: 20,
                                                      color:
                                                          AppColors.darkGreen,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        row.title,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: unread
                                                              ? FontWeight.w700
                                                              : FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  row.body,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    height: 1.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${bookingDate(time)} · ${bookingTime(time)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.muted,
                                                  ),
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Wrap(
                                                    children: [
                                                      if (unread &&
                                                          row.due(center.now))
                                                        IconButton(
                                                          tooltip:
                                                              'Đánh dấu đã đọc',
                                                          icon: const Icon(
                                                            Icons.done,
                                                          ),
                                                          onPressed: _busy
                                                              ? null
                                                              : () => _perform(
                                                                  () => center
                                                                      .markRead(
                                                                        row.id,
                                                                      ),
                                                                ),
                                                        ),
                                                      IconButton(
                                                        key: Key(
                                                          'notification-delete-${row.id}',
                                                        ),
                                                        tooltip:
                                                            row.due(center.now)
                                                            ? 'Xóa thông báo'
                                                            : 'Hủy lịch nhắc',
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                        ),
                                                        onPressed: _busy
                                                            ? null
                                                            : () => _delete(
                                                                center,
                                                                row,
                                                              ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
