class DriverStats {
  final int availableOrders;
  final int activeOrders;
  final int acceptedOrders;
  final int deliveredOrders;
  final int deliveredToday;
  final double todayEarnings;
  final double totalEarnings;

  const DriverStats({
    required this.availableOrders,
    required this.activeOrders,
    required this.acceptedOrders,
    required this.deliveredOrders,
    required this.deliveredToday,
    required this.todayEarnings,
    required this.totalEarnings,
  });

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    return DriverStats(
      availableOrders: (json['availableOrders'] ?? 0) as int,
      activeOrders: (json['activeOrders'] ?? 0) as int,
      acceptedOrders: (json['acceptedOrders'] ?? 0) as int,
      deliveredOrders: (json['deliveredOrders'] ?? 0) as int,
      deliveredToday: (json['deliveredToday'] ?? 0) as int,
      todayEarnings: ((json['todayEarnings'] ?? 0) as num).toDouble(),
      totalEarnings: ((json['totalEarnings'] ?? 0) as num).toDouble(),
    );
  }
}
