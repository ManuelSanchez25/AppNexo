import 'order_realtime_client_base.dart';

class _StubOrderRealtimeClient implements OrderRealtimeClient {
  @override
  Stream<Map<String, dynamic>> customerOrderEvents(String token) {
    return const Stream.empty();
  }

  @override
  Stream<Map<String, dynamic>> restaurantOrderEvents(String token) {
    return const Stream.empty();
  }

  @override
  Stream<Map<String, dynamic>> driverOrderEvents(String token) {
    return const Stream.empty();
  }
}

OrderRealtimeClient createRealtimeClient() => _StubOrderRealtimeClient();
