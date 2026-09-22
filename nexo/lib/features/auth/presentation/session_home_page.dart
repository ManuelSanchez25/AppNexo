import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/presentation/email_verification_page.dart';
import 'package:nexo/features/auth/presentation/login_page.dart';
import 'package:nexo/features/driver/presentation/driver_dashboard_page.dart';
import 'package:nexo/features/restaurant/presentation/home_page.dart';
import 'package:nexo/features/restaurant/presentation/restaurant_dashboard_page.dart';

class SessionHomePage extends StatelessWidget {
  const SessionHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);

    if (!authController.isAuthenticated) {
      return const LoginPage();
    }

    if (authController.email.isNotEmpty && !authController.emailVerified) {
      return EmailVerificationPage(email: authController.email);
    }

    if (authController.isRestaurant || authController.isAdmin) {
      return const RestaurantDashboardPage();
    }

    if (authController.isDriver) {
      return const DriverDashboardPage();
    }

    return const HomePage();
  }
}
