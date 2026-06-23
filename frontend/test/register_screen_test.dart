import 'package:ecommerce_frontend/features/auth/screen/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile image bytes are encoded for the register API payload', () {
    expect(
      profileImageDataUri([1, 2, 3]),
      'data:image/jpeg;base64,AQID',
    );
  });

  testWidgets('register screen offers gallery and camera profile photo upload',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );

    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('age field accepts only digits while typing',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '12a3b');

    expect(find.widgetWithText(TextFormField, '123'), findsOneWidget);
  });

  testWidgets('age field is limited to three digits',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '1234');

    expect(find.widgetWithText(TextFormField, '123'), findsOneWidget);
  });
}
