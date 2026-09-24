import 'package:flutter/material.dart';
import 'dart:math';
import 'package:nexo/features/address/data/address_api.dart';
import 'package:nexo/features/address/presentation/addresses_page.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/cart/application/cart_scope.dart';
import 'package:nexo/features/orders/data/order_api.dart';
import 'package:nexo/features/orders/presentation/order_received_page.dart';
import 'package:nexo/shared/models/address.dart';
import 'package:url_launcher/url_launcher.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _submitting = false;
  String? _checkoutError;
  List<Address> _addresses = const [];
  Address? _selectedAddress;
  String? _pendingOrderRequestId;

  String _createOrderRequestId() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${random.nextInt(1 << 32).toRadixString(36)}';
  }

  Future<void> _ensureAddresses() async {
    final authController = AuthScope.of(context);
    final token = authController.token;
    if (token == null || token.isEmpty) return;

    try {
      final addresses = await AddressApi.getAddresses(token: token);
      if (!mounted) return;

      setState(() {
        _addresses = addresses;
        if (_selectedAddress != null) {
          _selectedAddress = addresses.cast<Address?>().firstWhere(
            (item) => item?.id == _selectedAddress!.id,
            orElse: () => null,
          );
        }
        _selectedAddress ??= addresses.cast<Address?>().firstWhere(
          (item) => item?.isDefault == true,
          orElse: () => addresses.isNotEmpty ? addresses.first : null,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addresses = const [];
        _selectedAddress = null;
      });
    }
  }

  void _confirmOrder() {
    _showOrderSummary();
  }

  Future<void> _showOrderSummary() async {
    final cartController = CartScope.of(context);
    final authController = AuthScope.of(context);
    final pageContext = context;
    _checkoutError = null;
    await _ensureAddresses();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final subtotal = cartController.subtotal;
            final shipping = cartController.shipping;
            final total = cartController.total;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.84,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumen final',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Revisa tus productos y confirma cuando todo este listo.',
                        style: TextStyle(color: Color(0xFF666666), height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () async {
                          final token = authController.token;
                          if (token == null || token.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Tu sesion ya no es valida. Vuelve a iniciar sesion.',
                                ),
                              ),
                            );
                            return;
                          }

                          final selected = await Navigator.push<Address>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddressesPage(
                                token: token,
                                suggestedRecipientName: authController.userName,
                                selectionMode: true,
                                initiallySelectedAddressId:
                                    _selectedAddress?.id,
                              ),
                            ),
                          );

                          if (selected != null && context.mounted) {
                            await _ensureAddresses();
                            if (context.mounted) {
                              setModalState(() => _selectedAddress = selected);
                            }
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0x14F2C21A)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: _selectedAddress == null
                              ? const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Direccion de entrega',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Agrega o selecciona una direccion antes de confirmar.',
                                      style: TextStyle(
                                        color: Color(0xFF666666),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Direccion de entrega',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0x14F2C21A),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x22F2C21A),
                                            ),
                                          ),
                                          child: Text(
                                            _selectedAddress!.label,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedAddress!.recipientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedAddress!.phone,
                                      style: const TextStyle(
                                        color: Color(0xFF666666),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _selectedAddress!.fullAddress,
                                      style: const TextStyle(
                                        color: Color(0xFF666666),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView.separated(
                          itemCount: cartController.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = cartController.items[index];
                            final itemSubtotal = item.unitPrice * item.quantity;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0x14F2C21A),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF777777),
                                          ),
                                        ),
                                        if (item
                                            .customizationSummary
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            item.customizationSummary,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF555555),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0x14F2C21A),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: const Color(0x22F2C21A),
                                          ),
                                        ),
                                        child: Text(
                                          'x${item.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '\$${itemSubtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SummaryCard(
                        subtotal: subtotal,
                        shipping: shipping,
                        total: total,
                      ),
                      if (_checkoutError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4EE),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFF1D2C3)),
                          ),
                          child: Text(
                            _checkoutError!,
                            style: const TextStyle(
                              color: Color(0xFF8A3B1C),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              cartController.isEmpty ||
                                  _submitting ||
                                  _selectedAddress == null
                              ? null
                              : () async {
                                  final token = authController.token;
                                  if (token == null || token.isEmpty) {
                                    setModalState(() {
                                      _checkoutError =
                                          'Tu sesion ya no es valida. Vuelve a iniciar sesion.';
                                    });
                                    return;
                                  }

                                  setModalState(() {
                                    _checkoutError = null;
                                  });
                                  setModalState(() => _submitting = true);
                                  try {
                                    final response = await OrderApi.createOrder(
                                      items: cartController.items,
                                      token: token,
                                      addressId: _selectedAddress!.id,
                                      idempotencyKey: _pendingOrderRequestId ??=
                                          _createOrderRequestId(),
                                    );
                                    final checkoutUrl = await OrderApi.createMercadoPagoCheckout(
                                      token: token,
                                      orderId: response.orderId,
                                    );
                                    final launched = await launchUrl(
                                      Uri.parse(checkoutUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!launched) {
                                      throw Exception('No se pudo abrir Mercado Pago. Intenta nuevamente.');
                                    }
                                    if (!pageContext.mounted) return;
                                    cartController.clear();
                                    _pendingOrderRequestId = null;
                                    Navigator.of(context).pop();
                                    Navigator.of(pageContext).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => OrderReceivedPage(
                                          orderId: response.orderId,
                                          status: response.status,
                                          items: response.items,
                                          subtotal: response.subtotal,
                                          shipping: response.shipping,
                                          total: response.total,
                                          deliveryLabel: response.deliveryLabel,
                                          recipientName: response.recipientName,
                                          recipientPhone:
                                              response.recipientPhone,
                                          deliveryAddressText:
                                              response.deliveryAddressText,
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    setModalState(() {
                                      _checkoutError = error
                                          .toString()
                                          .replaceFirst('Exception: ', '');
                                    });
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(() => _submitting = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Confirmar pedido'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartController = CartScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Carrito')),
      body: cartController.isEmpty
          ? const _EmptyCartState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0x33F2C21A)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu pedido',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajusta cantidades, revisa extras y confirma cuando quieras terminar.',
                        style: TextStyle(
                          color: Color(0xFFD3D0CB),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _HeroMetric(
                            label: 'Productos',
                            value: cartController.items.length.toString(),
                          ),
                          const SizedBox(width: 10),
                          _HeroMetric(
                            label: 'Subtotal',
                            value:
                                '\$${cartController.subtotal.toStringAsFixed(0)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...cartController.items.map((item) {
                  final itemSubtotal = item.unitPrice * item.quantity;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            (item.image != null && item.image!.isNotEmpty)
                                ? item.image!
                                : 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80',
                            width: 86,
                            height: 86,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF777777),
                                ),
                              ),
                              if (item.customizationSummary.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  item.customizationSummary,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF555555),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                '\$${itemSubtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x14F2C21A),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x22F2C21A)),
                          ),
                          child: Column(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: Color(0xFFF2C21A),
                                ),
                                onPressed: () {
                                  cartController.increaseQuantity(item.cartKey);
                                },
                              ),
                              Text(
                                item.quantity.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: Color(0xFFF2C21A),
                                ),
                                onPressed: () {
                                  cartController.decreaseQuantity(item.cartKey);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
      bottomNavigationBar: cartController.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0x14F2C21A))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SummaryRow(
                    label: 'Subtotal',
                    value: cartController.subtotal,
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(label: 'Envio', value: cartController.shipping),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Total',
                    value: cartController.total,
                    isEmphasized: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: cartController.isEmpty ? null : _confirmOrder,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Confirmar pedido'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x22F2C21A)),
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

class _SummaryCard extends StatelessWidget {
  final double subtotal;
  final double shipping;
  final double total;

  const _SummaryCard({
    required this.subtotal,
    required this.shipping,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x14F2C21A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Envio', value: shipping),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Total', value: total, isEmphasized: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isEmphasized;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isEmphasized ? 16 : 14,
      fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w600,
      color: isEmphasized ? Colors.black : const Color(0xFF555555),
    );

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('\$${value.toStringAsFixed(2)}', style: style),
      ],
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x14F2C21A)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 46,
                color: Color(0xFFF2C21A),
              ),
              SizedBox(height: 14),
              Text(
                'Tu carrito esta vacio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'Agrega productos desde un negocio para continuar con tu pedido.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
