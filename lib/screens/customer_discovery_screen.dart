import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_events.dart';
import '../demo/demo_extras.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import '../widgets/venue_image.dart';
import 'customer_forum_views.dart';
import 'booking_screen.dart';
import 'customer_venue_detail_screen.dart';
import 'demo_account_screens.dart';
import 'events_screen.dart';
import 'venue_browse_screen.dart';
import 'notification_inbox_screen.dart';

void _open(BuildContext context, Widget screen) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

class DiscoveryHeader extends StatelessWidget {
  const DiscoveryHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final String title, subtitle, tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.green,
    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFFD2F3E1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .18),
            foregroundColor: Colors.white,
          ),
          icon: Icon(icon, size: 23),
        ),
      ],
    ),
  );
}

class DiscoveryHeading extends StatelessWidget {
  const DiscoveryHeading(this.title, {super.key, this.action, this.onPressed});
  final String title;
  final String? action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 15, height: 1.3)),
        ),
        if (action != null)
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.only(left: 8),
              foregroundColor: AppColors.green,
            ),
            child: Text(action!, style: const TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
}

class CustomerExploreScreen extends StatelessWidget {
  const CustomerExploreScreen({super.key, required this.session});
  final DemoSession session;
  void _notifications(BuildContext context) => _open(
    context,
    DiscoveryInformationScreen(session: session, notifications: true),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final event = session.availableEvents
          .where((e) => e.kind == DemoEventKind.tournament)
          .firstOrNull;
      return CustomScrollView(
        key: const PageStorageKey('customer-explore-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: DiscoveryHeader(
              title: 'Khám phá',
              subtitle: 'Sự kiện và hoạt động dành cho bạn',
              icon: Icons.notifications_none,
              tooltip: 'Thông báo',
              onPressed: () => _notifications(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList.list(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shortcut(
                      context,
                      'Sự kiện',
                      Icons.calendar_today_outlined,
                      const Color(0xFFFF922B),
                      const Color(0xFFFFF2E5),
                      () => _open(context, EventsScreen(session: session)),
                    ),
                    _shortcut(
                      context,
                      'Diễn đàn',
                      Icons.chat_bubble_outline,
                      const Color(0xFFF34D91),
                      const Color(0xFFFBD8E4),
                      () =>
                          _open(context, CustomerForumScreen(session: session)),
                    ),
                    _shortcut(
                      context,
                      'Thông báo',
                      Icons.notifications_none,
                      const Color(0xFF3489FF),
                      const Color(0xFFE9F2FF),
                      () => _notifications(context),
                    ),
                    _shortcut(
                      context,
                      'Khóa học',
                      Icons.school_outlined,
                      AppColors.green,
                      const Color(0xFFE5F7ED),
                      () => _open(context, AcademyScreen(session: session)),
                    ),
                    _shortcut(
                      context,
                      'Ưu đãi',
                      Icons.confirmation_number_outlined,
                      const Color(0xFF9160FF),
                      const Color(0xFFF1EBFF),
                      () =>
                          _open(context, VoucherWalletScreen(session: session)),
                    ),
                  ],
                ),
                DiscoveryHeading(
                  'Sự kiện sắp diễn ra',
                  action: 'Xem tất cả',
                  onPressed: () =>
                      _open(context, EventsScreen(session: session)),
                ),
                if (event != null)
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('explore-event'),
                      onTap: () => _open(
                        context,
                        CustomerEventDetailScreen(
                          session: session,
                          event: event,
                          start: event.start(session.now),
                        ),
                      ),
                      child: SizedBox(
                        height: 150 + _extra(context, 14) * 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/figma/07380.png',
                              fit: BoxFit.cover,
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xE610271B),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              top: 12,
                              child: _tag(
                                'SẮP DIỄN RA',
                                const Color(0xFFFFE665),
                                const Color(0xFF345225),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${bookingDate(event.start(session.now))} · ${event.hour.toString().padLeft(2, '0')}:00',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có sự kiện sắp diễn ra.'),
                  ),
                DiscoveryHeading(
                  'Dành cho bạn',
                  action: 'Lướt thêm',
                  onPressed: () => _open(
                    context,
                    DiscoveryInformationScreen(session: session),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _suggestion(
                        context,
                        'THÔNG BÁO',
                        'Lịch và vé của bạn',
                        'Theo dõi lịch tham gia',
                        Icons.notifications_none,
                        const Color(0xFF3489FF),
                        const Color(0xFFE9F2FF),
                        () => _notifications(context),
                      ),
                      _suggestion(
                        context,
                        'KHÓA HỌC',
                        demoCourses.first.title,
                        '90 phút · ${bookingMoney(DemoCourse.fee)}',
                        Icons.school_outlined,
                        AppColors.green,
                        const Color(0xFFE5F7ED),
                        () => _open(context, AcademyScreen(session: session)),
                      ),
                      _suggestion(
                        context,
                        'ƯU ĐÃI',
                        session.vouchers.firstOrNull?.title ?? 'Ví ưu đãi',
                        'Ưu đãi đặt sân',
                        Icons.local_offer_outlined,
                        const Color(0xFF9160FF),
                        const Color(0xFFF1EBFF),
                        () => _open(
                          context,
                          VoucherWalletScreen(session: session),
                        ),
                      ),
                    ];
                    final large =
                        MediaQuery.textScalerOf(context).scale(12) > 17;
                    final count = large ? 1 : 3;
                    final width =
                        (constraints.maxWidth - (count - 1) * 8) / count;
                    if (!large) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final card in cards)
                          SizedBox(width: width, child: card),
                      ],
                    );
                  },
                ),
                const DiscoveryHeading('Khám phá thêm'),
                _story(
                  context,
                  'CẨM NANG',
                  '5 cách chọn vợt cầu lông phù hợp',
                  '5 phút đọc · Dành cho người mới',
                  Icons.sports_tennis,
                  () => _open(context, const RacketGuideScreen()),
                ),
                const SizedBox(height: 10),
                _story(
                  context,
                  'CỘNG ĐỒNG',
                  'Tìm đồng đội quanh bạn, chơi vui hơn',
                  'Kết nối người chơi cùng sở thích',
                  Icons.groups_outlined,
                  () => _open(context, CustomerForumScreen(session: session)),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _shortcut(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    Color background,
    VoidCallback action,
  ) => Expanded(
    child: InkWell(
      key: Key('explore-shortcut-$label'),
      onTap: action,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _suggestion(
    BuildContext context,
    String label,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Color background,
    VoidCallback action,
  ) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 15),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _story(
    BuildContext context,
    String label,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(8),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 80,
            height: 62,
            child: Image.asset(
              label == 'CẨM NANG'
                  ? 'assets/figma/c0697.png'
                  : 'assets/figma/07380.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 20, color: AppColors.faint),
      ],
    ),
  );
}

double _extra(BuildContext context, double size) =>
    MediaQuery.textScalerOf(context).scale(size) - size;
Widget _tag(String text, Color background, Color foreground) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 9,
      color: foreground,
      fontWeight: FontWeight.w600,
    ),
  ),
);

class CustomerFeaturedScreen extends StatelessWidget {
  const CustomerFeaturedScreen({
    super.key,
    required this.session,
    required this.onMap,
  });
  final DemoSession session;
  final VoidCallback onMap;
  void _catalog(BuildContext context) => _open(
    context,
    VenueBrowseScreen(
      session: session,
      title: 'Sân nổi bật',
      featuredOnly: true,
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final venues = filterVenues(
        venues: session.currentVenues,
        maxPrice: 1000000,
      );
      final posters = venues.where((v) => v.featured).toList();
      return CustomScrollView(
        key: const PageStorageKey('customer-featured-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: DiscoveryHeader(
              title: 'Nổi bật',
              subtitle: 'Những địa điểm được yêu thích nhất',
              icon: Icons.favorite_border,
              tooltip: 'Sân yêu thích',
              onPressed: () => _open(
                context,
                VenueBrowseScreen(
                  session: session,
                  title: 'Sân yêu thích',
                  favoritesOnly: true,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            sliver: SliverList.list(
              children: [
                Material(
                  color: const Color(0xFF00944E),
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('featured-vouchers'),
                    onTap: () =>
                        _open(context, VoucherWalletScreen(session: session)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _tag(
                                  'ƯU ĐÃI ĐỘC QUYỀN',
                                  const Color(0xFFFFE665),
                                  const Color(0xFF345225),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Chơi nhiều, tiết kiệm hơn',
                                  style: TextStyle(
                                    fontSize: 18,
                                    height: 1.2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  session.vouchers.isEmpty
                                      ? 'Khám phá ưu đãi dành cho bạn.'
                                      : 'Ưu đãi đến 30.000đ khi đặt sân.',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFD2F3E1),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Nhận ưu đãi',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.darkGreen,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 12,
                                        color: AppColors.darkGreen,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/figma/07380.png',
                              width:
                                  MediaQuery.textScalerOf(context).scale(12) >
                                      17
                                  ? 64
                                  : 108,
                              height: 116,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                DiscoveryHeading(
                  'Poster sân nổi bật',
                  action: 'Xem tất cả',
                  onPressed: () => _catalog(context),
                ),
                if (posters.isEmpty)
                  const Text('Chưa có sân nổi bật.')
                else
                  SizedBox(
                    height: 170 + _extra(context, 14) * 4,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: posters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final venue = posters[index];
                        final width = MediaQuery.sizeOf(context).width;
                        return SizedBox(
                          width: ((width - 42) / 2).clamp(150, 240),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: Key('featured-poster-${venue.id}'),
                              onTap: () => _open(
                                context,
                                CustomerVenueDetailScreen(
                                  session: session,
                                  venueId: venue.id,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  VenueImage(venue: venue),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Color(0xED122D1C),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 8,
                                    top: 8,
                                    child: _tag(
                                      venue.sport,
                                      AppColors.green,
                                      Colors.white,
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: _tag(
                                      venue.ratingLabel,
                                      Colors.white,
                                      AppColors.ink,
                                    ),
                                  ),
                                  Positioned(
                                    left: 10,
                                    right: 10,
                                    bottom: 10,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          venue.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.2,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        const Text(
                                          'Đặt sân trong 30 giây',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                DiscoveryHeading(
                  'Đề xuất gần bạn',
                  action: 'Bản đồ',
                  onPressed: onMap,
                ),
                if (venues.isEmpty) const Text('Chưa có sân đang hoạt động.'),
                for (final venue in venues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CustomerVenueCard(session: session, venue: venue),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class CustomerVenueCard extends StatelessWidget {
  const CustomerVenueCard({
    super.key,
    required this.session,
    required this.venue,
    this.subtitle,
    this.onDetails,
    this.actionLabel = 'Đặt sân',
  });
  final DemoSession session;
  final VenueSummary venue;
  final String? subtitle;
  final VoidCallback? onDetails;
  final String actionLabel;
  @override
  Widget build(BuildContext context) {
    void details() => _open(
      context,
      CustomerVenueDetailScreen(session: session, venueId: venue.id),
    );
    final large = MediaQuery.textScalerOf(context).scale(12) > 17;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('customer-venue-${venue.id}'),
        onTap: onDetails ?? details,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: VenueImage(
                  venue: venue,
                  width: large ? 64 : 98,
                  height: large ? 80 : 88,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ?? venue.addressLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          venue.priceLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        FilledButton(
                          key: Key('customer-book-${venue.id}'),
                          onPressed:
                              onDetails ??
                              (venue.bookingEnabled
                                  ? () => openCustomerBooking(
                                      context,
                                      session,
                                      venue.id,
                                    )
                                  : details),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            !venue.bookingEnabled && onDetails == null
                                ? 'Xem chi tiết'
                                : actionLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoveryInformationScreen extends StatelessWidget {
  const DiscoveryInformationScreen({
    super.key,
    required this.session,
    this.notifications = false,
  });
  final DemoSession session;
  final bool notifications;
  @override
  Widget build(BuildContext context) => notifications
      ? NotificationInboxScreen(session: session)
      : Scaffold(
          appBar: AppBar(title: const Text('Dành cho bạn')),
          body: ListenableBuilder(
            listenable: session,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.confirmation_number_outlined,
                    color: AppColors.green,
                  ),
                  title: const Text('Vé và lịch tham gia'),
                  subtitle: const Text('Giao lưu và giải đấu của bạn'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, MyEventsScreen(session: session)),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.event_available,
                    color: AppColors.green,
                  ),
                  title: const Text('Lịch đặt sân'),
                  subtitle: const Text('Theo dõi đặt sân và thanh toán'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, BookingsScreen(session: session)),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.school_outlined,
                    color: AppColors.green,
                  ),
                  title: const Text('Khóa học'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, AcademyScreen(session: session)),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.local_offer_outlined,
                    color: AppColors.green,
                  ),
                  title: const Text('Ưu đãi của bạn'),
                  subtitle: Text('${session.vouchers.length} mã ưu đãi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _open(context, VoucherWalletScreen(session: session)),
                ),
              ],
            ),
          ),
        );
}

class RacketGuideScreen extends StatelessWidget {
  const RacketGuideScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cẩm nang')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          '5 cách chọn vợt cầu lông phù hợp',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 20),
        Text(
          '1. Chọn trọng lượng vừa tay\nVợt nhẹ dễ điều khiển khi bạn mới bắt đầu. Hãy thử cầm và vung trước khi chọn.',
        ),
        SizedBox(height: 20),
        Text(
          '2. Kiểm tra điểm cân bằng\nVợt cân bằng giúp làm quen cả tấn công và phòng thủ.',
        ),
        SizedBox(height: 20),
        Text(
          '3. Chọn độ cứng phù hợp\nThân vợt mềm hoặc trung bình thường dễ làm quen hơn thân cứng.',
        ),
        SizedBox(height: 20),
        Text(
          '4. Để ý cán và dây\nCán cần vừa tay, không trơn. Căng dây trong giới hạn của nhà sản xuất.',
        ),
        SizedBox(height: 20),
        Text(
          '5. Thử trước khi mua\nMượn vợt hoặc thử tại cửa hàng để tìm cảm giác thoải mái. Không chọn chỉ theo giá hay vẻ ngoài.',
        ),
      ],
    ),
  );
}
