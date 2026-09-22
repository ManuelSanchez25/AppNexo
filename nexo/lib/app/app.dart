import 'package:flutter/material.dart';
import 'package:nexo/core/theme/app_theme.dart';
import 'package:nexo/features/auth/application/auth_controller.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/cart/application/cart_controller.dart';
import 'package:nexo/features/cart/application/cart_scope.dart';
import 'package:nexo/features/notifications/application/notification_controller.dart';
import 'package:nexo/features/notifications/application/notification_scope.dart';
import 'package:nexo/features/orders/application/active_order_controller.dart';
import 'package:nexo/features/orders/application/active_order_scope.dart';
import 'package:nexo/features/orders/presentation/active_order_sync.dart';
import 'package:nexo/features/splash/presentation/splash_page.dart';

class NexoApp extends StatelessWidget {
  const NexoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: AuthController(),
      child: CartScope(
        controller: CartController(),
        child: NotificationScope(
          controller: NotificationController(),
          child: ActiveOrderScope(
            controller: ActiveOrderController(),
            child: ActiveOrderSync(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                home: const SplashPage(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
