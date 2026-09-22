import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nexo/app/app.dart';
import 'package:nexo/features/notifications/data/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await PushNotificationService.initialize();
  runApp(const NexoApp());
}
