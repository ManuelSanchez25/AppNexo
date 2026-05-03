import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';
import 'package:nexo/shared/models/address.dart';

class AddressApi {
  static Future<List<Address>> getAddresses({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/addresses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Address.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Address> createAddress({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/addresses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return Address.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Address> updateAddress({
    required String token,
    required int addressId,
    required Map<String, dynamic> body,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/addresses/$addressId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return Address.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deleteAddress({
    required String token,
    required int addressId,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/addresses/$addressId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }

  static Future<void> setDefaultAddress({
    required String token,
    required int addressId,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/addresses/$addressId/default'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
