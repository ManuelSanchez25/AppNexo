class Address {
  final int id;
  final String label;
  final String recipientName;
  final String phone;
  final String street;
  final String exteriorNumber;
  final String interiorNumber;
  final String neighborhood;
  final String city;
  final String state;
  final String postalCode;
  final String references;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime? createdAt;
  final String fullAddress;

  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.street,
    required this.exteriorNumber,
    required this.interiorNumber,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.references,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
    required this.createdAt,
    required this.fullAddress,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: (json['id'] ?? 0) as int,
      label: (json['label'] ?? '') as String,
      recipientName: (json['recipientName'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      street: (json['street'] ?? '') as String,
      exteriorNumber: (json['exteriorNumber'] ?? '') as String,
      interiorNumber: (json['interiorNumber'] ?? '') as String,
      neighborhood: (json['neighborhood'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      state: (json['state'] ?? '') as String,
      postalCode: (json['postalCode'] ?? '') as String,
      references: (json['references'] ?? '') as String,
      latitude: json['latitude'] == null
          ? null
          : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] == null
          ? null
          : (json['longitude'] as num).toDouble(),
      isDefault: (json['isDefault'] ?? false) as bool,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      fullAddress: (json['fullAddress'] ?? '') as String,
    );
  }
}
