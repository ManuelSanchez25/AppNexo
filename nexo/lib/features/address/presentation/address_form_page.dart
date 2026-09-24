import 'package:flutter/material.dart';
import 'package:nexo/features/address/data/address_api.dart';
import 'package:nexo/features/location/presentation/location_picker_page.dart';
import 'package:nexo/shared/models/address.dart';
import 'package:nexo/shared/models/location_search_result.dart';

class AddressFormPage extends StatefulWidget {
  final String token;
  final Address? address;
  final String? suggestedRecipientName;

  const AddressFormPage({
    super.key,
    required this.token,
    this.address,
    this.suggestedRecipientName,
  });

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  late final TextEditingController _labelController;
  late final TextEditingController _recipientController;
  late final TextEditingController _phoneController;
  late final TextEditingController _streetController;
  late final TextEditingController _exteriorController;
  late final TextEditingController _interiorController;
  late final TextEditingController _neighborhoodController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _referencesController;
  double? _latitude;
  double? _longitude;
  String _selectedLocationLabel = '';
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _labelController = TextEditingController(text: address?.label ?? 'Casa');
    _recipientController = TextEditingController(
      text: address?.recipientName ?? widget.suggestedRecipientName ?? '',
    );
    _phoneController = TextEditingController(text: address?.phone ?? '');
    _streetController = TextEditingController(text: address?.street ?? '');
    _exteriorController = TextEditingController(
      text: address?.exteriorNumber ?? '',
    );
    _interiorController = TextEditingController(
      text: address?.interiorNumber ?? '',
    );
    _neighborhoodController = TextEditingController(
      text: address?.neighborhood ?? '',
    );
    _cityController = TextEditingController(text: address?.city ?? '');
    _stateController = TextEditingController(text: address?.state ?? '');
    _postalCodeController = TextEditingController(
      text: address?.postalCode ?? '',
    );
    _referencesController = TextEditingController(
      text: address?.references ?? '',
    );
    _latitude = address?.latitude;
    _longitude = address?.longitude;
    _selectedLocationLabel = address?.fullAddress ?? '';
    _isDefault = address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _exteriorController.dispose();
    _interiorController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _referencesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildBody() {
    return {
      'label': _labelController.text.trim(),
      'recipientName': _recipientController.text.trim(),
      'phone': _phoneController.text.trim(),
      'street': _streetController.text.trim(),
      'exteriorNumber': _exteriorController.text.trim(),
      'interiorNumber': _interiorController.text.trim(),
      'neighborhood': _neighborhoodController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'postalCode': _postalCodeController.text.trim(),
      'references': _referencesController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      'isDefault': _isDefault,
    };
  }

  String? _validateBeforeSave() {
    if (_labelController.text.trim().isEmpty) {
      return 'Escribe una etiqueta para la direccion';
    }
    if (_recipientController.text.trim().isEmpty) {
      return 'Escribe quien recibe el pedido';
    }
    if (_phoneController.text.trim().isEmpty) {
      return 'Escribe un telefono de contacto';
    }
    if (_streetController.text.trim().isEmpty) return 'Escribe la calle';
    if (_exteriorController.text.trim().isEmpty &&
        _interiorController.text.trim().isEmpty) {
      return 'Escribe al menos numero exterior o interior';
    }
    if (_neighborhoodController.text.trim().isEmpty) {
      return 'Escribe la colonia';
    }
    if (_cityController.text.trim().isEmpty) return 'Escribe la ciudad';
    if (_stateController.text.trim().isEmpty) return 'Escribe el estado';
    if (_postalCodeController.text.trim().isEmpty) {
      return 'Escribe el codigo postal';
    }
    if (_latitude == null || _longitude == null) {
      return 'Selecciona el punto de entrega en el mapa';
    }
    return null;
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LocationSearchResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          title: 'Ubica tu direccion',
          searchHint: 'Ej. Calle, numero, colonia, ciudad',
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialQuery: _selectedLocationLabel,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _selectedLocationLabel = result.displayName;
      if (result.street.isNotEmpty) _streetController.text = result.street;
      if (result.exteriorNumber.isNotEmpty) {
        _exteriorController.text = result.exteriorNumber;
      }
      if (result.neighborhood.isNotEmpty) {
        _neighborhoodController.text = result.neighborhood;
      }
      if (result.city.isNotEmpty) _cityController.text = result.city;
      if (result.state.isNotEmpty) _stateController.text = result.state;
      if (result.postalCode.isNotEmpty) {
        _postalCodeController.text = result.postalCode;
      }
    });
  }

  Widget _locationPicker() {
    final selectedPoint = _latitude != null && _longitude != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E1D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ubicacion de entrega',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Busca la calle o marca el punto exacto para que el repartidor llegue bien.',
            style: TextStyle(color: Color(0xFF666666), height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.map_outlined),
            label: Text(
              selectedPoint
                  ? 'Cambiar ubicacion en el mapa'
                  : 'Buscar ubicacion en el mapa',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            !selectedPoint
                ? 'Falta seleccionar el punto en el mapa.'
                : 'Ubicacion seleccionada: $_selectedLocationLabel',
            style: TextStyle(
              color: !selectedPoint
                  ? const Color(0xFF9A5B1B)
                  : const Color(0xFF267348),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final validationError = _validateBeforeSave();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() => _saving = true);
    try {
      final body = _buildBody();
      final address = widget.address == null
          ? await AddressApi.createAddress(token: widget.token, body: body)
          : await AddressApi.updateAddress(
              token: widget.token,
              addressId: widget.address!.id,
              body: body,
            );

      if (!mounted) return;
      Navigator.pop(context, address);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.address != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar direccion' : 'Nueva direccion'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _locationPicker(),
          const SizedBox(height: 16),
          _field('Etiqueta', _labelController),
          _field('Recibe', _recipientController),
          _field(
            'Telefono',
            _phoneController,
            keyboardType: TextInputType.phone,
          ),
          _field('Calle', _streetController),
          Row(
            children: [
              Expanded(child: _field('Numero exterior', _exteriorController)),
              const SizedBox(width: 12),
              Expanded(child: _field('Interior', _interiorController)),
            ],
          ),
          _field('Colonia', _neighborhoodController),
          Row(
            children: [
              Expanded(child: _field('Ciudad', _cityController)),
              const SizedBox(width: 12),
              Expanded(child: _field('Estado', _stateController)),
            ],
          ),
          _field(
            'Codigo postal',
            _postalCodeController,
            keyboardType: TextInputType.number,
          ),
          _field('Referencias', _referencesController, maxLines: 3),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar como direccion principal'),
            value: _isDefault,
            onChanged: (value) => setState(() => _isDefault = value),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando...' : 'Guardar direccion'),
          ),
        ],
      ),
    );
  }
}
