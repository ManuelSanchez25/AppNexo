import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';
import 'package:nexo/shared/models/product.dart';

class ProductApi {
  static Future<List<Product>> getProducts(int businessId) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products',
    );
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Product> getProductDetail({
    required int businessId,
    required int productId,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/$productId',
    );
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<List<Product>> getOwnedProducts({
    required int businessId,
    required String token,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/owned',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Product> createProduct({
    required String token,
    required int businessId,
    required String name,
    required String description,
    required double price,
    required String image,
    required bool isAvailable,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products',
    );
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'price': price,
        'image': image,
        'isAvailable': isAvailable,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<Product> updateProduct({
    required String token,
    required int businessId,
    required int productId,
    required String name,
    required String description,
    required double price,
    required String image,
    required bool isAvailable,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/$productId',
    );
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'price': price,
        'image': image,
        'isAvailable': isAvailable,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<ProductOptionGroup> createOptionGroup({
    required String token,
    required int businessId,
    required int productId,
    required String name,
    required bool isRequired,
    required int minSelections,
    required int maxSelections,
    required int sortOrder,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/$productId/option-groups',
    );
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'isRequired': isRequired,
        'minSelections': minSelections,
        'maxSelections': maxSelections,
        'sortOrder': sortOrder,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return ProductOptionGroup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<List<ProductOptionGroup>> getBusinessOptionGroups({
    required String token,
    required int businessId,
    int? productId,
  }) async {
    final query = productId == null ? '' : '?productId=$productId';
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/option-groups$query',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (item) =>
              ProductOptionGroup.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<ProductOptionGroup> updateOptionGroup({
    required String token,
    required int businessId,
    required int productId,
    required int groupId,
    required String name,
    required bool isRequired,
    required int minSelections,
    required int maxSelections,
    required int sortOrder,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/$productId/option-groups/$groupId',
    );
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'isRequired': isRequired,
        'minSelections': minSelections,
        'maxSelections': maxSelections,
        'sortOrder': sortOrder,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return ProductOptionGroup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<ProductOption> createOption({
    required String token,
    required int businessId,
    required int productId,
    required int groupId,
    required String name,
    required double priceDelta,
    required bool isAvailable,
    required int sortOrder,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/$productId/option-groups/$groupId/options',
    );
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'priceDelta': priceDelta,
        'isAvailable': isAvailable,
        'sortOrder': sortOrder,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return ProductOption.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<ProductOption> updateOption({
    required String token,
    required int businessId,
    required int productId,
    required int groupId,
    required int optionId,
    required String name,
    required double priceDelta,
    required bool isAvailable,
    required int sortOrder,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/$productId/option-groups/$groupId/options/$optionId',
    );
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'priceDelta': priceDelta,
        'isAvailable': isAvailable,
        'sortOrder': sortOrder,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return ProductOption.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<ProductOptionGroup> attachOptionGroup({
    required String token,
    required int businessId,
    required int productId,
    required int groupId,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/$productId/option-groups/$groupId/attach',
    );
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return ProductOptionGroup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<void> detachOptionGroup({
    required String token,
    required int businessId,
    required int productId,
    required int groupId,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/businesses/$businessId/products/$productId/option-groups/$groupId/attach',
    );
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
