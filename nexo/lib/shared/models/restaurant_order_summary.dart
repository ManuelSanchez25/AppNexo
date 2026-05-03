class RestaurantOrderSummary {
  final String orderId;
  final int businessId;
  final String businessName;
  final String customerName;
  final String status;
  final double total;
  final DateTime? createdAt;
  final int itemsCount;

  RestaurantOrderSummary({
    required this.orderId,
    required this.businessId,
    required this.businessName,
    required this.customerName,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.itemsCount,
  });

  factory RestaurantOrderSummary.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderSummary(
      orderId: (json['orderId'] ?? '').toString(),
      businessId: (json['businessId'] ?? 0) as int,
      businessName: (json['businessName'] ?? '') as String,
      customerName: (json['customerName'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      total: ((json['total'] ?? 0) as num).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      itemsCount: (json['itemsCount'] ?? 0) as int,
    );
  }
}
