import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/restaurant/data/product_api.dart';
import 'package:nexo/shared/models/business.dart';
import 'package:nexo/shared/models/product.dart';

class ProductOptionsPage extends StatefulWidget {
  final Business business;
  final Product product;

  const ProductOptionsPage({
    super.key,
    required this.business,
    required this.product,
  });

  @override
  State<ProductOptionsPage> createState() => _ProductOptionsPageState();
}

class _ProductOptionsPageState extends State<ProductOptionsPage> {
  late Product _product;
  List<ProductOptionGroup> _businessGroups = const [];
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  String? get _token => AuthScope.of(context).token;

  List<ProductOptionGroup> get _availableReusableGroups => _businessGroups
      .where((group) => !group.isAssignedToProduct)
      .toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _reloadAll();
    }
  }

  Future<void> _reloadAll() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        ProductApi.getOwnedProducts(
          businessId: widget.business.id,
          token: token,
        ),
        ProductApi.getBusinessOptionGroups(
          businessId: widget.business.id,
          token: token,
          productId: _product.id,
        ),
      ]);

      final products = results[0] as List<Product>;
      final businessGroups = results[1] as List<ProductOptionGroup>;
      final updated = products.firstWhere((item) => item.id == _product.id);

      if (!mounted) return;
      setState(() {
        _product = updated;
        _businessGroups = businessGroups;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _openGroupDialog([ProductOptionGroup? group]) async {
    final nameController = TextEditingController(text: group?.name ?? '');
    final minController = TextEditingController(
      text: (group?.minSelections ?? 0).toString(),
    );
    final maxController = TextEditingController(
      text: (group?.maxSelections ?? 1).toString(),
    );
    bool isRequired = group?.isRequired ?? false;
    bool submitted = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Text(group == null ? 'Nuevo grupo reusable' : 'Editar grupo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Este grupo se guardará para tu negocio y podrás usarlo en otros productos después.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del grupo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Selecciones mínimas',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Selecciones máximas',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isRequired,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Grupo obligatorio'),
                      onChanged: (value) {
                        setDialogState(() => isRequired = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: submitted
                      ? null
                      : () async {
                          final token = _token;
                          final minSelections =
                              int.tryParse(minController.text.trim()) ?? 0;
                          final maxSelections =
                              int.tryParse(maxController.text.trim()) ?? 1;

                          if (token == null || token.isEmpty) return;
                          if (nameController.text.trim().isEmpty) return;

                          setDialogState(() => submitted = true);

                          try {
                            if (group == null) {
                              await ProductApi.createOptionGroup(
                                token: token,
                                businessId: widget.business.id,
                                productId: _product.id,
                                name: nameController.text.trim(),
                                isRequired: isRequired,
                                minSelections: minSelections,
                                maxSelections: maxSelections,
                                sortOrder: _businessGroups.length,
                              );
                            } else {
                              await ProductApi.updateOptionGroup(
                                token: token,
                                businessId: widget.business.id,
                                productId: _product.id,
                                groupId: group.id,
                                name: nameController.text.trim(),
                                isRequired: isRequired,
                                minSelections: minSelections,
                                maxSelections: maxSelections,
                                sortOrder: group.sortOrder,
                              );
                            }

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _reloadAll();
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$error')),
                            );
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => submitted = false);
                            }
                          }
                        },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openOptionDialog(
    ProductOptionGroup group, [
    ProductOption? option,
  ]) async {
    final nameController = TextEditingController(text: option?.name ?? '');
    final priceController = TextEditingController(
      text: option != null ? option.priceDelta.toStringAsFixed(2) : '0.00',
    );
    bool isAvailable = option?.isAvailable ?? true;
    bool submitted = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Text(option == null ? 'Nueva opción' : 'Editar opción'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la opción',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Precio extra',
                        prefixText: '\$ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isAvailable,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Disponible'),
                      onChanged: (value) {
                        setDialogState(() => isAvailable = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: submitted
                      ? null
                      : () async {
                          final token = _token;
                          if (token == null || token.isEmpty) return;
                          if (nameController.text.trim().isEmpty) return;
                          final priceDelta =
                              double.tryParse(priceController.text.trim()) ?? 0;

                          setDialogState(() => submitted = true);

                          try {
                            if (option == null) {
                              await ProductApi.createOption(
                                token: token,
                                businessId: widget.business.id,
                                productId: _product.id,
                                groupId: group.id,
                                name: nameController.text.trim(),
                                priceDelta: priceDelta,
                                isAvailable: isAvailable,
                                sortOrder: group.options.length,
                              );
                            } else {
                              await ProductApi.updateOption(
                                token: token,
                                businessId: widget.business.id,
                                productId: _product.id,
                                groupId: group.id,
                                optionId: option.id,
                                name: nameController.text.trim(),
                                priceDelta: priceDelta,
                                isAvailable: isAvailable,
                                sortOrder: option.sortOrder,
                              );
                            }

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _reloadAll();
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$error')),
                            );
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => submitted = false);
                            }
                          }
                        },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _attachExistingGroup() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        final groups = _availableReusableGroups;

        if (groups.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_clear_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay grupos libres para reutilizar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Primero crea un grupo nuevo o usa los que ya están asignados a este producto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF666666), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usar grupo existente',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Estos grupos ya existen en tu negocio. Asignalos a este producto sin duplicarlos.',
                  style: TextStyle(color: Color(0xFF666666), height: 1.4),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFCF7),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE8E1D6)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${group.options.length} opciones · usado en ${group.assignedProductsCount} producto(s)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonal(
                              onPressed: _working
                                  ? null
                                  : () async {
                                      Navigator.pop(context);
                                      setState(() => _working = true);
                                      try {
                                        await ProductApi.attachOptionGroup(
                                          token: token,
                                          businessId: widget.business.id,
                                          productId: _product.id,
                                          groupId: group.id,
                                        );
                                        await _reloadAll();
                                      } catch (error) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('$error')),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _working = false);
                                        }
                                      }
                                    },
                              child: const Text('Asignar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _detachGroup(ProductOptionGroup group) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _working = true);
    try {
      await ProductApi.detachOptionGroup(
        token: token,
        businessId: widget.business.id,
        productId: _product.id,
        groupId: group.id,
      );
      await _reloadAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_product.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reloadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
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
                            'Grupos reutilizables',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ingredientes y extras del producto',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crea una vez y reutiliza en otros platos de ${widget.business.name}.',
                          style: const TextStyle(
                            color: Color(0xFFD3D0CB),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _working ? null : () => _openGroupDialog(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Crear grupo'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _working ? null : _attachExistingGroup,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                ),
                                child: const Text('Usar existente'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _MetricCard(
                          label: 'Asignados',
                          value: _product.optionGroups.length.toString(),
                        ),
                        const SizedBox(width: 10),
                        _MetricCard(
                          label: 'Biblioteca',
                          value: _businessGroups.length.toString(),
                        ),
                        const SizedBox(width: 10),
                        _MetricCard(
                          label: 'Libres',
                          value: _availableReusableGroups.length.toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Asignados a este producto',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (_product.optionGroups.isEmpty)
                    _EmptyPanel(
                      icon: Icons.tune_rounded,
                      title: 'Todavía no hay grupos en este producto',
                      description:
                          'Crea uno nuevo o reutiliza un grupo ya existente del negocio.',
                    )
                  else
                    ..._product.optionGroups.map((group) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x11000000),
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
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _InlineTag(
                                            label: group.isRequired
                                                ? 'Obligatorio'
                                                : 'Opcional',
                                          ),
                                          _InlineTag(
                                            label:
                                                'Min ${group.minSelections}',
                                          ),
                                          _InlineTag(
                                            label: group.maxSelections == 0
                                                ? 'Sin límite'
                                                : 'Max ${group.maxSelections}',
                                          ),
                                          _InlineTag(
                                            label:
                                                'Usado en ${group.assignedProductsCount} producto(s)',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openGroupDialog(group);
                                    } else if (value == 'detach') {
                                      _detachGroup(group);
                                    } else if (value == 'add_option') {
                                      _openOptionDialog(group);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar grupo'),
                                    ),
                                    PopupMenuItem(
                                      value: 'add_option',
                                      child: Text('Agregar opción'),
                                    ),
                                    PopupMenuItem(
                                      value: 'detach',
                                      child: Text('Quitar de este producto'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (group.options.isEmpty)
                              const Text(
                                'Sin opciones todavía',
                                style: TextStyle(color: Color(0xFF777777)),
                              )
                            else
                              ...group.options.map(
                                (option) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFCF7),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFEAE3D8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: option.isAvailable
                                              ? const Color(0xFFEAF7EE)
                                              : const Color(0xFFFCE9E7),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          option.isAvailable
                                              ? 'Disponible'
                                              : 'Oculta',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: option.isAvailable
                                                ? const Color(0xFF137333)
                                                : const Color(0xFFC5221F),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _openOptionDialog(group, option),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F4EE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  final String label;

  const _InlineTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF666666),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
