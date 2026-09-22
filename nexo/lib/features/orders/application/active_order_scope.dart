import 'package:flutter/material.dart';
import 'package:nexo/features/orders/application/active_order_controller.dart';

class ActiveOrderScope extends InheritedNotifier<ActiveOrderController> {
  const ActiveOrderScope({
    super.key,
    required ActiveOrderController controller,
    required super.child,
  }) : super(notifier: controller);

  static ActiveOrderController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ActiveOrderScope>();
    assert(scope != null, 'ActiveOrderScope no encontrado en el arbol');
    return scope!.notifier!;
  }
}
