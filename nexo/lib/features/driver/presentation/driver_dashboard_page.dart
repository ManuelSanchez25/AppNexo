import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/presentation/login_page.dart';
import 'package:nexo/features/driver/data/driver_api.dart';
import 'package:nexo/features/driver/data/driver_stats.dart';
import 'package:nexo/features/driver/presentation/driver_profile_page.dart';
import 'package:nexo/features/notifications/application/notification_controller.dart';
import 'package:nexo/features/notifications/application/notification_scope.dart';
import 'package:nexo/features/orders/data/order_realtime_client.dart';
import 'package:nexo/shared/models/restaurant_order_summary.dart';

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage>
    with WidgetsBindingObserver {
  final OrderRealtimeClient _realtimeClient = createOrderRealtimeClient();
  List<RestaurantOrderSummary> _activeOrders = [];
  List<RestaurantOrderSummary> _availableOrders = [];
  final Set<String> _savingIds = {};
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  Timer? _refreshTimer;
  late NotificationController _notifications;
  DriverStats? _stats;
  String? _subscribedToken;
  int _lastAvailableCount = 0;
  bool _loading = true;
  bool _refreshingSession = false;
  bool _observerRegistered = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifications = NotificationScope.of(context);
    final auth = AuthScope.of(context);
    final token = auth.token;
    if (token != null &&
        token.isNotEmpty &&
        auth.isDriverApproved &&
        _subscribedToken != token) {
      _subscribedToken = token;
      _subscribeToRealtime(token);
    }

    if (_loading) {
      unawaited(_loadOrders());
    }

    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadOrders(silent: true),
    );
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
  }

  @override
  void dispose() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _refreshTimer?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadOrders(silent: true));
    }
  }

  void _subscribeToRealtime(String token) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _realtimeClient.driverOrderEvents(token).listen((
      event,
    ) async {
      final type = event['type']?.toString();
      if (type != 'driver-order-updated') return;

      final previousAvailable = _lastAvailableCount;
      await _loadOrders(silent: true);
      if (!mounted) return;

      final nextAvailable = _availableOrders.length;
      if (nextAvailable > previousAvailable) {
        _notifications.add(
          title: 'Pedido listo para tomar',
          body: 'Hay un nuevo pedido disponible para recoger.',
          dedupeKey: 'driver:available:${event['orderId'] ?? ''}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nuevo pedido listo para tomar'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _loadOrders({bool silent = false}) async {
    final auth = AuthScope.of(context);
    final token = auth.token;
    if (token == null || token.isEmpty || !auth.isDriverApproved) {
      setState(() => _loading = false);
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final active = await DriverApi.getActiveOrders(token: token);
      final available = await DriverApi.getAvailableOrders(token: token);
      final stats = await DriverApi.getStats(token: token);
      if (!mounted) return;
      setState(() {
        _activeOrders = active;
        _availableOrders = available;
        _stats = stats;
        _lastAvailableCount = available.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _refreshDriverStatus() async {
    if (_refreshingSession) return;

    final auth = AuthScope.of(context);
    setState(() => _refreshingSession = true);
    try {
      await auth.refreshSession();
      if (!mounted) return;

      if (auth.isDriverApproved) {
        await _loadOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu solicitud todavía está en revisión.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshingSession = false);
      }
    }
  }

  Future<void> _accept(RestaurantOrderSummary order) async {
    await _runOrderAction(order, () async {
      final token = AuthScope.of(context).token!;
      await DriverApi.acceptOrder(token: token, orderId: order.orderId);
    });
  }

  Future<void> _delivered(RestaurantOrderSummary order) async {
    final pin = await _requestDeliveryPin();
    if (pin == null || !mounted) return;

    await _runOrderAction(order, () async {
      final token = AuthScope.of(context).token!;
      await DriverApi.markDelivered(
        token: token,
        orderId: order.orderId,
        pin: pin,
      );
    });
  }

  Future<String?> _requestDeliveryPin() async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirmar entrega'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pide al cliente su PIN de 4 dígitos.'),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'PIN de entrega',
                  errorText: error,
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
                  setDialogState(() => error = 'Escribe los 4 dígitos');
                  return;
                }
                Navigator.pop(dialogContext, pin);
              },
              child: const Text('Confirmar entrega'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _runOrderAction(
    RestaurantOrderSummary order,
    Future<void> Function() action,
  ) async {
    if (_savingIds.contains(order.orderId)) return;

    setState(() => _savingIds.add(order.orderId));
    try {
      await action();
      await _loadOrders();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingIds.remove(order.orderId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    if (!auth.isDriverApproved) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Panel repartidor'),
          actions: [
            IconButton(
              tooltip: 'Mis datos',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverProfilePage(token: auth.token!),
                ),
              ),
              icon: const Icon(Icons.person_outline_rounded),
            ),
            IconButton(
              onPressed: () {
                auth.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: _DriverPendingState(
          refreshing: _refreshingSession,
          onRefreshStatus: _refreshDriverStatus,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel repartidor'),
        actions: [
          IconButton(
            tooltip: 'Mis datos',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverProfilePage(token: auth.token!),
              ),
            ),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () {
              auth.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _DriverErrorState(error: _error!, onRetry: _loadOrders)
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0x33F2C21A)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entregas en vivo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Toma pedidos listos, llévalos al cliente y marca entregado.',
                          style: TextStyle(color: Color(0xFFD8D4CB)),
                        ),
                      ],
                    ),
                  ),
                  if (_availableOrders.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _DriverAlertCard(count: _availableOrders.length),
                  ],
                  const SizedBox(height: 14),
                  _DriverStatsGrid(stats: _stats),
                  const SizedBox(height: 20),
                  const _SectionTitle('Mis entregas'),
                  if (_activeOrders.isEmpty)
                    const _SoftEmptyCard('No tienes entregas activas.')
                  else
                    ..._activeOrders.map(
                      (order) => _DriverOrderCard(
                        order: order,
                        saving: _savingIds.contains(order.orderId),
                        actionLabel: order.status == 'on_the_way'
                            ? 'Marcar entregado'
                            : 'Esperando entrega del restaurante',
                        onAction: order.status == 'on_the_way'
                            ? () => _delivered(order)
                            : null,
                      ),
                    ),
                  const SizedBox(height: 20),
                  const _SectionTitle('Pedidos disponibles'),
                  if (_availableOrders.isEmpty)
                    const _SoftEmptyCard('No hay pedidos listos por tomar.')
                  else
                    ..._availableOrders.map(
                      (order) => _DriverOrderCard(
                        order: order,
                        saving: _savingIds.contains(order.orderId),
                        actionLabel: 'Tomar pedido',
                        onAction: () => _accept(order),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DriverOrderCard extends StatelessWidget {
  final RestaurantOrderSummary order;
  final bool saving;
  final String actionLabel;
  final VoidCallback? onAction;

  const _DriverOrderCard({
    required this.order,
    required this.saving,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E1D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.businessName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Pedido ${order.orderId}')),
              _DriverStatusChip(status: order.status),
            ],
          ),
          Text('Cliente: ${order.customerName}'),
          const SizedBox(height: 12),
          _RoutePoint(
            icon: Icons.storefront_rounded,
            label: 'Recoger en',
            title: order.businessName,
            address: order.pickupAddressText,
          ),
          const SizedBox(height: 10),
          _RoutePoint(
            icon: Icons.home_rounded,
            label: 'Entregar en',
            title: order.customerName,
            address: order.deliveryAddressText,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${order.itemsCount} producto(s)'),
              const Spacer(),
              Text(
                '\$${order.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saving ? null : onAction,
              child: Text(saving ? 'Guardando...' : actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String address;

  const _RoutePoint({
    required this.icon,
    required this.label,
    required this.title,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E1D6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFF2C21A), size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAlertCard extends StatelessWidget {
  final int count;

  const _DriverAlertCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAD79B)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF2C21A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delivery_dining_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              count == 1
                  ? 'Hay 1 pedido listo para tomar.'
                  : 'Hay $count pedidos listos para tomar.',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5F4600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStatsGrid extends StatelessWidget {
  final DriverStats? stats;

  const _DriverStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final value =
        stats ??
        const DriverStats(
          availableOrders: 0,
          activeOrders: 0,
          acceptedOrders: 0,
          deliveredOrders: 0,
          deliveredToday: 0,
          todayEarnings: 0,
          totalEarnings: 0,
        );

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.72,
      children: [
        _DriverStatCard(
          label: 'Listos',
          value: '${value.availableOrders}',
          icon: Icons.notifications_active_rounded,
        ),
        _DriverStatCard(
          label: 'Activos',
          value: '${value.activeOrders}',
          icon: Icons.route_rounded,
        ),
        _DriverStatCard(
          label: 'Recibidos',
          value: '${value.acceptedOrders}',
          icon: Icons.inbox_rounded,
        ),
        _DriverStatCard(
          label: 'Entregados',
          value: '${value.deliveredOrders}',
          icon: Icons.check_circle_rounded,
        ),
        _DriverStatCard(
          label: 'Hoy',
          value: '${value.deliveredToday}',
          icon: Icons.today_rounded,
        ),
        _DriverStatCard(
          label: 'Ganancia hoy',
          value: '\$${value.todayEarnings.toStringAsFixed(2)}',
          icon: Icons.payments_rounded,
        ),
      ],
    );
  }
}

class _DriverStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DriverStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E1D6)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFF2C21A), size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStatusChip extends StatelessWidget {
  final String status;

  const _DriverStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'driver_assigned' => 'Por recoger',
      'on_the_way' => 'En camino',
      'delivered' => 'Entregado',
      'ready' => 'Listo',
      _ => 'Disponible',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22F2C21A)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DriverPendingState extends StatelessWidget {
  final bool refreshing;
  final VoidCallback onRefreshStatus;

  const _DriverPendingState({
    required this.refreshing,
    required this.onRefreshStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE8E1D6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 52,
                color: Color(0xFFF2C21A),
              ),
              const SizedBox(height: 16),
              const Text(
                'Solicitud en revisión',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Un administrador debe aprobar tu identidad antes de que puedas tomar pedidos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: refreshing ? null : onRefreshStatus,
                  child: Text(
                    refreshing ? 'Revisando...' : 'Ya me aprobaron, revisar',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _DriverErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SoftEmptyCard extends StatelessWidget {
  final String text;

  const _SoftEmptyCard(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E1D6)),
      ),
      child: Text(text),
    );
  }
}
