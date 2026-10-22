import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../chat/demo_chat.dart';
import '../demo/demo_events.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';
import 'community_screen.dart';
import 'customer_account_views.dart';
import 'events_screen.dart';
import 'customer_tournament_checkout_screen.dart';
import 'finance_screen.dart';
import 'play_groups_screen.dart';

const _eventPhoto = 'assets/figma/badminton-event-demo.png';
void _open(BuildContext context, Widget screen) =>
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));
AppBar _bar(BuildContext context, String title, {Widget? action}) => AppBar(
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
  toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 27 ? 98 : 56,
  title: Text(
    title,
    maxLines: 2,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  actions: [?action],
);
Widget _card(List<Widget> children) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.border),
  ),
  child: Material(
    type: MaterialType.transparency,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  ),
);
Widget _title(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  ),
);
Widget _badge(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: const Color(0xFFE4F6EC),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      color: AppColors.green,
      fontWeight: FontWeight.w600,
    ),
  ),
);
Widget _info(IconData icon, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
      ),
    ],
  ),
);
Widget _heading(
  String title,
  VoidCallback action, {
  String label = 'Xem thêm',
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      TextButton(
        onPressed: action,
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    ],
  ),
);
String _sport(DemoEvent event) => venueSports.firstWhere(
  (s) => venueSearchText(event.title).contains(venueSearchText(s)),
  orElse: () => 'Thể thao',
);

class CustomerForumScreen extends StatefulWidget {
  const CustomerForumScreen({super.key, required this.session});
  final DemoSession session;
  @override
  State<CustomerForumScreen> createState() => _CustomerForumScreenState();
}

class _CustomerForumScreenState extends State<CustomerForumScreen> {
  final _search = TextEditingController();
  int _mode = 0;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(String text) =>
      venueSearchText(text).contains(venueSearchText(_search.text));
  void _event(DemoEvent e) => _open(
    context,
    CustomerEventDetailScreen(
      session: widget.session,
      event: e,
      start: e.start(widget.session.now),
    ),
  );
  Future<void> _chat(String id) async {
    final s = widget.session;
    if (s.user == null) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => AuthScreen(session: s)),
      );
    }
    if (!mounted || s.user == null || s.role != DemoRole.player) {
      return;
    }
    _open(context, ChatDetailScreen(session: s, contactId: id));
  }

  Widget _invitation(DemoEvent e) {
    final start = e.start(widget.session.now);
    final seats = widget.session.eventSeats(e.id, start);
    return _card([
      Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE4F6EC),
            child: Icon(Icons.groups_outlined, color: AppColors.green),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Lời mời giao lưu',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          _badge(_sport(e)),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        e.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      const SizedBox(height: 8),
      Text(e.description, style: const TextStyle(fontSize: 12, height: 1.5)),
      _info(
        Icons.schedule,
        '${bookingDate(start)} · ${bookingTime(start)} – ${bookingTime(e.end(start))}',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Còn $seats/${e.capacity} chỗ',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          FilledButton(
            key: Key('forum-join-${e.id}'),
            onPressed: () => _event(e),
            child: const Text('Tham gia'),
          ),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final socials = s.availableEvents
          .where(
            (e) =>
                e.kind == DemoEventKind.social &&
                _matches('${e.title} ${e.description}'),
          )
          .toList();
      final tournaments = s.availableEvents
          .where(
            (e) =>
                e.kind == DemoEventKind.tournament &&
                _matches('${e.title} ${e.description}'),
          )
          .toList();
      final posts = s.posts
          .where((p) => _matches('${p.author} ${p.message}'))
          .toList();
      final contacts = demoChatContacts
          .where((c) => _matches('${c.name} ${c.sport}'))
          .toList();
      final groups = s.publicGroups.entries
          .where((g) => _matches(g.value))
          .toList();
      return Scaffold(
        appBar: _bar(
          context,
          'Khám phá',
          action: IconButton(
            tooltip: 'Lịch & vé của tôi',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => _open(context, MyEventsScreen(session: s)),
          ),
        ),
        bottomNavigationBar: const CustomerAccountNavigation(selectedIndex: 2),
        body: Column(
          children: [
            Container(
              color: AppColors.green,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: TextField(
                key: const Key('forum-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm bài viết, hội nhóm, sự kiện…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _search.clear()),
                        ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  for (final entry in const [
                    (Icons.chat_bubble_outline, 'Diễn đàn'),
                    (Icons.groups_outlined, 'Hội nhóm'),
                    (Icons.people_outline, 'Bạn bè'),
                    (Icons.emoji_events_outlined, 'Giải đấu'),
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('forum-mode-${entry.$1}'),
                        selected: _mode == entry.$1,
                        selectedColor: const Color(0xFFE4F6EC),
                        avatar: Icon(
                          entry.$2.$1,
                          size: 16,
                          color: AppColors.green,
                        ),
                        label: Text(entry.$2.$2),
                        onSelected: (_) => setState(() => _mode = entry.$1),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  FinanceSaveNotice(session: s),
                  if (_mode == 0) ...[
                    _heading(
                      'Bài viết mới nhất',
                      () => _open(context, CommunityScreen(session: s)),
                    ),
                    for (final p in posts.take(3))
                      _card([
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              child: Text(p.author.characters.first),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.author,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          p.message,
                          style: const TextStyle(fontSize: 12, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bookingDate(p.created),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ]),
                    for (final e in socials.take(3)) _invitation(e),
                    if (posts.isEmpty && socials.isEmpty)
                      const Text('Chưa có bài viết hoặc lời mời phù hợp.'),
                  ],
                  if (_mode == 0 || _mode == 2) ...[
                    _heading(
                      'Kết nối người chơi',
                      () => _open(context, ChatListScreen(session: s)),
                      label: 'Tin nhắn',
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            MediaQuery.textScalerOf(context).scale(12) > 18
                            ? 1
                            : 3;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 8) /
                            columns;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in contacts.take(_mode == 2 ? 5 : 3))
                              SizedBox(
                                width: width,
                                child: _card([
                                  Center(
                                    child: CircleAvatar(
                                      backgroundColor: const Color(0xFFE4F6EC),
                                      child: Text(c.initials),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    c.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.sport,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  TextButton(
                                    key: Key('forum-chat-${c.id}'),
                                    onPressed: () => _chat(c.id),
                                    child: const Text(
                                      'Nhắn tin',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ]),
                              ),
                          ],
                        );
                      },
                    ),
                    if (contacts.isEmpty)
                      const Text('Không có người chơi phù hợp.'),
                  ],
                  if (_mode == 0 || _mode == 1) ...[
                    _heading(
                      'Hội nhóm đề xuất',
                      () => _open(context, CommunityScreen(session: s)),
                    ),
                    for (final g in groups.take(_mode == 1 ? groups.length : 3))
                      _card([
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.groups_outlined,
                              color: AppColors.green,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                g.value,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (s.publicPlayGroup(g.key)?.photo.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: PlayGroupPhoto(
                              encoded: s.publicPlayGroup(g.key)!.photo,
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            key: Key('forum-group-${g.key}'),
                            onPressed: () => _open(
                              context,
                              s.publicPlayGroup(g.key) == null
                                  ? CommunityScreen(session: s)
                                  : PlayGroupDetailScreen(
                                      session: s,
                                      id: g.key,
                                    ),
                            ),
                            child: const Text('Vào nhóm'),
                          ),
                        ),
                      ]),
                    if (groups.isEmpty)
                      const Text('Không có hội nhóm phù hợp.'),
                  ],
                  if (_mode == 0 || _mode == 3) ...[
                    _heading(
                      'Giải đấu & Sự kiện nổi bật',
                      () => _open(context, EventsScreen(session: s)),
                    ),
                    for (final e in tournaments)
                      _card([
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AspectRatio(
                            aspectRatio: 2.1,
                            child: Image.asset(_eventPhoto, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _badge('GIẢI ĐẤU · Ảnh minh họa'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _info(Icons.location_on_outlined, DemoBooking.venue),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${bookingMoney(e.fee)}/đội',
                              style: const TextStyle(
                                color: AppColors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            FilledButton(
                              key: Key('forum-tournament-${e.id}'),
                              onPressed: () => _event(e),
                              child: const Text('Đăng ký ngay'),
                            ),
                          ],
                        ),
                      ]),
                    if (tournaments.isEmpty)
                      const Text('Chưa có giải đấu phù hợp.'),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class CustomerEventDetailScreen extends StatelessWidget {
  const CustomerEventDetailScreen({
    super.key,
    required this.session,
    required this.event,
    required this.start,
  });
  final DemoSession session;
  final DemoEvent event;
  final DateTime start;
  Future<void> _register(BuildContext context) async {
    if (session.user == null) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => AuthScreen(session: session)),
      );
    }
    if (!context.mounted || session.user == null) {
      return;
    }
    final current = session.availableEvents
        .where((e) => e.id == event.id)
        .firstOrNull;
    final joined = session.participations
        .where((p) => p.eventId == event.id && p.start == start && !p.cancelled)
        .firstOrNull;
    if (joined != null && session.role == DemoRole.player) {
      _open(
        context,
        joined.registration != null &&
                session.workflowPayment(joined.id) == null
            ? CustomerTournamentPaymentScreen(
                session: session,
                participation: joined,
              )
            : ParticipationDetailScreen(
                session: session,
                participation: joined,
              ),
      );
      return;
    }
    if (session.role != DemoRole.player ||
        current == null ||
        current.start(session.now) != start ||
        !start.isAfter(session.now) ||
        session.eventCancellation(event.id, start) != null ||
        session.eventSeats(event.id, start) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hoạt động không còn khả dụng cho đăng ký.'),
        ),
      );
      return;
    }
    _open(
      context,
      current.kind == DemoEventKind.tournament
          ? CustomerTournamentRegistrationScreen(
              session: session,
              event: current,
              start: start,
            )
          : EventRegistrationScreen(
              session: session,
              event: current,
              start: start,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final e = session.availableEvents
          .where((e) => e.id == event.id)
          .firstOrNull;
      final social = event.kind == DemoEventKind.social;
      if (e == null) {
        return Scaffold(
          appBar: _bar(
            context,
            social ? 'Chi phí & Lịch trình' : 'Chi tiết giải đấu',
          ),
          body: const Center(child: Text('Hoạt động không còn công khai.')),
        );
      }
      final seats = session.eventSeats(e.id, start), count = e.capacity - seats;
      final own = session.participations
          .where((p) => p.eventId == e.id && p.start == start && !p.cancelled)
          .toList();
      final ownCount = own.fold<int>(0, (sum, p) => sum + p.quantity);
      final cancelled = session.eventCancellation(e.id, start);
      final available =
          start.isAfter(session.now) &&
          start == e.start(session.now) &&
          cancelled == null &&
          seats > 0;
      final canRegister =
          session.user == null || session.role == DemoRole.player;
      return Scaffold(
        appBar: _bar(
          context,
          social ? 'Chi phí & Lịch trình' : 'Chi tiết giải đấu',
          action: IconButton(
            tooltip: social ? 'Lịch & vé của tôi' : 'Sao chép thông tin giải',
            icon: Icon(
              social ? Icons.notifications_none : Icons.share_outlined,
            ),
            onPressed: () async {
              if (social) {
                _open(context, MyEventsScreen(session: session));
                return;
              }
              await Clipboard.setData(
                ClipboardData(
                  text:
                      '${e.title}\n${bookingDate(start)} · ${bookingTime(start)}\n${DemoBooking.venue}\n${bookingMoney(e.fee)}/đội',
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép thông tin giải.')),
                );
              }
            },
          ),
        ),
        bottomNavigationBar: const CustomerAccountNavigation(selectedIndex: 2),
        body: ListView(
          children: [
            if (!social) ...[
              AspectRatio(
                aspectRatio: 2.1,
                child: Image.asset(_eventPhoto, fit: BoxFit.cover),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16, top: 4),
                child: Text(
                  'Ảnh minh họa',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FinanceSaveNotice(session: session),
                  if (cancelled != null)
                    _card([
                      Text(
                        'Buổi đã hủy: ${cancelled.reason}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ]),
                  _card([
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _badge(
                        cancelled != null
                            ? 'Đã hủy'
                            : available
                            ? 'Đang mở đăng ký'
                            : 'Đã đóng đăng ký',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      e.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _info(
                      Icons.calendar_today_outlined,
                      '${bookingDate(start)} · ${bookingTime(start)} – ${bookingTime(e.end(start))}',
                    ),
                    _info(
                      Icons.location_on_outlined,
                      '${DemoBooking.venue}\n${DemoBooking.address}',
                    ),
                    _info(
                      Icons.people_outline,
                      '$count/${e.capacity} ${social ? 'vé' : 'đội'} đã đăng ký',
                    ),
                    if (session.eventGroupName(e.id) != null)
                      _info(
                        Icons.groups_outlined,
                        session.eventGroupName(e.id)!,
                      ),
                  ]),
                  _title(social ? 'Chi phí tham gia' : 'Phí tham gia'),
                  _card([
                    Text(
                      '${bookingMoney(e.fee)}/${social ? 'người' : 'đội'}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      e.description,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const Divider(height: 24),
                    if (social) ...[
                      _info(
                        Icons.payments_outlined,
                        'Tổng phí khi đủ ${e.capacity} người: ${bookingMoney(e.fee * e.capacity)}',
                      ),
                      _info(
                        Icons.receipt_long_outlined,
                        'Phí của $count vé đã đăng ký: ${bookingMoney(e.fee * count)}',
                      ),
                      for (final p in own)
                        _info(
                          Icons.person_outline,
                          '${p.contact} · ${p.quantity} vé · ${bookingMoney(p.total)}',
                        ),
                      if (count > ownCount)
                        _info(
                          Icons.groups_outlined,
                          '${count - ownCount} vé của người tham gia khác',
                        ),
                      if (seats > 0)
                        _info(Icons.person_add_alt, 'Còn $seats chỗ tham gia'),
                      const Text(
                        'Mức phí cố định theo vé, không tự giảm khi có thêm người.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('customer-event-register'),
                        onPressed: canRegister && (own.isNotEmpty || available)
                            ? () => _register(context)
                            : null,
                        child: Text(
                          own.isNotEmpty
                              ? 'Xem đăng ký của tôi'
                              : available
                              ? 'Tham gia ngay'
                              : 'Đã đóng đăng ký',
                        ),
                      ),
                    ],
                  ]),
                  if (!social) ...[
                    _title('Thể lệ giải đấu'),
                    _card([
                      _title('THỂ THỨC'),
                      Text(
                        e.description,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                      const Divider(height: 24),
                      _title('SỐ NGƯỜI / ĐỘI'),
                      const Text(
                        '2 người · Đăng ký theo đội',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      _title('LỊCH THI ĐẤU CHI TIẾT'),
                      const Text(
                        'Thời gian từng trận, trang phục và thiết bị do ban tổ chức công bố.',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ]),
                  ],
                  _title(social ? 'Lịch sự kiện' : 'Lịch thi đấu & Sự kiện'),
                  _EventCalendar(
                    start: start,
                    end: e.end(start),
                    title: e.title,
                  ),
                  _title('Hủy đăng ký & Hoàn tiền'),
                  _card([
                    const Text(
                      'Vé chưa có hồ sơ thanh toán có thể hủy trước giờ bắt đầu. Khi đã mở hồ sơ thanh toán, cần yêu cầu hủy trước ít nhất 24 giờ và chưa check-in. Hoàn tiền được mô phỏng, không chuyển tiền thật.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ]),
                  if (!social) ...[
                    FilledButton(
                      key: const Key('customer-event-register'),
                      onPressed: canRegister && (own.isNotEmpty || available)
                          ? () => _register(context)
                          : null,
                      child: Text(
                        own.isNotEmpty
                            ? 'Xem đăng ký của tôi'
                            : available
                            ? 'Đăng ký tham gia · ${bookingMoney(e.fee)}'
                            : 'Đã đóng đăng ký',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Còn $seats suất đăng ký',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _EventCalendar extends StatefulWidget {
  const _EventCalendar({
    required this.start,
    required this.end,
    required this.title,
  });
  final DateTime start, end;
  final String title;
  @override
  State<_EventCalendar> createState() => _EventCalendarState();
}

class _EventCalendarState extends State<_EventCalendar> {
  late DateTime _selected = bookingDay(widget.start);
  @override
  Widget build(BuildContext context) => _card([
    Localizations.override(
      context: context,
      locale: const Locale('vi'),
      delegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: CalendarDatePicker(
        initialDate: bookingDay(widget.start),
        firstDate: DateTime(widget.start.year - 1),
        lastDate: DateTime(widget.start.year + 1, 12, 31),
        onDateChanged: (day) => setState(() => _selected = day),
      ),
    ),
    const Divider(),
    if (_selected == bookingDay(widget.start)) ...[
      Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Text(
        '${bookingDate(widget.start)} · ${bookingTime(widget.start)} – ${bookingTime(widget.end)}',
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ] else
      Text(
        'Không có lịch được công bố ngày ${bookingDate(_selected)}.',
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
  ]);
}
