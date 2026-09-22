import 'order_realtime_client_base.dart';
import 'order_realtime_client_stub.dart'
    if (dart.library.html) 'order_realtime_client_web.dart';

export 'order_realtime_client_base.dart';

OrderRealtimeClient createOrderRealtimeClient() => createRealtimeClient();
