import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pos_admin/main.dart';
import 'package:pos_admin/providers/auth_provider.dart';
import 'package:pos_admin/providers/device_provider.dart';

void main() {
  testWidgets('Admin app builds without error', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ],
        child: const AdminApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Login page should show the login button
    expect(find.text('登 录'), findsOneWidget);
  });
}
