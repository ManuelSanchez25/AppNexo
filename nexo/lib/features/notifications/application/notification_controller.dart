import 'package:flutter/foundation.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
    );
  }
}

class NotificationController extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((notification) => !notification.read).length;

  void add({required String title, required String body, String? dedupeKey}) {
    final now = DateTime.now();
    final id = dedupeKey ?? now.microsecondsSinceEpoch.toString();

    if (_notifications.any((notification) => notification.id == id)) return;

    _notifications.insert(
      0,
      AppNotification(id: id, title: title, body: body, createdAt: now),
    );

    if (_notifications.length > 60) {
      _notifications.removeRange(60, _notifications.length);
    }

    notifyListeners();
  }

  void markAllRead() {
    if (unreadCount == 0) return;

    for (var index = 0; index < _notifications.length; index++) {
      _notifications[index] = _notifications[index].copyWith(read: true);
    }
    notifyListeners();
  }

  void clear() {
    if (_notifications.isEmpty) return;
    _notifications.clear();
    notifyListeners();
  }
}
