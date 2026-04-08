import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 导入我们按功能划分的模块
import 'features/activation/activation_page.dart';
import 'features/pos/product_page.dart';
import 'features/pos/product_provider.dart';
import 'app_router.dart';

void main() async {
  // 💥 关键点 1：确保 Flutter 底层绑定完成，才能使用本地存储插件
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取 AuthProvider 的实例，传给路由进行监控
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 💥 使用 MaterialApp.router 替代 MaterialApp
    return MaterialApp.router(
      title: '餐饮智能 OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
        useMaterial3: true,
      ),
      // 载入刚才写的路由配置
      routerConfig: createRouter(authProvider), 
    );
  }
}
