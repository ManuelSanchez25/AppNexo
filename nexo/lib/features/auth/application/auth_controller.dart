import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nexo/features/auth/data/auth_api.dart';
import 'package:nexo/features/notifications/data/push_notification_service.dart';
import 'package:nexo/shared/models/login_response.dart';

class AuthController extends ChangeNotifier {
  LoginResponse? _session;

  LoginResponse? get session => _session;
  bool get isAuthenticated => _session != null;
  String? get token => _session?.token;
  int? get userId => _session?.userId;
  String get userName => _session?.name ?? '';
  String get email => _session?.email ?? '';
  bool get emailVerified => _session?.emailVerified ?? false;
  String get role => _session?.role ?? '';
  String get driverApprovalStatus => _session?.driverApprovalStatus ?? '';
  bool get isRestaurant => role.toLowerCase() == 'restaurant';
  bool get isDriver => role.toLowerCase() == 'driver';
  bool get isDriverApproved => driverApprovalStatus.toLowerCase() == 'approved';
  bool get isAdmin => role.toLowerCase() == 'admin';

  void setSession(LoginResponse response) {
    _session = response;
    unawaited(PushNotificationService.syncForSession(response.token));
    notifyListeners();
  }

  Future<void> refreshSession() async {
    final currentToken = token;
    if (currentToken == null || currentToken.isEmpty) return;

    _session = await AuthApi.me(token: currentToken);
    notifyListeners();
  }

  void logout() {
    _session = null;
    PushNotificationService.clearSession();
    notifyListeners();
  }
}
