import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/notifications/application/notification_controller.dart';
import 'package:nexo/features/notifications/application/notification_scope.dart';
import 'package:nexo/features/orders/application/active_order_scope.dart';
import 'package:nexo/features/orders/data/order_realtime_client.dart';

class ActiveOrderSync extends StatefulWidget {
  final Widget child;

  const ActiveOrderSync({super.key, required this.child});

  @override
  State<ActiveOrderSync> createState() => _ActiveOrderSyncState();
}

class _ActiveOrderSyncState extends State<ActiveOrderSync>
    with WidgetsBindingObserver {
  final OrderRealtimeClient _realtimeClient = createOrderRealtimeClient();
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  late NotificationController _notifications;
  bool _observerRegistered = false;
  String? _subscribedToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifications = NotificationScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncNow());
    _ensureRealtimeSubscription();

    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _syncNow());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncNow());
    }
  }

  @override
  void dispose() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _timer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _ensureRealtimeSubscription() {
    final token = AuthScope.of(context).token;
    if (token == null || token.isEmpty) {
      _subscribedToken = null;
      _eventSubscription?.cancel();
      _eventSubscription = null;
      return;
    }

    if (_subscribedToken == token && _eventSubscription != null) {
      return;
    }

    _subscribedToken = token;
    _eventSubscription?.cancel();
    _eventSubscription = _realtimeClient.customerOrderEvents(token).listen((
      event,
    ) {
      final type = event['type']?.toString();
      if (type == 'order-updated') {
        final orderId = event['orderId']?.toString() ?? '';
        final status = event['status']?.toString() ?? '';
        _notifications.add(
          title: 'Tu pedido se actualizo',
          body: _customerNotificationBody(status),
          dedupeKey: 'customer:$orderId:$status',
        );
        _syncNow();
      }
    });
  }

  void _syncNow() {
    if (!mounted) return;
    final authController = AuthScope.of(context);
    unawaited(
      ActiveOrderScope.of(context).syncSession(token: authController.token),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

String _customerNotificationBody(String status) {
  return switch (status) {
    'received' => 'El restaurante recibio tu pedido.',
    'preparing' => 'El restaurante esta preparando tu pedido.',
    'ready' => 'Tu pedido esta listo para que pase el repartidor.',
    'driver_assigned' => 'Ya hay repartidor asignado para tu pedido.',
    'on_the_way' => 'Tu pedido va en camino.',
    'delivered' => 'Tu pedido fue entregado.',
    'cancelled' => 'Tu pedido fue cancelado.',
    _ => 'Hay un cambio nuevo en tu pedido.',
  };
}
