import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/events_screen.dart';
import 'package:test_do_an/screens/auth_screen.dart';
import 'package:test_do_an/screens/booking_screen.dart';
import 'package:test_do_an/screens/demo_account_screens.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession session({TestSessionStore? store, DateTime Function()? clock}) {
    final s = DemoSession(
      now: clock ?? () => DateTime(2026, 10, 6, 10),
      store: store,
    );
    addTearDown(s.dispose);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
    double scale = 1,
    Size size = const Size(402, 879),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
    await t.pumpAndSettle();
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    return key;
  }

  Future<void> press(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  DemoParticipation join(DemoSession s) => s.joinEvent(
    eventId: demoEvents.first.id,
    start: demoEvents.first.start(s.now),
    quantity: 1,
    contact: 'User',
    contactPhone: DemoSession.phone,
  );
  testWidgets('Search, category tabs and ticket booking through cancellation', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final key = await pump(t, EventsScreen(session: s));
    await captureHome(key, 'events-list', t);
    await t.enterText(find.byKey(const Key('events-search')), 'buoi toi');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('event-social-evening')), findsOneWidget);
    expect(find.byKey(const Key('event-social-morning')), findsNothing);
    await press(t, find.byKey(const Key('event-social-evening')));
    await captureHome(key, 'events-detail', t);
    await press(t, find.byKey(const Key('event-register')));
    await captureHome(key, 'events-registration', t);
    await press(t, find.byKey(const Key('event-submit')));
    await press(t, find.byKey(const Key('event-confirm')));
    expect(s.participations.length, 1);
    expect(find.text('Đăng ký thành công'), findsOneWidget);
    await captureHome(key, 'events-ticket', t);
    await press(t, find.byKey(const Key('participation-qr')));
    expect(find.byType(QrImageView), findsOneWidget);
    final payload = s.participations.single.qrPayload;
    expect(
      Uri.parse(payload).queryParameters['id'],
      s.participations.single.id,
    );
    expect(payload.contains(DemoSession.phone), isFalse);
    await captureHome(key, 'events-qr', t);
    await press(t, find.text('Đóng'));
    await press(t, find.byKey(const Key('participation-cancel')));
    await press(t, find.byKey(const Key('participation-confirm')));
    expect(s.participations.single.cancelled, isTrue);
    expect(find.text('Đã hủy'), findsOneWidget);
    expect(find.byKey(const Key('participation-cancel')), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('Tournament validates team and partner then registers a team', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final key = await pump(
      t,
      EventsScreen(session: s, initialKind: DemoEventKind.tournament),
    );
    await captureHome(key, 'tournament-list', t);
    await press(t, find.byKey(const Key('event-tournament-doubles')));
    await press(t, find.byKey(const Key('event-register')));
    await press(t, find.byKey(const Key('event-submit')));
    expect(s.participations, isEmpty);
    await t.drag(find.byType(ListView), const Offset(0, 5000));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('tournament-year')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.enterText(find.byKey(const Key('tournament-year')), '1995');
    await t.ensureVisible(find.byKey(const Key('tournament-email')));
    await t.enterText(
      find.byKey(const Key('tournament-email')),
      'test@example.com',
    );
    if (find.byKey(const Key('event-team')).evaluate().isEmpty) {
      await t.scrollUntilVisible(
        find.byKey(const Key('event-team')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(find.byKey(const Key('event-team')));
    await t.enterText(find.byKey(const Key('event-team')), 'NVH Team');
    await t.enterText(find.byKey(const Key('event-partner')), 'Minh');
    await press(t, find.byKey(const Key('tournament-terms')));
    await press(t, find.byKey(const Key('event-submit')));
    expect(s.participations.single.team, 'NVH Team');
    expect(s.participations.single.total, 150000);
    expect(t.takeException(), isNull);
  });
  testWidgets('Guest authentication continues registration', (t) async {
    final s = session();
    await pump(
      t,
      EventDetailScreen(
        session: s,
        event: demoEvents.first,
        start: demoEvents.first.start(s.now),
      ),
    );
    await press(t, find.byKey(const Key('event-register')));
    expect(find.byType(AuthScreen), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('auth-identifier')),
      DemoSession.phone,
    );
    await t.enterText(
      find.byKey(const Key('auth-password')),
      DemoSession.password,
    );
    await press(t, find.byKey(const Key('auth-submit')));
    expect(find.byType(EventRegistrationScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Failed save displays retry without creating duplicate ticket', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = session(store: store);
    await s.initialize();
    s.login(DemoSession.phone, DemoSession.password);
    await s.flush();
    store.failWrite = true;
    await pump(
      t,
      EventRegistrationScreen(
        session: s,
        event: demoEvents.first,
        start: demoEvents.first.start(s.now),
      ),
    );
    await press(t, find.byKey(const Key('event-submit')));
    await press(t, find.byKey(const Key('event-confirm')));
    expect(find.text('Đăng ký đang chờ lưu'), findsOneWidget);
    expect(find.byKey(const Key('event-retry-save')), findsOneWidget);
    store.failWrite = false;
    await press(t, find.byKey(const Key('event-retry-save')));
    expect(s.participations.length, 1);
    expect(s.saveFailed, isFalse);
    expect(find.text('Đăng ký thành công'), findsOneWidget);
  });
  testWidgets('Check-in simulation and My events filters', (t) async {
    var now = DateTime(2026, 10, 6, 10);
    final s = session(clock: () => now)
      ..login(DemoSession.phone, DemoSession.password);
    final p = join(s);
    now = p.start;
    await pump(t, ParticipationDetailScreen(session: s, participation: p));
    await press(t, find.byKey(const Key('participation-check-in')));
    await press(t, find.byKey(const Key('participation-confirm')));
    expect(p.checkedIn, isTrue);
    expect(find.byKey(const Key('participation-check-in')), findsNothing);
    await pump(t, MyEventsScreen(session: s));
    expect(find.byKey(Key('my-event-${p.id}')), findsOneWidget);
    await press(t, find.byKey(const Key('my-events-cancelled')));
    expect(find.text('Chưa có đăng ký trong mục này.'), findsOneWidget);
  });
  testWidgets('Home and account provide event entry points', (t) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    t.view.physicalSize = const Size(402, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MyApp(session: s));
    await t.pumpAndSettle();
    await press(t, find.byKey(const Key('home-tournaments')));
    expect(find.byKey(const Key('event-tournament-doubles')), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, find.text('Tài khoản').last);
    await press(t, find.text('Vé & lịch tham gia'));
    expect(find.byType(MyEventsScreen), findsOneWidget);
  });
  for (final screen in [
    'list',
    'detail',
    'register',
    'mine',
    'ticket',
    'tournament',
  ]) {
    testWidgets('Event $screen fits 320px at 200 percent text', (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final p = join(s);
      final e = demoEvents.first;
      final widget = switch (screen) {
        'list' => EventsScreen(session: s),
        'detail' => EventDetailScreen(session: s, event: e, start: p.start),
        'register' => EventRegistrationScreen(
          session: s,
          event: e,
          start: p.start,
        ),
        'mine' => MyEventsScreen(session: s),
        'ticket' => ParticipationDetailScreen(session: s, participation: p),
        _ => EventRegistrationScreen(
          session: s,
          event: demoEvents.last,
          start: demoEvents.last.start(s.now),
        ),
      };
      final key = await pump(t, widget, size: const Size(320, 879), scale: 2);
      await captureHome(key, 'events-$screen-large', t);
      await t.drag(find.byType(ListView).first, const Offset(0, -500));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'Success Home selects Home even when booking starts in Featured',
    (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      await t.pumpWidget(MyApp(session: s));
      await t.pumpAndSettle();
      for (final finder in [
        find.text('Nổi bật').last,
        find.text('Xem tất cả').first,
        find.byKey(const Key('venue-result-cong-thuong')),
        find.byKey(const Key('venue-book')),
        find.text('Đặt lịch theo sân'),
        find.byKey(const Key('booking-day-1')),
        find.byKey(const Key('booking-hour-12')),
        find.byKey(const Key('booking-continue')),
        find.byKey(const Key('checkout-terms')),
        find.byKey(const Key('booking-confirm')),
      ]) {
        await press(t, finder);
      }
      final b = s.bookings.firstWhere(
        (b) => s.workflowPayment(b.id)?.checkout == true,
      );
      final proof = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      s.saveProofDraft(b, proof);
      s.saveStudentDraft(b, proof);
      await press(t, find.byKey(const Key('payment-submit-proof')));
      await press(t, find.text('Trang chủ'));
      expect(
        find.byKey(const Key('browse-search')).hitTestable(),
        findsNothing,
      );
      expect(find.text('Vị trí của bạn'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Settings actually clears optional phone', (t) async {
    final s = session()
      ..register('User', 'user@example.com', 'Test1234')
      ..updateContactPhone('0912345678');
    await pump(t, AccountSettingsScreen(session: s));
    await t.enterText(find.byKey(const Key('settings-phone')), '');
    await press(t, find.byKey(const Key('settings-save')));
    expect(s.contactPhone, '');
    expect(find.text('Đã lưu cài đặt.'), findsOneWidget);
  });
  for (final field in ['name', 'password']) {
    testWidgets(
      'Overlong $field shows validation rather than duplicate error',
      (t) async {
        final s = session();
        await pump(t, AuthScreen(session: s, register: true));
        await t.enterText(
          find.byKey(const Key('auth-name')),
          field == 'name' ? 'a' * 61 : 'Test User',
        );
        await t.enterText(
          find.byKey(const Key('auth-identifier')),
          '0912345678',
        );
        final secret = field == 'password' ? 'a' * 129 : 'Test1234';
        await t.enterText(find.byKey(const Key('auth-password')), secret);
        await t.enterText(find.byKey(const Key('auth-confirmation')), secret);
        await press(t, find.byKey(const Key('auth-consent')));
        await press(t, find.byKey(const Key('auth-submit')));
        expect(
          find.text('Số điện thoại hoặc email này đã được đăng ký.'),
          findsNothing,
        );
        expect(
          find.text(
            field == 'name'
                ? 'Họ tên tối đa 60 ký tự'
                : 'Mật khẩu tối đa 128 ký tự',
          ),
          findsOneWidget,
        );
        expect(s.user, isNull);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('Active booking and class are not labeled ended or upcoming', (
    t,
  ) async {
    var now = DateTime(2026, 10, 6, 10);
    final s = session(clock: () => now)
      ..login(DemoSession.phone, DemoSession.password);
    final b = s.reserve(
      court: 2,
      start: DateTime(2026, 10, 6, 12),
      hours: 2,
      contact: 'User',
      contactPhone: DemoSession.phone,
    );
    s.enroll('basic', DateTime(2026, 10, 8, 8));
    now = DateTime(2026, 10, 6, 12, 30);
    await pump(t, BookingDetailScreen(session: s, booking: b));
    expect(find.text('Đang diễn ra'), findsOneWidget);
    now = DateTime(2026, 10, 8, 8, 30);
    await pump(t, AcademyScreen(session: s));
    await press(t, find.text('Lịch của tôi'));
    expect(find.textContaining('Đang diễn ra'), findsOneWidget);
    expect(find.textContaining('Đã kết thúc'), findsNothing);
  });
  for (final register in [false, true]) {
    testWidgets('Auth large text has no overflows register=$register', (
      t,
    ) async {
      final key = await pump(
        t,
        AuthScreen(session: session(), register: register),
        scale: 2,
        size: const Size(320, 879),
      );
      await press(t, find.byKey(const Key('auth-submit')));
      await captureHome(key, 'auth-fixed-large-$register', t);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Venue catalog remains scrollable with landscape keyboard', (
    t,
  ) async {
    await pump(t, MyApp(session: session()), size: const Size(879, 402));
    await press(t, find.text('Nổi bật').last);
    await press(t, find.text('Xem tất cả').first);
    t.view.viewInsets = const FakeViewPadding(bottom: 220);
    await t.enterText(
      find.byKey(const Key('browse-search')).hitTestable(),
      'cong thuong',
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
