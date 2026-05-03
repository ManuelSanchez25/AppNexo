class OrderHistoryItem {
  final String orderId;
  final String status;
  final double subtotal;
  final double shipping;
  final double total;
  final DateTime createdAt;
  final int itemsCount;

  OrderHistoryItem({
    required this.orderId,
    required this.status,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.createdAt,
    required this.itemsCount,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return OrderHistoryItem(
      orderId: (json['orderId'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      subtotal: ((json['subtotal'] ?? 0) as num).toDouble(),
      shipping: ((json['shipping'] ?? 0) as num).toDouble(),
      total: ((json['total'] ?? 0) as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      itemsCount: (json['itemsCount'] ?? 0) as int,
    );
  }
}
