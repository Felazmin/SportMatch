import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import '../widgets/venue_favorite_button.dart';
import 'booking_screen.dart';
import 'facilities_screen.dart';
import 'customer_venue_detail_screen.dart';
import '../widgets/venue_image.dart';

class VenueBrowseScreen extends StatefulWidget {
  const VenueBrowseScreen({
    super.key,
    required this.session,
    this.title = 'Khám phá',
    this.embedded = false,
    this.favoritesOnly = false,
    this.featuredOnly = false,
  });
  final DemoSession session;
  final String title;
  final bool embedded;
  final bool favoritesOnly;
  final bool featuredOnly;
  @override
  State<VenueBrowseScreen> createState() => _VenueBrowseScreenState();
}

class _VenueBrowseScreenState extends State<VenueBrowseScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _sport;
  int _maxPrice = 300000;
  double _minRating = 0;
  bool _onlySaved = false;
  VenueSort _sort = VenueSort.rating;
  bool get _filtered =>
      _sport != null || _maxPrice != 300000 || _minRating != 0 || _onlySaved;
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _search.clear();
    _sport = null;
    _maxPrice = 300000;
    _minRating = 0;
    _onlySaved = false;
    _sort = VenueSort.rating;
  });
  Future<void> _filters() async {
    FocusScope.of(context).unfocus();
    var price = _maxPrice;
    var rating = _minRating;
    var saved = _onlySaved;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bộ lọc',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Giá tối đa: ${bookingMoney(price)} / giờ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  key: const Key('browse-price'),
                  value: price.toDouble(),
                  min: 0,
                  max: 1000000,
                  divisions: 6,
                  label: bookingMoney(price),
                  onChanged: (value) => update(() => price = value.round()),
                ),
                const SizedBox(height: 12),
                Text(
                  rating == 0
                      ? 'Đánh giá: Tất cả'
                      : 'Đánh giá từ ${rating.toStringAsFixed(1)} sao',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  key: const Key('browse-rating'),
                  value: rating,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  label: rating.toStringAsFixed(1),
                  onChanged: (value) => update(() => rating = value),
                ),
                if (!widget.favoritesOnly)
                  SwitchListTile(
                    key: const Key('browse-saved-only'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Chỉ sân yêu thích',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: saved,
                    onChanged: (value) => update(() => saved = value),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('browse-apply'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Áp dụng'),
                ),
                TextButton(
                  onPressed: () => update(() {
                    price = 300000;
                    rating = 0;
                    saved = false;
                  }),
                  child: const Text('Đặt lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && apply == true) {
      setState(() {
        _maxPrice = price;
        _minRating = rating;
        _onlySaved = saved;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final results = filterVenues(
        venues: widget.session.currentVenues,
        query: _search.text,
        sport: _sport,
        maxPrice: _maxPrice,
        minRating: _minRating,
        favorites: widget.session.favoriteVenueIds,
        favoritesOnly: widget.favoritesOnly || _onlySaved,
        featuredOnly: widget.featuredOnly,
        sort: _sort,
      );
      final body = CustomScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  color: AppColors.green,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.embedded) ...[
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('browse-search'),
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Tên sân, khu vực...',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.muted,
                                  size: 20,
                                ),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Xóa tìm kiếm',
                                        onPressed: () =>
                                            setState(() => _search.clear()),
                                        icon: const Icon(Icons.close, size: 20),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('browse-filter'),
                            tooltip: 'Bộ lọc',
                            onPressed: _filters,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              fixedSize: const Size(44, 44),
                            ),
                            icon: Icon(
                              Icons.tune,
                              color: _filtered
                                  ? AppColors.darkGreen
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height:
                      60 +
                      (MediaQuery.textScalerOf(context).scale(12) - 12) * 2,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: venueSports.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final sport = index == 0 ? null : venueSports[index - 1];
                      return ChoiceChip(
                        key: Key('browse-sport-$index'),
                        label: Text(
                          sport ?? 'Tất cả',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: sport == _sport,
                        onSelected: (_) => setState(() => _sport = sport),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${results.length} sân',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (_filtered || _search.text.isNotEmpty)
                        TextButton(
                          key: const Key('browse-reset'),
                          onPressed: _reset,
                          child: const Text(
                            'Xóa bộ lọc',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      PopupMenuButton<VenueSort>(
                        tooltip: 'Sắp xếp',
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        icon: const Icon(Icons.sort, color: AppColors.muted),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: VenueSort.rating,
                            child: Text('Đánh giá cao nhất'),
                          ),
                          PopupMenuItem(
                            value: VenueSort.price,
                            child: Text('Giá thấp đến cao'),
                          ),
                          PopupMenuItem(
                            value: VenueSort.name,
                            child: Text('Tên sân A-Z'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (results.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(
                      widget.favoritesOnly
                          ? Icons.favorite_border
                          : Icons.search_off,
                      size: 40,
                      color: AppColors.faint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.favoritesOnly && !_filtered && _search.text.isEmpty
                          ? 'Bạn chưa lưu sân yêu thích.'
                          : 'Không tìm thấy sân phù hợp.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (_filtered || _search.text.isNotEmpty)
                      TextButton(
                        onPressed: _reset,
                        child: const Text('Đặt lại'),
                      ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _venue(results[index]),
              ),
            ),
        ],
      );
      return widget.embedded
          ? body
          : Scaffold(
              appBar: AppBar(
                title: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
              body: body,
            );
    },
  );

  Widget _venue(VenueSummary venue) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.border),
    ),
    child: InkWell(
      key: Key('venue-result-${venue.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        FocusScope.of(context).unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => venue.isImported
                ? CustomerVenueDetailScreen(
                    session: widget.session,
                    venueId: venue.id,
                  )
                : venue.localPhoto
                ? PublicFacilityScreen(session: widget.session, id: venue.id)
                : VenueDetailScreen(session: widget.session),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: VenueImage(venue: venue, width: 84, height: 100),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        venue.addressLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFE6AB00), size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    venue.ratingLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    venue.sport,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                VenueFavoriteButton(session: widget.session, venueId: venue.id),
              ],
            ),
            Text(
              venue.priceLabel,
              style: const TextStyle(
                color: AppColors.darkGreen,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
