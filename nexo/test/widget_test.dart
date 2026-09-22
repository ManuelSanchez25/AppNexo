import 'package:flutter_test/flutter_test.dart';

import 'package:nexo/app/app.dart';
import 'package:nexo/shared/models/business.dart';

void main() {
  test('NexoApp can be created', () {
    const app = NexoApp();

    expect(app, isA<NexoApp>());
  });

  test(
    'Business availability skips today when opening time already passed',
    () {
      final today = DateTime.now().weekday;
      final tomorrow = today == DateTime.sunday ? 1 : today + 1;

      final business = Business.fromJson({
        'id': 1,
        'name': 'Horario Test',
        'description': 'Prueba horario',
        'time': '30',
        'rating': 4.5,
        'imageUrl': '',
        'addressText': 'Direccion',
        'approvalStatus': 'approved',
        'operatingHours': List.generate(7, (index) {
          final day = index + 1;
          return {
            'day': day,
            'isOpen': day == today || day == tomorrow,
            'openTime': day == today ? '00:00' : '09:00',
            'closeTime': day == today ? '00:01' : '22:00',
          };
        }),
        'deliveryRadiusKm': 5,
      });

      expect(business.isOpen, isFalse);
      expect(business.availabilityLabel, contains(_dayLabel(tomorrow)));
    },
  );
}

String _dayLabel(int day) {
  const names = {
    1: 'lunes',
    2: 'martes',
    3: 'miercoles',
    4: 'jueves',
    5: 'viernes',
    6: 'sabado',
    7: 'domingo',
  };
  return names[day]!;
}
