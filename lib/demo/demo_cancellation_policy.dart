class CancellationPolicy {
  const CancellationPolicy.standard()
    : thresholdHours = 2,
      earlyPercent = 95,
      latePercent = 50,
      minimumHours = 0;
  factory CancellationPolicy({
    required int thresholdHours,
    required int earlyPercent,
    required int latePercent,
    int minimumHours = 0,
  }) {
    if (thresholdHours < 1 ||
        thresholdHours > 168 ||
        minimumHours < 0 ||
        minimumHours > thresholdHours ||
        earlyPercent < 0 ||
        earlyPercent > 100 ||
        latePercent < 0 ||
        latePercent > earlyPercent) {
      throw const FormatException('Invalid cancellation policy');
    }
    return CancellationPolicy._(
      thresholdHours,
      earlyPercent,
      latePercent,
      minimumHours,
    );
  }
  const CancellationPolicy._(
    this.thresholdHours,
    this.earlyPercent,
    this.latePercent,
    this.minimumHours,
  );
  final int thresholdHours, earlyPercent, latePercent, minimumHours;
  bool canRequest(DateTime start, DateTime requested) =>
      start.isAfter(requested) &&
      start.difference(requested) >= Duration(hours: minimumHours);
  int refundPercent(DateTime start, DateTime requested) =>
      start.difference(requested) >= Duration(hours: thresholdHours)
      ? earlyPercent
      : latePercent;
  int refundAmount(int total, DateTime start, DateTime requested) =>
      total * refundPercent(start, requested) ~/ 100;
  String get summary =>
      'Hoàn $earlyPercent% khi yêu cầu trước ít nhất $thresholdHours giờ; '
      'hoàn $latePercent% khi yêu cầu muộn hơn.${minimumHours == 0 ? '' : ' Chỉ nhận yêu cầu trước ít nhất $minimumHours giờ.'}';
  Map<String, Object?> toJson() => {
    'thresholdHours': thresholdHours,
    'earlyPercent': earlyPercent,
    'latePercent': latePercent,
    'minimumHours': minimumHours,
  };
  factory CancellationPolicy.fromJson(Map<String, dynamic> j) =>
      CancellationPolicy(
        thresholdHours: j['thresholdHours'] as int,
        earlyPercent: j['earlyPercent'] as int,
        latePercent: j['latePercent'] as int,
        minimumHours: j['minimumHours'] as int,
      );
  @override
  bool operator ==(Object other) =>
      other is CancellationPolicy &&
      thresholdHours == other.thresholdHours &&
      earlyPercent == other.earlyPercent &&
      latePercent == other.latePercent &&
      minimumHours == other.minimumHours;
  @override
  int get hashCode =>
      Object.hash(thresholdHours, earlyPercent, latePercent, minimumHours);
}
