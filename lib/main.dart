import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  NotificationService().initialize();

  // Initialize widget service (desktop widget communication)
  WidgetService.instance.init();

  runApp(const MyApp());
}
