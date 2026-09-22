import 'package:flutter/material.dart';
import 'package:nexo/features/notifications/application/notification_controller.dart';

class NotificationScope extends InheritedNotifier<NotificationController> {
  const NotificationScope({
    super.key,
    required NotificationController controller,
    required super.child,
  }) : super(notifier: controller);

  static NotificationController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NotificationScope>();
    assert(scope != null, 'NotificationScope no encontrado en el arbol');
    return scope!.notifier!;
  }
}
