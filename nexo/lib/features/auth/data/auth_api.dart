import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';
import 'package:nexo/shared/models/login_response.dart';

class AuthApi {
  static Future<LoginResponse> register({
    required String name,
    required String email,
    required String password,
    required DateTime birthDate,
    required String role,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'birthDate': birthDate.toIso8601String(),
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return LoginResponse.fromJson(json);
    }

    if (response.statusCode == 409 || response.statusCode == 400) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    throw Exception('Error ${response.statusCode}: ${response.body}');
  }

  static Future<LoginResponse> login({
    required String identifier,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identifier': identifier.trim(),
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponse.fromJson(json);
  }
}
