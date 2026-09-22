import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/presentation/login_page.dart';
import 'package:nexo/features/auth/presentation/register_page.dart';
import 'package:nexo/features/driver/presentation/admin_drivers_page.dart';
import 'package:nexo/features/notifications/application/notification_controller.dart';
import 'package:nexo/features/notifications/application/notification_scope.dart';
import 'package:nexo/features/orders/data/order_api.dart';
import 'package:nexo/features/orders/data/order_realtime_client.dart';
import 'package:nexo/features/restaurant/application/catalog_refresh_controller.dart';
import 'package:nexo/features/restaurant/data/business_api.dart';
import 'package:nexo/features/restaurant/presentation/business_form_page.dart';
import 'package:nexo/features/restaurant/presentation/business_products_page.dart';
import 'package:nexo/features/restaurant/presentation/home_page.dart';
import 'package:nexo/features/restaurant/presentation/restaurant_orders_page.dart';
import 'package:nexo/shared/models/business.dart';
import 'package:nexo/shared/models/restaurant_order_summary.dart';

class RestaurantDashboardPage extends StatefulWidget {
  const RestaurantDashboardPage({super.key});

  @override
  State<RestaurantDashboardPage> createState() =>
      _RestaurantDashboardPageState();
}

class _RestaurantDashboardPageState extends State<RestaurantDashboardPage>
    with WidgetsBindingObserver {
  final OrderRealtimeClient _realtimeClient = createOrderRealtimeClient();
  Future<List<Business>>? _businessesFuture;
  String? _loadedToken;
  Timer? _refreshTimer;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  late NotificationController _notifications;
  bool _observerRegistered = false;
  int _pendingOrdersCount = 0;
  bool _loadingPendingOrders = false;
  List<RestaurantOrderSummary> _orders = [];
  String _adminBusinessFilter = 'pending';

  @override
  void initState() {
    super.initState();
    CatalogRefreshController.instance.addListener(_onCatalogChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifications = NotificationScope.of(context);
    final authController = AuthScope.of(context);
    final token = authController.token;

    if (token != null && token.isNotEmpty && _loadedToken != token) {
      _loadedToken = token;
      _businessesFuture = BusinessApi.getOwnedBusinesses(token);
      unawaited(_loadOrderMetrics());
      _subscribeToRealtime(token);
    }

    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _refreshDashboardSilently(),
      );
    }
  }

  Future<void> _reload() async {
    final authController = AuthScope.of(context);
    final token = authController.token;
    if (token == null || token.isEmpty) return;

    final future = BusinessApi.getOwnedBusinesses(token);
    setState(() {
      _businessesFuture = future;
    });
    await future;
    await _loadOrderMetrics();
  }

  Future<void> _loadOrderMetrics() async {
    final token = AuthScope.of(context).token;
    if (_loadingPendingOrders || token == null || token.isEmpty) return;

    _loadingPendingOrders = true;
    try {
      final orders = await OrderApi.getRestaurantOrders(token: token);
      if (!mounted) return;

      final pendingCount = orders
          .where(
            (order) =>
                order.status != 'delivered' && order.status != 'cancelled',
          )
          .length;

      setState(() {
        _orders = orders;
        _pendingOrdersCount = pendingCount;
      });
    } catch (_) {
      // Ignore dashboard badge refresh failures.
    } finally {
      _loadingPendingOrders = false;
    }
  }

  void _refreshDashboardSilently() {
    if (!mounted) return;
    unawaited(_loadOrderMetrics());
  }

  void _onCatalogChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDashboardSilently();
    }
  }

  @override
  void dispose() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _refreshTimer?.cancel();
    _realtimeSubscription?.cancel();
    CatalogRefreshController.instance.removeListener(_onCatalogChanged);
    super.dispose();
  }

  void _subscribeToRealtime(String token) {
    _realtimeSubscription?.cancel();
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
            body: _restaurantDashboardNotificationBody(status),
            dedupeKey: 'restaurant:$orderId:$status',
          );
          _refreshDashboardSilently();
        }
      },
    );
  }

  Future<void> _openBusinessForm([Business? business]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BusinessFormPage(business: business)),
    );

    if (changed == true) {
      await _reload();
    }
  }

  Future<void> _updateBusinessApproval(Business business, String status) async {
    final token = AuthScope.of(context).token;
    if (token == null || token.isEmpty) return;

    try {
      await BusinessApi.updateApproval(
        token: token,
        businessId: business.id,
        status: status,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Negocio ${_approvalLabel(status).toLowerCase()}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudimos actualizar el negocio: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);
    final canManageRestaurant =
        authController.isRestaurant || authController.isAdmin;

    if (!canManageRestaurant) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel restaurante')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0x14F2C21A)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 34,
                      color: Color(0xFFF2C21A),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Necesitas una cuenta restaurante',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu cuenta actual es de cliente. Crea una cuenta restaurante para administrar negocios, productos y pedidos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterPage(
                            initialAccountType: AccountType.restaurant,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Crear cuenta restaurante'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel restaurante'),
        actions: [
          if (authController.isAdmin)
            IconButton(
              tooltip: 'Modo cliente',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
              icon: const Icon(Icons.shopping_bag_rounded),
            ),
          if (authController.isAdmin)
            IconButton(
              tooltip: 'Repartidores',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDriversPage()),
                );
              },
              icon: const Icon(Icons.verified_user_rounded),
            ),
          IconButton(
            tooltip: 'Pedidos',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const RestaurantOrdersPage()),
              );
              if (changed == true && mounted) {
                await _loadOrderMetrics();
              }
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.receipt_long_rounded),
                if (_pendingOrdersCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE24A2B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 20),
                      child: Text(
                        _pendingOrdersCount > 99
                            ? '99+'
                            : '$_pendingOrdersCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () {
              authController.logout();
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
      floatingActionButton: authController.isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: _openBusinessForm,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Nuevo negocio'),
            ),
      body: FutureBuilder<List<Business>>(
        future: _businessesFuture,
        builder: (context, snapshot) {
          if (_businessesFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No pudimos cargar tus negocios.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final businesses = snapshot.data ?? [];
          final pendingBusinesses = businesses
              .where((business) => business.approvalStatus == 'pending')
              .toList();
          final approvedBusinesses = businesses
              .where((business) => business.approvalStatus == 'approved')
              .toList();
          final rejectedBusinesses = businesses
              .where((business) => business.approvalStatus == 'rejected')
              .toList();
          final filteredAdminBusinesses = switch (_adminBusinessFilter) {
            'approved' => approvedBusinesses,
            'rejected' => rejectedBusinesses,
            _ => pendingBusinesses,
          };
          final metrics = _RestaurantMetrics.fromOrders(_orders);
          if (businesses.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0x14F2C21A)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.store_mall_directory_rounded,
                        size: 48,
                        color: Color(0xFFF2C21A),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Todavía no hay negocios registrados',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Empieza creando tu restaurante y después agrega el menú, ingredientes y pedidos que verá el cliente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (_pendingOrdersCount > 0) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4EE),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFF0C6B8)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE24A2B),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _pendingOrdersCount == 1
                                ? 'Tienes 1 pedido pendiente por atender.'
                                : 'Tienes $_pendingOrdersCount pedidos pendientes por atender.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF7A2E16),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RestaurantOrdersPage(),
                              ),
                            );
                            if (changed == true && mounted) {
                              await _loadOrderMetrics();
                            }
                          },
                          child: const Text('Ver'),
                        ),
                      ],
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF090909),
                        Color(0xFF121212),
                        Color(0xFF1D1B16),
                      ],
                    ),
                    border: Border.all(color: const Color(0x33F2C21A)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu operación, más clara y con más presencia.',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1.04,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Administra catálogo, disponibilidad y pedidos desde una vista más limpia para una operación más seria.',
                        style: TextStyle(color: Color(0xFFD8D4CB), height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _HeroStat(
                            label: 'Negocios',
                            value: '${businesses.length}',
                          ),
                          const SizedBox(width: 10),
                          _HeroStat(
                            label: 'Pendientes',
                            value: '${pendingBusinesses.length}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _RestaurantCommandCenter(
                  metrics: metrics,
                  onOpenOrders: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RestaurantOrdersPage(),
                      ),
                    );
                    if (changed == true && mounted) {
                      await _loadOrderMetrics();
                    }
                  },
                  onRefresh: _reload,
                ),
                const SizedBox(height: 20),
                if (authController.isAdmin) ...[
                  _AdminBusinessFilters(
                    selected: _adminBusinessFilter,
                    pendingCount: pendingBusinesses.length,
                    approvedCount: approvedBusinesses.length,
                    rejectedCount: rejectedBusinesses.length,
                    onSelected: (value) {
                      setState(() => _adminBusinessFilter = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (filteredAdminBusinesses.isEmpty)
                    _AdminBusinessEmptyState(filter: _adminBusinessFilter)
                  else
                    ...filteredAdminBusinesses.map(_buildBusinessCard),
                ] else
                  ...businesses.map(_buildBusinessCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusinessCard(Business business) {
    final authController = AuthScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _BusinessAdminCard(
        business: business,
        canApprove: authController.isAdmin,
        canManage: authController.isRestaurant,
        onApprovalChanged: (status) =>
            _updateBusinessApproval(business, status),
        onEdit: () => _openBusinessForm(business),
        onManageProducts: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BusinessProductsPage(business: business),
            ),
          );
          if (mounted) {
            await _reload();
          }
        },
      ),
    );
  }
}

String _restaurantDashboardNotificationBody(String status) {
  return switch (status) {
    'received' => 'Hay un pedido nuevo en tu panel.',
    'driver_assigned' => 'Un repartidor tomo un pedido listo.',
    'on_the_way' => 'Un pedido salio a domicilio.',
    'delivered' => 'Un pedido fue entregado.',
    'cancelled' => 'Un pedido fue cancelado.',
    _ => 'Hay un cambio nuevo en pedidos.',
  };
}

class _BusinessAdminCard extends StatelessWidget {
  final Business business;
  final bool canApprove;
  final bool canManage;
  final ValueChanged<String> onApprovalChanged;
  final VoidCallback onEdit;
  final VoidCallback onManageProducts;

  const _BusinessAdminCard({
    required this.business,
    required this.canApprove,
    required this.canManage,
    required this.onApprovalChanged,
    required this.onEdit,
    required this.onManageProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x14F2C21A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  business.imageUrl.isNotEmpty
                      ? business.imageUrl
                      : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80',
                  fit: BoxFit.cover,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x88000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        business.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ApprovalChip(status: business.approvalStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  business.description,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      icon: Icons.timer_rounded,
                      label: '${business.time} min',
                    ),
                    _InfoChip(
                      icon: business.isOpen
                          ? Icons.bolt_rounded
                          : Icons.pause_circle_rounded,
                      label: business.availabilityLabel,
                    ),
                    _InfoChip(
                      icon: Icons.star_rounded,
                      label: business.rating.toStringAsFixed(1),
                    ),
                  ],
                ),
                if (canApprove) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (business.approvalStatus != 'approved')
                        ElevatedButton.icon(
                          onPressed: () => onApprovalChanged('approved'),
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('Aprobar'),
                        ),
                      if (business.approvalStatus != 'pending')
                        OutlinedButton.icon(
                          onPressed: () => onApprovalChanged('pending'),
                          icon: const Icon(Icons.pause_circle_rounded),
                          label: const Text('Suspender'),
                        ),
                      if (business.approvalStatus != 'rejected')
                        OutlinedButton.icon(
                          onPressed: () => onApprovalChanged('rejected'),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Rechazar'),
                        ),
                    ],
                  ),
                ],
                if (canManage) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onManageProducts,
                          icon: const Icon(Icons.inventory_2_rounded),
                          label: const Text('Catálogo'),
                        ),
                      ),
                    ],
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

class _AdminBusinessFilters extends StatelessWidget {
  final String selected;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final ValueChanged<String> onSelected;

  const _AdminBusinessFilters({
    required this.selected,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _AdminFilterButton(
            label: 'Pendientes',
            count: pendingCount,
            selected: selected == 'pending',
            attention: pendingCount > 0,
            onTap: () => onSelected('pending'),
          ),
          _AdminFilterButton(
            label: 'Activos',
            count: approvedCount,
            selected: selected == 'approved',
            onTap: () => onSelected('approved'),
          ),
          _AdminFilterButton(
            label: 'Rechazados',
            count: rejectedCount,
            selected: selected == 'rejected',
            onTap: () => onSelected('rejected'),
          ),
        ],
      ),
    );
  }
}

class _AdminFilterButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final bool attention;
  final VoidCallback onTap;

  const _AdminFilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.attention = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF5D5A55),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: attention && !selected
                        ? const Color(0xFFE24A2B)
                        : selected
                        ? const Color(0xFFF2C21A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: attention && !selected
                          ? Colors.white
                          : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminBusinessEmptyState extends StatelessWidget {
  final String filter;

  const _AdminBusinessEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final (icon, title, description) = switch (filter) {
      'approved' => (
        Icons.storefront_rounded,
        'No hay negocios activos',
        'Los negocios que apruebes aparecerán en esta bandeja.',
      ),
      'rejected' => (
        Icons.block_rounded,
        'No hay negocios rechazados',
        'Aquí podrás revisar solicitudes que no fueron aprobadas.',
      ),
      _ => (
        Icons.task_alt_rounded,
        'Todo está revisado',
        'No tienes solicitudes de negocios pendientes.',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9E4DC)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F1EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: const Color(0xFF4F4B44)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6C6861), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ApprovalChip extends StatelessWidget {
  final String status;

  const _ApprovalChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => const Color(0xFF1E8E4D),
      'rejected' => const Color(0xFFE24A2B),
      _ => const Color(0xFFC79300),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        _approvalLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _approvalLabel(String status) {
  return switch (status) {
    'approved' => 'Aprobado',
    'rejected' => 'Rechazado',
    _ => 'Pendiente',
  };
}

class _RestaurantCommandCenter extends StatelessWidget {
  final _RestaurantMetrics metrics;
  final VoidCallback onOpenOrders;
  final Future<void> Function() onRefresh;

  const _RestaurantCommandCenter({
    required this.metrics,
    required this.onOpenOrders,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x18F2C21A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: Color(0xFFF2C21A),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro de operación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ventas, pedidos activos y corte rápido del día.',
                      style: TextStyle(color: Color(0xFF666666), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final tiles = [
                _CommandMetricTile(
                  label: 'Ventas hoy',
                  value: _money(metrics.todaySales),
                  icon: Icons.payments_rounded,
                  accent: const Color(0xFF0E8F5A),
                ),
                _CommandMetricTile(
                  label: 'Pedidos hoy',
                  value: '${metrics.todayOrders}',
                  icon: Icons.today_rounded,
                  accent: const Color(0xFFF2C21A),
                ),
                _CommandMetricTile(
                  label: 'Activos',
                  value: '${metrics.activeOrders}',
                  icon: Icons.local_fire_department_rounded,
                  accent: const Color(0xFFE24A2B),
                ),
                _CommandMetricTile(
                  label: 'Ticket prom.',
                  value: _money(metrics.averageTicket),
                  icon: Icons.trending_up_rounded,
                  accent: const Color(0xFF2B68E2),
                ),
              ];

              if (wide) {
                return Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      Expanded(child: tiles[i]),
                      if (i != tiles.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles
                    .map(
                      (tile) => SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: tile,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenOrders,
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Operación en vivo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Entregados: ${metrics.deliveredOrders} · Cancelados: ${metrics.cancelledOrders}',
            style: const TextStyle(
              color: Color(0xFF777777),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _CommandMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9E0D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF151515),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6F6A61),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantMetrics {
  final int todayOrders;
  final int activeOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final double todaySales;
  final double averageTicket;

  const _RestaurantMetrics({
    required this.todayOrders,
    required this.activeOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
    required this.todaySales,
    required this.averageTicket,
  });

  factory _RestaurantMetrics.fromOrders(List<RestaurantOrderSummary> orders) {
    final today = DateTime.now();
    final todayOrders = orders.where((order) {
      final createdAt = order.createdAt?.toLocal();
      return createdAt != null &&
          createdAt.year == today.year &&
          createdAt.month == today.month &&
          createdAt.day == today.day;
    }).toList();

    final deliveredToday = todayOrders
        .where((order) => order.status == 'delivered')
        .toList();
    final todaySales = deliveredToday.fold<double>(
      0,
      (sum, order) => sum + order.total,
    );

    return _RestaurantMetrics(
      todayOrders: todayOrders.length,
      activeOrders: orders
          .where(
            (order) =>
                order.status != 'delivered' && order.status != 'cancelled',
          )
          .length,
      deliveredOrders: orders
          .where((order) => order.status == 'delivered')
          .length,
      cancelledOrders: orders
          .where((order) => order.status == 'cancelled')
          .length,
      todaySales: todaySales,
      averageTicket: deliveredToday.isEmpty
          ? 0
          : todaySales / deliveredToday.length,
    );
  }
}

String _money(double value) {
  return '\$${value.toStringAsFixed(2)}';
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x16FFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x24F2C21A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFF2C21A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD8D4CB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14F2C21A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF2C21A)),
          const SizedBox(width: 6),
          Text(
            label.isEmpty ? 'Sin dato' : label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}
