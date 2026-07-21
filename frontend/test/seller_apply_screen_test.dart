import 'package:ecommerce_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:ecommerce_frontend/features/auth/model/user_model.dart';
import 'package:ecommerce_frontend/features/auth/provider/auth_provider.dart';
import 'package:ecommerce_frontend/features/profile/screen/seller_apply_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('routes to home after seller application succeeds',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    final router = GoRouter(
      initialLocation: '/seller-apply',
      routes: [
        GoRoute(
          path: '/seller-apply',
          builder: (_, __) => const SellerApplyScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Home Screen')),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const Scaffold(body: Text('Profile Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SellerApplyRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Demo Shop');
    await tester.enterText(find.byType(TextField).at(1), 'Bangkok');
    await tester.enterText(find.byType(TextField).at(2), '1234567890');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Home Screen'), findsOneWidget);
  });
}

class _SellerApplyRepository implements AuthRepository {
  @override
  Future<void> applySeller(
    String shopName,
    String shopLocation,
    String taxPayerNumber,
  ) async {}

  @override
  Future<UserModel> me() async {
    return const UserModel(
      id: 'u1',
      name: 'Test',
      lastname: 'User',
      age: 28,
      gender: 'Other',
      email: 'test@example.com',
      role: ['customer'],
      sellerStatus: 'pending',
    );
  }

  @override
  Future<({String token, String refreshToken, UserModel user})> login(
          String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserModel> register(Map<String, dynamic> body) =>
      throw UnimplementedError();

  @override
  Future<UserModel> updateProfile(Map<String, dynamic> body) =>
      throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) => throw UnimplementedError();
}
