class Product {
  final int id;
  final int businessId;
  final String name;
  final double price;
  final String description;
  final String image;
  final bool isAvailable;
  final List<ProductOptionGroup> optionGroups;

  Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.description,
    required this.image,
    required this.isAvailable,
    required this.optionGroups,
  });

  bool get hasCustomizations => optionGroups.isNotEmpty;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      businessId: (json['businessId'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      price: ((json['price'] ?? 0) as num).toDouble(),
      description: (json['description'] ?? '') as String,
      image: (json['image'] ?? '') as String,
      isAvailable: (json['isAvailable'] ?? true) as bool,
      optionGroups: ((json['optionGroups'] ?? const []) as List)
          .map(
            (item) =>
                ProductOptionGroup.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ProductOptionGroup {
  final int id;
  final int businessId;
  final String name;
  final bool isRequired;
  final int minSelections;
  final int maxSelections;
  final int sortOrder;
  final int assignedProductsCount;
  final bool isAssignedToProduct;
  final List<ProductOption> options;

  ProductOptionGroup({
    required this.id,
    required this.businessId,
    required this.name,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.sortOrder,
    required this.assignedProductsCount,
    required this.isAssignedToProduct,
    required this.options,
  });

  factory ProductOptionGroup.fromJson(Map<String, dynamic> json) {
    return ProductOptionGroup(
      id: json['id'] as int,
      businessId: (json['businessId'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      isRequired: (json['isRequired'] ?? false) as bool,
      minSelections: (json['minSelections'] ?? 0) as int,
      maxSelections: (json['maxSelections'] ?? 0) as int,
      sortOrder: (json['sortOrder'] ?? 0) as int,
      assignedProductsCount: (json['assignedProductsCount'] ?? 0) as int,
      isAssignedToProduct: (json['isAssignedToProduct'] ?? false) as bool,
      options: ((json['options'] ?? const []) as List)
          .map(
            (item) => ProductOption.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ProductOption {
  final int id;
  final String name;
  final double priceDelta;
  final bool isAvailable;
  final int sortOrder;

  ProductOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.isAvailable,
    required this.sortOrder,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      priceDelta: ((json['priceDelta'] ?? 0) as num).toDouble(),
      isAvailable: (json['isAvailable'] ?? true) as bool,
      sortOrder: (json['sortOrder'] ?? 0) as int,
    );
  }
}
