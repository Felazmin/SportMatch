import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../demo/demo_reviews.dart';
import '../venues/venue_catalog.dart';
import 'finance_screen.dart';
import 'workflow_screen.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({
    super.key,
    required this.session,
    this.admin = false,
    this.facilityId = '',
  });
  final DemoSession session;
  final bool admin;
  final String facilityId;
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  String _filter = 'all', _query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (widget.admin && (s.user == null || s.role != DemoRole.admin)) {
        return Scaffold(
          appBar: financeBar('Đánh giá'),
          body: const Center(
            child: Text('Chỉ Admin được kiểm duyệt đánh giá.'),
          ),
        );
      }
      final public = s.publicReviewsForFacility(widget.facilityId);
      final reviews = widget.admin ? s.managedReviews : public;
      final name = widget.facilityId.isEmpty
          ? DemoBooking.venue
          : s.publicFacilities
                .where((f) => f.id == widget.facilityId)
                .firstOrNull
                ?.profile
                .name;
      final items = reviews
          .where(
            (r) =>
                (_filter == 'all' ||
                    (_filter == 'hidden' ? r.hidden : !r.hidden)) &&
                venueSearchText('${r.author} ${r.message}')
                    .contains(venueSearchText(_query)),
          )
          .toList();
      return Scaffold(
        appBar: financeBar(
          widget.admin ? 'Kiểm duyệt đánh giá' : 'Đánh giá sân',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              widget.admin ? 'Tất cả cơ sở' : name ?? 'Cơ sở không còn công bố',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.admin
                  ? '${reviews.length} đánh giá trên toàn bộ cơ sở'
                  : public.isEmpty
                  ? widget.facilityId.isEmpty
                        ? 'Chưa có đánh giá từ lịch hoàn thành · Điểm mẫu 4.9'
                        : 'Chưa có đánh giá từ lịch hoàn thành'
                  : '${s.facilityRating(widget.facilityId).toStringAsFixed(1)} / 5 · ${public.length} đánh giá công khai',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('reviews-search'),
              decoration: const InputDecoration(
                labelText: 'Tìm kiếm',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            if (widget.admin)
              Wrap(
                spacing: 8,
                children: [
                  for (final e in {
                    'all': 'Tất cả',
                    'visible': 'Công khai',
                    'hidden': 'Đã ẩn',
                  }.entries)
                    ChoiceChip(
                      key: Key('reviews-filter-${e.key}'),
                      label: Text(e.value),
                      selected: _filter == e.key,
                      onSelected: (_) => setState(() => _filter = e.key),
                    ),
                ],
              ),
            if (!widget.admin &&
                s.reviewableBookings.any(
                  (b) => b.facilityId == widget.facilityId,
                ))
              FilledButton.icon(
                key: const Key('reviews-write'),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Viết đánh giá'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewFormScreen(
                      session: s,
                      facilityId: widget.facilityId,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (items.isEmpty) const Text('Không có đánh giá phù hợp.'),
            for (final r in items)
              _reviewTile(context, s, r, admin: widget.admin),
            if (!widget.admin &&
                s.ownReviews.any(
                  (r) =>
                      r.hidden &&
                      s.reviewFacilityId(r.bookingId) == widget.facilityId,
                )) ...[
              const Divider(height: 32),
              const Text(
                'Đánh giá của bạn đã ẩn',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final r in s.ownReviews.where(
                (r) =>
                    r.hidden &&
                    s.reviewFacilityId(r.bookingId) == widget.facilityId,
              ))
                _reviewTile(context, s, r),
            ],
          ],
        ),
      );
    },
  );
}

Widget _reviewTile(
  BuildContext context,
  DemoSession s,
  DemoVenueReview r, {
  bool admin = false,
}) => ListTile(
  key: Key('review-${r.bookingId}'),
  contentPadding: EdgeInsets.zero,
  title: Text('${r.author} · ${r.stars}/5'),
  subtitle: Text(
    '${admin ? '${s.reviewVenueName(r.bookingId)} · ' : ''}${r.hidden ? 'Đã ẩn · ' : ''}${r.message}',
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ReviewDetailScreen(session: s, bookingId: r.bookingId, admin: admin),
    ),
  ),
);

class ReviewFormScreen extends StatefulWidget {
  const ReviewFormScreen({
    super.key,
    required this.session,
    this.bookingId,
    this.facilityId,
  });
  final DemoSession session;
  final String? bookingId;
  final String? facilityId;
  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  final _message = TextEditingController();
  String? _id, _error;
  String? _author;
  int _stars = 5;
  bool _busy = false, _committed = false;
  @override
  void initState() {
    super.initState();
    _id = widget.bookingId;
    _author = widget.session.user?.identifier;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _committed || _id == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.session.user?.identifier != _author) {
        throw StateError('Tài khoản đã thay đổi. Mở lại biểu mẫu.');
      }
      widget.session.submitVenueReview(_id!, _stars, _message.text);
      _committed = true;
      final saved = await widget.session.flush();
      if (mounted && saved) Navigator.pop(context);
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.user == null ||
          s.role != DemoRole.player ||
          s.user?.identifier != _author) {
        return Scaffold(
          appBar: financeBar('Viết đánh giá'),
          body: const Center(
            child: Text('Cần đăng nhập tài khoản người chơi.'),
          ),
        );
      }
      final choices = s.reviewableBookings
          .where(
            (b) =>
                widget.facilityId == null || b.facilityId == widget.facilityId,
          )
          .toList();
      final selected = choices.any((b) => b.id == _id) ? _id : null;
      return Scaffold(
        appBar: financeBar('Viết đánh giá'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            if (_committed) ...[
              const Text('Đã ghi nhận đánh giá. Không cần gửi lại.'),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quay lại'),
              ),
            ] else ...[
              if (choices.isEmpty)
                const Text('Chưa có lịch hoàn thành đủ điều kiện đánh giá.'),
              DropdownButtonFormField<String>(
                key: const Key('review-booking'),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lịch hoàn thành'),
                items: [
                  for (final b in choices)
                    DropdownMenuItem(value: b.id, child: Text(b.id)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _id = v),
              ),
              if (selected != null)
                Text(
                  '${bookingDate(choices.firstWhere((b) => b.id == selected).start)} · Sân ${choices.firstWhere((b) => b.id == selected).court}',
                ),
              const SizedBox(height: 16),
              Wrap(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      key: Key('review-star-$i'),
                      tooltip: '$i sao',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _stars = i),
                      icon: Icon(
                        i <= _stars ? Icons.star : Icons.star_border,
                        color: const Color(0xFFE6AB00),
                      ),
                    ),
                ],
              ),
              Text('$_stars / 5'),
              TextField(
                key: const Key('review-message'),
                controller: _message,
                minLines: 3,
                maxLines: 8,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Nhận xét'),
                enabled: !_busy,
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                key: const Key('review-submit'),
                onPressed: _busy || selected == null ? null : _submit,
                child: const Text('Gửi đánh giá'),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class ReviewDetailScreen extends StatefulWidget {
  const ReviewDetailScreen({
    super.key,
    required this.session,
    required this.bookingId,
    this.admin = false,
  });
  final DemoSession session;
  final String bookingId;
  final bool admin;
  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _moderate(DemoVenueReview review) async {
    if (_busy) return;
    final reason = await financeText(
      context,
      review.hidden ? 'Lý do khôi phục' : 'Lý do ẩn đánh giá',
      minimum: 5,
      maximum: 300,
    );
    if (!mounted || reason == null) return;
    if (!await financeConfirm(
          context,
          'Xác nhận kiểm duyệt?',
          review.hidden
              ? 'Khôi phục nội dung công khai và tính lại điểm sao.'
              : 'Ẩn nội dung công khai, không xóa lịch sử đánh giá.',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.session.moderateVenueReview(
        review.bookingId,
        hidden: !review.hidden,
        reason: reason,
        expectedRevision: review.revision,
      );
      await widget.session.flush();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final admin = widget.admin && s.role == DemoRole.admin && s.user != null;
      final reviews = admin
          ? s.managedReviews
          : [...s.allPublicReviews, ...s.ownReviews];
      final r = widget.admin && !admin
          ? null
          : reviews.where((r) => r.bookingId == widget.bookingId).firstOrNull;
      if (r == null) {
        return Scaffold(
          appBar: financeBar('Đánh giá'),
          body: const Center(
            child: Text('Đánh giá không khả dụng hoặc không có quyền xem.'),
          ),
        );
      }
      final owner = r.owner == s.user?.identifier;
      return Scaffold(
        appBar: financeBar('Chi tiết đánh giá'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FinanceSaveNotice(session: s),
            Text(
              r.author,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text('${r.stars} / 5 · ${bookingDate(r.created)}'),
            Text(s.reviewVenueName(r.bookingId)),
            const Divider(height: 32),
            Text(r.message),
            if (admin || owner) ...[
              const Divider(height: 32),
              Text(r.hidden ? 'Đã ẩn' : 'Công khai'),
              if (r.reason.isNotEmpty) Text('Lý do: ${r.reason}'),
              TextButton.icon(
                key: const Key('review-record-link'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Xem lịch liên quan'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WorkflowDetailScreen(session: s, id: r.bookingId),
                  ),
                ),
              ),
            ],
            if (admin)
              FilledButton.icon(
                key: const Key('review-moderate'),
                onPressed: _busy || s.saveFailed ? null : () => _moderate(r),
                icon: Icon(
                  r.hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                label: Text(r.hidden ? 'Khôi phục đánh giá' : 'Ẩn đánh giá'),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    },
  );
}
