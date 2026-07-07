import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  NotificationService().initialize();

  runApp(const MyApp());
}
