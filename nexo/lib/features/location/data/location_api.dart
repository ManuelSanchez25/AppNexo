import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexo/config/api_config.dart';
import 'package:nexo/shared/models/location_search_result.dart';

class LocationApi {
  static Future<List<LocationSearchResult>> search(String query) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/location/search?q=${Uri.encodeQueryComponent(query)}');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => LocationSearchResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<LocationSearchResult> reverse({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/api/location/reverse?lat=$latitude&lng=$longitude',
    );
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    return LocationSearchResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
