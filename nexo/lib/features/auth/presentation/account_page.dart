import 'package:flutter/material.dart';
import 'package:nexo/features/address/presentation/addresses_page.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/presentation/login_page.dart';
import 'package:nexo/features/orders/presentation/orders_history_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu cuenta'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFF2C21A),
                  child: Text(
                    authController.userName.isNotEmpty
                        ? authController.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  authController.userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  authController.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFD4CEC3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ActionTile(
            icon: Icons.receipt_long_rounded,
            title: 'Mis pedidos',
            subtitle: 'Consulta tu historial y abre cada detalle',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrdersHistoryPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.location_on_outlined,
            title: 'Mis direcciones',
            subtitle: 'Administra donde quieres recibir tus pedidos',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddressesPage(
                    token: authController.token!,
                    suggestedRecipientName: authController.userName,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.logout_rounded,
            title: 'Cerrar sesion',
            subtitle: 'Salir de tu cuenta en este dispositivo',
            onTap: () {
              authController.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: title == 'Cerrar sesion'
                      ? const Color(0xFFF2C21A)
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFF2C21A)),
            ],
          ),
        ),
      ),
    );
  }
}
