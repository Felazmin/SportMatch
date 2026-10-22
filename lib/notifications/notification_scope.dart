import 'package:flutter/widgets.dart';

import 'notification_center.dart';

class NotificationScope extends InheritedWidget {
  const NotificationScope({
    super.key,
    required this.center,
    required super.child,
  });
  final NotificationCenter center;
  static NotificationCenter? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationScope>()?.center;
  @override
  bool updateShouldNotify(NotificationScope oldWidget) =>
      center != oldWidget.center;
}
