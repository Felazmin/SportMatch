class DemoVenueReview {
  const DemoVenueReview({
    required this.bookingId,
    required this.owner,
    required this.author,
    required this.stars,
    required this.message,
    required this.created,
    this.hidden = false,
    this.reason = '',
    this.moderatedAt,
    this.revision = 0,
  });
  final String bookingId, owner, author, message, reason;
  final int stars, revision;
  final DateTime created;
  final bool hidden;
  final DateTime? moderatedAt;
  Map<String, Object?> toJson() => {
    'bookingId': bookingId,
    'owner': owner,
    'author': author,
    'stars': stars,
    'message': message,
    'created': created.toIso8601String(),
    'hidden': hidden,
    'reason': reason,
    'moderatedAt': moderatedAt?.toIso8601String(),
    'revision': revision,
  };
  factory DemoVenueReview.fromJson(Map<String, dynamic> j) {
    final r = DemoVenueReview(
      bookingId: j['bookingId'] as String,
      owner: j['owner'] as String,
      author: j['author'] as String,
      stars: j['stars'] as int,
      message: j['message'] as String,
      created: DateTime.parse(j['created'] as String).toLocal(),
      hidden: j['hidden'] as bool,
      reason: j['reason'] as String,
      moderatedAt: j['moderatedAt'] == null
          ? null
          : DateTime.parse(j['moderatedAt'] as String).toLocal(),
      revision: j['revision'] as int,
    );
    if (!RegExp(r'^NVH\d{4,}$').hasMatch(r.bookingId) ||
        r.author.trim().isEmpty ||
        r.author.length > 60 ||
        r.stars < 1 ||
        r.stars > 5 ||
        r.message.trim().length < 10 ||
        r.message.length > 1000 ||
        r.revision < 0 ||
        (r.revision == 0 &&
            (r.hidden || r.reason.isNotEmpty || r.moderatedAt != null)) ||
        (r.revision > 0 &&
            (r.reason.trim().length < 5 ||
                r.reason.length > 300 ||
                r.moderatedAt == null ||
                r.moderatedAt!.isBefore(r.created)))) {
      throw const FormatException('Invalid venue review');
    }
    return r;
  }
}
