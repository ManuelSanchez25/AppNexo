import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';
import 'package:nexo/features/driver/data/driver_stats.dart';
import 'package:nexo/shared/models/restaurant_order_summary.dart';

class DriverApi {
  static Future<List<RestaurantOrderSummary>> getAvailableOrders({
    required String token,
  }) {
    return _getOrders(token: token, path: '/api/driver/orders/available');
  }

  static Future<List<RestaurantOrderSummary>> getActiveOrders({
    required String token,
  }) {
    return _getOrders(token: token, path: '/api/driver/orders/active');
  }

  static Future<DriverStats> getStats({required String token}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/stats'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    return DriverStats.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<void> acceptOrder({
    required String token,
    required String orderId,
  }) {
    return _postAction(
      token: token,
      path: '/api/driver/orders/$orderId/accept',
    );
  }

  static Future<void> markDelivered({
    required String token,
    required String orderId,
    required String pin,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/driver/orders/$orderId/delivered'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode != 204) {
      throw Exception(response.body.replaceAll('"', ''));
    }
  }

  static Future<List<RestaurantOrderSummary>> _getOrders({
    required String token,
    required String path,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(response.body.replaceAll('"', ''));
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (item) =>
              RestaurantOrderSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<void> _postAction({
    required String token,
    required String path,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw Exception(response.body.replaceAll('"', ''));
    }
  }
}
