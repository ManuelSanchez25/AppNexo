import 'package:flutter/foundation.dart';
import 'package:nexo/shared/models/login_response.dart';

class AuthController extends ChangeNotifier {
  LoginResponse? _session;

  LoginResponse? get session => _session;
  bool get isAuthenticated => _session != null;
  String? get token => _session?.token;
  int? get userId => _session?.userId;
  String get userName => _session?.name ?? '';
  String get email => _session?.email ?? '';
  String get role => _session?.role ?? '';
  bool get isRestaurant => role.toLowerCase() == 'restaurant';
  bool get isAdmin => role.toLowerCase() == 'admin';

  void setSession(LoginResponse response) {
    _session = response;
    notifyListeners();
  }

  void logout() {
    _session = null;
    notifyListeners();
  }
}
