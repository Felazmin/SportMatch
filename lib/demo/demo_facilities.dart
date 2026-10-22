import 'dart:convert';
import 'dart:typed_data';

import 'demo_finance.dart';
import 'demo_cancellation_policy.dart';
import 'demo_payout.dart';

const facilityPdfLimit = 400 * 1024;
bool isFacilityPdf(String encoded) => encoded.startsWith('pdf:');
Uint8List decodeFacilityDocument(String encoded) {
  if (!isFacilityPdf(encoded)) return decodeProof(encoded);
  if (encoded.length > 4 + ((facilityPdfLimit + 2) ~/ 3) * 4) {
    throw const FormatException('PDF too large');
  }
  final bytes = base64Decode(encoded.substring(4));
  if (bytes.length > facilityPdfLimit ||
      bytes.length < 20 ||
      ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-' ||
      !latin1
          .decode(bytes.sublist(bytes.length > 1024 ? bytes.length - 1024 : 0))
          .contains('%%EOF')) {
    throw const FormatException('Invalid PDF attachment');
  }
  return bytes;
}

String encodeFacilityPdf(Uint8List bytes) {
  if (bytes.length > facilityPdfLimit) {
    throw const FormatException('PDF too large');
  }
  final encoded = 'pdf:${base64Encode(bytes)}';
  decodeFacilityDocument(encoded);
  return encoded;
}

const facilitySports = [
  'Cầu lông',
  'Pickleball',
  'Bóng đá',
  'Bóng rổ',
  'Quần vợt',
  'Đa năng',
  'Bóng bàn',
  'Bóng đá trong nhà',
];
const facilityAmenities = [
  'Bãi xe',
  'Nước uống',
  'Nhà vệ sinh',
  'Phòng thay đồ',
  'Wi-Fi',
];

// Partial form input is never used as a published facility contract.
class FacilityFormDraft {
  FacilityFormDraft({
    required Map<String, String> fields,
    required this.sport,
    required this.openHour,
    required this.closeHour,
    this.facilityId = '',
    this.revision = 0,
    this.courtTypeId = '',
    this.photo = '',
    this.legalProof = '',
    Set<String> amenities = const {},
  }) : fields = Map.unmodifiable(fields),
       amenities = Set.unmodifiable(amenities) {
    const limits = {
      'name': 100,
      'address': 200,
      'city': 60,
      'district': 60,
      'phone': 30,
      'ownerName': 60,
      'courtCount': 2,
      'baseRate': 7,
      'description': 1000,
      'cancelPolicy': 1000,
    };
    if (fields.length != limits.length ||
        limits.entries.any(
          (e) => !fields.containsKey(e.key) || fields[e.key]!.length > e.value,
        ) ||
        !facilitySports.contains(sport) ||
        openHour < 0 ||
        openHour > 23 ||
        closeHour < 1 ||
        closeHour > 24 ||
        revision < 0 ||
        (facilityId.isEmpty
            ? revision != 0
            : !RegExp(r'^CS\d{4,}$').hasMatch(facilityId) || revision < 1) ||
        (courtTypeId.isNotEmpty &&
            !RegExp(r'^LS\d{4,}$').hasMatch(courtTypeId)) ||
        amenities.any((a) => !facilityAmenities.contains(a))) {
      throw const FormatException('Invalid partial facility form');
    }
    if (photo.isNotEmpty) decodeProof(photo);
    if (legalProof.isNotEmpty) decodeFacilityDocument(legalProof);
  }
  final Map<String, String> fields;
  final String facilityId, sport, courtTypeId, photo, legalProof;
  final int revision, openHour, closeHour;
  final Set<String> amenities;
  Map<String, Object?> toJson() => {
    'fields': fields,
    'facilityId': facilityId,
    'revision': revision,
    'sport': sport,
    'courtTypeId': courtTypeId,
    'photo': photo,
    'legalProof': legalProof,
    'openHour': openHour,
    'closeHour': closeHour,
    'amenities': amenities.toList(),
  };
  factory FacilityFormDraft.fromJson(Map<String, dynamic> j) =>
      FacilityFormDraft(
        fields: Map<String, String>.from(j['fields'] as Map),
        facilityId: j['facilityId'] as String,
        revision: j['revision'] as int,
        sport: j['sport'] as String,
        courtTypeId: j['courtTypeId'] as String,
        photo: j['photo'] as String,
        legalProof: j['legalProof'] as String,
        openHour: j['openHour'] as int,
        closeHour: j['closeHour'] as int,
        amenities: (j['amenities'] as List).cast<String>().toSet(),
      );
}

class FacilityProfile {
  FacilityProfile({
    required this.name,
    required this.sport,
    required this.address,
    required this.city,
    required this.district,
    required this.phone,
    required this.ownerName,
    required this.courtCount,
    required this.openHour,
    required this.closeHour,
    required this.baseRate,
    this.description = '',
    this.cancelPolicy = '',
    this.cancellationPolicy = const CancellationPolicy.standard(),
    this.photo = '',
    this.legalProof = '',
    this.courtTypeId = '',
    Set<String> amenities = const {},
    this.receivingAccount,
  }) : amenities = Set.unmodifiable(amenities) {
    if (name.trim().length < 3 ||
        name.length > 100 ||
        !facilitySports.contains(sport) ||
        (courtTypeId.isNotEmpty &&
            !RegExp(r'^LS\d{4,}$').hasMatch(courtTypeId)) ||
        address.trim().length < 5 ||
        address.length > 200 ||
        city.trim().length < 2 ||
        city.length > 60 ||
        district.trim().length < 2 ||
        district.length > 60 ||
        ownerName.trim().length < 2 ||
        ownerName.length > 60 ||
        !RegExp(r'^0[35789]\d{8}$').hasMatch(phone) ||
        courtCount < 1 ||
        courtCount > 20 ||
        openHour < 0 ||
        openHour > 23 ||
        closeHour > 24 ||
        closeHour <= openHour ||
        baseRate < 10000 ||
        baseRate > 1000000 ||
        baseRate % 1000 != 0 ||
        description.length > 1000 ||
        cancelPolicy.length > 1000 ||
        amenities.any((a) => !facilityAmenities.contains(a))) {
      throw const FormatException('Invalid facility profile');
    }
    if (photo.isNotEmpty) decodeProof(photo);
    if (legalProof.isNotEmpty) decodeFacilityDocument(legalProof);
    if (receivingAccount != null) {
      DemoBankAccount.fromJson(receivingAccount!.toJson());
    }
  }
  final String name, sport, address, city, district, phone, ownerName;
  final String description, cancelPolicy, photo, legalProof;
  final String courtTypeId;
  final DemoBankAccount? receivingAccount;
  final CancellationPolicy cancellationPolicy;
  final int courtCount, openHour, closeHour, baseRate;
  final Set<String> amenities;
  FacilityProfile get publicView => FacilityProfile.fromJson({
    ...toJson(),
    'legalProof': '',
    'ownerName': 'Chủ cơ sở',
  });
  Map<String, Object?> toJson() => {
    'name': name,
    'sport': sport,
    'courtTypeId': courtTypeId,
    'address': address,
    'city': city,
    'district': district,
    'phone': phone,
    'ownerName': ownerName,
    'courtCount': courtCount,
    'openHour': openHour,
    'closeHour': closeHour,
    'baseRate': baseRate,
    'description': description,
    'cancelPolicy': cancelPolicy,
    'cancellationPolicy': cancellationPolicy.toJson(),
    'photo': photo,
    'legalProof': legalProof,
    'amenities': amenities.toList(),
    'receivingAccount': receivingAccount?.toJson(),
  };
  factory FacilityProfile.fromJson(Map<String, dynamic> j) => FacilityProfile(
    name: j['name'] as String,
    sport: j['sport'] as String,
    courtTypeId: (j['courtTypeId'] ?? '') as String,
    address: j['address'] as String,
    city: j['city'] as String,
    district: j['district'] as String,
    phone: j['phone'] as String,
    ownerName: j['ownerName'] as String,
    courtCount: j['courtCount'] as int,
    openHour: j['openHour'] as int,
    closeHour: j['closeHour'] as int,
    baseRate: j['baseRate'] as int,
    description: j['description'] as String,
    cancelPolicy: j['cancelPolicy'] as String,
    cancellationPolicy: j['cancellationPolicy'] == null
        ? const CancellationPolicy.standard()
        : CancellationPolicy.fromJson(
            j['cancellationPolicy'] as Map<String, dynamic>,
          ),
    photo: j['photo'] as String,
    legalProof: j['legalProof'] as String,
    amenities: (j['amenities'] as List).cast<String>().toSet(),
    receivingAccount: j['receivingAccount'] == null
        ? null
        : DemoBankAccount.fromJson(
            j['receivingAccount'] as Map<String, dynamic>,
          ),
  );
}

class DemoFacility {
  DemoFacility({
    required this.id,
    required this.owner,
    required this.draft,
    required this.updated,
    this.published,
    this.state = 'draft',
    this.note = '',
    this.suspended = false,
    this.revision = 1,
    this.reviewDecision = '',
    this.sourceVenueId = '',
  });
  final String id, owner;
  final String sourceVenueId;
  FacilityProfile draft;
  FacilityProfile? published;
  DateTime updated;
  String state, note;
  String reviewDecision;
  bool suspended;
  int revision;
  String get label => suspended
      ? 'Tạm ngưng'
      : switch (state) {
          'draft' => 'Bản nháp',
          'pending' => 'Chờ duyệt',
          'rejected' =>
            reviewDecision == 'rejected' ? 'Bị từ chối' : 'Cần bổ sung',
          'approved' => 'Đã duyệt',
          _ => 'Không hợp lệ',
        };
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'draft': draft.toJson(),
    'published': published?.toJson(),
    'state': state,
    'note': note,
    'suspended': suspended,
    'updated': updated.toIso8601String(),
    'revision': revision,
    'reviewDecision': reviewDecision,
    'sourceVenueId': sourceVenueId,
  };
  factory DemoFacility.fromJson(Map<String, dynamic> j) {
    final f = DemoFacility(
      id: j['id'] as String,
      owner: j['owner'] as String,
      draft: FacilityProfile.fromJson(j['draft'] as Map<String, dynamic>),
      published: j['published'] == null
          ? null
          : FacilityProfile.fromJson(j['published'] as Map<String, dynamic>),
      state: j['state'] as String,
      note: j['note'] as String,
      suspended: j['suspended'] as bool,
      updated: DateTime.parse(j['updated'] as String),
      revision: j['revision'] as int,
      reviewDecision: (j['reviewDecision'] ?? '') as String,
      sourceVenueId: (j['sourceVenueId'] ?? '') as String,
    );
    if (!RegExp(r'^CS\d{4,}$').hasMatch(f.id) ||
        (f.sourceVenueId.isNotEmpty &&
            !RegExp(r'^osm-(node|way|relation)-\d+$')
                .hasMatch(f.sourceVenueId)) ||
        f.owner != '__owner__' ||
        !['draft', 'pending', 'rejected', 'approved'].contains(f.state) ||
        f.note.length > 300 ||
        ![
          '',
          'approved',
          'supplement',
          'rejected',
        ].contains(f.reviewDecision) ||
        (f.reviewDecision.isNotEmpty &&
            !(f.state == 'approved' && f.reviewDecision == 'approved' ||
                f.state == 'rejected' &&
                    ['supplement', 'rejected'].contains(f.reviewDecision))) ||
        (f.state == 'rejected' && f.note.trim().length < 5) ||
        (f.state == 'approved' &&
            (f.published == null || !_sameProfile(f.draft, f.published!))) ||
        (f.suspended && f.published == null) ||
        f.revision < 1 ||
        (f.published != null &&
            (f.published!.photo.isEmpty || f.published!.legalProof.isEmpty))) {
      throw const FormatException('Invalid facility state');
    }
    return f;
  }
}

bool _sameProfile(FacilityProfile a, FacilityProfile b) {
  final ja = a.toJson(), jb = b.toJson();
  return ja.keys.every(
    (k) => k == 'amenities'
        ? a.amenities.length == b.amenities.length &&
              a.amenities.containsAll(b.amenities)
        : k == 'receivingAccount'
        ? jsonEncode(ja[k]) == jsonEncode(jb[k])
        : k == 'cancellationPolicy'
        ? a.cancellationPolicy == b.cancellationPolicy
        : ja[k] == jb[k],
  );
}
