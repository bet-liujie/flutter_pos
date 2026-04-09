import 'package:go_router/go_router.dart';
import 'package:pos_app/features/activation/activation_page.dart';
import 'package:pos_app/features/pos/product_page.dart';
import 'package:pos_app/features/activation/auth_provider.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/pos',

    // 彻底删除了 refreshListenable: authProvider！
    // 杜绝它在后台偷偷和我们的点击事件抢夺路由控制权。
    redirect: (context, state) {
      final isActivated = authProvider.isActivated;
      final path = state.uri.path;

      // 守卫规则 1：没激活，想去别的地方 -> 踢回激活页
      if (!isActivated && path != '/activation') {
        return '/activation';
      }

      // 守卫规则 2：已激活，但卡在激活页 -> 自动送到收银台
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
      GoRoute(path: '/pos', builder: (context, state) => const ProductPage()),
    ],
  );
}
