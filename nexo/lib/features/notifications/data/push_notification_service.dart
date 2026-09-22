import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nexo/features/auth/data/auth_api.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static String? _sessionToken;

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      final sessionToken = _sessionToken;
      if (sessionToken != null) unawaited(_register(token, sessionToken));
    });
  }

  static Future<void> syncForSession(String sessionToken) async {
    _sessionToken = sessionToken;
    final token = await _messaging.getToken();
    if (token != null) await _register(token, sessionToken);
  }

  static void clearSession() => _sessionToken = null;

  static Future<void> _register(String deviceToken, String sessionToken) {
    return AuthApi.registerPushDevice(
      token: sessionToken,
      deviceToken: deviceToken,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    );
  }
}
