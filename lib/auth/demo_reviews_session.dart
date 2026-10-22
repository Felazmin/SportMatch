part of 'demo_session.dart';

extension DemoReviewsSession on DemoSession {
  List<DemoVenueReview> publicReviewsForFacility(String id) =>
      List.unmodifiable(
        _reviews
            .where(
              (r) =>
                  !r.hidden &&
                  _bookings.any(
                    (b) => b.id == r.bookingId && b.facilityId == id,
                  ),
            )
            .toList()
          ..sort((a, b) => b.created.compareTo(a.created)),
      );
  double facilityRating(String id) {
    final reviews = publicReviewsForFacility(id);
    return reviews.isEmpty
        ? (id.isEmpty ? demoVenues.first.rating! : 0)
        : reviews.fold<int>(0, (sum, r) => sum + r.stars) / reviews.length;
  }

  List<DemoVenueReview> get allPublicReviews =>
      List.unmodifiable(_reviews.where((r) => !r.hidden));
  String reviewFacilityId(String bookingId) =>
      _bookings.where((b) => b.id == bookingId).firstOrNull?.facilityId ?? '';
  String reviewVenueName(String bookingId) =>
      _bookings.where((b) => b.id == bookingId).firstOrNull?.venueName ??
      DemoBooking.venue;
  List<DemoVenueReview> get publicReviews => List.unmodifiable(
    _reviews
        .where(
          (r) =>
              !r.hidden &&
              _bookings.any((b) => b.id == r.bookingId && b.facilityId.isEmpty),
        )
        .toList()
      ..sort((a, b) => b.created.compareTo(a.created)),
  );
  double get venueRating => publicReviews.isEmpty
      ? demoVenues.first.rating!
      : publicReviews.fold<int>(0, (sum, r) => sum + r.stars) /
            publicReviews.length;
  List<DemoVenueReview> get managedReviews {
    _requireAdmin();
    return List.unmodifiable(_reviews.reversed);
  }

  List<DemoVenueReview> get ownReviews {
    _requireReady();
    if (user == null || role != DemoRole.player) return const [];
    return List.unmodifiable(
      _reviews.where((r) => r.owner == user!.identifier),
    );
  }

  List<DemoBooking> get reviewableBookings {
    _requireReady();
    if (user == null || role != DemoRole.player) return const [];
    return List.unmodifiable(
      _bookings.where(
        (b) =>
            b.owner == user!.identifier &&
            !b.cancelled &&
            !now.isBefore(b.end) &&
            b.attendance == DemoAttendance.completed &&
            _payments[b.id]?.state == DemoPaymentState.approved &&
            !_reviews.any((r) => r.bookingId == b.id),
      ),
    );
  }

  void submitVenueReview(String bookingId, int stars, String message) {
    _requireReady();
    if (!reviewableBookings.any((b) => b.id == bookingId)) {
      throw StateError(
        'Chỉ đánh giá một lần cho lịch của bạn đã hoàn thành và xác nhận thanh toán.',
      );
    }
    final review = DemoVenueReview(
      bookingId: bookingId,
      owner: user!.identifier,
      author: user!.name,
      stars: stars,
      message: message.trim(),
      created: now,
    );
    try {
      DemoVenueReview.fromJson(review.toJson());
    } on FormatException {
      throw StateError('Chọn 1–5 sao, nhập nhận xét 10–1.000 ký tự.');
    }
    _reviews.add(review);
    _recordOperation('Gửi đánh giá $bookingId');
  }

  void moderateVenueReview(
    String bookingId, {
    required bool hidden,
    required String reason,
    required int expectedRevision,
  }) {
    _requireAdmin();
    final index = _reviews.indexWhere((r) => r.bookingId == bookingId);
    if (index < 0) throw StateError('Đánh giá không tồn tại.');
    final old = _reviews[index];
    if (old.revision != expectedRevision || old.hidden == hidden) {
      throw StateError('Đánh giá đã thay đổi. Mở lại hồ sơ.');
    }
    if (reason.trim().length < 5 ||
        reason.trim().length > 300 ||
        now.isBefore(old.created)) {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    _reviews[index] = DemoVenueReview(
      bookingId: old.bookingId,
      owner: old.owner,
      author: old.author,
      stars: old.stars,
      message: old.message,
      created: old.created,
      hidden: hidden,
      reason: reason.trim(),
      moderatedAt: now,
      revision: old.revision + 1,
    );
    _recordOperation(
      '${hidden ? 'Ẩn' : 'Khôi phục'} đánh giá $bookingId: ${reason.trim()}',
    );
  }
}
