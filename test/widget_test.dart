import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:inspect_pro/main.dart';
import 'package:inspect_pro/services/auth_service.dart';

void main() {
  testWidgets('起動時は白画面ではなくログイン画面を表示', (tester) async {
    AuthService().logout();
    PackageInfo.setMockInitialValues(
      appName: 'Inspect Pro',
      packageName: 'inspect_pro',
      version: '1.4.2',
      buildNumber: '5',
      buildSignature: '',
    );
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('点検者ログイン'), findsOneWidget);
    expect(find.text('管理者ログイン'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
