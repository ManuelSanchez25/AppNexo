class LocationSearchResult {
  final String displayName;
  final String street;
  final String neighborhood;
  final String city;
  final String state;
  final String postalCode;
  final double latitude;
  final double longitude;

  const LocationSearchResult({
    required this.displayName,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
  });

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    return LocationSearchResult(
      displayName: (json['displayName'] ?? '') as String,
      street: (json['street'] ?? '') as String,
      neighborhood: (json['neighborhood'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      state: (json['state'] ?? '') as String,
      postalCode: (json['postalCode'] ?? '') as String,
      latitude: ((json['latitude'] ?? 0) as num).toDouble(),
      longitude: ((json['longitude'] ?? 0) as num).toDouble(),
    );
  }
}
