import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/restaurant/application/catalog_refresh_controller.dart';
import 'package:nexo/features/restaurant/data/business_api.dart';
import 'package:nexo/shared/models/business.dart';

class BusinessFormPage extends StatefulWidget {
  final Business? business;

  const BusinessFormPage({super.key, this.business});

  @override
  State<BusinessFormPage> createState() => _BusinessFormPageState();
}

class _DaySchedule {
  final int day;
  final String label;
  bool isOpen;
  String openTime;
  String closeTime;

  _DaySchedule({
    required this.day,
    required this.label,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  BusinessOperatingHour toOperatingHour() {
    return BusinessOperatingHour(
      day: day,
      isOpen: isOpen,
      openTime: openTime,
      closeTime: closeTime,
    );
  }
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
  late final List<_DaySchedule> _schedule;
  bool _saving = false;

  bool get _isEditing => widget.business != null;

  int? _parseMinutes(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  String get _openDaysPayload {
    final days =
        _schedule.where((item) => item.isOpen).map((item) => item.day).toList()
          ..sort();
    return days.join(',');
  }

  List<BusinessOperatingHour> get _operatingHoursPayload {
    return _schedule.map((item) => item.toOperatingHour()).toList();
  }

  String? _validateSchedule() {
    final openDays = _schedule.where((item) => item.isOpen).toList();
    if (openDays.isEmpty) return 'Selecciona al menos un dia abierto.';

    for (final day in openDays) {
      final open = _parseMinutes(day.openTime);
      final close = _parseMinutes(day.closeTime);
      if (open == null || close == null) {
        return 'El horario de ${day.label} debe usar HH:mm.';
      }
      if (close <= open) {
        return 'En ${day.label}, la hora de cierre debe ser mayor que la de apertura.';
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.business?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.business?.description ?? '',
    );
    _timeController = TextEditingController(
      text: _normalizeEstimatedMinutes(widget.business?.time ?? '30'),
    );
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
    _schedule = _initialSchedule(widget.business);
    _latitude = widget.business?.latitude;
    _longitude = widget.business?.longitude;
  }

  List<_DaySchedule> _initialSchedule(Business? business) {
    const labels = {
      1: 'Lunes',
      2: 'Martes',
      3: 'Miercoles',
      4: 'Jueves',
      5: 'Viernes',
      6: 'Sabado',
      7: 'Domingo',
    };
    final byDay = {
      for (final hour
          in business?.operatingHours ?? const <BusinessOperatingHour>[])
        hour.day: hour,
    };

    return List.generate(7, (index) {
      final day = index + 1;
      final saved = byDay[day];
      return _DaySchedule(
        day: day,
        label: labels[day]!,
        isOpen: saved?.isOpen ?? day <= 5,
        openTime: saved?.openTime ?? business?.openTime ?? '09:00',
        closeTime: saved?.closeTime ?? business?.closeTime ?? '22:00',
      );
    });
  }

  String _normalizeEstimatedMinutes(String value) {
    final trimmed = value.trim();
    final direct = int.tryParse(trimmed);
    if (direct != null) return direct.clamp(5, 180).toString();

    final match = RegExp(r'\d+').firstMatch(trimmed);
    if (match == null) return '30';

    final parsed = int.tryParse(match.group(0) ?? '') ?? 30;
    return parsed.clamp(5, 180).toString();
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

    final scheduleError = _validateSchedule();
    if (scheduleError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(scheduleError)));
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
          openTime: _schedule.firstWhere((item) => item.isOpen).openTime,
          closeTime: _schedule.firstWhere((item) => item.isOpen).closeTime,
          openDays: _openDaysPayload,
          operatingHours: _operatingHoursPayload,
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
          openTime: _schedule.firstWhere((item) => item.isOpen).openTime,
          closeTime: _schedule.firstWhere((item) => item.isOpen).closeTime,
          openDays: _openDaysPayload,
          operatingHours: _operatingHoursPayload,
          latitude: _latitude,
          longitude: _longitude,
          deliveryRadiusKm: deliveryRadiusKm,
        );
      }

      if (!mounted) return;
      CatalogRefreshController.instance.catalogChanged();
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

  Future<void> _pickHour(_DaySchedule day, bool isOpening) async {
    final current = _timeOfDayFromText(
      isOpening ? day.openTime : day.closeTime,
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: isOpening ? 'Hora de apertura' : 'Hora de cierre',
    );
    if (selected == null || !mounted) return;

    setState(() {
      final formatted = _formatTimeOfDay(selected);
      if (isOpening) {
        day.openTime = formatted;
      } else {
        day.closeTime = formatted;
      }
    });
  }

  TimeOfDay _timeOfDayFromText(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
                  const SizedBox(height: 18),
                  const Text(
                    'Horario por dia',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Activa cada dia que abre y elige su hora real de apertura y cierre.',
                    style: TextStyle(color: Color(0xFF666666), height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  ..._schedule.map(
                    (day) => _ScheduleRow(
                      day: day,
                      onToggle: (value) => setState(() => day.isOpen = value),
                      onPickOpen: () => _pickHour(day, true),
                      onPickClose: () => _pickHour(day, false),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descripcion'),
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
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tiempo estimado (min)',
                            hintText: '30',
                          ),
                          validator: (value) {
                            final minutes = int.tryParse((value ?? '').trim());
                            if (minutes == null) {
                              return 'Solo minutos';
                            }
                            if (minutes < 5 || minutes > 180) {
                              return '5 a 180';
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
                            final parsed = double.tryParse(
                              (value ?? '').trim(),
                            );
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
                      style: TextStyle(color: Color(0xFFD8D4CB), height: 1.45),
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

class _ScheduleRow extends StatelessWidget {
  final _DaySchedule day;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  const _ScheduleRow({
    required this.day,
    required this.onToggle,
    required this.onPickOpen,
    required this.onPickClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E1D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Switch(value: day.isOpen, onChanged: onToggle),
            ],
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: day.isOpen ? 1 : 0.38,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: day.isOpen ? onPickOpen : null,
                    icon: const Icon(Icons.storefront_rounded),
                    label: Text('Abre ${day.openTime}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: day.isOpen ? onPickClose : null,
                    icon: const Icon(Icons.lock_clock_rounded),
                    label: Text('Cierra ${day.closeTime}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
