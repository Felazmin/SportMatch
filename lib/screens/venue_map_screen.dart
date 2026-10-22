import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/demo_session.dart';
import '../venues/venue_catalog.dart';
import '../venues/venue_map_service.dart';
import '../widgets/design.dart';
import 'customer_discovery_screen.dart';
import 'customer_venue_detail_screen.dart';
import 'owner_venue_navigation.dart';

Uri venueMapUrl(String address, {bool directions = false}) => Uri.https(
  'www.google.com',
  directions ? '/maps/dir/' : '/maps/search/',
  {'api': '1', directions ? 'destination' : 'query': address},
);
Future<void> openVenueMap(
  BuildContext context,
  String address, {
  bool directions = false,
}) async {
  bool opened;
  try {
    opened = await launchUrl(
      venueMapUrl(address, directions: directions),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Không mở được bản đồ. Bạn có thể sao chép địa chỉ để tìm kiếm.',
        ),
      ),
    );
  }
}

class VenueMapScreen extends StatefulWidget {
  const VenueMapScreen({
    super.key,
    required this.session,
    this.active = true,
    this.ownerMode = false,
  });
  final DemoSession session;
  final bool active;
  final bool ownerMode;
  @override
  State<VenueMapScreen> createState() => _VenueMapScreenState();
}

class _VenueMapScreenState extends State<VenueMapScreen> {
  final _search = TextEditingController();
  final _controller = MapController();
  late final _service = VenueMapService.instance;
  late TileProvider _tiles = _service.createTileProvider();
  final _points = <String, LatLng>{};
  final _attempted = <String>{};
  // Initial city view is not represented as the user's GPS position.
  static const _city = LatLng(10.8006, 106.6525);
  LatLng? _position;
  LatLng? _searchPoint;
  String? _resolvingAddress;
  String? _sport, _selected, _status;
  bool _ready = false,
      _locating = false,
      _resolving = false,
      _tileFailed = false;
  int _tileRevision = 0, _searchRevision = 0;
  bool _ownOnly = true;
  bool get _owner => widget.ownerMode && widget.session.role == DemoRole.owner;
  List<VenueSummary> get _owned =>
      _owner ? widget.session.ownerMapVenues : const [];
  bool _isOwned(String id) => _owned.any((v) => v.id == id);
  List<VenueSummary> get _venues => !_owner
      ? widget.session.currentVenues
      : _ownOnly
      ? _owned
      : {
          for (final v in widget.session.currentVenues) v.sourceUrl ?? v.id: v,
          for (final v in _owned) v.sourceUrl ?? v.id: v,
        }.values.toList();
  List<VenueSummary> get _results => filterVenues(
    venues: _venues,
    maxPrice: 1000000,
    query: _search.text,
    sport: _sport,
  );
  VenueSummary? get _venue =>
      _results.where((v) => v.id == _selected).firstOrNull ??
      _results.firstOrNull;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_venuesChanged);
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveVenues());
    }
  }

  @override
  void didUpdateWidget(VenueMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_venuesChanged);
      widget.session.addListener(_venuesChanged);
    }
    if (widget.active && !oldWidget.active) {
      _tiles = _service.createTileProvider();
      _resolveVenues();
    }
  }

  void _venuesChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.active) _resolveVenues();
  }

  Future<void> _resolveVenues({bool retry = false}) async {
    if (!mounted || _resolving || !widget.active) return;
    // Imported points already have coordinates; do not geocode missing addresses.
    setState(() {
      for (final venue in _venues) {
        if (venue.latitude != null && venue.longitude != null) {
          _points[venue.mapKey] = LatLng(venue.latitude!, venue.longitude!);
          _attempted.add(venue.mapKey);
        }
      }
    });
    if (retry) _attempted.removeWhere((a) => !_points.containsKey(a));
    final venues = _venues
        .where((v) => !_attempted.contains(v.mapKey))
        .toList();
    if (venues.isEmpty) return;
    setState(() => _resolving = true);
    try {
      for (final v in venues) {
        if (!mounted || !widget.active) break;
        setState(() => _resolvingAddress = v.mapKey);
        _attempted.add(v.mapKey);
        final point = await _lookup(v.address);
        if (!mounted) return;
        if (point != null) {
          setState(() => _points[v.mapKey] = point);
          if (_venue?.mapKey == v.mapKey &&
              _position == null &&
              _searchPoint == null) {
            _move(point);
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _resolving = false;
          _resolvingAddress = null;
        });
        if (widget.active &&
            _venues.any((v) => !_attempted.contains(v.mapKey))) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _resolveVenues());
        }
      }
    }
  }

  Future<LatLng?> _lookup(String address) async {
    try {
      return await _service
          .locateAddress(address)
          .timeout(const Duration(seconds: 18));
    } catch (_) {
      return null;
    }
  }

  void _move(LatLng point, {double zoom = 15}) {
    if (_ready) _controller.move(point, zoom);
  }

  Future<void> _select(VenueSummary v) async {
    final revision = ++_searchRevision;
    setState(() {
      _selected = v.id;
      _searchPoint = null;
      _status = _points[v.mapKey] == null ? 'Đang tìm vị trí sân...' : null;
    });
    final point =
        _points[v.mapKey] ??
        (v.latitude != null && v.longitude != null
            ? LatLng(v.latitude!, v.longitude!)
            : await _lookup(v.address));
    if (!mounted || revision != _searchRevision) return;
    setState(() {
      if (point != null) _points[v.mapKey] = point;
      _status = point == null
          ? 'Không tìm được tọa độ sân. Hãy thử lại.'
          : null;
    });
    if (point != null) _move(point);
  }

  void _changeFilter(VoidCallback change) {
    _searchRevision++;
    setState(() {
      change();
      _selected = null;
      _status = null;
      _searchPoint = null;
    });
    final point = _points[_venue?.mapKey];
    if (point != null) _move(point);
  }

  Future<void> _searchAddress(String query) async {
    final local = _results.firstOrNull;
    if (local != null) {
      await _select(local);
      return;
    }
    if (query.trim().isEmpty) return;
    final revision = ++_searchRevision;
    setState(() => _status = 'Đang tìm địa chỉ...');
    final point = await _lookup(query.trim());
    if (!mounted || revision != _searchRevision) return;
    setState(() {
      _searchPoint = point;
      _status = point == null
          ? 'Không tìm được tọa độ địa chỉ này.'
          : '${_service.isApproximate(query.trim()) ? 'Vị trí gần đúng' : 'Địa chỉ'}: ${_service.addressLabel(query.trim()) ?? query.trim()}';
    });
    if (point != null) _move(point);
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final point = await _service.currentPosition();
      if (!mounted) return;
      setState(() {
        _position = point;
        _status = null;
      });
      _move(point);
    } on MapLocationFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            action: e.settings
                ? SnackBarAction(
                    label: 'Cài đặt',
                    onPressed: Geolocator.openAppSettings,
                  )
                : null,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lấy được vị trí. Hãy kiểm tra GPS và thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _tileError() {
    if (_tileFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileFailed) setState(() => _tileFailed = true);
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_venuesChanged);
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final large = MediaQuery.textScalerOf(context).scale(12) > 17;
      final venue = _venue;
      final content = Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.green,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _owner ? 'Bản đồ cơ sở' : 'Bản đồ quanh bạn',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _position == null
                            ? 'TP. Hồ Chí Minh'
                            : 'Vị trí hiện tại của bạn',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    key: const Key('embedded-venue-map'),
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: _city,
                      initialZoom: 14,
                      minZoom: 3,
                      maxZoom: 19,
                      backgroundColor: const Color(0xFFE9EFE8),
                      onMapReady: () {
                        _ready = true;
                        final point =
                            _searchPoint ??
                            _position ??
                            _points[_venue?.mapKey];
                        if (point != null) _move(point);
                      },
                    ),
                    children: [
                      if (widget.active)
                        TileLayer(
                          key: ValueKey('map-tiles-$_tileRevision'),
                          urlTemplate: const String.fromEnvironment(
                            'MAP_TILE_URL',
                            defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          ),
                          userAgentPackageName: 'com.example.test_do_an',
                          tileProvider: _tiles,
                          panBuffer: 0,
                          errorTileCallback: (_, _, _) => _tileError(),
                        ),
                      MarkerLayer(
                        markers: [
                          if (_searchPoint case final point?)
                            Marker(
                              point: point,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                key: Key('map-search-position'),
                                color: Color(0xFFE44C43),
                                size: 40,
                              ),
                            ),
                          for (final v in _results)
                            if (_points[v.mapKey] case final point?)
                              Marker(
                                point: point,
                                width: 48,
                                height: 48,
                                child: Tooltip(
                                  message: v.name,
                                  child: Material(
                                    shape: CircleBorder(
                                      side: BorderSide(
                                        color: _isOwned(v.id)
                                            ? const Color(0xFF2479C9)
                                            : _venue?.id == v.id
                                            ? AppColors.green
                                            : Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    elevation: 3,
                                    color: _venue?.id == v.id
                                        ? (_isOwned(v.id)
                                              ? const Color(0xFF2479C9)
                                              : AppColors.green)
                                        : Colors.white,
                                    child: InkWell(
                                      key: Key('map-marker-${v.id}'),
                                      customBorder: const CircleBorder(),
                                      onTap: () => _select(v),
                                      child: Padding(
                                        padding: const EdgeInsets.all(9),
                                        child: DesignAsset(
                                          switch (v.sport) {
                                            'Bóng đá' => 'sport-soccer',
                                            'Bóng rổ' => 'sport-basketball',
                                            'Cầu lông' => 'sport-badminton',
                                            'Quần vợt' => 'sport-tennis',
                                            'Pickleball' => 'sport-paddle',
                                            _ => 'sport-stadium',
                                          },
                                          folder: 'figma',
                                          size: 24,
                                          color: _venue?.id == v.id
                                              ? Colors.white
                                              : (_isOwned(v.id)
                                                    ? const Color(0xFF2479C9)
                                                    : AppColors.green),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          if (_position case final position?)
                            Marker(
                              point: position,
                              width: 28,
                              height: 28,
                              child: Container(
                                key: const Key('map-user-position'),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF438EFF),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33438EFF),
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        elevation: 3,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          key: const Key('map-search'),
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => _changeFilter(() {}),
                          onSubmitted: _searchAddress,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Tìm sân hoặc địa chỉ',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: AppColors.faint,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _search.text.isEmpty
                                  ? 'Danh sách sân'
                                  : 'Xóa tìm kiếm',
                              onPressed: _search.text.isEmpty
                                  ? _showResults
                                  : () => _changeFilter(_search.clear),
                              icon: Icon(
                                _search.text.isEmpty ? Icons.tune : Icons.close,
                                size: 20,
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_owner) ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final mine in [true, false])
                              ChoiceChip(
                                key: Key(
                                  mine ? 'map-own-venues' : 'map-all-venues',
                                ),
                                label: Text(
                                  mine ? 'Sân của tôi' : 'Tất cả sân',
                                ),
                                selected: _ownOnly == mine,
                                onSelected: (_) {
                                  _changeFilter(() => _ownOnly = mine);
                                  _resolveVenues();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final sport in [
                              null,
                              'Bóng đá',
                              'Cầu lông',
                              'Pickleball',
                              'Bóng rổ',
                              'Quần vợt',
                              'Đa năng',
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  key: Key('map-sport-${sport ?? 'all'}'),
                                  label: Text(
                                    sport ?? 'Tất cả',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _sport == sport
                                          ? Colors.white
                                          : AppColors.ink,
                                    ),
                                  ),
                                  selected: _sport == sport,
                                  showCheckmark: false,
                                  selectedColor: AppColors.green,
                                  backgroundColor: Colors.white,
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                  shape: const StadiumBorder(),
                                  onSelected: (_) =>
                                      _changeFilter(() => _sport = sport),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_status != null || _tileFailed)
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _tileFailed
                                      ? 'Chưa tải được bản đồ. Kiểm tra kết nối mạng.'
                                      : _status!,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (_tileFailed)
                                  TextButton(
                                    key: const Key('map-retry-tiles'),
                                    onPressed: () => setState(() {
                                      _tileFailed = false;
                                      _tileRevision++;
                                      _tiles = _service.createTileProvider();
                                    }),
                                    child: const Text(
                                      'Thử lại',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 36,
                  child: Column(
                    children: [
                      _control(
                        'Phóng to',
                        Icons.add,
                        () => _controller.move(
                          _controller.camera.center,
                          (_controller.camera.zoom + 1).clamp(3, 19),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _control(
                        'Thu nhỏ',
                        Icons.remove,
                        () => _controller.move(
                          _controller.camera.center,
                          (_controller.camera.zoom - 1).clamp(3, 19),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _control(
                        _locating ? 'Đang lấy vị trí' : 'Vị trí của bạn',
                        Icons.my_location,
                        _locating ? null : _locate,
                        key: const Key('map-locate'),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 4,
                  child: Material(
                    color: Colors.white.withValues(alpha: .9),
                    child: InkWell(
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 9, color: AppColors.muted),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: venue != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomerVenueCard(
                        session: widget.session,
                        venue: venue,
                        subtitle: _distance(venue),
                        actionLabel: _isOwned(venue.id)
                            ? 'Quản lý sân'
                            : 'Xem chi tiết',
                        onDetails: () => _isOwned(venue.id)
                            ? openOwnerVenue(context, widget.session, venue.id)
                            : Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => CustomerVenueDetailScreen(
                                    session: widget.session,
                                    venueId: venue.id,
                                  ),
                                ),
                              ),
                      ),
                      if (_points[venue.mapKey] == null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _resolvingAddress == venue.mapKey
                                    ? 'Đang xác định vị trí sân...'
                                    : 'Chưa xác định được tọa độ sân.',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _resolving
                                  ? null
                                  : () => _resolveVenues(retry: true),
                              child: const Text(
                                'Thử lại',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      if (_points[venue.mapKey] != null &&
                          (venue.representativeCenter ||
                              _service.isApproximate(venue.address)))
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Ghim gần đúng theo đường/khu vực; chưa xác minh vị trí cổng sân.',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            key: const Key('map-copy'),
                            tooltip: 'Sao chép địa chỉ',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: venue.isImported
                                      ? venue.mapQuery
                                      : venue.address,
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã sao chép địa chỉ.'),
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            key: const Key('map-open'),
                            tooltip: 'Mở bản đồ ngoài',
                            icon: const Icon(Icons.open_in_new, size: 18),
                            onPressed: () =>
                                openVenueMap(context, venue.mapQuery),
                          ),
                          IconButton(
                            key: const Key('map-directions'),
                            tooltip: 'Chỉ đường',
                            icon: const Icon(Icons.near_me_outlined, size: 18),
                            onPressed: () => openVenueMap(
                              context,
                              venue.mapQuery,
                              directions: true,
                            ),
                          ),
                          TextButton(
                            onPressed: _showResults,
                            child: Text(
                              '${_results.length} sân',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          _searchPoint == null
                              ? 'Không tìm thấy địa chỉ phù hợp.'
                              : 'Đã ghim kết quả địa chỉ trên bản đồ.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => _changeFilter(() {
                          _search.clear();
                          _sport = null;
                        }),
                        child: const Text('Xóa bộ lọc'),
                      ),
                    ],
                  ),
          ),
        ],
      );
      return size.maxHeight < 500 || large
          ? SingleChildScrollView(
              child: SizedBox(height: large ? 1100 : 720, child: content),
            )
          : content;
    },
  );
  String _distance(VenueSummary venue) {
    final point = _points[venue.mapKey];
    if (_position == null || point == null) return venue.addressLabel;
    final km = const Distance().as(LengthUnit.Kilometer, _position!, point);
    return '${venue.addressLabel} · Cách ${km.toStringAsFixed(1)} km (đường thẳng)';
  }

  Widget _control(
    String tooltip,
    IconData icon,
    VoidCallback? onPressed, {
    Key? key,
  }) => Material(
    elevation: 2,
    shape: const CircleBorder(),
    color: Colors.white,
    child: IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: AppColors.green),
    ),
  );
  Future<void> _showResults() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Sân trong khu vực',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final v in _results)
              ListTile(
                key: Key('map-select-${v.id}'),
                title: Text(v.name),
                subtitle: Text(v.addressLabel),
                trailing: const Icon(Icons.location_on_outlined),
                onTap: () {
                  Navigator.pop(context);
                  _select(v);
                },
              ),
            if (_results.isEmpty) const Text('Không tìm thấy sân phù hợp.'),
          ],
        ),
      ),
    ),
  );
}
