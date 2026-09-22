class RestaurantOrderSummary {
  final String orderId;
  final int businessId;
  final int? driverUserId;
  final String businessName;
  final String pickupAddressText;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String customerName;
  final String deliveryAddressText;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String status;
  final double total;
  final DateTime? createdAt;
  final int itemsCount;

  RestaurantOrderSummary({
    required this.orderId,
    required this.businessId,
    required this.driverUserId,
    required this.businessName,
    required this.pickupAddressText,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.customerName,
    required this.deliveryAddressText,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.itemsCount,
  });

  RestaurantOrderSummary copyWith({String? status}) {
    return RestaurantOrderSummary(
      orderId: orderId,
      businessId: businessId,
      driverUserId: driverUserId,
      businessName: businessName,
      pickupAddressText: pickupAddressText,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      customerName: customerName,
      deliveryAddressText: deliveryAddressText,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      status: status ?? this.status,
      total: total,
      createdAt: createdAt,
      itemsCount: itemsCount,
    );
  }

  factory RestaurantOrderSummary.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderSummary(
      orderId: (json['orderId'] ?? '').toString(),
      businessId: (json['businessId'] ?? 0) as int,
      driverUserId: json['driverUserId'] as int?,
      businessName: (json['businessName'] ?? '') as String,
      pickupAddressText: (json['pickupAddressText'] ?? '') as String,
      pickupLatitude: json['pickupLatitude'] == null
          ? null
          : (json['pickupLatitude'] as num).toDouble(),
      pickupLongitude: json['pickupLongitude'] == null
          ? null
          : (json['pickupLongitude'] as num).toDouble(),
      customerName: (json['customerName'] ?? '') as String,
      deliveryAddressText: (json['deliveryAddressText'] ?? '') as String,
      deliveryLatitude: json['deliveryLatitude'] == null
          ? null
          : (json['deliveryLatitude'] as num).toDouble(),
      deliveryLongitude: json['deliveryLongitude'] == null
          ? null
          : (json['deliveryLongitude'] as num).toDouble(),
      status: (json['status'] ?? '') as String,
      total: ((json['total'] ?? 0) as num).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      itemsCount: (json['itemsCount'] ?? 0) as int,
    );
  }
}
