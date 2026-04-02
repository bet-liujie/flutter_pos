import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/product_provider.dart';
import 'pages/product_page.dart';

void main() {
  runApp(
    // 在最顶层注入 Provider
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ProductProvider())],
      child: const PosApp(),
    ),
  );
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ProductPage());
  }
}
