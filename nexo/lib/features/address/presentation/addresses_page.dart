import 'package:flutter/material.dart';
import 'package:nexo/features/address/data/address_api.dart';
import 'package:nexo/features/address/presentation/address_form_page.dart';
import 'package:nexo/shared/models/address.dart';

class AddressesPage extends StatefulWidget {
  final String token;
  final String suggestedRecipientName;
  final bool selectionMode;
  final int? initiallySelectedAddressId;

  const AddressesPage({
    super.key,
    required this.token,
    required this.suggestedRecipientName,
    this.selectionMode = false,
    this.initiallySelectedAddressId,
  });

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  Future<List<Address>>? _future;
  int? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _selectedAddressId = widget.initiallySelectedAddressId;
    _future = _loadAddresses();
  }

  Future<List<Address>> _loadAddresses() {
    return AddressApi.getAddresses(token: widget.token);
  }

  Future<void> _reload() async {
    final future = _loadAddresses();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openForm([Address? address]) async {
    final result = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormPage(
          token: widget.token,
          address: address,
          suggestedRecipientName: widget.suggestedRecipientName,
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedAddressId = result.id);
      await _reload();
    }
  }

  Future<void> _delete(Address address) async {
    await AddressApi.deleteAddress(token: widget.token, addressId: address.id);
    if (_selectedAddressId == address.id) {
      _selectedAddressId = null;
    }
    await _reload();
  }

  Future<void> _setDefault(Address address) async {
    await AddressApi.setDefaultAddress(token: widget.token, addressId: address.id);
    setState(() => _selectedAddressId = address.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Selecciona direccion' : 'Mis direcciones'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva direccion'),
      ),
      body: FutureBuilder<List<Address>>(
        future: _future,
        builder: (context, snapshot) {
          if (_future == null || snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 40),
                  Icon(Icons.location_on_outlined, size: 46),
                  SizedBox(height: 14),
                  Text(
                    'Todavia no tienes direcciones',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Agrega al menos una para poder pedir y guardar tu entrega correctamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF666666), height: 1.4),
                  ),
                ],
              ),
            );
          }

          _selectedAddressId ??=
              addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first).id;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      ...addresses.map((address) {
                        final selected = _selectedAddressId == address.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: selected ? Colors.black : const Color(0xFFE6E1D8),
                              width: selected ? 1.4 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: widget.selectionMode
                                ? () => setState(() => _selectedAddressId = address.id)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          address.label,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (address.isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF4F1EC),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'Principal',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    address.recipientName,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(address.phone, style: const TextStyle(color: Color(0xFF666666))),
                                  const SizedBox(height: 8),
                                  Text(
                                    address.fullAddress,
                                    style: const TextStyle(color: Color(0xFF666666), height: 1.4),
                                  ),
                                  if (address.references.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Referencias: ${address.references}',
                                      style: const TextStyle(color: Color(0xFF666666)),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _openForm(address),
                                        child: const Text('Editar'),
                                      ),
                                      if (!address.isDefault)
                                        OutlinedButton(
                                          onPressed: () => _setDefault(address),
                                          child: const Text('Usar como principal'),
                                        ),
                                      TextButton(
                                        onPressed: () => _delete(address),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (widget.selectionMode)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedAddressId == null
                          ? null
                          : () {
                              final selected = addresses.firstWhere(
                                (item) => item.id == _selectedAddressId,
                              );
                              Navigator.pop(context, selected);
                            },
                      child: const Text('Usar esta direccion'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
