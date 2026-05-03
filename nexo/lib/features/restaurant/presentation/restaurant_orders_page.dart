import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/orders/data/order_api.dart';
import 'package:nexo/shared/models/create_order_response.dart';
import 'package:nexo/shared/models/restaurant_order_summary.dart';

class RestaurantOrdersPage extends StatefulWidget {
  const RestaurantOrdersPage({super.key});

  @override
  State<RestaurantOrdersPage> createState() => _RestaurantOrdersPageState();
}

class _RestaurantOrdersPageState extends State<RestaurantOrdersPage>
    with WidgetsBindingObserver {
  Future<List<RestaurantOrderSummary>>? _ordersFuture;
  Timer? _refreshTimer;
  bool _observerRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ordersFuture ??= _loadOrders();
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => _reloadSilently(),
    );
  }

  Future<List<RestaurantOrderSummary>> _loadOrders() {
    final token = AuthScope.of(context).token!;
    return OrderApi.getRestaurantOrders(token: token);
  }

  Future<void> _reload() async {
    final future = _loadOrders();
    setState(() => _ordersFuture = future);
    await future;
  }

  void _reloadSilently() {
    if (!mounted) return;
    setState(() => _ordersFuture = _loadOrders());
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

  Future<void> _openOrder(RestaurantOrderSummary summary) async {
    final token = AuthScope.of(context).token!;
    final detail = await OrderApi.getRestaurantOrderDetail(
      token: token,
      orderId: summary.orderId,
    );

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => _RestaurantOrderDetailSheet(
        summary: summary,
        detail: detail,
        onStatusChanged: (status) async {
          await OrderApi.updateRestaurantOrderStatus(
            token: token,
            orderId: summary.orderId,
            status: status,
          );
          await _reload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<RestaurantOrderSummary>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (_ordersFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];
          final activeOrders = orders
              .where((order) => order.status != 'delivered' && order.status != 'cancelled')
              .length;

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
                        'Pedidos',
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
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0x33F2C21A)),
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
                          'OPERACION',
                          style: TextStyle(
                            color: Color(0xFFF2C21A),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Supervisa tus pedidos y actualiza su estado.',
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Recibidos, preparando, listos o entregados. Todo desde un solo panel.',
                        style: TextStyle(
                          color: Color(0xFFD3D0CB),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _MetricCard(
                            label: 'Total',
                            value: orders.length.toString(),
                          ),
                          const SizedBox(width: 10),
                          _MetricCard(
                            label: 'Activos',
                            value: activeOrders.toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (orders.isEmpty)
                  const _EmptyRestaurantOrdersState()
                else
                  ...orders.map((order) {
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _openOrder(order),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0x14F2C21A)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.businessName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _StatusChip(status: order.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Pedido ${order.orderId}',
                                style: const TextStyle(
                                  color: Color(0xFF444444),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cliente: ${order.customerName}',
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${order.itemsCount} producto(s)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '\$${order.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              if (order.createdAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _formatDate(order.createdAt!),
                                  style: const TextStyle(
                                    color: Color(0xFF777777),
                                  ),
                                ),
                              ],
                            ],
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
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

class _RestaurantOrderDetailSheet extends StatefulWidget {
  final RestaurantOrderSummary summary;
  final CreateOrderResponse detail;
  final Future<void> Function(String status) onStatusChanged;

  const _RestaurantOrderDetailSheet({
    required this.summary,
    required this.detail,
    required this.onStatusChanged,
  });

  @override
  State<_RestaurantOrderDetailSheet> createState() =>
      _RestaurantOrderDetailSheetState();
}

class _RestaurantOrderDetailSheetState
    extends State<_RestaurantOrderDetailSheet> {
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.detail.status;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pedido ${widget.summary.orderId}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.summary.customerName,
              style: const TextStyle(color: Color(0xFF666666)),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: 'received', child: Text('Recibido')),
                DropdownMenuItem(value: 'preparing', child: Text('Preparando')),
                DropdownMenuItem(value: 'ready', child: Text('Listo')),
                DropdownMenuItem(value: 'delivered', child: Text('Entregado')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelado')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
              decoration: const InputDecoration(labelText: 'Estado del pedido'),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...widget.detail.items.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8E1D6)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.quantity} x ${item.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (item.selectedOptions.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.selectedOptions
                                        .map(
                                          (option) =>
                                              '${option.groupName}: ${option.name}',
                                        )
                                        .join(' · '),
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('\$${item.lineTotal.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DetailTotalRow(
                    label: 'Subtotal',
                    value: widget.detail.subtotal,
                  ),
                  const SizedBox(height: 8),
                  _DetailTotalRow(
                    label: 'Envio',
                    value: widget.detail.shipping,
                  ),
                  const SizedBox(height: 8),
                  _DetailTotalRow(
                    label: 'Total',
                    value: widget.detail.total,
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await widget.onStatusChanged(_status);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        } finally {
                          if (mounted) {
                            setState(() => _saving = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(_saving ? 'Guardando...' : 'Guardar estado'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFF2C21A),
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD3D0CB),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;

  const _DetailTotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasized ? 16 : 14,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      color: emphasized ? Colors.black : const Color(0xFF555555),
    );

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('\$${value.toStringAsFixed(2)}', style: style),
      ],
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
      'delivered' => 'Entregado',
      'cancelled' => 'Cancelado',
      _ => 'Recibido',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F1EC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x22F2C21A)),
        ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF2A2419),
        ),
      ),
    );
  }
}

class _EmptyRestaurantOrdersState extends StatelessWidget {
  const _EmptyRestaurantOrdersState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
          Icon(Icons.receipt_long_rounded, size: 46),
          SizedBox(height: 14),
          Text(
            'Todavia no hay pedidos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Cuando lleguen nuevas ordenes de tus negocios apareceran aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
