import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static Future<void>? _initializeFuture;

  static Future<void> ensureInitialized() {
    return _initializeFuture ??= _initialize();
  }

  static Future<GoogleSignInAccount> signIn() async {
    await ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception('Google requiere el botón oficial en esta plataforma.');
    }

    return GoogleSignIn.instance.authenticate();
  }

  static Future<void> signOut() async {
    await ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }

  static String idTokenFrom(GoogleSignInAccount account) {
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw Exception('Google no devolvió un token válido.');
    }

    return token;
  }

  static Future<void> _initialize() {
    const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

    return GoogleSignIn.instance.initialize(
      clientId: clientId.isEmpty ? null : clientId,
      serverClientId: kIsWeb || serverClientId.isEmpty ? null : serverClientId,
    );
  }
}
