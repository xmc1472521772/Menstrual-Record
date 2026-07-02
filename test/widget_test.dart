import 'package:flutter_test/flutter_test.dart';
import 'package:yimaflutter/app.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('月事记'), findsOneWidget);
  });
}
