import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/features/cart/application/cart_controller.dart';
import 'package:nexo/shared/models/cart_item.dart';

void main() {
  group('CartController', () {
    test('combina solo configuraciones identicas', () {
      final cart = CartController();

      expect(cart.addItem(businessId: 1, item: _item('10:1')), isTrue);
      expect(cart.addItem(businessId: 1, item: _item('10:1')), isTrue);
      expect(cart.addItem(businessId: 1, item: _item('10:2')), isTrue);

      expect(cart.items, hasLength(2));
      expect(cart.items.first.quantity, 2);
      expect(cart.totalItems, 3);
    });

    test('no mezcla productos de negocios diferentes', () {
      final cart = CartController();

      expect(cart.addItem(businessId: 1, item: _item('10')), isTrue);
      expect(cart.addItem(businessId: 2, item: _item('20')), isFalse);

      expect(cart.businessId, 1);
      expect(cart.items, hasLength(1));
    });

    test('libera el negocio al retirar el ultimo producto', () {
      final cart = CartController();
      cart.addItem(businessId: 1, item: _item('10'));

      cart.decreaseQuantity('10');

      expect(cart.isEmpty, isTrue);
      expect(cart.businessId, isNull);
      expect(cart.addItem(businessId: 2, item: _item('20')), isTrue);
    });

    test('limita cada configuracion a 20 unidades', () {
      final cart = CartController();
      cart.addItem(businessId: 1, item: _item('10'));

      for (var i = 1; i < CartController.maxQuantityPerItem; i++) {
        cart.increaseQuantity('10');
      }
      cart.increaseQuantity('10');

      expect(cart.items.single.quantity, CartController.maxQuantityPerItem);
      expect(cart.addItem(businessId: 1, item: _item('10')), isFalse);
    });
  });
}

CartItem _item(String cartKey) {
  return CartItem(
    cartKey: cartKey,
    id: 10,
    name: 'Producto',
    description: 'Prueba',
    basePrice: 100,
  );
}
