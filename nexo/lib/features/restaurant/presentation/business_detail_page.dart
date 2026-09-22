import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/cart/application/cart_scope.dart';
import 'package:nexo/features/restaurant/application/catalog_refresh_controller.dart';
import 'package:nexo/features/restaurant/data/business_api.dart';
import 'package:nexo/features/restaurant/data/product_api.dart';
import 'package:nexo/features/restaurant/presentation/product_customization_page.dart';
import 'package:nexo/shared/models/cart_item.dart';
import 'package:nexo/shared/models/product.dart';
import 'package:nexo/shared/widgets/cart_icon.dart';

class BusinessDetailPage extends StatefulWidget {
  final int businessId;
  final String name;
  final String description;
  final String time;
  final double rating;
  final bool isOpen;
  final String availabilityLabel;

  const BusinessDetailPage({
    super.key,
    required this.businessId,
    required this.name,
    required this.description,
    required this.time,
    required this.rating,
    required this.isOpen,
    required this.availabilityLabel,
  });

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage>
    with WidgetsBindingObserver {
  Future<List<Product>>? _productsFuture;
  Timer? _refreshTimer;
  bool _observerRegistered = false;
  late bool _isOpen;
  late String _availabilityLabel;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.isOpen;
    _availabilityLabel = widget.availabilityLabel;
    CatalogRefreshController.instance.addListener(_onCatalogChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_productsFuture == null) {
      _productsFuture = _loadProducts();
      unawaited(_refreshBusinessState());
    }
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => _reloadSilently(),
    );
  }

  Future<List<Product>> _loadProducts() {
    return ProductApi.getProducts(widget.businessId);
  }

  Future<void> _reload() async {
    final future = _loadProducts();
    setState(() {
      _productsFuture = future;
    });
    await _refreshBusinessState();
    await future;
  }

  void _reloadSilently() {
    if (!mounted) return;
    setState(() {
      _productsFuture = _loadProducts();
    });
    unawaited(_refreshBusinessState());
  }

  void _onCatalogChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadSilently());
  }

  Future<void> _refreshBusinessState() async {
    try {
      final business = await BusinessApi.getBusinessById(widget.businessId);
      if (!mounted) return;
      setState(() {
        _isOpen = business.isOpen;
        _availabilityLabel = business.availabilityLabel;
      });
    } catch (_) {
      // Si falla el refresco silencioso, mantenemos el estado anterior.
    }
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
    CatalogRefreshController.instance.removeListener(_onCatalogChanged);
    super.dispose();
  }

  Future<void> _openProduct(Product product) async {
    await _refreshBusinessState();
    if (!mounted) return;

    if (!_isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Este negocio esta cerrado. $_availabilityLabel'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final latestProduct = await ProductApi.getProductDetail(
        businessId: widget.businessId,
        productId: product.id,
      );

      if (!mounted) return;

      if (latestProduct.hasCustomizations) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductCustomizationPage(
              businessId: widget.businessId,
              product: latestProduct,
            ),
          ),
        );
        _reloadSilently();
        return;
      }

      final cartController = CartScope.of(context);
      final wasExisting = cartController.items.any(
        (item) => item.cartKey == '${latestProduct.id}:',
      );

      if (!cartController.canAddFromBusiness(widget.businessId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu carrito es de otro negocio. Vacialo para continuar.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      cartController.addItem(
        businessId: widget.businessId,
        item: CartItem(
          cartKey: '${latestProduct.id}:',
          id: latestProduct.id,
          name: latestProduct.name,
          description: latestProduct.description,
          basePrice: latestProduct.price,
          image: latestProduct.image,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasExisting
                ? 'Se actualizo la cantidad'
                : 'Producto agregado al carrito',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reloadSilently();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No pudimos actualizar este producto. ${error.toString()}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reloadSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name), actions: const [CartIcon()]),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0x33F2C21A)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFD4CEC3),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(
                        icon: Icons.timer_rounded,
                        label: widget.time.isEmpty
                            ? 'Tiempo por confirmar'
                            : '${widget.time} min',
                      ),
                      _InfoChip(
                        icon: _isOpen
                            ? Icons.bolt_rounded
                            : Icons.pause_circle_rounded,
                        label: _availabilityLabel,
                      ),
                      _InfoChip(
                        icon: Icons.star_rounded,
                        label: widget.rating.toStringAsFixed(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_isOpen) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDE8),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x33E24A2B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      color: Color(0xFFE24A2B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Negocio cerrado',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE24A2B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ya no puedes pedir por ahora. $_availabilityLabel',
                            style: const TextStyle(
                              color: Color(0xFF6B3428),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Productos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (_productsFuture == null ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Text('No hay productos disponibles');
                }

                final screenWidth = MediaQuery.of(context).size.width;
                final cardAspectRatio = screenWidth < 380 ? 0.58 : 0.62;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: cardAspectRatio,
                  children: products.map((product) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _isOpen ? () => _openProduct(product) : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0x14F2C21A)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.18,
                                  child: Image.network(
                                    product.image.isNotEmpty
                                        ? product.image
                                        : 'https://th.bing.com/th/id/R.29d71f83ddc95f2e0ed25142e2cf80ab?rik=dmZEPaicpB5nbQ&pid=ImgRaw&r=0',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: _isOpen
                                        ? () => _openProduct(product)
                                        : null,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF121212),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x14000000),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        product.hasCustomizations
                                            ? Icons.tune_rounded
                                            : Icons.add,
                                        size: 18,
                                        color: const Color(0xFFF2C21A),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                14,
                              ),
                              child: SizedBox(
                                height: 108,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF737373),
                                        height: 1.35,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (product.optionGroups.isNotEmpty) ...[
                                      const Text(
                                        'Personalizable',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF8A6A08),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      'Desde \$${product.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
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
        color: const Color(0x22F2C21A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2BF2C21A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF2C21A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
