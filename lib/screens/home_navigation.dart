import 'package:flutter/material.dart';

class HomeNavigation extends InheritedWidget {
  const HomeNavigation({
    super.key,
    required this.goHome,
    this.goToTab,
    required super.child,
  });
  final VoidCallback goHome;
  final ValueChanged<int>? goToTab;
  static void openTab(BuildContext context, int index) {
    if (index < 0 || index > 4) return;
    final navigation = context.getInheritedWidgetOfExactType<HomeNavigation>();
    if (navigation?.goToTab == null) {
      if (index == 0) returnHome(context);
      return;
    }
    navigation!.goToTab!(index);
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  static void returnHome(BuildContext context) {
    context.getInheritedWidgetOfExactType<HomeNavigation>()?.goHome();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  bool updateShouldNotify(HomeNavigation oldWidget) => false;
}
