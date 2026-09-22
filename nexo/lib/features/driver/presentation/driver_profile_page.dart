import 'package:flutter/material.dart';
import 'package:nexo/features/auth/data/auth_api.dart';

class DriverProfilePage extends StatefulWidget {
  final String token;
  const DriverProfilePage({super.key, required this.token});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  Map<String, dynamic>? _profile;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await AuthApi.driverProfile(token: widget.token);
      if (mounted) setState(() => _profile = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _value(String key) =>
      _profile?[key]?.toString().trim().isNotEmpty == true
      ? _profile![key].toString()
      : 'No registrado';
  String _vehicle(String value) =>
      {'motorcycle': 'Moto', 'bicycle': 'Bicicleta', 'car': 'Auto'}[value] ??
      value;
  String _status(String value) =>
      {
        'approved': 'Aprobado',
        'pending': 'Pendiente',
        'rejected': 'Rechazado',
      }[value] ??
      value;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis datos'),
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No pudimos cargar tus datos.'),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          )
        : _profile == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFF2C21A),
                      child: Icon(
                        Icons.delivery_dining_rounded,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _value('fullName'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _status(_value('approvalStatus')),
                      style: const TextStyle(
                        color: Color(0xFFF2C21A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _section('Cuenta', [
                _row(Icons.alternate_email, 'Usuario', _value('username')),
                _row(Icons.email_outlined, 'Correo', _value('email')),
                _row(Icons.phone_outlined, 'Teléfono', _value('phone')),
              ]),
              _section('Vehículo', [
                _row(
                  Icons.two_wheeler_rounded,
                  'Tipo',
                  _vehicle(_value('vehicleType')),
                ),
                _row(
                  Icons.directions_car_outlined,
                  'Marca y modelo',
                  _value('vehicleMakeModel'),
                ),
                _row(Icons.palette_outlined, 'Color', _value('vehicleColor')),
                _row(Icons.pin_outlined, 'Placa', _value('vehiclePlate')),
              ]),
              _section('Verificación', [
                _row(
                  Icons.badge_outlined,
                  'Identificación',
                  _value('identityType').toUpperCase(),
                ),
                _row(
                  Icons.numbers_rounded,
                  'Folio',
                  _value('identityDocument'),
                ),
                _row(
                  Icons.credit_card_outlined,
                  'Licencia o permiso',
                  _value('licenseType'),
                ),
                _row(Icons.numbers_rounded, 'Folio', _value('licenseNumber')),
              ]),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Los datos verificados están protegidos. Para corregir identidad, licencia o vehículo, solicita una nueva revisión al administrador.',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
              ),
            ],
          ),
  );

  Widget _section(String title, List<Widget> rows) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE8E1D6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const Divider(height: 24),
        ...rows,
      ],
    ),
  );
  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 21, color: const Color(0xFF8C7310)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    ),
  );
}
