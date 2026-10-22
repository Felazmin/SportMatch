import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/booking_screen.dart';
import 'package:test_do_an/screens/customer_forum_views.dart';
import 'package:test_do_an/screens/customer_discovery_screen.dart';
import 'package:test_do_an/screens/customer_venue_detail_screen.dart';
import 'package:test_do_an/screens/demo_account_screens.dart';
import 'package:test_do_an/screens/events_screen.dart';
import 'package:test_do_an/screens/facility_booking_screen.dart';
import 'package:test_do_an/screens/venue_browse_screen.dart';
import 'package:test_do_an/venues/venue_map_service.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'multi_facility_test.dart' show publishTestFacility;

late Uint8List testTileBytes;

class TestTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(testTileBytes);
}

class TestMapService extends VenueMapService {
  int gpsCalls = 0, addressCalls = 0;
  bool denied = false, noCoordinates = false;
  Completer<LatLng?>? pending;
  @override
  TileProvider createTileProvider() => TestTileProvider();
  @override
  Future<LatLng?> locateAddress(String address) async {
    addressCalls++;
    if (pending != null) return pending!.future;
    return noCoordinates ? null : const LatLng(10.8006, 106.6525);
  }

  @override
  Future<LatLng> currentPosition() async {
    gpsCalls++;
    if (denied) {
      throw const MapLocationFailure(
        'Chưa được cấp quyền vị trí. Bạn vẫn có thể xem bản đồ và tìm sân.',
      );
    }
    return const LatLng(10.801, 106.653);
  }
}

void main() {
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFE9EFE8), BlendMode.src);
    final image = await recorder.endRecording().toImage(16, 16);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    testTileBytes = bytes!.buffer.asUint8List();
    image.dispose();
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  late TestMapService maps;
  setUp(() {
    maps = TestMapService();
    VenueMapService.instance = maps;
  });
  tearDown(() => VenueMapService.instance = VenueMapService());

  Future<(DemoSession, GlobalKey)> home(
    WidgetTester t, {
    double width = 402,
    double scale = 1,
    bool facility = false,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
    await s.initialize();
    if (facility) publishTestFacility(s);
    s.login(DemoSession.phone, DemoSession.password);
    addTearDown(s.dispose);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MyApp(session: s),
      ),
    );
    await t.pumpAndSettle();
    return (s, key);
  }

  Future<void> press(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Explore and featured have separate content and correct routes', (
    t,
  ) async {
    await home(t);
    await press(t, find.text('Khám phá').last);
    expect(find.text('Sự kiện và hoạt động dành cho bạn'), findsOneWidget);
    expect(find.text('Poster sân nổi bật'), findsNothing);
    expect(find.byKey(const Key('browse-search')), findsNothing);
    await press(t, find.byKey(const Key('explore-event')));
    expect(find.byType(CustomerEventDetailScreen), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, find.text('Nổi bật').last);
    expect(find.text('Những địa điểm được yêu thích nhất'), findsOneWidget);
    expect(find.text('Poster sân nổi bật'), findsOneWidget);
    expect(find.text('Sự kiện sắp diễn ra'), findsNothing);
    await press(t, find.byKey(const Key('featured-vouchers')));
    expect(find.byType(VoucherWalletScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final entry in <String, Type>{
    'Sự kiện': EventsScreen,
    'Diễn đàn': CustomerForumScreen,
    'Thông báo': DiscoveryInformationScreen,
    'Khóa học': AcademyScreen,
    'Ưu đãi': VoucherWalletScreen,
  }.entries) {
    testWidgets('Explore shortcut opens ${entry.key}', (t) async {
      await home(t);
      await press(t, find.text('Khám phá').last);
      await press(t, find.byKey(Key('explore-shortcut-${entry.key}')));
      expect(find.byType(entry.value), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Featured opens detail, favorite, existing catalog and booking', (
    t,
  ) async {
    final (s, _) = await home(t);
    await press(t, find.text('Nổi bật').last);
    await press(t, find.byKey(const Key('featured-poster-cong-thuong')));
    expect(find.byType(CustomerVenueDetailScreen), findsOneWidget);
    await press(t, find.byTooltip('Lưu sân yêu thích'));
    expect(s.favoriteVenueIds, contains('cong-thuong'));
    await press(t, find.byKey(const Key('customer-detail-book')));
    await press(t, find.text('Đặt lịch theo sân'));
    expect(find.byType(BookingScheduleScreen), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, find.byTooltip('Sân yêu thích'));
    expect(find.byType(VenueBrowseScreen), findsOneWidget);
    expect(find.byKey(const Key('venue-result-cong-thuong')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Recommendation opens matching facility booking, not primary', (
    t,
  ) async {
    await home(t, facility: true);
    await press(t, find.text('Nổi bật').last);
    await press(t, find.byKey(const Key('customer-book-CS0001')));
    await press(t, find.text('Đặt lịch theo sân'));
    expect(find.byType(FacilityBookingScreen), findsOneWidget);
    expect(
      t.widget<FacilityBookingScreen>(find.byType(FacilityBookingScreen)).id,
      'CS0001',
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Map is embedded, pans, zooms, filters and opens correct detail',
    (t) async {
      await home(t);
      expect(maps.addressCalls, 0);
      expect(maps.gpsCalls, 0);
      await press(t, find.text('Bản đồ').last);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const Key('map-marker-cong-thuong')), findsOneWidget);
      final map = t.widget<FlutterMap>(find.byType(FlutterMap));
      final controller = map.mapController!;
      final zoom = controller.camera.zoom;
      await press(t, find.byTooltip('Phóng to'));
      expect(controller.camera.zoom, zoom + 1);
      final center = controller.camera.center;
      await t.drag(find.byType(FlutterMap), const Offset(-70, 80));
      await t.pumpAndSettle();
      expect(controller.camera.center, isNot(center));
      await press(t, find.byKey(const Key('map-sport-Bóng đá')));
      expect(find.text('Không tìm thấy địa chỉ phù hợp.'), findsOneWidget);
      expect(find.byKey(const Key('map-marker-cong-thuong')), findsNothing);
      await press(t, find.byKey(const Key('map-sport-all')));
      await press(t, find.byKey(const Key('customer-book-cong-thuong')));
      expect(find.byType(CustomerVenueDetailScreen), findsOneWidget);
      expect(maps.gpsCalls, 0);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'GPS is requested only after tapping, permission denial is recoverable',
    (t) async {
      await home(t);
      await press(t, find.text('Bản đồ').last);
      maps.denied = true;
      await press(t, find.byKey(const Key('map-locate')));
      expect(maps.gpsCalls, 1);
      expect(
        find.text(
          'Chưa được cấp quyền vị trí. Bạn vẫn có thể xem bản đồ và tìm sân.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-user-position')), findsNothing);
      maps.denied = false;
      await press(t, find.byKey(const Key('map-locate')));
      expect(find.byKey(const Key('map-user-position')), findsOneWidget);
      expect(find.text('Vị trí hiện tại của bạn'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Map search, clear, coordinate failure and retry retain the venue',
    (t) async {
      maps.noCoordinates = true;
      await home(t);
      await press(t, find.text('Bản đồ').last);
      expect(find.text('Chưa xác định được tọa độ sân.'), findsOneWidget);
      expect(find.byKey(const Key('map-marker-cong-thuong')), findsNothing);
      maps.noCoordinates = false;
      await press(t, find.text('Thử lại'));
      expect(find.byKey(const Key('map-marker-cong-thuong')), findsOneWidget);
      await t.enterText(find.byKey(const Key('map-search')), 'khong ton tai');
      await t.pumpAndSettle();
      expect(find.text('Không tìm thấy địa chỉ phù hợp.'), findsOneWidget);
      await press(t, find.byTooltip('Xóa tìm kiếm'));
      expect(find.byKey(const Key('map-marker-cong-thuong')), findsOneWidget);
      await press(t, find.byTooltip('Danh sách sân'));
      await press(t, find.byKey(const Key('map-select-cong-thuong')));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Map lookup deadline ends loading and permits retry', (t) async {
    maps.pending = Completer<LatLng?>();
    await home(t);
    await press(t, find.text('Bản đồ').last);
    expect(find.text('Đang xác định vị trí sân...'), findsOneWidget);
    await t.pump(const Duration(seconds: 19));
    await t.pumpAndSettle();
    expect(find.text('Đang xác định vị trí sân...'), findsNothing);
    expect(find.text('Chưa xác định được tọa độ sân.'), findsOneWidget);
    maps.pending!.complete(null);
    maps.pending = null;
    await press(t, find.text('Thử lại'));
    expect(find.byKey(const Key('map-marker-cong-thuong')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Map submits address with pin and retries a local venue search', (
    t,
  ) async {
    maps.noCoordinates = true;
    await home(t);
    await press(t, find.text('Bản đồ').last);
    maps.noCoordinates = false;
    await t.enterText(find.byKey(const Key('map-search')), 'Công Thương');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('map-marker-cong-thuong')), findsOneWidget);
    await t.enterText(find.byKey(const Key('map-search')), '140 Lê Trọng Tấn');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('map-search-position')), findsOneWidget);
    final map = t.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center.latitude, closeTo(10.8006, .0001));
    expect(find.text('Đã ghim kết quả địa chỉ trên bản đồ.'), findsOneWidget);
    await t.enterText(find.byKey(const Key('map-search')), 'khác');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('map-search-position')), findsNothing);
    expect(t.takeException(), isNull);
  });
  for (final viewport in [(402.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
    for (final tab in ['Khám phá', 'Nổi bật', 'Bản đồ']) {
      testWidgets('$tab renders ${viewport.$1}/${viewport.$2}', (t) async {
        final (_, key) = await home(t, width: viewport.$1, scale: viewport.$2);
        await press(t, find.text(tab).last);
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pumpAndSettle();
        await captureHome(
          key,
          'customer-${tab == 'Khám phá'
              ? 'explore'
              : tab == 'Nổi bật'
              ? 'featured'
              : 'map-fixture'}-${viewport.$1.toInt()}-${viewport.$2}',
          t,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('New venue detail renders at text scale $scale', (t) async {
      final (_, key) = await home(t, width: 320, scale: scale);
      await press(t, find.text('Nổi bật').last);
      await press(t, find.byKey(const Key('featured-poster-cong-thuong')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pumpAndSettle();
      await captureHome(key, 'customer-detail-320-$scale', t);
      expect(t.takeException(), isNull);
      await press(t, find.byKey(const Key('customer-detail-book')));
      await press(t, find.text('Đặt lịch theo sân'));
      expect(find.byType(BookingScheduleScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
