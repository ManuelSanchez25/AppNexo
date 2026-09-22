import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/orders/data/order_api.dart';
import 'package:nexo/features/orders/presentation/order_received_page.dart';
import 'package:nexo/shared/models/order_history_item.dart';

class OrdersHistoryPage extends StatefulWidget {
  const OrdersHistoryPage({super.key});

  @override
  State<OrdersHistoryPage> createState() => _OrdersHistoryPageState();
}

class _OrdersHistoryPageState extends State<OrdersHistoryPage>
    with WidgetsBindingObserver {
  Future<List<OrderHistoryItem>>? _future;
  Timer? _refreshTimer;
  bool _observerRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _loadOrders();
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _reloadSilently(),
    );
  }

  Future<List<OrderHistoryItem>> _loadOrders() {
    final authController = AuthScope.of(context);
    final token = authController.token;
    if (token == null || token.isEmpty) {
      return Future.error('Tu sesion no es valida');
    }
    return OrderApi.getMyOrders(token: token);
  }

  Future<void> _reload() async {
    final future = _loadOrders();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _reloadSilently() async {
    if (!mounted) return;
    setState(() {
      _future = _loadOrders();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadSilently();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);

    return Scaffold(
      body: FutureBuilder<List<OrderHistoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Mis pedidos',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0x33F2C21A)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x14F2C21A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x4DF2C21A)),
                        ),
                        child: const Text(
                          'NEXO',
                          style: TextStyle(
                            color: Color(0xFFF2C21A),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Todo lo que pediste,\nordenado y a la mano.',
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Abre cualquier pedido para revisar productos, extras y total.',
                        style: TextStyle(
                          color: Color(0xFFD3D0CB),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _MiniMetric(
                        value: orders.length.toString(),
                        label: 'Pedidos',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (orders.isEmpty)
                  const _EmptyOrdersState()
                else
                  ...orders.map((order) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () async {
                            final detail = await OrderApi.getOrderDetail(
                              token: authController.token!,
                              orderId: order.orderId,
                            );
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderReceivedPage(
                                  orderId: detail.orderId,
                                  status: detail.status,
                                  items: detail.items,
                                  subtotal: detail.subtotal,
                                  shipping: detail.shipping,
                                  total: detail.total,
                                  deliveryLabel: detail.deliveryLabel,
                                  recipientName: detail.recipientName,
                                  recipientPhone: detail.recipientPhone,
                                  deliveryAddressText:
                                      detail.deliveryAddressText,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Pedido #${order.orderId}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    _StatusChip(status: order.status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _formatDate(order.createdAt),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF777777),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${order.itemsCount} producto(s)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '\$${order.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }
}

class _MiniMetric extends StatelessWidget {
  final String value;
  final String label;

  const _MiniMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x20F2C21A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF2C21A),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFFD3D0CB))),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'preparing' => 'Preparando',
      'ready' => 'Listo',
      'driver_assigned' => 'Por recoger',
      'on_the_way' => 'En camino',
      'delivered' => 'Entregado',
      'cancelled' => 'Cancelado',
      _ => 'Recibido',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22F2C21A)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2A2419),
        ),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x14F2C21A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 46, color: Color(0xFFF2C21A)),
          SizedBox(height: 14),
          Text(
            'Aun no tienes pedidos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Cuando hagas tu primera orden aparecera aqui para consultarla cuando quieras.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
