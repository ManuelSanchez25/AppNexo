class CartItem {
  final String cartKey;
  final int id;
  final String name;
  final String description;
  final double basePrice;
  final String? image;
  final List<CartSelectedOption> selectedOptions;
  int quantity;

  CartItem({
    required this.cartKey,
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    this.image,
    this.selectedOptions = const [],
    this.quantity = 1,
  });

  double get optionsPrice =>
      selectedOptions.fold(0, (sum, option) => sum + option.priceDelta);

  double get unitPrice => basePrice + optionsPrice;

  String get customizationSummary {
    if (selectedOptions.isEmpty) return '';
    return selectedOptions.map((option) => option.name).join(', ');
  }
}

class CartSelectedOption {
  final int id;
  final String groupName;
  final String name;
  final double priceDelta;

  const CartSelectedOption({
    required this.id,
    required this.groupName,
    required this.name,
    required this.priceDelta,
  });
}
