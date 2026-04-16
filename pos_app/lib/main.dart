import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 导入我们按功能划分的模块
import 'features/pos/product_provider.dart';
import 'core/router/app_router.dart';
import 'features/activation/auth_provider.dart';
import 'core/widgets/network_overlay.dart';
import 'features/pos/cart_provider.dart';

void main() async {
  // 确保 Flutter 引擎已启动
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isActivated = prefs.getBool('is_device_activated') ?? false;

  // 将明确的真实状态传给 AuthProvider
  final authProvider = AuthProvider(initialStatus: isActivated);
  final appRouter = createRouter(authProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MyApp(router: appRouter),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter router; // 接收唯一的 Router

  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '餐饮智能 OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
        useMaterial3: true,
      ),
      // 💥 关键修复 2：使用传入的 router，而不是重新 create
      routerConfig: router,
      builder: (context, child) {
        return NetworkOverlay(child: child!);
      },
    );
  }
}
