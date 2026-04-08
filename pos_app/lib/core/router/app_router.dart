import 'package:go_router/go_router.dart';
import 'package:pos_app/features/activation/activation_page.dart';
import 'package:pos_app/features/pos/product_page.dart';
import 'package:pos_app/features/activation/auth_provider.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/pos',
    // 💥 关键点 1：将路由器与 AuthProvider 绑定
    // 只要 notifyListeners() 被调用，路由就会重新评估当前的页面
    refreshListenable: authProvider, 
    
    // 💥 关键点 2：全局重定向拦截器 (核心防盗门逻辑)
    redirect: (context, state) {
      final isActivated = authProvider.isActivated;
      final isGoingToActivation = state.uri.toString() == '/activation';

      // 场景 A：设备未激活，且用户想去的不是激活页 -> 强制踢回激活页
      if (!isActivated && !isGoingToActivation) {
        return '/activation';
      }

      // 场景 B：设备已激活，但用户还在激活页 -> 自动护送到收银主页
      if (isActivated && isGoingToActivation) {
        return '/pos';
      }

      // 场景 C：正常情况，不需要干预，放行
      return null; 
    },
    
    routes: [
      GoRoute(
        path: '/activation',
        builder: (context, state) => const ActivationPage(),
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) => const ProductPage(),
      ),
    ],
  );
}