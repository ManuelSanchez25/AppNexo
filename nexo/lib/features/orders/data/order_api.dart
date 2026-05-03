import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';
import 'package:nexo/shared/models/cart_item.dart';
import 'package:nexo/shared/models/create_order_response.dart';
import 'package:nexo/shared/models/order_history_item.dart';
import 'package:nexo/shared/models/restaurant_order_summary.dart';

class OrderApi {
  static Future<CreateOrderResponse> createOrder({
    required List<CartItem> items,
    required String token,
    required int addressId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/orders');
    final body = {
      'addressId': addressId,
      'items': items
          .map(
            (item) => {
              'productId': item.id,
              'quantity': item.quantity,
              'selectedOptionIds': item.selectedOptions.map((option) => option.id).toList(),
            },
          )
          .toList(),
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CreateOrderResponse.fromJson(json);
  }

  static Future<List<OrderHistoryItem>> getMyOrders({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/orders'),
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
        .map((item) => OrderHistoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<CreateOrderResponse> getOrderDetail({
    required String token,
    required String orderId,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/orders/$orderId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CreateOrderResponse.fromJson(json);
  }

  static Future<List<RestaurantOrderSummary>> getRestaurantOrders({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/restaurant/orders'),
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
        .map(
          (item) =>
              RestaurantOrderSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<CreateOrderResponse> getRestaurantOrderDetail({
    required String token,
    required String orderId,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/restaurant/orders/$orderId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CreateOrderResponse.fromJson(json);
  }

  static Future<void> updateRestaurantOrderStatus({
    required String token,
    required String orderId,
    required String status,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/restaurant/orders/$orderId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 204) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
