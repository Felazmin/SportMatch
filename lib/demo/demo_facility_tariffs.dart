import 'dart:convert';

import '../booking/demo_booking.dart';

class FacilityTariffBand {
  const FacilityTariffBand({
    required this.court,
    required this.weekend,
    required this.fromHour,
    required this.toHour,
    required this.rate,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.surcharge = 0,
  });
  final int court, fromHour, toHour, rate, surcharge;
  final bool weekend;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  int get quotedRate => rate + surcharge;
  bool applies(int c, DateTime time) =>
      c == court &&
      (time.weekday >= 6) == weekend &&
      time.hour >= fromHour &&
      time.hour < toHour &&
      !bookingDay(time).isBefore(effectiveFrom) &&
      (effectiveUntil == null || !bookingDay(time).isAfter(effectiveUntil!));
  Map<String, Object?> toJson() => {
    'court': court,
    'weekend': weekend,
    'fromHour': fromHour,
    'toHour': toHour,
    'rate': rate,
    'surcharge': surcharge,
    'effectiveFrom': effectiveFrom.toIso8601String(),
    'effectiveUntil': effectiveUntil?.toIso8601String(),
  };
  factory FacilityTariffBand.fromJson(Map<String, dynamic> j) {
    final b = FacilityTariffBand(
      court: j['court'] as int,
      weekend: j['weekend'] as bool,
      fromHour: j['fromHour'] as int,
      toHour: j['toHour'] as int,
      rate: j['rate'] as int,
      surcharge: j['surcharge'] as int,
      effectiveFrom: DateTime.parse(j['effectiveFrom'] as String),
      effectiveUntil: j['effectiveUntil'] == null
          ? null
          : DateTime.parse(j['effectiveUntil'] as String),
    );
    if (b.court < 1 ||
        b.court > 20 ||
        b.fromHour < 0 ||
        b.toHour > 24 ||
        b.fromHour >= b.toHour ||
        b.rate < 10000 ||
        b.rate > 1000000 ||
        b.rate % 1000 != 0 ||
        b.surcharge < 0 ||
        b.surcharge > 100000 ||
        b.surcharge % 1000 != 0 ||
        b.quotedRate > 1000000 ||
        b.effectiveFrom.isUtc ||
        b.effectiveFrom != bookingDay(b.effectiveFrom) ||
        (b.effectiveUntil != null &&
            (b.effectiveUntil!.isUtc ||
                b.effectiveUntil != bookingDay(b.effectiveUntil!) ||
                b.effectiveUntil!.isBefore(b.effectiveFrom)))) {
      throw const FormatException('Invalid facility tariff');
    }
    return b;
  }
}

class FacilityTariffPlan {
  FacilityTariffPlan({
    required this.facilityId,
    this.revision = 0,
    this.facilityRevision = 0,
    this.state = 'none',
    this.note = '',
    List<FacilityTariffBand> published = const [],
    List<FacilityTariffBand>? draft,
  }) : published = List.unmodifiable(published),
       draft = draft == null ? null : List.unmodifiable(draft);
  final String facilityId, state, note;
  final int revision, facilityRevision;
  final List<FacilityTariffBand> published;
  final List<FacilityTariffBand>? draft;
  Map<String, Object?> toJson() => {
    'facilityId': facilityId,
    'revision': revision,
    'facilityRevision': facilityRevision,
    'state': state,
    'note': note,
    'published': published.map((b) => b.toJson()).toList(),
    'draft': draft?.map((b) => b.toJson()).toList(),
  };
  static void validateBands(List<FacilityTariffBand> bands) {
    if (bands.length > 36) {
      throw const FormatException('Too many facility tariffs');
    }
    for (var i = 0; i < bands.length; i++) {
      final a = FacilityTariffBand.fromJson(bands[i].toJson());
      for (final b in bands.take(i)) {
        if (a.court == b.court &&
            a.weekend == b.weekend &&
            a.fromHour < b.toHour &&
            b.fromHour < a.toHour &&
            (a.effectiveUntil == null ||
                !a.effectiveUntil!.isBefore(b.effectiveFrom)) &&
            (b.effectiveUntil == null ||
                !b.effectiveUntil!.isBefore(a.effectiveFrom))) {
          throw const FormatException('Overlapping facility tariffs');
        }
      }
    }
  }

  factory FacilityTariffPlan.fromJson(Map<String, dynamic> j) {
    List<FacilityTariffBand> bands(dynamic value) => (value as List)
        .map((b) => FacilityTariffBand.fromJson(b as Map<String, dynamic>))
        .toList();
    final p = FacilityTariffPlan(
      facilityId: j['facilityId'] as String,
      revision: j['revision'] as int,
      facilityRevision: j['facilityRevision'] as int,
      state: j['state'] as String,
      note: j['note'] as String,
      published: bands(j['published']),
      draft: j['draft'] == null ? null : bands(j['draft']),
    );
    if (!RegExp(r'^CS\d{4,}$').hasMatch(p.facilityId) ||
        p.revision < 0 ||
        p.facilityRevision < 0 ||
        !['none', 'pending', 'approved', 'rejected'].contains(p.state) ||
        p.note.length > 300 ||
        (p.state == 'none' &&
            (p.revision != 0 ||
                p.draft != null ||
                p.published.isNotEmpty ||
                p.note.isNotEmpty)) ||
        (p.state != 'none' &&
            (p.revision < 1 || p.facilityRevision < 1 || p.draft == null)) ||
        (p.state == 'rejected' && p.note.trim().length < 5) ||
        (p.state != 'rejected' && p.note.isNotEmpty)) {
      throw const FormatException('Invalid facility tariff plan');
    }
    validateBands(p.published);
    if (p.draft != null) validateBands(p.draft!);
    if (p.state == 'approved' &&
        jsonEncode(p.published.map((b) => b.toJson()).toList()) !=
            jsonEncode(p.draft!.map((b) => b.toJson()).toList())) {
      throw const FormatException('Invalid approved facility tariff plan');
    }
    return p;
  }
}
