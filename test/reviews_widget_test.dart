import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/reviews_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

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
  (DemoSession, String) fixture() {
    var now = DateTime(2026, 10, 7, 10);
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    s.login(DemoSession.phone, DemoSession.password);
    final b = s.reserve(
      court: 2,
      start: now.add(const Duration(days: 1)),
      hours: 1,
      contact: 'Test User',
      contactPhone: DemoSession.phone,
    );
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.confirmVenuePayment(b);
    now = b.start;
    s.setAttendance(b.id, DemoAttendance.checkedIn);
    now = b.end;
    s.setAttendance(b.id, DemoAttendance.completed);
    s.login(DemoSession.phone, DemoSession.password);
    return (s, b.id);
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(scale == 1 ? 402 : 320, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
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
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Write review with stars and validation; list updates', (
    t,
  ) async {
    final (s, id) = fixture();
    await pump(t, ReviewFormScreen(session: s, bookingId: id));
    await press(t, 'review-submit');
    expect(s.publicReviews, isEmpty);
    await t.enterText(
      find.byKey(const Key('review-message')),
      'Good court and friendly service',
    );
    await press(t, 'review-star-3');
    await press(t, 'review-submit');
    expect(s.publicReviews.single.stars, 3);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Admin searches, hides with reason; player sees own hidden review',
    (t) async {
      final (s, id) = fixture();
      s.submitVenueReview(id, 3, 'Good court and friendly service');
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await pump(t, ReviewsScreen(session: s, admin: true));
      await t.enterText(find.byKey(const Key('reviews-search')), 'no match');
      await t.pumpAndSettle();
      expect(find.text('Không có đánh giá phù hợp.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('reviews-search')), 'friendly');
      await t.pumpAndSettle();
      await press(t, 'review-$id');
      await press(t, 'review-moderate');
      await t.enterText(
        find.byType(TextField).last,
        'Contains personal information',
      );
      await t.tap(find.text('Xác nhận'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(s.publicReviews, isEmpty);
      s.login(DemoSession.phone, DemoSession.password);
      await pump(t, ReviewsScreen(session: s));
      expect(find.text('Đánh giá của bạn đã ẩn'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Account switch hides private review draft', (t) async {
    final (s, id) = fixture();
    await pump(t, ReviewFormScreen(session: s, bookingId: id));
    await t.enterText(
      find.byKey(const Key('review-message')),
      'Private unfinished draft',
    );
    s.register('Other', 'other@example.com', 'Test1234');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('review-message')), findsNothing);
    expect(find.byKey(const Key('review-submit')), findsNothing);
    expect(s.publicReviews, isEmpty);
  });
  testWidgets('Role switch during confirmation cannot moderate', (t) async {
    final (s, id) = fixture();
    s.submitVenueReview(id, 4, 'Good court and friendly service');
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(t, ReviewDetailScreen(session: s, bookingId: id, admin: true));
    await press(t, 'review-moderate');
    await t.enterText(
      find.byType(TextField).last,
      'Contains personal information',
    );
    await t.tap(find.byKey(const Key('finance-text-confirm')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.publicReviews.single.hidden, isFalse);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Hidden review unavailable to guest; management link opens queue',
    (t) async {
      final (s, id) = fixture();
      s.submitVenueReview(id, 4, 'Good court and friendly service');
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.moderateVenueReview(
        id,
        hidden: true,
        reason: 'Personal information',
        expectedRevision: 0,
      );
      await pump(t, ManagementScreen(session: s));
      await press(t, 'management-review-moderation');
      expect(find.byType(ReviewsScreen), findsOneWidget);
      s.logout();
      await pump(t, ReviewDetailScreen(session: s, bookingId: id));
      expect(find.text('Good court and friendly service'), findsNothing);
      expect(find.byKey(const Key('review-record-link')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    for (final view in ['detail', 'form']) {
      testWidgets('Review $view fits scale $scale', (t) async {
        final (s, id) = fixture();
        Widget screen = ReviewFormScreen(session: s, bookingId: id);
        if (view == 'detail') {
          s.submitVenueReview(id, 4, 'Good court and friendly service');
          s.loginStaff(
            DemoRole.admin,
            DemoSession.adminEmail,
            DemoSession.password,
          );
          screen = ReviewDetailScreen(session: s, bookingId: id, admin: true);
        }
        final key = await pump(t, screen, scale: scale);
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'review-$view-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 5; i++) {
          await t.drag(find.byType(ListView), const Offset(0, -250));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'review-$view-bottom-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
      });
    }
  }
}
