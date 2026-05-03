import 'package:flutter/material.dart';
import 'package:nexo/features/cart/application/cart_controller.dart';

class CartScope extends InheritedNotifier<CartController> {
  const CartScope({
    super.key,
    required CartController controller,
    required super.child,
  }) : super(notifier: controller);

  static CartController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope no encontrado en el árbol');
    return scope!.notifier!;
  }
}
