import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/provider/auth_provider.dart';
import '../../features/auth/screen/login_screen.dart';
import '../../features/auth/screen/register_screen.dart';
import '../../features/cart/screen/cart_screen.dart';
import '../../features/home/screen/home_screen.dart';
import '../../features/product/screen/product_detail_screen.dart';
import '../../features/profile/screen/profile_screen.dart';
import '../../features/profile/screen/seller_apply_screen.dart';
import '../../features/seller/screen/seller_dashboard_screen.dart';
import '../../features/seller/screen/seller_product_form_screen.dart';
import '../dio/dio_client.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: RouterRefresh(ref),
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).isLoggedIn;
      final authRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!loggedIn && !authRoute) return '/login';
      if (loggedIn && authRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/seller-apply', builder: (_, __) => const SellerApplyScreen()),
      GoRoute(path: '/products/:id', builder: (_, s) => ProductDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/seller', builder: (_, __) => const SellerDashboardScreen()),
      GoRoute(path: '/seller/product', builder: (_, s) => SellerProductFormScreen(productId: s.uri.queryParameters['id'])),
    ],
  );
});

class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
