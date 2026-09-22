import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/driver/data/admin_driver_api.dart';
import 'package:nexo/theme/app_buttons.dart';

class AdminDriversPage extends StatefulWidget {
  const AdminDriversPage({super.key});

  @override
  State<AdminDriversPage> createState() => _AdminDriversPageState();
}

class _AdminDriversPageState extends State<AdminDriversPage> {
  List<DriverApplication> _drivers = [];
  final Set<int> _savingIds = {};
  bool _loading = true;
  Object? _error;
  String _selectedStatus = 'pending';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      unawaited(_loadDrivers());
    }
  }

  Future<void> _loadDrivers() async {
    final token = AuthScope.of(context).token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final drivers = await AdminDriverApi.getApplications(token: token);
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(DriverApplication driver, String status) async {
    final token = AuthScope.of(context).token;
    if (token == null || token.isEmpty || _savingIds.contains(driver.userId)) {
      return;
    }

    setState(() => _savingIds.add(driver.userId));
    try {
      await AdminDriverApi.updateApproval(
        token: token,
        userId: driver.userId,
        status: status,
      );
      await _loadDrivers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Repartidor ${_statusLabel(status).toLowerCase()}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingIds.remove(driver.userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleDrivers = _drivers
        .where((driver) => driver.approvalStatus == _selectedStatus)
        .toList();
    final pendingCount = _drivers
        .where((driver) => driver.approvalStatus == 'pending')
        .length;
    final approvedCount = _drivers
        .where((driver) => driver.approvalStatus == 'approved')
        .length;
    final rejectedCount = _drivers
        .where((driver) => driver.approvalStatus == 'rejected')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repartidores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadDrivers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(error: _error!, onRetry: _loadDrivers)
          : RefreshIndicator(
              onRefresh: _loadDrivers,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0x33F2C21A)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verificación de identidad',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Revisa teléfono, vehículo, licencia e identificación antes de aprobar repartidores.',
                          style: TextStyle(
                            color: Color(0xFFD8D4CB),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  _DriverStatusFilters(
                    selected: _selectedStatus,
                    pendingCount: pendingCount,
                    approvedCount: approvedCount,
                    rejectedCount: rejectedCount,
                    onSelected: (status) =>
                        setState(() => _selectedStatus = status),
                  ),
                  const SizedBox(height: 16),
                  if (visibleDrivers.isEmpty)
                    _EmptyState(status: _selectedStatus)
                  else
                    ...visibleDrivers.map(
                      (driver) => _DriverApplicationCard(
                        driver: driver,
                        saving: _savingIds.contains(driver.userId),
                        onStatus: (status) => _updateStatus(driver, status),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DriverApplicationCard extends StatelessWidget {
  final DriverApplication driver;
  final bool saving;
  final ValueChanged<String> onStatus;

  const _DriverApplicationCard({
    required this.driver,
    required this.saving,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8E1D6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
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
                      driver.fullName.isNotEmpty
                          ? driver.fullName
                          : driver.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.email,
                      style: const TextStyle(color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
              _ApprovalChip(status: driver.approvalStatus),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Teléfono', value: driver.phone),
          _InfoRow(label: 'Vehículo', value: _vehicleLabel(driver.vehicleType)),
          if (driver.vehicleMakeModel.isNotEmpty)
            _InfoRow(label: 'Marca/modelo', value: driver.vehicleMakeModel),
          if (driver.vehicleColor.isNotEmpty)
            _InfoRow(label: 'Color', value: driver.vehicleColor),
          if (driver.vehiclePlate.isNotEmpty)
            _InfoRow(label: 'Placa', value: driver.vehiclePlate),
          if (driver.licenseNumber.isNotEmpty)
            _InfoRow(
              label: _licenseLabel(driver.licenseType),
              value: driver.licenseNumber,
            ),
          _InfoRow(
            label: _identityLabel(driver.identityType),
            value: driver.identityDocument,
          ),
          const SizedBox(height: 16),
          if (saving)
            const LinearProgressIndicator(minHeight: 3)
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () => onStatus('approved'),
                  style: AppButtons.primary,
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Aprobar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onStatus('pending'),
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Pendiente'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onStatus('rejected'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rechazar'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _vehicleLabel(String value) => switch (value) {
    'motorcycle' => 'Moto',
    'bicycle' => 'Bicicleta',
    'car' => 'Auto',
    _ => value,
  };

  String _licenseLabel(String value) =>
      value == 'permit' ? 'Permiso' : 'Licencia';

  String _identityLabel(String value) => switch (value) {
    'ine' => 'INE',
    'passport' => 'Pasaporte',
    'professional_license' => 'Cédula',
    _ => 'Identificación',
  };
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF777777),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'Sin dato',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalChip extends StatelessWidget {
  final String status;

  const _ApprovalChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => const Color(0xFF1E8E4D),
      'rejected' => const Color(0xFFE24A2B),
      _ => const Color(0xFFC79300),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DriverStatusFilters extends StatelessWidget {
  final String selected;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final ValueChanged<String> onSelected;

  const _DriverStatusFilters({
    required this.selected,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _DriverFilterButton(
            label: 'Pendientes',
            count: pendingCount,
            selected: selected == 'pending',
            attention: pendingCount > 0,
            onTap: () => onSelected('pending'),
          ),
          _DriverFilterButton(
            label: 'Aprobados',
            count: approvedCount,
            selected: selected == 'approved',
            onTap: () => onSelected('approved'),
          ),
          _DriverFilterButton(
            label: 'Rechazados',
            count: rejectedCount,
            selected: selected == 'rejected',
            onTap: () => onSelected('rejected'),
          ),
        ],
      ),
    );
  }
}

class _DriverFilterButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final bool attention;
  final VoidCallback onTap;

  const _DriverFilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.attention = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF5D5A55),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: attention && !selected
                        ? const Color(0xFFE24A2B)
                        : selected
                        ? const Color(0xFFF2C21A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: attention && !selected
                          ? Colors.white
                          : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String status;

  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8E1D6)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.delivery_dining_rounded,
            size: 48,
            color: Color(0xFFF2C21A),
          ),
          const SizedBox(height: 12),
          Text(
            switch (status) {
              'approved' => 'No hay repartidores aprobados.',
              'rejected' => 'No hay solicitudes rechazadas.',
              _ => 'No hay solicitudes pendientes.',
            },
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            status == 'pending'
                ? 'Las nuevas solicitudes aparecerán aquí para revisarlas.'
                : 'Puedes cambiar el estado desde otra pestaña cuando sea necesario.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF666666), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No pudimos cargar repartidores.\n${error.toString().replaceAll('Exception:', '').trim()}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'approved' => 'Aprobado',
    'rejected' => 'Rechazado',
    _ => 'Pendiente',
  };
}
