import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexo/features/orders/data/order_api.dart';
import 'package:nexo/shared/models/create_order_response.dart';

class ActiveOrderController extends ChangeNotifier {
  CreateOrderResponse? _activeOrder;
  Timer? _refreshTimer;
  String? _token;
  bool _loading = false;

  CreateOrderResponse? get activeOrder => _activeOrder;
  bool get hasActiveOrder => _activeOrder != null;

  Future<void> syncSession({required String? token}) async {
    if (token == null || token.isEmpty) {
      clear();
      return;
    }

    _token = token;

    if (_activeOrder == null) {
      await _restoreLatestActiveOrder();
    } else {
      await refresh();
    }

    _startPolling();
  }

  Future<void> trackOrder(CreateOrderResponse order, {required String token}) async {
    _token = token;

    if (_isTerminal(order.status)) {
      _activeOrder = null;
      _refreshTimer?.cancel();
      _refreshTimer = null;
      notifyListeners();
      return;
    }

    _activeOrder = order;
    notifyListeners();
    _startPolling();
    await refresh();
  }

  Future<void> refresh() async {
    final token = _token;
    final orderId = _activeOrder?.orderId;
    if (_loading || token == null || token.isEmpty || orderId == null || orderId.isEmpty) {
      return;
    }

    _loading = true;
    try {
      final detail = await OrderApi.getOrderDetail(token: token, orderId: orderId);
      if (_isTerminal(detail.status)) {
        _activeOrder = null;
        _refreshTimer?.cancel();
      } else {
        _activeOrder = detail;
      }
      notifyListeners();
    } catch (_) {
      // Keep the latest visible state if refresh fails.
    } finally {
      _loading = false;
    }
  }

  void clear() {
    _activeOrder = null;
    _token = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    notifyListeners();
  }

  Future<void> _restoreLatestActiveOrder() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      final history = await OrderApi.getMyOrders(token: token);
      final activeOrders = history.where((order) => !_isTerminal(order.status)).toList();
      final activeSummary = activeOrders.isEmpty ? null : activeOrders.first;
      if (activeSummary == null) {
        _activeOrder = null;
        notifyListeners();
        return;
      }

      final detail = await OrderApi.getOrderDetail(
        token: token,
        orderId: activeSummary.orderId,
      );

      if (_isTerminal(detail.status)) {
        _activeOrder = null;
      } else {
        _activeOrder = detail;
      }
      notifyListeners();
    } catch (_) {
      // Ignore restore failures to avoid blocking the home screen.
    }
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    if (_token == null || _token!.isEmpty || _activeOrder == null) return;

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => refresh(),
    );
  }

  static bool _isTerminal(String status) {
    return status == 'delivered' || status == 'cancelled';
  }
}
