import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'providers/policy_provider.dart';
import 'pages/login_page.dart';
import 'pages/device_list_page.dart';
import 'pages/device_detail_page.dart';
import 'pages/policy_list_page.dart';
import 'pages/policy_detail_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => PolicyProvider()),
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
      builder: (context, child) {
        return _AdminShell(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

/// 管理后台外壳 — 固定导航栏
class _AdminShell extends StatefulWidget {
  final Widget child;
  const _AdminShell({required this.child});

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _currentIndex = 0;
  late final VoidCallback _routeListener;

  @override
  void initState() {
    super.initState();
    _updateIndex();
    _routeListener = _updateIndex;
    _router.routeInformationProvider.addListener(_routeListener);
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_routeListener);
    super.dispose();
  }

  void _updateIndex() {
    final path = _router.routeInformationProvider.value.uri.path;
    final index = path.startsWith('/policies') ? 1 : 0;
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return widget.child;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  _router.go('/devices');
                case 1:
                  _router.go('/policies');
              }
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.grey[50],
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.phone_android),
                selectedIcon: Icon(Icons.phone_android, color: Colors.orange),
                label: Text('设备管理'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.policy_outlined),
                selectedIcon: Icon(Icons.policy, color: Colors.orange),
                label: Text('策略管理'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      ),
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
    GoRoute(
      path: '/policies',
      builder: (_, _) => const PolicyListPage(),
      routes: [
        GoRoute(
          path: ':policyId',
          builder: (_, state) => PolicyDetailPage(
            policyId: int.parse(state.pathParameters['policyId']!),
          ),
        ),
      ],
    ),
  ],
);
