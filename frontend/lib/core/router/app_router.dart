import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/provider/auth_provider.dart';
import '../../features/admin/screen/admin_dashboard_screen.dart';
import '../../features/auth/screen/login_screen.dart';
import '../../features/auth/screen/register_screen.dart';
import '../../features/cart/screen/cart_screen.dart';
import '../../features/chat/screen/chat_list_screen.dart';
import '../../features/chat/screen/chat_room_screen.dart';
import '../../features/checkout/screen/checkout_screen.dart';
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
    initialLocation: '/splash',
    refreshListenable: RouterRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loggedIn = auth.isLoggedIn;
      final splashRoute = state.matchedLocation == '/splash';
      final authRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final adminRoute = state.matchedLocation == '/admin';
      final adminOnly = auth.user?.isAdmin == true;
      if (!auth.bootstrapped) return splashRoute ? null : '/splash';
      if (splashRoute) {
        if (!loggedIn) return '/login';
        return adminOnly ? '/admin' : '/home';
      }
      if (!loggedIn && !authRoute) {
        return loginLocationFor(state.uri.toString());
      }
      if (loggedIn && authRoute) return adminOnly ? '/admin' : '/home';
      if (adminRoute && !adminOnly) {
        return '/home';
      }
      if (adminOnly && !adminRoute) {
        return '/admin';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/chats', builder: (_, __) => const ChatListScreen()),
      GoRoute(
          path: '/chats/:id',
          builder: (_, s) => ChatRoomScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/checkout',
          builder: (_, s) => CheckoutScreen(
                productId: s.uri.queryParameters['productId'],
                quantity: int.tryParse(s.uri.queryParameters['quantity'] ?? ''),
                selectedProductIds:
                    (s.uri.queryParameters['cartProductIds'] ?? '')
                        .split(',')
                        .where((id) => id.isNotEmpty)
                        .toList(),
              )),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: '/seller-apply', builder: (_, __) => const SellerApplyScreen()),
      GoRoute(
          path: '/products/:id',
          builder: (_, s) => ProductDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/seller', builder: (_, __) => const SellerDashboardScreen()),
      GoRoute(
          path: '/seller/product',
          builder: (_, s) =>
              SellerProductFormScreen(productId: s.uri.queryParameters['id'])),
    ],
  );
});

String loginLocationFor(String requestedLocation) {
  final target = postLoginLocation(requestedLocation);
  if (target == '/home') return '/login';
  return Uri(path: '/login', queryParameters: {'next': target}).toString();
}

String registerLocationFor(String? requestedLocation) {
  final target = postLoginLocation(requestedLocation);
  if (target == '/home') return '/register';
  return Uri(path: '/register', queryParameters: {'next': target}).toString();
}

String postLoginLocation(String? requestedLocation) {
  if (requestedLocation == null || requestedLocation.isEmpty) return '/home';
  final uri = Uri.tryParse(requestedLocation);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return '/home';
  if (!requestedLocation.startsWith('/') ||
      requestedLocation.startsWith('//')) {
    return '/home';
  }
  if (requestedLocation == '/login' ||
      requestedLocation == '/register' ||
      requestedLocation == '/splash') {
    return '/home';
  }
  return requestedLocation;
}

class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
