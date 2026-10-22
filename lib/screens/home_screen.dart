import 'dart:async';

import 'package:flutter/material.dart';

import 'owner_management_views.dart';
import 'admin_dashboard_screen.dart';
import 'management_screen.dart';
import 'approval_center_screen.dart';
import 'admin_system_report_screen.dart';
import 'admin_account_screen.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../venues/venue_catalog.dart';
import '../widgets/design.dart';
import 'auth_screen.dart';
import 'account_screen.dart';
import 'customer_account_views.dart';
import 'booking_screen.dart';
import 'demo_account_screens.dart';
import 'venue_map_screen.dart';
import 'customer_discovery_screen.dart';
import 'owner_tabs_screen.dart';
import 'chat_screen.dart';
import 'events_screen.dart';
import 'community_screen.dart';
import 'customer_social_screen.dart';
import 'finance_screen.dart';
import '../demo/demo_events.dart';

export '../widgets/design.dart' show AppColors;

const _venueName = 'Sân Cầu Lông Đại Học Công Thương';
const _venueAddress = '73/1 Nguyễn Đỗ Cung, Tây Thạnh, TP.HCM';
const _tabs = ['Trang chủ', 'Bản đồ', 'Khám phá', 'Nổi bật', 'Tài khoản'];
const _tabIcons = ['70656', 'ae34c', '8c511', '96aba', 'd96ab'];
const _sports = [
  'Pickleball',
  'Cầu lông',
  'Bóng đá',
  'Bóng rổ',
  'Quần vợt',
  'Đa năng',
];
const _sportAssets = [
  'sport-paddle',
  'sport-badminton',
  'sport-soccer',
  'sport-basketball',
  'sport-tennis',
  'sport-stadium',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.session});
  final DemoSession? session;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  void goHome() => setState(() => _tab = 0);
  void goToTab(int index) {
    if (index >= 0 && index < _tabs.length) setState(() => _tab = index);
  }

  final _search = TextEditingController();
  late final DemoSession _session;
  int _tab = 0;
  int _nearby = 0;
  int _sport = 0;
  bool _hasSportFilter = false;
  bool _proofRecoveryStarted = false;
  Timer? _socialExpiryTimer;
  DemoRole _lastRole = DemoRole.player;
  bool get _favorite => _session.isFavorite(demoVenueId);
  bool get _largeText => MediaQuery.textScalerOf(context).scale(12) > 15;
  double _textExtra(double size) =>
      MediaQuery.textScalerOf(context).scale(size) - size;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? DemoSession();
    _lastRole = _session.role;
    _session.addListener(_refreshSession);
    _socialExpiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session.initialized) _session.expireSocialTickets();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.initialize();
    });
  }

  void _refreshSession() {
    if (_lastRole != _session.role) {
      _lastRole = _session.role;
      _tab = 0;
    }
    setState(() {});
    if (_session.initialized && !_proofRecoveryStarted) {
      _proofRecoveryStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final message = await ProofPicker.recover(_session);
        if (mounted && message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      });
    }
  }

  @override
  void dispose() {
    _socialExpiryTimer?.cancel();
    _session.removeListener(_refreshSession);
    if (widget.session == null) _session.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _searching => _search.text.trim().isNotEmpty || _hasSportFilter;
  List<VenueSummary> get _matchingVenues => filterVenues(
    venues: _session.currentVenues,
    query: _search.text,
    sport: _hasSportFilter ? _sports[_sport] : null,
    maxPrice: 1000000,
  );
  bool get _matches => _matchingVenues.any((v) => v.id == demoVenueId);

  void _sheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      ),
    );
  }

  void _showVenue() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => VenueDetailScreen(session: _session)),
  );

  void _showFavorites() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CustomerFavoritesScreen(session: _session),
    ),
  );

  Future<void> _showAuth(bool register) async {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AuthScreen(session: _session, register: register),
      ),
    );
    if (mounted && loggedIn == true) {
      setState(() => _tab = _session.role == DemoRole.admin ? 0 : 4);
    }
  }

  Future<void> _showMessages() async {
    if (_session.user == null) await _showAuth(false);
    if (!mounted || _session.user == null) return;
    final tab = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => ChatListScreen(session: _session)),
    );
    if (mounted && tab != null && tab >= 0 && tab < 5) {
      setState(() => _tab = tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_session.initialized) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _session.loadFailed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 40,
                          color: AppColors.green,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Không thể đọc dữ liệu đã lưu.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('storage-retry-load'),
                          onPressed: _session.initialize,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppColors.green,
            height: _session.role == DemoRole.admin
                ? 0
                : MediaQuery.paddingOf(context).top,
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: _session.role == DemoRole.admin
                  ? [
                      _tab == 0
                          ? AdminDashboardScreen(
                              session: _session,
                              onTab: goToTab,
                            )
                          : const SizedBox(),
                      _tab == 1
                          ? ManagementScreen(
                              session: _session,
                              adminPresentation: true,
                              embedded: true,
                            )
                          : const SizedBox(),
                      _tab == 2
                          ? ApprovalCenterScreen(
                              session: _session,
                              embedded: true,
                            )
                          : const SizedBox(),
                      _tab == 3
                          ? AdminSystemReportScreen(session: _session)
                          : const SizedBox(),
                      _tab == 4
                          ? AdminAccountScreen(
                              session: _session,
                              embedded: true,
                            )
                          : const SizedBox(),
                    ]
                  : [
                      _tab == 0
                          ? _session.role == DemoRole.owner
                                ? OwnerDashboardTab(session: _session)
                                : _home()
                          : const SizedBox(),
                      VenueMapScreen(
                        key: ValueKey(
                          'venue-map-${_session.user?.identifier ?? 'guest'}',
                        ),
                        session: _session,
                        active: _tab == 1,
                        ownerMode: _session.role == DemoRole.owner,
                      ),
                      _session.role == DemoRole.owner
                          ? OwnerActivitiesView(
                              session: _session,
                              embedded: true,
                            )
                          : CustomerExploreScreen(
                              key: const ValueKey('explore'),
                              session: _session,
                            ),
                      _session.role == DemoRole.owner
                          ? OwnerFacilitiesView(
                              session: _session,
                              embedded: true,
                            )
                          : CustomerFeaturedScreen(
                              key: const ValueKey('featured'),
                              session: _session,
                              onMap: () => setState(() => _tab = 1),
                            ),
                      _tab == 4
                          ? AccountScreen(
                              session: _session,
                              onLogin: _showAuth,
                              onFavorites: _showFavorites,
                              favoriteCount: _session.favoriteVenueIds.length,
                              onMessages: _showMessages,
                            )
                          : const SizedBox(),
                    ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _navigation(),
    );
  }

  ButtonStyle get _quickActionStyle => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    minimumSize: const Size(0, 36),
    textStyle: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    iconSize: 14,
  );

  Widget _home() => _searching
      ? _homeSearchResults()
      : CustomScrollView(
          key: const PageStorageKey('home-scroll'),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _filters()),
            SliverToBoxAdapter(child: _categories()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width:
                        (MediaQuery.sizeOf(context).width - 32) *
                        (MediaQuery.textScalerOf(context).scale(12) > 17
                            ? 1.7
                            : 1),
                    child: Row(
                      spacing: 6,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: _quickActionStyle,
                            key: const Key('home-social'),
                            icon: const Icon(Icons.groups_outlined),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SocialVenueEventsScreen(session: _session),
                              ),
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Giao lưu'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: _quickActionStyle,
                            key: const Key('home-tournaments'),
                            icon: const Icon(Icons.emoji_events_outlined),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventsScreen(
                                  session: _session,
                                  initialKind: DemoEventKind.tournament,
                                ),
                              ),
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Giải đấu'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: _quickActionStyle,
                            key: const Key('home-community'),
                            icon: const Icon(Icons.forum_outlined),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CommunityScreen(session: _session),
                              ),
                            ),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Cộng đồng'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _academy()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sân cầu lông nổi bật',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _tab = 3),
                      child: const Padding(
                        padding: EdgeInsets.zero,
                        child: Text(
                          'Xem tất cả',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: _matches ? _venueCard() : _emptyResults(),
              ),
            ),
          ],
        );

  Widget _header() => Container(
    color: AppColors.green,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      children: [
        Flex(
          direction: _largeText ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: _largeText
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Flexible(
              flex: _largeText ? 0 : 1,
              fit: FlexFit.tight,
              child: InkWell(
                onTap: () => _sheet(
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vị trí của bạn',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.location_on,
                          color: AppColors.green,
                        ),
                        title: Text('Hồ Chí Minh, VN'),
                      ),
                    ],
                  ),
                ),
                child: const Row(
                  children: [
                    FigmaIcon('54444', size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vị trí của bạn',
                            style: TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            'Hồ Chí Minh, VN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8, height: _largeText ? 12 : 0),
            if (_session.user == null) ...[
              if (_largeText)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _authButton('Đăng nhập', false),
                    _authButton('Đăng ký', true),
                  ],
                )
              else ...[
                _authButton('Đăng nhập', false),
                const SizedBox(width: 8),
                _authButton('Đăng ký', true),
              ],
            ] else
              Flexible(
                flex: _largeText ? 0 : 1,
                child: Tooltip(
                  message: 'Tài khoản của ${_session.user!.name}',
                  child: TextButton(
                    key: const Key('home-customer-account'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => setState(() => _tab = 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 20),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _session.user!.name,
                            key: const Key('home-customer-name'),
                            maxLines: _largeText ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.25,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36 + _textExtra(13) * 1.5,
                child: TextField(
                  key: const Key('home-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(fontSize: 13),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm sân, câu lạc bộ...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.faint,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(11),
                      child: _search.text.isEmpty
                          ? const FigmaIcon('d92aa', size: 14)
                          : InkWell(
                              onTap: () {
                                _search.clear();
                                setState(() {});
                              },
                              child: const Icon(Icons.close, size: 14),
                            ),
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: const Color(0x33FFFFFF),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _showFavorites,
                tooltip: 'Sân yêu thích',
                style: IconButton.styleFrom(
                  fixedSize: const Size(40, 40),
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const FigmaIcon('86ac1', size: 20),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _authButton(String label, bool register) => Material(
    color: register ? Colors.white : const Color(0x33FFFFFF),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showAuth(register),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: register ? AppColors.green : Colors.white,
          ),
        ),
      ),
    ),
  );

  Widget _filters() => SizedBox(
    height: 55 + _textExtra(12) * 1.2,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => Material(
        color: index == _nearby ? AppColors.green : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: index == _nearby ? AppColors.green : AppColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _nearby = index);
            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventsScreen(session: _session),
                ),
              );
            } else {
              openVenueMap(
                context,
                index == 0 ? 'sân pickleball' : 'sân cầu lông',
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              [
                'Pickleball gần tôi',
                'Cầu lông gần tôi',
                'Xé vé gần tôi',
              ][index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: index == _nearby
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: index == _nearby ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _categories() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = 60 * MediaQuery.textScalerOf(context).scale(11) / 11;
        final children = List.generate(
          _sports.length,
          (index) => SizedBox(
            width: itemWidth,
            child: InkWell(
              key: Key('home-sport-$index'),
              onTap: () => setState(() {
                _sport = index;
                _hasSportFilter = true;
              }),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _sport == index
                          ? const Color(0xFFE6F6EC)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _sport == index
                            ? AppColors.green
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: DesignAsset(
                        _sportAssets[index],
                        key: Key('home-sport-icon-$index'),
                        folder: 'figma',
                        size: 26,
                        color: _sport == index
                            ? AppColors.green
                            : AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sports[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _sport == index ? AppColors.green : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (constraints.maxWidth >= itemWidth * _sports.length) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: children,
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(spacing: 2, children: children),
        );
      },
    ),
  );

  Widget _academy() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.green],
        ),
      ),
      child: Flex(
        direction: _largeText ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: _largeText ? 0 : 1,
            fit: FlexFit.tight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEB3B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'RA MẮT',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'NVH ACADEMY',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tìm kiếm lớp học và đăng ký khóa học gần bạn nhất.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AcademyScreen(session: _session),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Khám phá ngay',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                color: AppColors.darkGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          FigmaIcon('7fbbd', size: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12, height: _largeText ? 12 : 0),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/figma/07380.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _venueCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/figma/c0697.png', fit: BoxFit.cover),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FigmaIcon('e6089', size: 12),
                      SizedBox(width: 4),
                      Text(
                        _session.venueRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: const Color(0xCCFFFFFF),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: _favorite ? 'Bỏ yêu thích' : 'Lưu sân yêu thích',
                    style: IconButton.styleFrom(
                      fixedSize: const Size(40, 40),
                      minimumSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _session.toggleFavorite(demoVenueId),
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: _favorite
                        ? const Icon(
                            Icons.favorite,
                            size: 16,
                            color: AppColors.green,
                          )
                        : const FigmaIcon('ca5eb', size: 16),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Row(
                  children: [
                    _badge('Đơn ngày', AppColors.green),
                    const SizedBox(width: 6),
                    _badge('Sự kiện', const Color(0xFFB388FF)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                _venueName,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  FigmaIcon('ec335', size: 14),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _venueAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flex(
                direction: _largeText ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: _largeText
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: _largeText ? 0 : 1,
                    fit: FlexFit.tight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giá chỉ từ',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            color: AppColors.muted,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: bookingMoney(_session.minimumCourtRate),
                                style: const TextStyle(
                                  color: AppColors.darkGreen,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(
                                text: ' /giờ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12, height: _largeText ? 12 : 0),
                  SizedBox(
                    height: 36 + _textExtra(13) * 1.5,
                    width: _largeText ? double.infinity : null,
                    child: FilledButton(
                      onPressed: _showVenue,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text(
                        'Đặt sân ngay',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _homeSearchResults() {
    final results = _matchingVenues;
    return CustomScrollView(
      key: const PageStorageKey('home-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _categories()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Kết quả tìm kiếm (${results.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (results.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _search.clear();
                      _hasSportFilter = false;
                      _sport = 0;
                    }),
                    child: const Text('Xóa bộ lọc'),
                  ),
              ],
            ),
          ),
        ),
        if (results.isEmpty)
          SliverToBoxAdapter(child: _emptyResults())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) =>
                  CustomerVenueCard(session: _session, venue: results[index]),
            ),
          ),
      ],
    );
  }

  Widget _emptyResults() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.search_off, color: AppColors.faint, size: 32),
        const SizedBox(height: 12),
        const Text(
          'Không tìm thấy sân phù hợp.',
          style: TextStyle(color: AppColors.muted),
        ),
        TextButton(
          onPressed: () => setState(() {
            _search.clear();
            _hasSportFilter = false;
            _sport = 0;
          }),
          child: const Text('Xóa bộ lọc'),
        ),
      ],
    ),
  );

  Widget _navigation() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 58 + _textExtra(10) * 3.2,
        child: Row(
          children: List.generate(
            _tabs.length,
            (index) => Expanded(
              child: Semantics(
                selected: _tab == index,
                button: true,
                label: _session.role == DemoRole.admin
                    ? adminTabLabels[index]
                    : _tabs[index],
                child: InkWell(
                  key: Key(
                    _session.role == DemoRole.admin
                        ? 'admin-nav-$index'
                        : 'home-nav-$index',
                  ),
                  onTap: () => setState(() => _tab = index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_session.role == DemoRole.admin)
                        Icon(
                          adminTabIcons[index],
                          size: 22,
                          color: _tab == index
                              ? AppColors.green
                              : AppColors.faint,
                        )
                      else
                        FigmaIcon(
                          _tabIcons[index],
                          size: 22,
                          color: _tab == index
                              ? AppColors.green
                              : AppColors.faint,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _session.role == DemoRole.admin
                            ? adminTabLabels[index]
                            : _tabs[index],
                        maxLines: _largeText ? 2 : 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: _tab == index
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _tab == index
                              ? AppColors.green
                              : AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
