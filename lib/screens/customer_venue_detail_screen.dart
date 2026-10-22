import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import '../widgets/venue_favorite_button.dart';
import '../widgets/venue_image.dart';
import 'booking_screen.dart';
import 'facility_booking_screen.dart';
import 'reviews_screen.dart';
import 'venue_map_screen.dart';
import 'customer_social_screen.dart';
import 'osm_venue_detail_screen.dart';

void openCustomerBooking(BuildContext context, DemoSession session, String id) {
  final venue = session.currentVenues.where((v) => v.id == id).firstOrNull;
  if (venue == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sân không còn khả dụng.')));
    return;
  }
  if (!venue.bookingEnabled) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OsmVenueDetailScreen(session: session, venue: venue),
      ),
    );
    return;
  }
  showBookingMethod(
    context,
    session,
    id,
    () => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => venue.bookingId == demoVenueId
            ? BookingScheduleScreen(session: session)
            : FacilityBookingScreen(session: session, id: venue.bookingId),
      ),
    ),
  );
}

class CustomerVenueDetailScreen extends StatelessWidget {
  const CustomerVenueDetailScreen({
    super.key,
    required this.session,
    required this.venueId,
  });
  final DemoSession session;
  final String venueId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final venue = session.currentVenues
          .where((v) => v.id == venueId)
          .firstOrNull;
      if (venue == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Chi tiết sân')),
          body: const Center(
            child: Text('Cơ sở chưa công bố hoặc đã tạm ngưng.'),
          ),
        );
      }
      if (venue.isImported && !venue.bookingEnabled) {
        return OsmVenueDetailScreen(session: session, venue: venue);
      }
      final profile = session.publicFacilities
          .where((f) => f.id == venue.bookingId)
          .firstOrNull
          ?.profile;
      final hours = profile == null
          ? '06:00–22:00'
          : '${profile.openHour.toString().padLeft(2, '0')}:00–${profile.closeHour.toString().padLeft(2, '0')}:00';
      final amenities =
          profile?.amenities ?? ['Bãi đỗ xe', 'Nhà vệ sinh', 'Nước uống'];
      final reviews = venueId == demoVenueId
          ? session.publicReviews
          : session.publicReviewsForFacility(venue.bookingId);
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight:
                  230 + (MediaQuery.textScalerOf(context).scale(20) - 20) * 5,
              pinned: true,
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              title: const Text('Chi tiết sân', style: TextStyle(fontSize: 16)),
              actions: [
                VenueFavoriteButton(
                  session: session,
                  venueId: venueId,
                  color: Colors.white,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    VenueImage(venue: venue),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x50000000),
                            Colors.transparent,
                            Color(0xDD003F26),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              venue.sport,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            venue.name,
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
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
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 23,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          venue.address,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Chỉ đường',
                        onPressed: () => openVenueMap(
                          context,
                          venue.address,
                          directions: true,
                        ),
                        icon: const Icon(
                          Icons.near_me_outlined,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    color: AppColors.background,
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 14,
                      children: [
                        _fact(
                          Icons.payments_outlined,
                          'Giá thuê',
                          venue.priceLabel,
                        ),
                        _fact(Icons.schedule, 'Giờ mở cửa', hours),
                        _fact(
                          Icons.sports_tennis,
                          'Mặt sân',
                          profile == null ? 'Trong nhà' : venue.sport,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tiện ích',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in amenities)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFE5F7ED),
                          side: BorderSide.none,
                          avatar: Icon(
                            a.contains('xe')
                                ? Icons.local_parking
                                : a.contains('Nước')
                                ? Icons.local_drink_outlined
                                : a.contains('Wi')
                                ? Icons.wifi
                                : Icons.check_circle_outline,
                            size: 15,
                            color: AppColors.green,
                          ),
                          label: Text(
                            a,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.darkGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFFFFF7E6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 17,
                          color: Color(0xFFF59C28),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Giờ hoạt động $hours',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              openCustomerBooking(context, session, venueId),
                          child: const Text(
                            'Xem lịch',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Đánh giá',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ReviewsScreen(
                              session: session,
                              facilityId: venueId == demoVenueId
                                  ? ''
                                  : venue.bookingId,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Xem tất cả',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFA029),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        venue.ratingLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${reviews.length} đánh giá trong ứng dụng',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final review in reviews.take(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFE5F7ED),
                            child: Text(
                              review.author.substring(0, 1),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.darkGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  review.author,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  review.message,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Chưa có đánh giá trong ứng dụng.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  if (profile?.description.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    Text(
                      profile!.description,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                  if (venue.isImported) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Vị trí nguồn: © OpenStreetMap contributors. Thông tin vận hành do chủ sân cung cấp trong bản demo.',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const Key('customer-detail-book'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => openCustomerBooking(context, session, venueId),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 8,
                children: [
                  const Text(
                    'Đặt sân',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(venue.priceLabel, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _fact(IconData icon, String label, String value) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: AppColors.faint),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.darkGreen,
        ),
      ),
    ],
  );
}
