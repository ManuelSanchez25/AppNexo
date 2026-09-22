import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/presentation/session_home_page.dart';
import 'package:nexo/features/orders/application/active_order_scope.dart';
import 'package:nexo/features/orders/data/order_api.dart';
import 'package:nexo/shared/models/create_order_response.dart';

class OrderReceivedPage extends StatefulWidget {
  final String orderId;
  final String status;
  final List<CreateOrderItemResponse> items;
  final double subtotal;
  final double shipping;
  final double total;
  final String deliveryLabel;
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddressText;
  final String deliveryPin;

  const OrderReceivedPage({
    super.key,
    required this.orderId,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.deliveryLabel,
    required this.recipientName,
    required this.recipientPhone,
    required this.deliveryAddressText,
    this.deliveryPin = '',
  });

  @override
  State<OrderReceivedPage> createState() => _OrderReceivedPageState();
}

class _OrderReceivedPageState extends State<OrderReceivedPage>
    with WidgetsBindingObserver {
  late String _status;
  late List<CreateOrderItemResponse> _items;
  late double _subtotal;
  late double _shipping;
  late double _total;
  late String _deliveryLabel;
  late String _recipientName;
  late String _recipientPhone;
  late String _deliveryAddressText;
  late String _deliveryPin;
  Timer? _refreshTimer;
  bool _loading = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = widget.status;
    _items = widget.items;
    _subtotal = widget.subtotal;
    _shipping = widget.shipping;
    _total = widget.total;
    _deliveryLabel = widget.deliveryLabel;
    _recipientName = widget.recipientName;
    _recipientPhone = widget.recipientPhone;
    _deliveryAddressText = widget.deliveryAddressText;
    _deliveryPin = widget.deliveryPin;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshOrder(),
    );
    _syncActiveOrder();
    _refreshOrder();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOrder();
    }
  }

  Future<void> _refreshOrder() async {
    final token = AuthScope.of(context).token;
    if (_loading || token == null || token.isEmpty) return;

    _loading = true;
    try {
      final detail = await OrderApi.getOrderDetail(
        token: token,
        orderId: widget.orderId,
      );

      if (!mounted) return;
      setState(() {
        _status = detail.status;
        _items = detail.items;
        _subtotal = detail.subtotal;
        _shipping = detail.shipping;
        _total = detail.total;
        _deliveryLabel = detail.deliveryLabel;
        _recipientName = detail.recipientName;
        _recipientPhone = detail.recipientPhone;
        _deliveryAddressText = detail.deliveryAddressText;
        _deliveryPin = detail.deliveryPin;
      });
      await ActiveOrderScope.of(context).trackOrder(detail, token: token);
    } catch (_) {
      // keep current visible data if refresh fails
    } finally {
      _loading = false;
    }
  }

  Future<void> _syncActiveOrder() async {
    final token = AuthScope.of(context).token;
    if (token == null || token.isEmpty) return;

    await ActiveOrderScope.of(context).trackOrder(
      CreateOrderResponse(
        orderId: widget.orderId,
        businessId: 0,
        driverUserId: null,
        status: _status,
        subtotal: _subtotal,
        shipping: _shipping,
        total: _total,
        addressId: 0,
        deliveryLabel: _deliveryLabel,
        recipientName: _recipientName,
        recipientPhone: _recipientPhone,
        deliveryAddressText: _deliveryAddressText,
        deliveryPin: _deliveryPin,
        createdAt: null,
        items: _items,
      ),
      token: token,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancelOrder() async {
    if (_cancelling || _status != 'received') return;

    const reasons = [
      'Me equivoqué en el pedido',
      'La dirección es incorrecta',
      'Ya no necesito el pedido',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Por qué quieres cancelar?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;

    final token = AuthScope.of(context).token;
    if (token == null || token.isEmpty) return;

    setState(() => _cancelling = true);
    try {
      await OrderApi.cancelOrder(
        token: token,
        orderId: widget.orderId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _status = 'cancelled');
      ActiveOrderScope.of(context).clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido cancelado')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedido recibido')),
      body: RefreshIndicator(
        onRefresh: _refreshOrder,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFF232323)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2C21A),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tu pedido fue recibido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orden #${widget.orderId}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFD4CEC3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x22F2C21A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Estado: ${_statusLabel(_status)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Esta pantalla se actualiza sola cuando cambia el estado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFFC9C2B7)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_deliveryAddressText.isNotEmpty) ...[
              const Text(
                'Entrega',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E0D7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_deliveryLabel.isNotEmpty)
                      Text(
                        _deliveryLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    if (_recipientName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _recipientName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (_recipientPhone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _recipientPhone,
                        style: const TextStyle(color: Color(0xFF666666)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _deliveryAddressText,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_deliveryPin.isNotEmpty &&
                (_status == 'driver_assigned' || _status == 'on_the_way')) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5C96F)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PIN para recibir tu pedido',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _deliveryPin,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Dáselo al repartidor cuando tengas el pedido.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Resumen del pedido',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ..._items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E0D7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              color: const Color(0xFFF1F1EF),
                              child: const Icon(Icons.image_not_supported),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cantidad ${item.quantity}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF777777),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '\$${item.lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE5E0D7)),
              ),
              child: Column(
                children: [
                  _ReceiptRow(label: 'Subtotal', value: _subtotal),
                  const SizedBox(height: 10),
                  _ReceiptRow(label: 'Envio', value: _shipping),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _ReceiptRow(label: 'Total', value: _total, emphasized: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SessionHomePage()),
                  (route) => false,
                );
              },
              child: const Text('Volver al inicio'),
            ),
            if (_status == 'received') ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _cancelling ? null : _cancelOrder,
                child: Text(
                  _cancelling ? 'Cancelando...' : 'Cancelar pedido',
                  style: const TextStyle(color: Color(0xFFC5221F)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'preparing' => 'Preparando',
    'ready' => 'Listo',
    'driver_assigned' => 'Por recoger',
    'on_the_way' => 'En camino',
    'delivered' => 'Entregado',
    'cancelled' => 'Cancelado',
    _ => 'Recibido',
  };
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasized ? 16 : 14,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      color: emphasized ? Colors.black : const Color(0xFF666666),
    );

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('\$${value.toStringAsFixed(2)}', style: style),
      ],
    );
  }
}
