import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';
import 'package:nexo/shared/models/login_response.dart';

class AuthApi {
  static Future<LoginResponse> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required DateTime birthDate,
    required String role,
    bool acceptTerms = false,
    String driverFullName = '',
    String driverPhone = '',
    String driverVehicleType = '',
    String driverVehicleMakeModel = '',
    String driverVehicleColor = '',
    String driverVehiclePlate = '',
    String driverLicenseType = '',
    String driverLicenseNumber = '',
    String driverIdentityType = '',
    String driverIdentityDocument = '',
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'birthDate': birthDate.toIso8601String(),
        'role': role,
        'acceptTerms': acceptTerms,
        'driverFullName': driverFullName,
        'driverPhone': driverPhone,
        'driverVehicleType': driverVehicleType,
        'driverVehicleMakeModel': driverVehicleMakeModel,
        'driverVehicleColor': driverVehicleColor,
        'driverVehiclePlate': driverVehiclePlate,
        'driverLicenseType': driverLicenseType,
        'driverLicenseNumber': driverLicenseNumber,
        'driverIdentityType': driverIdentityType,
        'driverIdentityDocument': driverIdentityDocument,
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
      body: jsonEncode({'identifier': identifier.trim(), 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponse.fromJson(json);
  }

  static Future<LoginResponse> googleLogin({
    required String idToken,
    required String role,
    String phone = '',
    bool acceptTerms = false,
    DateTime? birthDate,
    String name = '',
    String driverFullName = '',
    String driverPhone = '',
    String driverVehicleType = '',
    String driverVehicleMakeModel = '',
    String driverVehicleColor = '',
    String driverVehiclePlate = '',
    String driverLicenseType = '',
    String driverLicenseNumber = '',
    String driverIdentityType = '',
    String driverIdentityDocument = '',
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        'role': role,
        'birthDate': birthDate?.toIso8601String(),
        'name': name,
        'phone': phone,
        'acceptTerms': acceptTerms,
        'driverFullName': driverFullName,
        'driverPhone': driverPhone,
        'driverVehicleType': driverVehicleType,
        'driverVehicleMakeModel': driverVehicleMakeModel,
        'driverVehicleColor': driverVehicleColor,
        'driverVehiclePlate': driverVehiclePlate,
        'driverLicenseType': driverLicenseType,
        'driverLicenseNumber': driverLicenseNumber,
        'driverIdentityType': driverIdentityType,
        'driverIdentityDocument': driverIdentityDocument,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponse.fromJson(json);
  }

  static Future<LoginResponse> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponse.fromJson(json);
  }

  static Future<void> resendEmailCode({required String email}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/resend-email-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }
  }

  static Future<LoginResponse> me({required String token}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponse.fromJson(json);
  }

  static Future<void> requestPasswordReset({required String email}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }
  }

  static Future<Map<String, dynamic>> driverProfile({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/driver-profile'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
