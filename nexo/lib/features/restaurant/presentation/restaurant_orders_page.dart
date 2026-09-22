import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/notifications/application/notification_controller.dart';
import 'package:nexo/features/notifications/application/notification_scope.dart';
import 'package:nexo/features/orders/data/order_api.dart';
import 'package:nexo/features/orders/data/order_realtime_client.dart';
import 'package:nexo/shared/models/create_order_response.dart';
import 'package:nexo/shared/models/restaurant_order_summary.dart';

class RestaurantOrdersPage extends StatefulWidget {
  const RestaurantOrdersPage({super.key});

  @override
  State<RestaurantOrdersPage> createState() => _RestaurantOrdersPageState();
}

class _RestaurantOrdersPageState extends State<RestaurantOrdersPage>
    with WidgetsBindingObserver {
  final OrderRealtimeClient _realtimeClient = createOrderRealtimeClient();
  List<RestaurantOrderSummary> _orders = [];
  final Set<String> _savingOrderIds = {};
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  late NotificationController _notifications;
  String? _loadedToken;
  String? _subscribedToken;
  Object? _loadError;
  bool _loading = true;
  bool _observerRegistered = false;
  bool _hasStatusChanges = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifications = NotificationScope.of(context);
    final token = AuthScope.of(context).token;
    if (token != null && token.isNotEmpty && _loadedToken != token) {
      _loadedToken = token;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_loadOrders());
      });
      _subscribeToRealtime(token);
    }

    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
  }

  Future<void> _loadOrders({bool silent = false}) async {
    final token = _loadedToken ?? AuthScope.of(context).token;
    if (token == null || token.isEmpty) return;

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final orders = await OrderApi.getRestaurantOrders(token: token);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  void _updateOrderStatusLocally(
    String orderId,
    String status, {
    RestaurantOrderSummary? fallbackOrder,
  }) {
    var foundOrder = false;
    final updatedOrders = _orders.map((order) {
      if (order.orderId != orderId) return order;

      foundOrder = true;
      return order.copyWith(status: status);
    }).toList();

    if (!foundOrder && fallbackOrder != null) {
      updatedOrders.insert(0, fallbackOrder.copyWith(status: status));
    }

    if (!mounted) return;
    setState(() => _orders = updatedOrders);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadOrders(silent: true));
    }
  }

  @override
  void dispose() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToRealtime(String token) {
    if (_realtimeSubscription != null && _subscribedToken == token) {
      return;
    }

    unawaited(_realtimeSubscription?.cancel());
    _subscribedToken = token;
    _realtimeSubscription = _realtimeClient.restaurantOrderEvents(token).listen(
      (event) {
        final type = event['type']?.toString();
        if (type == 'restaurant-order-updated') {
          final orderId = event['orderId']?.toString() ?? '';
          final status = event['status']?.toString() ?? '';
          _notifications.add(
            title: status == 'received'
                ? 'Nuevo pedido recibido'
                : 'Pedido actualizado',
            body: _restaurantNotificationBody(status),
            dedupeKey: 'restaurant:$orderId:$status',
          );
          unawaited(_loadOrders(silent: true));
        }
      },
    );
  }

  Future<void> _openOrder(RestaurantOrderSummary summary) async {
    final token = AuthScope.of(context).token!;
    final detail = await OrderApi.getRestaurantOrderDetail(
      token: token,
      orderId: summary.orderId,
    );

    if (!mounted) return;

    final changedStatus = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) =>
          _RestaurantOrderDetailSheet(summary: summary, detail: detail),
    );

    if (changedStatus != null && mounted) {
      await _changeOrderStatus(summary, changedStatus);
    }
  }

  Future<void> _changeOrderStatus(
    RestaurantOrderSummary order,
    String status,
  ) async {
    if (_savingOrderIds.contains(order.orderId) || order.status == status) {
      return;
    }

    final token = AuthScope.of(context).token;
    if (token == null || token.isEmpty) return;

    final previousStatus = order.status;
    _hasStatusChanges = true;

    setState(() => _savingOrderIds.add(order.orderId));
    _updateOrderStatusLocally(order.orderId, status, fallbackOrder: order);

    try {
      await OrderApi.updateRestaurantOrderStatus(
        token: token,
        orderId: order.orderId,
        status: status,
      );
      await _loadOrders(silent: true);
    } catch (error) {
      if (!mounted) return;
      _updateOrderStatusLocally(
        order.orderId,
        previousStatus,
        fallbackOrder: order,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el estado: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingOrderIds.remove(order.orderId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = _orders
        .where(
          (order) => order.status != 'delivered' && order.status != 'cancelled',
        )
        .length;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasStatusChanges);
        return false;
      },
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? _OrdersErrorState(error: _loadError!, onRetry: _loadOrders)
            : RefreshIndicator(
                onRefresh: _loadOrders,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              Navigator.pop(context, _hasStatusChanges),
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
                        IconButton(
                          tooltip: 'Actualizar',
                          onPressed: () => unawaited(_loadOrders()),
                          icon: const Icon(Icons.refresh_rounded),
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
                              border: Border.all(
                                color: const Color(0x4DF2C21A),
                              ),
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
                            'Sin refrescos forzados: actualiza por accion, realtime o deslizando.',
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
                                value: _orders.length.toString(),
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
                    if (_orders.isEmpty)
                      const _EmptyRestaurantOrdersState()
                    else
                      ..._orders.map(_buildOrderCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOrderCard(RestaurantOrderSummary order) {
    final nextStatus = _nextStatus(order);
    final isSaving = _savingOrderIds.contains(order.orderId);

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
                style: const TextStyle(color: Color(0xFF444444)),
              ),
              const SizedBox(height: 4),
              Text(
                'Cliente: ${order.customerName}',
                style: const TextStyle(color: Color(0xFF666666)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${order.itemsCount} producto(s)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
                  style: const TextStyle(color: Color(0xFF777777)),
                ),
              ],
              if (nextStatus != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () =>
                              unawaited(_changeOrderStatus(order, nextStatus)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isSaving ? 'Guardando...' : _nextActionLabel(order),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

String? _nextStatus(RestaurantOrderSummary order) {
  return switch (order.status) {
    'received' => 'preparing',
    'preparing' => 'ready',
    'driver_assigned' => 'on_the_way',
    _ => null,
  };
}

String _nextActionLabel(RestaurantOrderSummary order) {
  return switch (order.status) {
    'received' => 'Aceptar y preparar',
    'preparing' => 'Marcar como listo',
    'driver_assigned' => 'Entregar al repartidor',
    _ => 'Actualizar',
  };
}

String _restaurantNotificationBody(String status) {
  return switch (status) {
    'received' => 'Tienes un pedido nuevo por aceptar.',
    'preparing' => 'El pedido paso a preparacion.',
    'ready' => 'El pedido ya esta listo para repartidor.',
    'driver_assigned' => 'Un repartidor tomo el pedido.',
    'on_the_way' => 'El pedido fue entregado al repartidor.',
    'delivered' => 'El repartidor marco el pedido como entregado.',
    'cancelled' => 'El pedido fue cancelado.',
    _ => 'Hay un cambio nuevo en un pedido.',
  };
}

class _RestaurantOrderDetailSheet extends StatefulWidget {
  final RestaurantOrderSummary summary;
  final CreateOrderResponse detail;

  const _RestaurantOrderDetailSheet({
    required this.summary,
    required this.detail,
  });

  @override
  State<_RestaurantOrderDetailSheet> createState() =>
      _RestaurantOrderDetailSheetState();
}

class _RestaurantOrderDetailSheetState
    extends State<_RestaurantOrderDetailSheet> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.detail.status;
  }

  @override
  Widget build(BuildContext context) {
    final restaurantLocked = _status == 'on_the_way' || _status == 'delivered';

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
              onChanged: restaurantLocked
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
              items: _restaurantStatusItems(widget.detail.status),
              decoration: const InputDecoration(labelText: 'Estado del pedido'),
            ),
            if (restaurantLocked) ...[
              const SizedBox(height: 10),
              const Text(
                'El repartidor ya recibio este pedido. El restaurante ya no puede cambiar el estado.',
                style: TextStyle(
                  color: Color(0xFF7A5B00),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
                onPressed: () => Navigator.of(
                  context,
                ).pop(restaurantLocked ? null : _status),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(restaurantLocked ? 'Cerrar' : 'Guardar estado'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> _restaurantStatusItems(String status) {
  DropdownMenuItem<String> item(
    String value,
    String label, {
    bool enabled = true,
  }) {
    return DropdownMenuItem(value: value, enabled: enabled, child: Text(label));
  }

  return switch (status) {
    'received' => [
      item('received', 'Recibido'),
      item('preparing', 'Preparando'),
      item('cancelled', 'Cancelado'),
    ],
    'preparing' => [
      item('preparing', 'Preparando'),
      item('ready', 'Listo para repartidor'),
      item('cancelled', 'Cancelado'),
    ],
    'ready' => [
      item('ready', 'Listo, esperando repartidor'),
      item('cancelled', 'Cancelado'),
    ],
    'driver_assigned' => [
      item('driver_assigned', 'Repartidor asignado', enabled: false),
      item('on_the_way', 'Entregado al repartidor'),
      item('cancelled', 'Cancelado'),
    ],
    'on_the_way' => [item('on_the_way', 'En camino', enabled: false)],
    'delivered' => [item('delivered', 'Entregado', enabled: false)],
    'cancelled' => [item('cancelled', 'Cancelado', enabled: false)],
    _ => [item(status, status, enabled: false)],
  };
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

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
              style: const TextStyle(color: Color(0xFFD3D0CB), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _OrdersErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 42,
              color: Color(0xFFE24A2B),
            ),
            const SizedBox(height: 14),
            const Text(
              'No pudimos cargar los pedidos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
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
      'driver_assigned' => 'Por recoger',
      'on_the_way' => 'En camino',
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
            style: TextStyle(color: Color(0xFF666666), height: 1.4),
          ),
        ],
      ),
    );
  }
}
