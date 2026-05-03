import 'package:flutter/material.dart';
import 'package:nexo/features/cart/application/cart_scope.dart';
import 'package:nexo/shared/models/cart_item.dart';
import 'package:nexo/shared/models/product.dart';

class ProductCustomizationPage extends StatefulWidget {
  final int businessId;
  final Product product;

  const ProductCustomizationPage({
    super.key,
    required this.businessId,
    required this.product,
  });

  @override
  State<ProductCustomizationPage> createState() =>
      _ProductCustomizationPageState();
}

class _ProductCustomizationPageState extends State<ProductCustomizationPage> {
  final Map<int, Set<int>> _selectedByGroup = {};

  double get _selectedOptionsPrice {
    double total = 0;
    for (final group in widget.product.optionGroups) {
      final selectedIds = _selectedByGroup[group.id] ?? <int>{};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          total += option.priceDelta;
        }
      }
    }
    return total;
  }

  void _toggleOption(ProductOptionGroup group, ProductOption option) {
    final current = {...(_selectedByGroup[group.id] ?? <int>{})};
    final isSelected = current.contains(option.id);

    if (group.maxSelections == 1) {
      if (isSelected) {
        current.clear();
      } else {
        current
          ..clear()
          ..add(option.id);
      }
    } else {
      if (isSelected) {
        current.remove(option.id);
      } else {
        if (group.maxSelections > 0 && current.length >= group.maxSelections) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Solo puedes elegir ${group.maxSelections} opciones en ${group.name}',
              ),
            ),
          );
          return;
        }
        current.add(option.id);
      }
    }

    setState(() {
      if (current.isEmpty) {
        _selectedByGroup.remove(group.id);
      } else {
        _selectedByGroup[group.id] = current;
      }
    });
  }

  bool _validateRequiredGroups() {
    for (final group in widget.product.optionGroups) {
      final selectedCount = (_selectedByGroup[group.id] ?? <int>{}).length;
      final minimum = group.isRequired && group.minSelections == 0
          ? 1
          : group.minSelections;

      if (selectedCount < minimum) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completa la seleccion en ${group.name}'),
          ),
        );
        return false;
      }
    }

    return true;
  }

  void _addToCart() {
    if (!_validateRequiredGroups()) return;

    final cartController = CartScope.of(context);
    if (!cartController.canAddFromBusiness(widget.businessId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu carrito es de otro negocio. Vacialo para continuar.'),
        ),
      );
      return;
    }

    final selectedOptions = <CartSelectedOption>[];
    for (final group in widget.product.optionGroups) {
      final selectedIds = _selectedByGroup[group.id] ?? <int>{};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          selectedOptions.add(
            CartSelectedOption(
              id: option.id,
              groupName: group.name,
              name: option.name,
              priceDelta: option.priceDelta,
            ),
          );
        }
      }
    }

    final sortedOptionIds = selectedOptions.map((option) => option.id).toList()
      ..sort();
    final cartKey = '${widget.product.id}:${sortedOptionIds.join('-')}';

    cartController.addItem(
      businessId: widget.businessId,
      item: CartItem(
        cartKey: cartKey,
        id: widget.product.id,
        name: widget.product.name,
        description: widget.product.description,
        basePrice: widget.product.price,
        image: widget.product.image,
        selectedOptions: selectedOptions,
      ),
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto agregado al carrito')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.product.price + _selectedOptionsPrice;

    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: ElevatedButton(
          onPressed: _addToCart,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text('Agregar por \$${totalPrice.toStringAsFixed(2)}'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  widget.product.name,
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
                if (widget.product.image.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      widget.product.image,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                    'Personalizable',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.product.description.isEmpty
                      ? 'Configura tus ingredientes y extras antes de agregarlo al carrito.'
                      : widget.product.description,
                  style: const TextStyle(
                    color: Color(0xFFD3D0CB),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _TopTag(
                      label: 'Base \$${widget.product.price.toStringAsFixed(2)}',
                    ),
                    const SizedBox(width: 8),
                    _TopTag(
                      label:
                          '${widget.product.optionGroups.length} grupo(s)',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...widget.product.optionGroups.map((group) {
            final selectedIds = _selectedByGroup[group.id] ?? <int>{};
            final selectedCount = selectedIds.length;
            final helper = group.maxSelections == 1
                ? 'Elige una opcion'
                : group.maxSelections == 0
                    ? 'Hasta ${group.minSelections == 0 ? 'las que quieras' : 'desde ${group.minSelections} en adelante'}'
                    : 'Elige hasta ${group.maxSelections} opciones';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              helper,
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: group.isRequired
                              ? const Color(0xFFFEF0E6)
                              : const Color(0xFFF3F0EA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          group.isRequired ? 'Obligatorio' : 'Opcional',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: group.isRequired
                                ? const Color(0xFFB25517)
                                : const Color(0xFF6A6358),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...group.options.map((option) {
                    final isSelected = selectedIds.contains(option.id);
                    return GestureDetector(
                      onTap: () => _toggleOption(group, option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFF6EC)
                              : const Color(0xFFF9F7F2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFE4B17D)
                                : const Color(0xFFE8E3DA),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    option.priceDelta == 0
                                        ? 'Sin costo extra'
                                        : '+ \$${option.priceDelta.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _SelectionIndicator(selected: isSelected),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (selectedCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$selectedCount seleccionado(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A6F61),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TopTag extends StatelessWidget {
  final String label;

  const _TopTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool selected;

  const _SelectionIndicator({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? Colors.black : const Color(0xFFCFC8BE),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
