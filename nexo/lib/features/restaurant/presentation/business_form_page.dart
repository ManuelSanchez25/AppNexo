import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/restaurant/data/business_api.dart';
import 'package:nexo/shared/models/business.dart';

class BusinessFormPage extends StatefulWidget {
  final Business? business;

  const BusinessFormPage({
    super.key,
    this.business,
  });

  @override
  State<BusinessFormPage> createState() => _BusinessFormPageState();
}

class _BusinessFormPageState extends State<BusinessFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _timeController;
  late final TextEditingController _ratingController;
  late final TextEditingController _imageController;
  late final TextEditingController _addressController;
  late final TextEditingController _radiusController;
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  bool get _isEditing => widget.business != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.business?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.business?.description ?? '',
    );
    _timeController = TextEditingController(text: widget.business?.time ?? '');
    _ratingController = TextEditingController(
      text: widget.business != null
          ? widget.business!.rating.toStringAsFixed(1)
          : '4.5',
    );
    _imageController = TextEditingController(
      text: widget.business?.imageUrl ?? '',
    );
    _addressController = TextEditingController(
      text: widget.business?.addressText ?? '',
    );
    _radiusController = TextEditingController(
      text: widget.business != null
          ? ((widget.business!.deliveryRadiusKm <= 0
                  ? 5.0
                  : widget.business!.deliveryRadiusKm))
              .toStringAsFixed(1)
          : '5.0',
    );
    _latitude = widget.business?.latitude;
    _longitude = widget.business?.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    _ratingController.dispose();
    _imageController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
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
      final rating = double.parse(_ratingController.text.trim());
      final deliveryRadiusKm = double.parse(_radiusController.text.trim());

      if (_isEditing) {
        await BusinessApi.updateBusiness(
          token: token,
          businessId: widget.business!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          time: _timeController.text.trim(),
          rating: rating,
          imageUrl: _imageController.text.trim(),
          addressText: _addressController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          deliveryRadiusKm: deliveryRadiusKm,
        );
      } else {
        await BusinessApi.createBusiness(
          token: token,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          time: _timeController.text.trim(),
          rating: rating,
          imageUrl: _imageController.text.trim(),
          addressText: _addressController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          deliveryRadiusKm: deliveryRadiusKm,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudimos guardar el negocio: $error')),
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
        title: Text(_isEditing ? 'Editar negocio' : 'Nuevo negocio'),
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
                      _isEditing ? 'NEXO BUSINESS' : 'NUEVO NEGOCIO',
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
                        ? 'Actualiza la identidad de tu negocio'
                        : 'Empieza con una base limpia para tu restaurante',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nombre, descripcion, tiempos e imagen bien presentados hacen que el catalogo se vea mucho mas serio.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del negocio',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Escribe el nombre del negocio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripcion',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Escribe una descripcion';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _timeController,
                          decoration: const InputDecoration(
                            labelText: 'Tiempo estimado',
                            hintText: '20-30 min',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Escribe el tiempo estimado';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _ratingController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Rating',
                            hintText: '4.7',
                          ),
                          validator: (value) {
                            final parsed = double.tryParse((value ?? '').trim());
                            if (parsed == null) {
                              return 'Invalido';
                            }
                            if (parsed < 0 || parsed > 5) {
                              return '0 a 5';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _imageController,
                    decoration: const InputDecoration(
                      labelText: 'URL de imagen',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ubicacion del negocio',
                      hintText: 'Escribe la direccion completa del negocio',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Escribe la ubicacion del negocio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x33F2C21A)),
                    ),
                    child: const Text(
                      'Mapa y cobertura automatica deshabilitados temporalmente. La ubicacion sigue siendo obligatoria, pero por ahora se captura manualmente.',
                      style: TextStyle(
                        color: Color(0xFFD8D4CB),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _radiusController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Radio de entrega (km)',
                      hintText: '5.0',
                    ),
                    validator: (value) {
                      final parsed = double.tryParse((value ?? '').trim());
                      if (parsed == null) {
                        return 'Escribe un numero valido';
                      }
                      if (parsed < 0.5 || parsed > 50) {
                        return 'Usa un radio entre 0.5 y 50 km';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Guardando...' : 'Guardar negocio'),
            ),
          ],
        ),
      ),
    );
  }
}
