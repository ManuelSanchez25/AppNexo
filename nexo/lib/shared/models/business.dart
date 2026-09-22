class Business {
  final int id;
  final String name;
  final String description;
  final String time;
  final double rating;
  final String imageUrl;
  final String addressText;
  final String approvalStatus;
  final String openTime;
  final String closeTime;
  final String openDays;
  final List<BusinessOperatingHour> operatingHours;
  final bool isPaused;
  final bool isOpen;
  final String availabilityLabel;
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
    required this.approvalStatus,
    required this.openTime,
    required this.closeTime,
    required this.openDays,
    required this.operatingHours,
    required this.isPaused,
    required this.isOpen,
    required this.availabilityLabel,
    required this.latitude,
    required this.longitude,
    required this.deliveryRadiusKm,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    final operatingHours = _parseOperatingHours(json);
    final approvalStatus = (json['approvalStatus'] ?? 'approved') as String;

    return Business(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      time: _normalizeEstimatedMinutes((json['time'] ?? '') as String),
      rating: ((json['rating'] ?? 0) as num).toDouble(),
      imageUrl: (json['imageUrl'] ?? '') as String,
      addressText: (json['addressText'] ?? '') as String,
      approvalStatus: approvalStatus,
      openTime: (json['openTime'] ?? '09:00') as String,
      closeTime: (json['closeTime'] ?? '22:00') as String,
      openDays: (json['openDays'] ?? '1,2,3,4,5') as String,
      operatingHours: operatingHours,
      isPaused: (json['isPaused'] ?? false) as bool,
      isOpen: _calculateIsOpen(
        operatingHours: operatingHours,
        approvalStatus: approvalStatus,
      ),
      availabilityLabel: _availabilityLabel(
        operatingHours: operatingHours,
        approvalStatus: approvalStatus,
      ),
      latitude: json['latitude'] == null
          ? null
          : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] == null
          ? null
          : (json['longitude'] as num).toDouble(),
      deliveryRadiusKm: ((json['deliveryRadiusKm'] ?? 5) as num).toDouble(),
    );
  }

  static String _normalizeEstimatedMinutes(String value) {
    final trimmed = value.trim();
    final direct = int.tryParse(trimmed);
    if (direct != null) return direct.clamp(5, 180).toString();

    final match = RegExp(r'\d+').firstMatch(trimmed);
    if (match == null) return '';

    final parsed = int.tryParse(match.group(0) ?? '');
    if (parsed == null) return '';
    return parsed.clamp(5, 180).toString();
  }

  static bool _calculateIsOpen({
    required List<BusinessOperatingHour> operatingHours,
    required String approvalStatus,
  }) {
    if (approvalStatus != 'approved') return false;
    final today = operatingHours
        .where((item) => item.day == _todayNumber())
        .cast<BusinessOperatingHour?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (today == null || !today.isOpen) return false;
    final open = _parseMinutes(today.openTime);
    final close = _parseMinutes(today.closeTime);
    if (open == null || close == null || close <= open) return false;
    final now = DateTime.now();
    final minutesNow = now.hour * 60 + now.minute;
    return minutesNow >= open && minutesNow < close;
  }

  static String _availabilityLabel({
    required List<BusinessOperatingHour> operatingHours,
    required String approvalStatus,
  }) {
    if (approvalStatus != 'approved') return 'Pendiente de aprobacion';
    return _calculateIsOpen(
          operatingHours: operatingHours,
          approvalStatus: approvalStatus,
        )
        ? 'Abierto hasta ${_todaySchedule(operatingHours)!.closeTime}'
        : _closedLabel(operatingHours);
  }

  static int? _parseMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static List<BusinessOperatingHour> _parseOperatingHours(
    Map<String, dynamic> json,
  ) {
    final raw = json['operatingHours'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .map(
            (item) =>
                BusinessOperatingHour.fromJson(item as Map<String, dynamic>),
          )
          .toList()
        ..sort((a, b) => a.day.compareTo(b.day));
    }

    final openDays = ((json['openDays'] ?? '1,2,3,4,5') as String)
        .split(',')
        .map((day) => int.tryParse(day.trim()) ?? 0)
        .where((day) => day >= 1 && day <= 7)
        .toSet();
    final openTime = (json['openTime'] ?? '09:00') as String;
    final closeTime = (json['closeTime'] ?? '22:00') as String;
    return List.generate(
      7,
      (index) => BusinessOperatingHour(
        day: index + 1,
        isOpen: openDays.contains(index + 1),
        openTime: openTime,
        closeTime: closeTime,
      ),
    );
  }

  static int _todayNumber() {
    final day = DateTime.now().weekday;
    return day == DateTime.sunday ? 7 : day;
  }

  static BusinessOperatingHour? _todaySchedule(
    List<BusinessOperatingHour> operatingHours,
  ) {
    return operatingHours
        .where((item) => item.day == _todayNumber())
        .cast<BusinessOperatingHour?>()
        .firstWhere((item) => item != null, orElse: () => null);
  }

  static String _closedLabel(List<BusinessOperatingHour> operatingHours) {
    final today = _todayNumber();
    final now = DateTime.now();
    final minutesNow = now.hour * 60 + now.minute;
    final openDays = operatingHours.where((item) => item.isOpen).toList()
      ..sort((a, b) => a.openTime.compareTo(b.openTime));
    if (openDays.isEmpty) return 'Cerrado';

    for (var offset = 0; offset < 7; offset++) {
      final day = ((today - 1 + offset) % 7) + 1;
      final candidates = openDays.where((item) => item.day == day);
      for (final candidate in candidates) {
        final open = _parseMinutes(candidate.openTime);
        if (offset > 0 || (open != null && open > minutesNow)) {
          return 'Cerrado, abre ${_dayLabel(candidate.day)} a las ${candidate.openTime}';
        }
      }
    }

    return 'Cerrado';
  }

  static String _dayLabel(int day) {
    const names = {
      1: 'lunes',
      2: 'martes',
      3: 'miercoles',
      4: 'jueves',
      5: 'viernes',
      6: 'sabado',
      7: 'domingo',
    };
    return names[day] ?? 'otro dia';
  }
}

class BusinessOperatingHour {
  final int day;
  final bool isOpen;
  final String openTime;
  final String closeTime;

  const BusinessOperatingHour({
    required this.day,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  factory BusinessOperatingHour.fromJson(Map<String, dynamic> json) {
    return BusinessOperatingHour(
      day: (json['day'] ?? 1) as int,
      isOpen: (json['isOpen'] ?? false) as bool,
      openTime: (json['openTime'] ?? '09:00') as String,
      closeTime: (json['closeTime'] ?? '22:00') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'isOpen': isOpen,
      'openTime': openTime,
      'closeTime': closeTime,
    };
  }
}
