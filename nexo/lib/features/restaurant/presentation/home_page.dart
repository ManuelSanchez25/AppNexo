import 'package:flutter/material.dart';
import 'package:nexo/features/auth/presentation/account_page.dart';
import 'package:nexo/features/restaurant/data/business_api.dart';
import 'package:nexo/shared/models/business.dart';
import 'package:nexo/shared/widgets/business_card.dart';
import 'package:nexo/shared/widgets/cart_icon.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _navIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  Future<void>? _loadFuture;
  List<Business> _allBusinesses = [];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadBusinesses();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    _allBusinesses = await BusinessApi.getBusinesses();
  }

  List<Business> get filteredBusinesses {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _allBusinesses;

    return _allBusinesses.where((business) {
      return business.name.toLowerCase().contains(query) ||
          business.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexo'),
        actions: const [CartIcon()],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (_loadFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF090909),
                      Color(0xFF111111),
                      Color(0xFF1B1A16),
                    ],
                  ),
                  border: Border.all(color: const Color(0x33F2C21A)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 28,
                      offset: Offset(0, 14),
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
                      child: const Text(
                        'NEXO SELECT',
                        style: TextStyle(
                          color: Color(0xFFF2C21A),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Pide con una presencia mas limpia, seria y moderna.',
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        height: 1.03,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Explora negocios bien presentados, personaliza tus productos y confirma pedidos en una experiencia mas premium.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFFD8D4CB),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _HeroMetric(
                          label: 'Negocios',
                          value: _allBusinesses.length.toString(),
                        ),
                        const SizedBox(width: 10),
                        const _HeroMetric(
                          label: 'Estilo',
                          value: 'NEXO',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x14F2C21A)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Buscar negocio o categoria',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Color(0xFFF2C21A),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Negocios disponibles',
                      style: textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${filteredBusinesses.length} resultados',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredBusinesses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0x14F2C21A)),
                  ),
                  child: const Text(
                    'No encontramos negocios con esa busqueda.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ...filteredBusinesses.map(
                (business) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: BusinessCard(
                    businessId: business.id,
                    name: business.name,
                    description: business.description,
                    time: business.time,
                    rating: business.rating,
                    imageUrl: business.imageUrl,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (index) {
          if (index == 0) {
            setState(() => _navIndex = index);
            return;
          }

          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountPage()),
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esta seccion estara disponible pronto'),
            ),
          );
        },
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_rounded),
            label: 'Notificaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x15FFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x24F2C21A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFF2C21A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD8D4CB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
