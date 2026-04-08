import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 导入我们按功能划分的模块
import 'features/activation/activation_page.dart';
import 'features/pos/product_page.dart';
import 'features/pos/product_provider.dart';

void main() async {
  // 💥 关键点 1：确保 Flutter 底层绑定完成，才能使用本地存储插件
  WidgetsFlutterBinding.ensureInitialized();

  // 💥 关键点 2：在 App 启动前，读取硬盘上的激活状态
  final prefs = await SharedPreferences.getInstance();
  final isActivated = prefs.getBool('is_device_activated') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        // 以后有 appStoreProvider 等都加在这里
      ],
      child: MyApp(isActivated: isActivated),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isActivated;

  const MyApp({super.key, required this.isActivated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '餐饮智能 OS',
      debugShowCheckedModeBanner: false, // 隐藏右上角的 debug 标签
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
        useMaterial3: true,
      ),
      // 💥 关键点 3：路由分发 (已激活进收银台，未激活进防盗门)
      home: isActivated ? const ProductPage() : const ActivationPage(),
    );
  }
}
