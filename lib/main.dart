import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'auth/demo_session.dart';
import 'auth/session_store.dart';
import 'venues/osm_venue_catalog.dart';
import 'demo/demo_finance.dart';
import 'demo/demo_seed_assets.dart';
import 'screens/home_navigation.dart';
import 'notifications/notification_center.dart';
import 'notifications/notification_store.dart';
import 'notifications/notification_scope.dart';
import 'notifications/reminder_gateway.dart';
import 'screens/notification_inbox_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.green,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final session = DemoSession(
    store: const SecureSessionStore(),
    venueCatalogLoader: loadOsmVenues,
    demoFixtureLoader: () async => (
      photo: encodeProof(
        (await rootBundle.load('assets/figma/c0697.png')).buffer.asUint8List(),
      ),
      proof: await createDemoSeedProof(),
    ),
  );
  runApp(
    MyApp(
      session: session,
      notificationCenter: NotificationCenter(
        session: session,
        store: NotificationStore(),
        gateway: LocalReminderGateway(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.session, this.notificationCenter});
  final DemoSession? session;
  final NotificationCenter? notificationCenter;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _home = GlobalKey<HomeScreenState>();
  final _navigator = GlobalKey<NavigatorState>();
  DemoSession? get session => widget.session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.notificationCenter?.onOpen = (notice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _navigator.currentContext;
        if (mounted && context != null && session != null) {
          unawaited(
            openBookingNotice(
              context,
              session!,
              widget.notificationCenter!,
              notice,
            ),
          );
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    };
    widget.notificationCenter?.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.notificationCenter?.sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.notificationCenter?.onOpen = null;
    widget.notificationCenter?.dispose();
    super.dispose();
  }

  Widget _notifications(Widget child) => widget.notificationCenter == null
      ? child
      : NotificationScope(center: widget.notificationCenter!, child: child);

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    title: 'NVH Sports',
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
      textTheme: ThemeData.light().textTheme
          .merge(
            const TextTheme(
              displayLarge: TextStyle(letterSpacing: 0),
              displayMedium: TextStyle(letterSpacing: 0),
              displaySmall: TextStyle(letterSpacing: 0),
              headlineLarge: TextStyle(letterSpacing: 0),
              headlineMedium: TextStyle(letterSpacing: 0),
              headlineSmall: TextStyle(letterSpacing: 0),
              titleLarge: TextStyle(letterSpacing: 0),
              titleMedium: TextStyle(letterSpacing: 0),
              titleSmall: TextStyle(letterSpacing: 0),
              bodyLarge: TextStyle(letterSpacing: 0),
              bodyMedium: TextStyle(letterSpacing: 0),
              bodySmall: TextStyle(letterSpacing: 0),
              labelLarge: TextStyle(letterSpacing: 0),
              labelMedium: TextStyle(letterSpacing: 0),
              labelSmall: TextStyle(letterSpacing: 0),
            ),
          )
          .apply(
            fontFamily: 'Inter',
            bodyColor: AppColors.ink,
            displayColor: AppColors.ink,
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    builder: (context, child) => _notifications(
      HomeNavigation(
        goHome: () => _home.currentState?.goHome(),
        goToTab: (index) => _home.currentState?.goToTab(index),
        child: session == null
            ? child!
            : ListenableBuilder(
                listenable: session!,
                builder: (context, _) => Column(
                  children: [
                    if (session!.saveFailed)
                      SafeArea(
                        bottom: false,
                        child: Material(
                          color: const Color(0xFFFFF3CD),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Chưa lưu được dữ liệu. Đừng đóng ứng dụng.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  key: const Key('storage-retry-save'),
                                  onPressed: session!.retrySave,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Expanded(child: child!),
                  ],
                ),
              ),
      ),
    ),
    home: HomeScreen(key: _home, session: session),
  );
}
