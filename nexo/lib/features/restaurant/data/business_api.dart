import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';
import 'package:nexo/shared/models/business.dart';

class BusinessApi {
  static Future<List<Business>> getBusinesses() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/businesses');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Business.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Business>> getOwnedBusinesses(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/businesses/owned');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Business.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Business> createBusiness({
    required String token,
    required String name,
    required String description,
    required String time,
    required double rating,
    required String imageUrl,
    required String addressText,
    double? latitude,
    double? longitude,
    required double deliveryRadiusKm,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/businesses');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'time': time,
        'rating': rating,
        'imageUrl': imageUrl,
        'addressText': addressText,
        'latitude': latitude,
        'longitude': longitude,
        'deliveryRadiusKm': deliveryRadiusKm,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return Business.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Business> updateBusiness({
    required String token,
    required int businessId,
    required String name,
    required String description,
    required String time,
    required double rating,
    required String imageUrl,
    required String addressText,
    double? latitude,
    double? longitude,
    required double deliveryRadiusKm,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/businesses/$businessId');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'time': time,
        'rating': rating,
        'imageUrl': imageUrl,
        'addressText': addressText,
        'latitude': latitude,
        'longitude': longitude,
        'deliveryRadiusKm': deliveryRadiusKm,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return Business.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
