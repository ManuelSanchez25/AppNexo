import 'package:flutter/material.dart';
import 'package:nexo/features/notifications/application/notification_controller.dart';
import 'package:nexo/features/notifications/application/notification_scope.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationScope.of(context).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = NotificationScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final notifications = controller.notifications;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notificaciones'),
            actions: [
              if (notifications.isNotEmpty)
                IconButton(
                  tooltip: 'Limpiar',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          body: notifications.isEmpty
              ? const _EmptyNotificationsState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationCard(notification: notification);
                  },
                ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.read ? Colors.white : const Color(0xFFFFF8DE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E1D6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFFF2C21A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  notification.body,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(notification.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF8A8377),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE8E1D6)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded, size: 52),
              SizedBox(height: 14),
              Text(
                'Sin notificaciones',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'Aqui apareceran cambios de pedidos, nuevos pedidos y avisos importantes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
