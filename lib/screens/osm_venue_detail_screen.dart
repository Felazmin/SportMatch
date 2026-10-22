import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/demo_session.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import '../widgets/venue_favorite_button.dart';
import '../widgets/venue_image.dart';
import 'venue_map_screen.dart';
import 'venue_claims_screen.dart';

class OsmVenueDetailScreen extends StatelessWidget {
  const OsmVenueDetailScreen({
    super.key,
    required this.session,
    required this.venue,
  });
  final DemoSession session;
  final VenueSummary venue;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chi tiết địa điểm'),
      actions: [VenueFavoriteButton(session: session, venueId: venue.id)],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: VenueImage(venue: venue),
        ),
        const SizedBox(height: 16),
        Text(
          venue.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          venue.sports.join(' • '),
          style: const TextStyle(color: AppColors.darkGreen),
        ),
        const SizedBox(height: 16),
        _info(Icons.location_on_outlined, 'Địa chỉ', venue.addressLabel),
        _info(
          Icons.my_location,
          'Tọa độ',
          '${venue.latitude}, ${venue.longitude}',
        ),
        if (venue.representativeCenter)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Ghim đại diện cho khuôn viên sân; có thể khác vị trí cổng vào.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        _info(Icons.payments_outlined, 'Giá thuê', venue.priceLabel),
        if (venue.priceReference case final reference?) ...[
          _info(Icons.sports, 'Môn áp dụng giá', reference.sport),
          _info(Icons.info_outline, 'Điều kiện giá', reference.note),
          if (reference.publishedAt != null)
            _info(
              Icons.article_outlined,
              'Ngày đăng nguồn giá',
              reference.publishedAt!,
            ),
          _info(
            Icons.fact_check_outlined,
            'Nguồn giá: ${reference.sourceName}',
            'Ngày đối chiếu: ${reference.checkedAt}. Chưa được chủ sân xác nhận; '
                'không dùng mức tham khảo này để thanh toán.',
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Xem nguồn giá'),
            onPressed: () => _openUrl(context, reference.sourceUrl),
          ),
        ],
        _info(
          Icons.schedule,
          'Giờ mở cửa',
          venue.openingHours ?? 'Chưa có thông tin',
        ),
        if (venue.phone != null)
          _info(Icons.phone_outlined, 'Liên hệ công khai', venue.phone!),
        if (venue.access != null)
          _info(Icons.info_outline, 'Quyền tiếp cận theo OSM', venue.access!),
        const Divider(height: 32),
        const Text(
          'Địa điểm chưa nhận đặt sân trên SportMatch.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        if (session.user != null && session.role == DemoRole.owner)
          OutlinedButton.icon(
            key: const Key('osm-claim-venue'),
            icon: const Icon(Icons.assignment_ind_outlined),
            label: const Text('Yêu cầu quản lý sân'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    VenueClaimScreen(session: session, venueId: venue.id),
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Nguồn: © OpenStreetMap contributors. Thông tin có thể chưa đầy đủ hoặc chưa được cập nhật.',
        ),
        if (venue.extractedAt != null) ...[
          const SizedBox(height: 8),
          Text('Ngày trích xuất: ${venue.extractedAt!.split('T').first}'),
        ],
        TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Xem địa điểm trên OpenStreetMap'),
          onPressed: () => _openSource(context),
        ),
        TextButton(
          onPressed: () =>
              _openUrl(context, 'https://www.openstreetmap.org/copyright'),
          child: const Text('Bản quyền dữ liệu OpenStreetMap'),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: const Key('osm-directions'),
          icon: const Icon(Icons.near_me_outlined),
          label: const Text('Chỉ đường'),
          onPressed: () =>
              openVenueMap(context, venue.mapQuery, directions: true),
        ),
      ),
    ),
  );

  Future<void> _openSource(BuildContext context) =>
      _openUrl(context, venue.sourceUrl!);
  Future<void> _openUrl(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      /* Show a retryable error below. */
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được liên kết. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Widget _info(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    ),
  );
}
