import 'package:flutter/foundation.dart';
import 'package:nexo/shared/models/cart_item.dart';

class CartController extends ChangeNotifier {
  final List<CartItem> _items = [];
  int? _businessId;

  List<CartItem> get items => List.unmodifiable(_items);
  int? get businessId => _businessId;
  bool get isEmpty => _items.isEmpty;
  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal =>
      _items.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));
  double get shipping => _items.isEmpty ? 0 : 15;
  double get total => subtotal + shipping;

  bool canAddFromBusiness(int businessId) {
    return _businessId == null || _businessId == businessId;
  }

  bool addItem({
    required int businessId,
    required CartItem item,
  }) {
    if (!canAddFromBusiness(businessId)) {
      return false;
    }

    _businessId ??= businessId;

    final index = _items.indexWhere((cartItem) => cartItem.cartKey == item.cartKey);
    if (index == -1) {
      _items.add(item);
    } else {
      _items[index].quantity++;
    }

    notifyListeners();
    return true;
  }

  void increaseQuantity(String cartKey) {
    final index = _items.indexWhere((item) => item.cartKey == cartKey);
    if (index == -1) return;

    _items[index].quantity++;
    notifyListeners();
  }

  void decreaseQuantity(String cartKey) {
    final index = _items.indexWhere((item) => item.cartKey == cartKey);
    if (index == -1) return;

    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
      if (_items.isEmpty) {
        _businessId = null;
      }
    }

    notifyListeners();
  }

  void clear() {
    _items.clear();
    _businessId = null;
    notifyListeners();
  }
}
