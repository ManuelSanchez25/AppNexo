import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/presentation/login_page.dart';
import 'package:nexo/features/auth/presentation/register_page.dart';
import 'package:nexo/features/restaurant/data/business_api.dart';
import 'package:nexo/features/restaurant/presentation/business_form_page.dart';
import 'package:nexo/features/restaurant/presentation/business_products_page.dart';
import 'package:nexo/features/restaurant/presentation/restaurant_orders_page.dart';
import 'package:nexo/shared/models/business.dart';

class RestaurantDashboardPage extends StatefulWidget {
  const RestaurantDashboardPage({super.key});

  @override
  State<RestaurantDashboardPage> createState() => _RestaurantDashboardPageState();
}

class _RestaurantDashboardPageState extends State<RestaurantDashboardPage> {
  Future<List<Business>>? _businessesFuture;
  String? _loadedToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authController = AuthScope.of(context);
    final token = authController.token;

    if (token != null && token.isNotEmpty && _loadedToken != token) {
      _loadedToken = token;
      _businessesFuture = BusinessApi.getOwnedBusinesses(token);
    }
  }

  Future<void> _reload() async {
    final authController = AuthScope.of(context);
    final token = authController.token;
    if (token == null || token.isEmpty) return;

    final future = BusinessApi.getOwnedBusinesses(token);
    setState(() => _businessesFuture = future);
    await future;
  }

  Future<void> _openBusinessForm([Business? business]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessFormPage(business: business),
      ),
    );

    if (changed == true) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);
    final canManageRestaurant =
        authController.isRestaurant || authController.isAdmin;

    if (!canManageRestaurant) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Panel restaurante'),
        ),
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
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
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
          IconButton(
            tooltip: 'Pedidos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RestaurantOrdersPage(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded),
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
      floatingActionButton: FloatingActionButton.extended(
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
                        style: TextStyle(
                          color: Color(0xFFD8D4CB),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _HeroStat(
                            label: 'Negocios',
                            value: '${businesses.length}',
                          ),
                          const SizedBox(width: 10),
                          const _HeroStat(
                            label: 'Modo',
                            value: 'Owner',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...businesses.map(
                  (business) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _BusinessAdminCard(
                      business: business,
                      onEdit: () => _openBusinessForm(business),
                      onManageProducts: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusinessProductsPage(
                              business: business,
                            ),
                          ),
                        );
                        if (mounted) {
                          await _reload();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BusinessAdminCard extends StatelessWidget {
  final Business business;
  final VoidCallback onEdit;
  final VoidCallback onManageProducts;

  const _BusinessAdminCard({
    required this.business,
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
                      colors: [
                        Color(0x88000000),
                        Color(0x00000000),
                      ],
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
                Text(
                  business.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
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
                      icon: Icons.schedule_rounded,
                      label: business.time,
                    ),
                    _InfoChip(
                      icon: Icons.star_rounded,
                      label: business.rating.toStringAsFixed(1),
                    ),
                  ],
                ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({
    required this.label,
    required this.value,
  });

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

  const _InfoChip({
    required this.icon,
    required this.label,
  });

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
