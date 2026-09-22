import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';

class DriverApplication {
  final int userId;
  final String name;
  final String email;
  final String fullName;
  final String phone;
  final String vehicleType;
  final String vehicleMakeModel;
  final String vehicleColor;
  final String vehiclePlate;
  final String licenseType;
  final String licenseNumber;
  final String identityType;
  final String identityDocument;
  final String approvalStatus;

  const DriverApplication({
    required this.userId,
    required this.name,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.vehicleType,
    required this.vehicleMakeModel,
    required this.vehicleColor,
    required this.vehiclePlate,
    required this.licenseType,
    required this.licenseNumber,
    required this.identityType,
    required this.identityDocument,
    required this.approvalStatus,
  });

  factory DriverApplication.fromJson(Map<String, dynamic> json) {
    return DriverApplication(
      userId: (json['userId'] ?? 0) as int,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      vehicleType: (json['vehicleType'] ?? '').toString(),
      vehicleMakeModel: (json['vehicleMakeModel'] ?? '').toString(),
      vehicleColor: (json['vehicleColor'] ?? '').toString(),
      vehiclePlate: (json['vehiclePlate'] ?? '').toString(),
      licenseType: (json['licenseType'] ?? '').toString(),
      licenseNumber: (json['licenseNumber'] ?? '').toString(),
      identityType: (json['identityType'] ?? '').toString(),
      identityDocument: (json['identityDocument'] ?? '').toString(),
      approvalStatus: (json['approvalStatus'] ?? 'pending').toString(),
    );
  }
}

class AdminDriverApi {
  static Future<List<DriverApplication>> getApplications({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/drivers'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => DriverApplication.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updateApproval({
    required String token,
    required int userId,
    required String status,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/drivers/$userId/approval'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 204) {
      throw Exception(response.body.replaceAll('"', ''));
    }
  }
}
