import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/restaurant/data/product_api.dart';
import 'package:nexo/shared/models/business.dart';
import 'package:nexo/shared/models/product.dart';

class ProductFormPage extends StatefulWidget {
  final Business business;
  final Product? product;

  const ProductFormPage({
    super.key,
    required this.business,
    this.product,
  });

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageController;
  bool _isAvailable = true;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product != null
          ? widget.product!.price.toStringAsFixed(2)
          : '',
    );
    _imageController = TextEditingController(text: widget.product?.image ?? '');
    _isAvailable = widget.product?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    final token = AuthScope.of(context).token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu sesion no es valida. Vuelve a iniciar sesion.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final price = double.parse(_priceController.text.trim());

      if (_isEditing) {
        await ProductApi.updateProduct(
          token: token,
          businessId: widget.business.id,
          productId: widget.product!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          image: _imageController.text.trim(),
          isAvailable: _isAvailable,
        );
      } else {
        await ProductApi.createProduct(
          token: token,
          businessId: widget.business.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          image: _imageController.text.trim(),
          isAvailable: _isAvailable,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudimos guardar el producto: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x14F2C21A)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
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
                      color: const Color(0x14F2C21A),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x4DF2C21A)),
                    ),
                    child: Text(
                      _isEditing ? 'AJUSTES DE PRODUCTO' : 'NUEVO PRODUCTO',
                      style: const TextStyle(
                        color: Color(0xFFF2C21A),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isEditing
                        ? 'Haz ajustes finos en tu producto'
                        : 'Construye un producto claro y atractivo',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nombre, foto, descripcion y disponibilidad bien definidos ayudan a que el menu se vea mas profesional.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Escribe el nombre del producto';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripcion',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Precio',
                            prefixText: '\$ ',
                          ),
                          validator: (value) {
                            final price = double.tryParse((value ?? '').trim());
                            if (price == null) {
                              return 'Escribe un precio valido';
                            }
                            if (price <= 0) {
                              return 'Debe ser mayor a 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _imageController,
                          decoration: const InputDecoration(
                            labelText: 'URL de imagen',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x33F2C21A)),
                    ),
                    child: SwitchListTile(
                      value: _isAvailable,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: const Text(
                        'Disponible para clientes',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Si lo apagas, el cliente no lo vera en el catalogo.',
                        style: TextStyle(color: Color(0xFFD8D4CB)),
                      ),
                      onChanged: (value) {
                        setState(() => _isAvailable = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Guardando...' : 'Guardar producto'),
            ),
          ],
        ),
      ),
    );
  }
}
