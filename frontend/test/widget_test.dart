import 'package:ecommerce_frontend/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows login screen on app start', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShopApp()));
    await tester.pump();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('ShopApp'), findsOneWidget);
  });
}
