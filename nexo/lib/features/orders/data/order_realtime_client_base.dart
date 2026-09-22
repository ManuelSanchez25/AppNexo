abstract class OrderRealtimeClient {
  Stream<Map<String, dynamic>> customerOrderEvents(String token);
  Stream<Map<String, dynamic>> restaurantOrderEvents(String token);
  Stream<Map<String, dynamic>> driverOrderEvents(String token);
}
