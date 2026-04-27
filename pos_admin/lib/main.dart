import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'pages/login_page.dart';
import 'pages/device_list_page.dart';
import 'pages/device_detail_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: const AdminApp(),
    ),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MDM 管理后台',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final path = state.uri.path;

    if (!isLoggedIn && path != '/login') {
      return '/login';
    }

    if (isLoggedIn && path == '/login') {
      return '/devices';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginPage(),
    ),
    GoRoute(
      path: '/devices',
      builder: (_, _) => const DeviceListPage(),
      routes: [
        GoRoute(
          path: ':deviceId',
          builder: (_, state) => DeviceDetailPage(
            deviceId: state.pathParameters['deviceId']!,
          ),
        ),
      ],
    ),
  ],
);
