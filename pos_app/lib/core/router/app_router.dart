import 'package:go_router/go_router.dart';
import 'package:pos_app/features/activation/activation_page.dart';
import 'package:pos_app/features/pos/pos_checkout_page.dart'; // 引入收银台
import 'package:pos_app/features/pos/product_page.dart'; // 引入商品管理
import 'package:pos_app/features/activation/auth_provider.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/pos', // 默认进入收银台

    redirect: (context, state) {
      final isActivated = authProvider.isActivated;
      final path = state.uri.path;

      if (!isActivated && path != '/activation') {
        return '/activation';
      }

      if (isActivated && path == '/activation') {
        return '/pos';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/activation',
        builder: (context, state) => const ActivationPage(),
      ),
      // 默认的 POS 界面改为收银台
      GoRoute(
        path: '/pos',
        builder: (context, state) => const PosCheckoutPage(),
      ),
      // 新增商品管理页面的路由
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductPage(),
      ),
    ],
  );
}
