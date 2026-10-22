import 'package:diacritic/diacritic.dart';

import '../booking/demo_booking.dart';

const demoVenueId = 'cong-thuong';
const missingVenuePriceLabel = 'Liên hệ sân để biết giá';
const venueSports = [
  'Pickleball',
  'Cầu lông',
  'Bóng đá',
  'Bóng rổ',
  'Quần vợt',
  'Đa năng',
  'Bóng bàn',
  'Bóng đá trong nhà',
];

class VenueSummary {
  const VenueSummary({
    required this.id,
    required this.name,
    required this.address,
    required this.sport,
    required this.image,
    required this.price,
    required this.rating,
    this.featured = false,
    this.localPhoto = false,
    this.sports = const [],
    this.latitude,
    this.longitude,
    this.sourceUrl,
    this.extractedAt,
    this.openingHours,
    this.phone,
    this.access,
    this.representativeCenter = false,
    this.bookingEnabled = true,
    this.priceReference,
    this.bookingFacilityId = '',
  });
  final String id;
  final String name;
  final String address;
  final String sport;
  final String image;
  final String bookingFacilityId;
  String get bookingId => bookingFacilityId.isEmpty ? id : bookingFacilityId;
  final int? price;
  final VenuePriceReference? priceReference;
  final double? rating;
  final bool featured;
  final bool localPhoto;
  final List<String> sports;
  final double? latitude, longitude;
  final String? sourceUrl, extractedAt, openingHours, phone, access;
  final bool representativeCenter, bookingEnabled;
  bool get isImported => sourceUrl != null;
  String get addressLabel =>
      address.isEmpty ? 'Chưa có địa chỉ chi tiết' : address;
  String get priceLabel {
    if (price != null && price! > 0) return '${bookingMoney(price!)}/giờ';
    final reference = priceReference;
    if (reference == null) return missingVenuePriceLabel;
    return sports.length > 1
        ? '${reference.sport}: ${reference.label}'
        : reference.label;
  }

  String get ratingLabel => rating?.toStringAsFixed(1) ?? 'Chưa có đánh giá';
  String get mapKey => isImported ? id : address;
  String get mapQuery =>
      latitude != null && longitude != null ? '$latitude,$longitude' : address;
}

class VenuePriceReference {
  const VenuePriceReference({
    required this.min,
    required this.max,
    required this.sourceName,
    required this.sourceUrl,
    required this.checkedAt,
    required this.note,
    required this.sport,
    this.publishedAt,
    this.indicative = false,
  });

  final int min, max;
  final String sourceName, sourceUrl, checkedAt, note;
  final String sport;
  final String? publishedAt;
  final bool indicative;

  String get label {
    final amount = min == max
        ? bookingMoney(min)
        : '${bookingMoney(min)}–${bookingMoney(max)}';
    return '${indicative ? 'Khoảng ' : ''}$amount/giờ (tham khảo)';
  }

  factory VenuePriceReference.fromJson(Map<String, dynamic> row) {
    final min = row['min'];
    final max = row['max'];
    final url = Uri.tryParse(row['sourceUrl'] as String? ?? '');
    final checkedAt = row['checkedAt'] as String? ?? '';
    final sport = row['sport'] as String? ?? '';
    final publishedAt = row['publishedAt'] as String?;
    final kind = row['kind'] as String? ?? 'range';
    bool validDate(String value) {
      final date = DateTime.tryParse(value);
      return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
          date != null &&
          date.toIso8601String().startsWith(value);
    }

    if (min is! int ||
        max is! int ||
        min <= 0 ||
        max < min ||
        row['currency'] != 'VND' ||
        row['unit'] != 'court_hour' ||
        row['status'] != 'third_party_publication' ||
        url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        !validDate(checkedAt) ||
        !venueSports.contains(sport) ||
        !['range', 'indicative'].contains(kind) ||
        (kind == 'indicative' && min != max) ||
        (publishedAt != null &&
            (!validDate(publishedAt) ||
                publishedAt.compareTo(checkedAt) > 0)) ||
        (row['sourceName'] as String? ?? '').trim().isEmpty ||
        (row['note'] as String? ?? '').trim().isEmpty) {
      throw const FormatException('Invalid venue price reference');
    }
    return VenuePriceReference(
      min: min,
      max: max,
      sourceName: row['sourceName'] as String,
      sourceUrl: url.toString(),
      checkedAt: checkedAt,
      note: row['note'] as String,
      sport: sport,
      publishedAt: publishedAt,
      indicative: kind == 'indicative',
    );
  }
}

const demoVenues = [
  VenueSummary(
    id: demoVenueId,
    name: DemoBooking.venue,
    address: DemoBooking.address,
    sport: 'Cầu lông',
    image: 'assets/figma/c0697.png',
    price: DemoBooking.hourlyPrice,
    rating: 4.9,
    featured: true,
  ),
];

enum VenueSort { rating, price, name }

String venueSearchText(String text) =>
    removeDiacritics(text.toLowerCase()).trim();

List<VenueSummary> filterVenues({
  Iterable<VenueSummary> venues = demoVenues,
  String query = '',
  String? sport,
  int maxPrice = 300000,
  double minRating = 0,
  Set<String> favorites = const {},
  bool favoritesOnly = false,
  bool featuredOnly = false,
  VenueSort sort = VenueSort.rating,
}) {
  final words = venueSearchText(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final result = venues.where((venue) {
    final text = venueSearchText(
      '${venue.name} ${venue.address} ${venue.sport} ${venue.sports.join(' ')}',
    );
    return words.every(text.contains) &&
        (sport == null ||
            venue.sport == sport ||
            venue.sports.contains(sport)) &&
        (venue.price == null ? maxPrice >= 300000 : venue.price! <= maxPrice) &&
        (venue.rating == null ? minRating == 0 : venue.rating! >= minRating) &&
        (!favoritesOnly || favorites.contains(venue.id)) &&
        (!featuredOnly || venue.featured);
  }).toList();
  result.sort((a, b) {
    final order = switch (sort) {
      VenueSort.rating =>
        a.rating == null
            ? (b.rating == null ? 0 : 1)
            : b.rating == null
            ? -1
            : b.rating!.compareTo(a.rating!),
      VenueSort.price =>
        a.price == null
            ? (b.price == null ? 0 : 1)
            : b.price == null
            ? -1
            : a.price!.compareTo(b.price!),
      VenueSort.name => venueSearchText(
        a.name,
      ).compareTo(venueSearchText(b.name)),
    };
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return result;
}
