class CreateOrderResponse {
  final String orderId;
  final int businessId;
  final int? driverUserId;
  final String status;
  final String paymentStatus;
  final String deliveryPin;
  final String cancelledBy;
  final String cancellationReason;
  final double subtotal;
  final double shipping;
  final double total;
  final int addressId;
  final String deliveryLabel;
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddressText;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final List<CreateOrderItemResponse> items;

  CreateOrderResponse({
    required this.orderId,
    required this.businessId,
    required this.driverUserId,
    required this.status,
    this.paymentStatus = '',
    this.deliveryPin = '',
    this.cancelledBy = '',
    this.cancellationReason = '',
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.addressId,
    required this.deliveryLabel,
    required this.recipientName,
    required this.recipientPhone,
    required this.deliveryAddressText,
    required this.createdAt,
    this.deliveredAt,
    required this.items,
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrderResponse(
      orderId: (json['orderId'] ?? '').toString(),
      businessId: (json['businessId'] ?? 0) as int,
      driverUserId: json['driverUserId'] as int?,
      status: (json['status'] ?? '') as String,
      paymentStatus: (json['paymentStatus'] ?? '') as String,
      deliveryPin: (json['deliveryPin'] ?? '') as String,
      cancelledBy: (json['cancelledBy'] ?? '') as String,
      cancellationReason: (json['cancellationReason'] ?? '') as String,
      subtotal: ((json['subtotal'] ?? 0) as num).toDouble(),
      shipping: ((json['shipping'] ?? 0) as num).toDouble(),
      total: ((json['total'] ?? 0) as num).toDouble(),
      addressId: (json['addressId'] ?? 0) as int,
      deliveryLabel: (json['deliveryLabel'] ?? '') as String,
      recipientName: (json['recipientName'] ?? '') as String,
      recipientPhone: (json['recipientPhone'] ?? '') as String,
      deliveryAddressText: (json['deliveryAddressText'] ?? '') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.tryParse(json['deliveredAt'].toString())
          : null,
      items: ((json['items'] ?? const []) as List)
          .map(
            (e) => CreateOrderItemResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CreateOrderItemResponse {
  final int productId;
  final String name;
  final double price;
  final int quantity;
  final double lineTotal;
  final String imageUrl;
  final List<CreateOrderItemOptionResponse> selectedOptions;

  CreateOrderItemResponse({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.lineTotal,
    required this.imageUrl,
    required this.selectedOptions,
  });

  factory CreateOrderItemResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrderItemResponse(
      productId: json['productId'] as int,
      name: (json['name'] ?? '') as String,
      price: ((json['price'] ?? 0) as num).toDouble(),
      quantity: json['quantity'] as int,
      lineTotal: ((json['lineTotal'] ?? 0) as num).toDouble(),
      imageUrl: ((json['imageUrl'] ?? json['image']) ?? '') as String,
      selectedOptions: ((json['selectedOptions'] ?? const []) as List)
          .map(
            (e) => CreateOrderItemOptionResponse.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CreateOrderItemOptionResponse {
  final String groupName;
  final String name;
  final double priceDelta;

  CreateOrderItemOptionResponse({
    required this.groupName,
    required this.name,
    required this.priceDelta,
  });

  factory CreateOrderItemOptionResponse.fromJson(Map<String, dynamic> json) {
    return CreateOrderItemOptionResponse(
      groupName: (json['groupName'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      priceDelta: ((json['priceDelta'] ?? 0) as num).toDouble(),
    );
  }
}
