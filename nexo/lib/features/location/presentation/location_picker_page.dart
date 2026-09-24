import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nexo/features/location/data/location_api.dart';
import 'package:nexo/shared/models/location_search_result.dart';

class LocationPickerPage extends StatefulWidget {
  final String title;
  final String searchHint;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialQuery;

  const LocationPickerPage({
    super.key,
    required this.title,
    required this.searchHint,
    this.initialLatitude,
    this.initialLongitude,
    this.initialQuery,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late final TextEditingController _searchController;
  List<LocationSearchResult> _results = const [];
  bool _searching = false;
  bool _resolvingPoint = false;
  LocationSearchResult? _selectedResult;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe al menos 4 caracteres para buscar.'),
        ),
      );
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await LocationApi.search(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  void _selectResult(LocationSearchResult result) {
    setState(() {
      _selectedResult = result;
      _searchController.text = result.displayName;
    });
  }

  Future<void> _selectMapPoint(LatLng point) async {
    setState(() => _resolvingPoint = true);
    try {
      final result = await LocationApi.reverse(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) return;
      _selectResult(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _resolvingPoint = false);
    }
  }

  LatLng get _mapCenter {
    final selected = _selectedResult;
    if (selected != null) return LatLng(selected.latitude, selected.longitude);
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      return LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
    return const LatLng(21.0375, -104.3715);
  }

  @override
  Widget build(BuildContext context) {
    final selectedResult = _selectedResult;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _searching ? null : _search,
                  child: Text(_searching ? 'Buscando...' : 'Buscar'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 290,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: selectedResult == null ? 13 : 17,
                    onTap: (_, point) => _selectMapPoint(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.reyval.nexo',
                    ),
                    if (selectedResult != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              selectedResult.latitude,
                              selectedResult.longitude,
                            ),
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.location_pin,
                              color: Color(0xFFD94B3D),
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap contributors'),
                    ),
                    if (_resolvingPoint)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Busca la calle y elige el resultado, o toca el punto exacto en el mapa. Al seleccionarlo se guardan sus coordenadas.',
                    style: TextStyle(color: Color(0xFF666666), height: 1.45),
                  ),
                ),
                if (selectedResult != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE6E1D8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ubicacion seleccionada',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedResult.displayName,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_results.isEmpty && !_searching)
                  const Text(
                    'Busca una direccion y selecciona el resultado que mejor coincida con tu ubicacion.',
                    style: TextStyle(color: Color(0xFF666666), height: 1.5),
                  ),
                ..._results.map(
                  (result) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color:
                            _selectedResult?.displayName == result.displayName
                            ? Colors.black
                            : const Color(0xFFE6E1D8),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _selectResult(result),
                      title: Text(
                        result.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          result.neighborhood,
                          result.city,
                          result.state,
                        ].where((part) => part.isNotEmpty).join(', '),
                      ),
                      trailing: const Icon(Icons.north_west_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedResult == null
                ? null
                : () => Navigator.pop(context, selectedResult),
            child: const Text('Usar esta ubicacion'),
          ),
        ),
      ),
    );
  }
}
