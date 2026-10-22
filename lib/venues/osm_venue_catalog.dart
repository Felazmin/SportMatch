import 'dart:convert';

import 'package:flutter/services.dart';

import 'venue_catalog.dart';

Future<List<VenueSummary>> loadOsmVenues() async => parseOsmVenues(
  await rootBundle.loadString('assets/data/hcm_venues.json'),
  pricingSource: await rootBundle.loadString(
    'assets/data/venue_price_references.json',
  ),
);

List<VenueSummary> parseOsmVenues(String source, {String? pricingSource}) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  final prices = <String, VenuePriceReference>{};
  if (pricingSource != null) {
    final pricing = jsonDecode(pricingSource) as Map<String, dynamic>;
    for (final entry in pricing.entries) {
      if (!(data['venues'] as List).any((v) => v['id'] == entry.key)) {
        throw const FormatException('Price reference has no matching venue');
      }
      prices[entry.key] = VenuePriceReference.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
  }
  final ids = <String>{};
  return List.unmodifiable(
    (data['venues'] as List).map((value) {
      final row = Map<String, dynamic>.from(value as Map);
      final id = row['id'] as String;
      final name = (row['name'] as String).trim();
      final sports = (row['sports'] as List).cast<String>();
      final lat = (row['latitude'] as num).toDouble();
      final lon = (row['longitude'] as num).toDouble();
      final sourceUrl = row['sourceUrl'] as String;
      if (!RegExp(r'^osm-(node|way|relation)-\d+$').hasMatch(id) ||
          !ids.add(id) ||
          name.isEmpty ||
          sports.isEmpty ||
          sports.any((s) => !venueSports.contains(s)) ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180 ||
          sourceUrl != 'https://www.openstreetmap.org/${row['sourceId']}') {
        throw const FormatException('Invalid OSM venue');
      }
      if (prices[id] != null && !sports.contains(prices[id]!.sport)) {
        throw const FormatException(
          'Price reference belongs to a different sport',
        );
      }
      return VenueSummary(
        id: id,
        name: name,
        address: row['address'] as String? ?? '',
        sport: sports.first,
        sports: List.unmodifiable(sports),
        image: '',
        price: null,
        priceReference: prices[id],
        rating: null,
        latitude: lat,
        longitude: lon,
        sourceUrl: sourceUrl,
        extractedAt: row['extractedAt'] as String?,
        openingHours: row['openingHours'] as String?,
        phone: row['phone'] as String?,
        access: row['access'] as String?,
        representativeCenter: row['coordinateKind'] == 'representative_center',
        bookingEnabled: false,
      );
    }),
  );
}
