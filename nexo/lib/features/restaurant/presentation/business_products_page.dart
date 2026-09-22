import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/restaurant/application/catalog_refresh_controller.dart';
import 'package:nexo/features/restaurant/data/product_api.dart';
import 'package:nexo/features/restaurant/presentation/product_form_page.dart';
import 'package:nexo/features/restaurant/presentation/product_options_page.dart';
import 'package:nexo/shared/models/business.dart';
import 'package:nexo/shared/models/product.dart';

class BusinessProductsPage extends StatefulWidget {
  final Business business;

  const BusinessProductsPage({super.key, required this.business});

  @override
  State<BusinessProductsPage> createState() => _BusinessProductsPageState();
}

class _BusinessProductsPageState extends State<BusinessProductsPage> {
  Future<List<Product>>? _productsFuture;
  Timer? _refreshTimer;
  bool _reloadInProgress = false;

  @override
  void initState() {
    super.initState();
    CatalogRefreshController.instance.addListener(_onCatalogChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _productsFuture ??= _loadProducts();
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _reloadSilently(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    CatalogRefreshController.instance.removeListener(_onCatalogChanged);
    super.dispose();
  }

  void _onCatalogChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadSilently());
  }

  Future<List<Product>> _loadProducts() {
    final token = AuthScope.of(context).token!;
    return ProductApi.getOwnedProducts(
      businessId: widget.business.id,
      token: token,
    );
  }

  Future<void> _reload() async {
    if (_reloadInProgress) return;
    _reloadInProgress = true;
    final future = _loadProducts();
    if (mounted) {
      setState(() {
        _productsFuture = future;
      });
    }
    try {
      await future;
    } finally {
      _reloadInProgress = false;
    }
  }

  void _reloadSilently() {
    if (!mounted || _reloadInProgress) return;
    unawaited(_reload());
  }

  Future<void> _openProductForm([Product? product]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductFormPage(business: widget.business, product: product),
      ),
    );

    if (changed == true) {
      await _reload();
    }
  }

  Future<void> _openOptions(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductOptionsPage(business: widget.business, product: product),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openProductForm,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo producto'),
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (_productsFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No pudimos cargar los productos.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final products = snapshot.data ?? [];
          final visibleCount = products
              .where((item) => item.isAvailable)
              .length;
          final customizableCount = products
              .where((item) => item.optionGroups.isNotEmpty)
              .length;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        widget.business.name,
                        style: const TextStyle(
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
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Menu del restaurante',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Controla tu carta y lo que realmente ve el cliente.',
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Activa, oculta y personaliza productos con grupos reutilizables de ingredientes y extras.',
                        style: TextStyle(
                          color: Color(0xFFD6D2CB),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _DashboardMetric(
                            label: 'Productos',
                            value: products.length.toString(),
                          ),
                          const SizedBox(width: 10),
                          _DashboardMetric(
                            label: 'Visibles',
                            value: visibleCount.toString(),
                          ),
                          const SizedBox(width: 10),
                          _DashboardMetric(
                            label: 'Con extras',
                            value: customizableCount.toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (products.isEmpty)
                  const _EmptyProductsState()
                else ...[
                  const Text(
                    'Productos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  ...products.map((product) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              product.image.isNotEmpty
                                  ? product.image
                                  : 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80',
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  product.description.isEmpty
                                      ? 'Sin descripcion'
                                      : product.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _InfoChip(
                                      label:
                                          '\$${product.price.toStringAsFixed(2)}',
                                      background: const Color(0xFFF4F1EC),
                                      foreground: Colors.black,
                                    ),
                                    _InfoChip(
                                      label: product.isAvailable
                                          ? 'Disponible'
                                          : 'Oculto',
                                      background: product.isAvailable
                                          ? const Color(0xFFE7F6EC)
                                          : const Color(0xFFFDEBE9),
                                      foreground: product.isAvailable
                                          ? const Color(0xFF137333)
                                          : const Color(0xFFC5221F),
                                    ),
                                    if (product.optionGroups.isNotEmpty)
                                      _InfoChip(
                                        label:
                                            '${product.optionGroups.length} grupos',
                                        background: const Color(0xFFF7F4EE),
                                        foreground: const Color(0xFF6A5D47),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openProductForm(product);
                              } else if (value == 'options') {
                                _openOptions(product);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar producto'),
                              ),
                              PopupMenuItem(
                                value: 'options',
                                child: Text('Ingredientes y extras'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DashboardMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFD6D2CB), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _InfoChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_rounded, size: 42),
          SizedBox(height: 14),
          Text(
            'Todavia no hay productos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Agrega el primer producto para empezar a mostrar el menu al cliente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF666666), height: 1.45),
          ),
        ],
      ),
    );
  }
}
