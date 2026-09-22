import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:nexo/config/api_config.dart';

import 'order_realtime_client_base.dart';

class _WebOrderRealtimeClient implements OrderRealtimeClient {
  @override
  Stream<Map<String, dynamic>> customerOrderEvents(String token) {
    return _openStream('/api/orders/stream', token);
  }

  @override
  Stream<Map<String, dynamic>> restaurantOrderEvents(String token) {
    return _openStream('/api/restaurant/orders/stream', token);
  }

  @override
  Stream<Map<String, dynamic>> driverOrderEvents(String token) {
    return _openStream('/api/driver/orders/stream', token);
  }

  Stream<Map<String, dynamic>> _openStream(String path, String token) {
    late final html.EventSource source;
    StreamSubscription<html.MessageEvent>? messageSubscription;
    StreamSubscription<html.Event>? errorSubscription;
    late final StreamController<Map<String, dynamic>> controller;

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        final uri = Uri.parse(
          '${ApiConfig.baseUrl}$path?access_token=${Uri.encodeComponent(token)}',
        );

        source = html.EventSource(uri.toString());
        messageSubscription = source.onMessage.listen((event) {
          final data = event.data;
          if (data == null || '$data'.isEmpty) return;

          try {
            final decoded = jsonDecode('$data') as Map<String, dynamic>;
            controller.add(decoded);
          } catch (_) {
            // Ignore malformed payloads.
          }
        });

        errorSubscription = source.onError.listen((_) {
          // EventSource retries automatically in the browser.
        });
      },
      onCancel: () async {
        await messageSubscription?.cancel();
        await errorSubscription?.cancel();
        source.close();
      },
    );

    return controller.stream.asBroadcastStream();
  }
}

OrderRealtimeClient createRealtimeClient() => _WebOrderRealtimeClient();
