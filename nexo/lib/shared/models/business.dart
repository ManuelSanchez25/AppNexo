class Business {
  final int id;
  final String name;
  final String description;
  final String time;
  final double rating;
  final String imageUrl;
  final String addressText;
  final double? latitude;
  final double? longitude;
  final double deliveryRadiusKm;

  Business({
    required this.id,
    required this.name,
    required this.description,
    required this.time,
    required this.rating,
    required this.imageUrl,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    required this.deliveryRadiusKm,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      time: (json['time'] ?? '') as String,
      rating: ((json['rating'] ?? 0) as num).toDouble(),
      imageUrl: (json['imageUrl'] ?? '') as String,
      addressText: (json['addressText'] ?? '') as String,
      latitude: json['latitude'] == null
          ? null
          : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] == null
          ? null
          : (json['longitude'] as num).toDouble(),
      deliveryRadiusKm: ((json['deliveryRadiusKm'] ?? 5) as num).toDouble(),
    );
  }
}
