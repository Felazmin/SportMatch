import '../demo/demo_finance.dart' show DemoAttendance;
import '../demo/demo_cancellation_policy.dart';
import '../demo/demo_payout.dart';

class DemoBooking {
  DemoBooking({
    required this.id,
    required this.owner,
    required this.court,
    required this.start,
    required this.hours,
    required this.contact,
    required this.phone,
    this.voucherCode,
    this.discount = 0,
    this.rate = hourlyPrice,
    this.facilityId = '',
    this.venueName = venue,
    this.venueAddress = address,
    this.sport = 'Cầu lông',
    this.venueCourtCount = 3,
    this.venueOpenHour = 6,
    this.venueCloseHour = 22,
    this.cancellationPolicy = const CancellationPolicy.standard(),
    this.receivingAccount,
    List<int>? hourlyRates,
  }) : hourlyRates = hourlyRates == null
           ? null
           : List.unmodifiable(hourlyRates);
  final String id;
  final String owner;
  final String facilityId, venueName, venueAddress, sport;
  final CancellationPolicy cancellationPolicy;
  final DemoBankAccount? receivingAccount;
  final int venueCourtCount, venueOpenHour, venueCloseHour;
  int court;
  DateTime start;
  int revision = 0;
  final int hours;
  final String contact;
  final String phone;
  final String? voucherCode;
  final int discount;
  final int rate;
  final List<int>? hourlyRates;
  bool cancelled = false;
  DemoAttendance attendance = DemoAttendance.pending;
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'facilityId': facilityId,
    'venueName': venueName,
    'venueAddress': venueAddress,
    'sport': sport,
    'venueCourtCount': venueCourtCount,
    'venueOpenHour': venueOpenHour,
    'venueCloseHour': venueCloseHour,
    'court': court,
    'start': start.toIso8601String(),
    'hours': hours,
    'contact': contact,
    'phone': phone,
    'cancelled': cancelled,
    'voucherCode': voucherCode,
    'discount': discount,
    'rate': rate,
    'hourlyRates': hourlyRates,
    'attendance': attendance.name,
    'revision': revision,
    'cancellationPolicy': cancellationPolicy.toJson(),
    'receivingAccount': receivingAccount?.toJson(),
  };

  factory DemoBooking.fromJson(Map<String, dynamic> json) {
    final booking =
        DemoBooking(
            id: json['id'] as String,
            owner: json['owner'] as String,
            facilityId: (json['facilityId'] ?? '') as String,
            venueName: (json['venueName'] ?? venue) as String,
            venueAddress: (json['venueAddress'] ?? address) as String,
            sport: (json['sport'] ?? 'Cầu lông') as String,
            receivingAccount: json['receivingAccount'] == null
                ? null
                : DemoBankAccount.fromJson(
                    json['receivingAccount'] as Map<String, dynamic>,
                  ),
            cancellationPolicy: json['cancellationPolicy'] == null
                ? const CancellationPolicy.standard()
                : CancellationPolicy.fromJson(
                    json['cancellationPolicy'] as Map<String, dynamic>,
                  ),
            venueCourtCount: (json['venueCourtCount'] ?? 3) as int,
            venueOpenHour: (json['venueOpenHour'] ?? 6) as int,
            venueCloseHour: (json['venueCloseHour'] ?? 22) as int,
            court: json['court'] as int,
            start: DateTime.parse(json['start'] as String).toLocal(),
            hours: json['hours'] as int,
            contact: json['contact'] as String,
            phone: json['phone'] as String,
            voucherCode: json['voucherCode'] as String?,
            discount: (json['discount'] ?? 0) as int,
            rate: (json['rate'] ?? hourlyPrice) as int,
            hourlyRates: (json['hourlyRates'] as List?)?.cast<int>(),
          )
          ..cancelled = json['cancelled'] as bool
          ..attendance = DemoAttendance.values.byName(
            (json['attendance'] ?? 'pending') as String,
          )
          ..revision = (json['revision'] ?? 0) as int;
    if ((booking.hourlyRates != null &&
            (booking.hourlyRates!.length != booking.hours ||
                booking.hourlyRates!.first != booking.rate ||
                booking.hourlyRates!.any(
                  (r) => r < 10000 || r > 1000000 || r % 1000 != 0,
                ))) ||
        booking.revision < 0 ||
        (booking.cancelled && booking.attendance != DemoAttendance.pending) ||
        booking.rate < 10000 ||
        booking.rate > 1000000 ||
        booking.rate % 1000 != 0 ||
        booking.discount < 0 ||
        booking.discount > booking.subtotal ||
        (booking.voucherCode == null && booking.discount != 0) ||
        !RegExp(r'^NVH\d{4,}$').hasMatch(booking.id) ||
        booking.court < 1 ||
        booking.court > booking.venueCourtCount ||
        booking.venueCourtCount < 1 ||
        booking.venueCourtCount > 20 ||
        booking.venueOpenHour < 0 ||
        booking.venueCloseHour > 24 ||
        booking.venueCloseHour <= booking.venueOpenHour ||
        booking.venueName.trim().length < 3 ||
        booking.venueName.length > 100 ||
        booking.venueAddress.trim().length < 5 ||
        booking.venueAddress.length > 400 ||
        booking.sport.trim().isEmpty ||
        booking.sport.length > 60 ||
        (booking.facilityId.isNotEmpty &&
            !RegExp(r'^CS\d{4,}$').hasMatch(booking.facilityId)) ||
        (booking.facilityId.isEmpty &&
            (booking.venueCourtCount != 3 ||
                booking.venueOpenHour != 6 ||
                booking.venueCloseHour != 22 ||
                booking.venueName != venue ||
                booking.venueAddress != address ||
                booking.sport != 'Cầu lông')) ||
        booking.hours < 1 ||
        booking.hours > 3 ||
        booking.start.hour < booking.venueOpenHour ||
        booking.start.hour + booking.hours > booking.venueCloseHour ||
        booking.start.minute != 0 ||
        booking.start.second != 0 ||
        booking.start.millisecond != 0 ||
        booking.start.microsecond != 0 ||
        booking.contact.trim().isEmpty ||
        !RegExp(r'^0[35789]\d{8}$').hasMatch(booking.phone)) {
      throw const FormatException('Invalid booking');
    }
    return booking;
  }
  DateTime get end => start.add(Duration(hours: hours));
  int get subtotal =>
      hourlyRates?.fold<int>(0, (a, b) => a + b) ?? hours * rate;
  int get total => subtotal - discount;
  static const hourlyPrice = 120000;
  static const venue = 'Sân Cầu Lông Đại Học Công Thương';
  static const address = '73/1 Nguyễn Đỗ Cung, Tây Thạnh, TP.HCM';
}

DateTime bookingDay(DateTime date) => DateTime(date.year, date.month, date.day);
String bookingDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String bookingTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:00';
String bookingMoney(int value) {
  final digits = value.toString();
  return '${digits.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';
}
