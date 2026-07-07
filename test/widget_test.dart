import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yimaflutter/app.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Mock the local notifications channel to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );
  });

  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // SplashScreen shows the app name during the initial animation
    expect(find.text('月事记'), findsOneWidget);

    // Wait for the splash delay timer to complete to avoid
    // "Timer is still pending" assertion failures
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
  });
}
