import 'demo_finance.dart';

class DemoVenueClaim {
  const DemoVenueClaim({
    required this.venueId,
    required this.venueName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.owner,
    required this.contact,
    required this.phone,
    required this.explanation,
    required this.proof,
    required this.created,
    required this.updated,
    required this.revision,
    this.state = 'pending',
    this.note = '',
    this.reviewer = '',
  });

  final String venueId, venueName, address, owner, contact, phone;
  final String explanation, proof, state, note, reviewer;
  final double latitude, longitude;
  final DateTime created, updated;
  final int revision;
  String get key => '$owner:$venueId';
  String get label => const {
    'pending': 'Chờ duyệt quyền quản lý',
    'approved': 'Đã duyệt quyền quản lý',
    'rejected': 'Đã từ chối yêu cầu',
    'withdrawn': 'Đã rút yêu cầu',
  }[state]!;

  Map<String, Object?> toJson() => {
    'venueId': venueId,
    'venueName': venueName,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'owner': owner,
    'contact': contact,
    'phone': phone,
    'explanation': explanation,
    'proof': proof,
    'state': state,
    'note': note,
    'reviewer': reviewer,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'revision': revision,
  };

  factory DemoVenueClaim.fromJson(Map<String, dynamic> j) {
    final c = DemoVenueClaim(
      venueId: j['venueId'] as String,
      venueName: j['venueName'] as String,
      address: j['address'] as String,
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      owner: j['owner'] as String,
      contact: j['contact'] as String,
      phone: j['phone'] as String,
      explanation: j['explanation'] as String,
      proof: j['proof'] as String,
      state: j['state'] as String,
      note: j['note'] as String,
      reviewer: j['reviewer'] as String,
      created: DateTime.parse(j['created'] as String).toLocal(),
      updated: DateTime.parse(j['updated'] as String).toLocal(),
      revision: j['revision'] as int,
    );
    bool text(String s, int min, int max) =>
        s == s.trim() && s.length >= min && s.length <= max;
    if (!RegExp(r'^osm-(node|way|relation)-\d+$').hasMatch(c.venueId) ||
        !text(c.venueName, 1, 200) ||
        !text(c.address, 1, 500) ||
        !text(c.owner, 1, 128) ||
        !text(c.contact, 3, 60) ||
        !text(c.explanation, 20, 1000) ||
        !RegExp(r'^0[35789]\d{8}$').hasMatch(c.phone) ||
        !c.latitude.isFinite ||
        !c.longitude.isFinite ||
        c.latitude.abs() > 90 ||
        c.longitude.abs() > 180 ||
        !['pending', 'approved', 'rejected', 'withdrawn'].contains(c.state) ||
        c.revision < (c.state == 'pending' ? 1 : 2) ||
        c.created.year < 2020 ||
        c.updated.year > 2100 ||
        c.updated.isBefore(c.created) ||
        (c.state == 'rejected' ? !text(c.note, 5, 300) : c.note.isNotEmpty) ||
        (['approved', 'rejected'].contains(c.state)
            ? c.reviewer.isEmpty
            : c.reviewer.isNotEmpty)) {
      throw const FormatException('Invalid venue claim');
    }
    decodeProof(c.proof);
    return c;
  }
}
