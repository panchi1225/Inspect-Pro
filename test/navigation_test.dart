import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:inspect_pro/navigation/app_navigation.dart';
import 'package:inspect_pro/navigation/app_router.dart';
import 'package:inspect_pro/screens/admin_screen.dart';
import 'package:inspect_pro/screens/home_screen.dart';
import 'package:inspect_pro/screens/inspection_input_screen.dart';
import 'package:inspect_pro/screens/inspector_selection_screen.dart';
import 'package:inspect_pro/screens/machine_selection_screen_v2.dart';
import 'package:inspect_pro/screens/master_data_management_screen.dart';
import 'package:inspect_pro/screens/record_detail_screen.dart';
import 'package:inspect_pro/screens/site_selection_screen.dart';
import 'package:inspect_pro/services/auth_service.dart';
import 'package:inspect_pro/services/firestore_service.dart';

class NavigationService extends FirestoreService {
  NavigationService(super.firestore) : super.forTesting();
  int recordReads = 0;
  Completer<List<Map<String, dynamic>>>? pendingRecords;
  @override
  Future<List<Map<String, dynamic>>> getInspections() {
    recordReads++;
    return pendingRecords?.future ?? super.getInspections();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late NavigationService service;
  late GoRouter router;
  final reports = <Map<String, dynamic>>[];
  final modes = <String>[];

  Future<void> mount(WidgetTester tester, {TargetPlatform? platform}) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router = createAppRouter(dataSource: service);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(platform: platform),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> checkpoint() => Map.of(reports.last);
  Future<void> browserBack(
    WidgetTester tester,
    Map<String, dynamic> entry,
  ) async {
    await router.routeInformationProvider.didPushRouteInformation(
      RouteInformation(
        uri: Uri.parse(entry['uri'] as String),
        state: entry['state'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  setUp(() async {
    AuthService().login(UserRole.admin, '4043');
    PackageInfo.setMockInitialValues(
      appName: 'Inspect Pro',
      packageName: 'inspect_pro',
      version: '1.4.2',
      buildNumber: '5',
      buildSignature: '',
    );
    db = FakeFirebaseFirestore();
    service = NavigationService(db);
    await db.doc('sites/site').set({'name': '検証工事', 'isActive': true});
    await db.doc('companies/company').set({'name': '検証会社', 'isActive': true});
    await db.doc('inspectors/inspector').set({
      'name': '確認者',
      'companyId': 'company',
      'companyName': '検証会社',
      'isActive': true,
    });
    await db.doc('machines/rtc_25t_01').set({
      'type': 'ラフタークレーン',
      'typeId': 'rough_terrain_crane',
      'model': '25t',
      'unitNumber': '1号機',
      'isActive': true,
      'sortOrder': 100,
    });
    final fixture =
        jsonDecode(
              File('scripts/data/rough_terrain_crane.json').readAsStringSync(),
            )
            as Map;
    final results = <String, dynamic>{};
    for (final item in fixture['items'] as List) {
      await db
          .doc('machine_types/rough_terrain_crane/items/${item['code']}')
          .set(Map<String, dynamic>.from(item));
      results[item['code']] = {'itemCode': item['code'], 'isGood': true};
    }
    await db.doc('inspections/record').set({
      'siteName': '検証工事',
      'inspectorName': '確認者',
      'machineId': 'rtc_25t_01',
      'machineType': 'ラフタークレーン',
      'machineTypeId': 'rough_terrain_crane',
      'machineModel': '25t',
      'machineUnitNumber': '1号機',
      'date': '2026-10-20',
      'results': results,
    });
    reports.clear();
    modes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add(Map<String, dynamic>.from(call.arguments as Map));
          }
          if (call.method.startsWith('select')) modes.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null);
    AuthService().logout();
  });

  testWidgets('ブラウザ戻るは既存画面を保持し、単一履歴の作り直しを行わない', (tester) async {
    await mount(tester);
    final home = tester.state(find.byType(HomeScreen));
    final homeEntry = checkpoint();
    await tester.tap(find.text('点検を開始'));
    await tester.pumpAndSettle();
    final site = tester.state(find.byType(SiteSelectionScreen));
    final siteEntry = checkpoint();
    await tester.enterText(find.byType(TextField), '検証');
    await tester.tap(find.text('検証工事'));
    await tester.pump();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.byType(InspectorSelectionScreen), findsOneWidget);
    await browserBack(tester, siteEntry);
    expect(tester.state(find.byType(SiteSelectionScreen)), same(site));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '検証',
    );
    expect(find.text('次へ'), findsOneWidget);
    await browserBack(tester, homeEntry);
    expect(tester.state(find.byType(HomeScreen)), same(home));
    expect(modes, contains('selectMultiEntryHistory'));
    expect(modes, isNot(contains('selectSingleEntryHistory')));
  });

  testWidgets('機械・点検入力から一つずつ戻り、選択状態を維持', (tester) async {
    await mount(tester);
    await tester.tap(find.text('点検を開始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('検証工事'));
    await tester.pump();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    final inspectorEntry = checkpoint();
    await tester.tap(find.text('検証会社'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認者'));
    await tester.pump();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    final machineState = tester.state(find.byType(MachineSelectionScreenV2));
    final machineEntry = checkpoint();
    const values = ['ラフタークレーン', '25t', '1号機'];
    for (var i = 0; i < values.length; i++) {
      final fields = tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .toList();
      fields[i].onChanged!(values[i]);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(ElevatedButton, '点検を開始'));
    await tester.pumpAndSettle();
    expect(find.byType(InspectionInputScreen), findsOneWidget);
    await tester.tap(find.text('未入力項目を一括で「⚪」にする'));
    await tester.pumpAndSettle();
    expect(find.text('14 / 14'), findsOneWidget);
    await browserBack(tester, machineEntry);
    expect(
      tester.state(find.byType(MachineSelectionScreenV2)),
      same(machineState),
    );
    final fields = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList();
    expect(fields.map((f) => f.initialValue), values);
    await browserBack(tester, inspectorEntry);
    expect(find.text('確認者'), findsOneWidget);
  });

  testWidgets('詳細から戻っても一覧を再読込せずフィルタを保持、マスタ管理も戻れる', (tester) async {
    await mount(tester);
    final homeEntry = checkpoint();
    await tester.tap(find.text('点検データ管理'));
    await tester.pumpAndSettle();
    final adminState = tester.state(find.byType(AdminScreen));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('検証工事').last);
    await tester.pumpAndSettle();
    final recordsEntry = checkpoint();
    await tester.tap(find.text('25t'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordDetailScreen), findsOneWidget);
    await browserBack(tester, recordsEntry);
    expect(tester.state(find.byType(AdminScreen)), same(adminState));
    expect(service.recordReads, 1);
    expect(
      tester
          .state<FormFieldState<String>>(
            find.byType(DropdownButtonFormField<String>).first,
          )
          .value,
      '検証工事',
    );
    await browserBack(tester, homeEntry);
    await tester.tap(find.text('マスタデータ管理'));
    await tester.pumpAndSettle();
    expect(find.byType(MasterDataManagementScreen), findsOneWidget);
    await browserBack(tester, homeEntry);
  });

  testWidgets('読込途中で戻ってもdispose後に画面更新しない', (tester) async {
    await mount(tester);
    final homeEntry = checkpoint();
    service.pendingRecords = Completer();
    await tester.tap(find.text('点検データ管理'));
    await tester.pump();
    await router.routeInformationProvider.didPushRouteInformation(
      RouteInformation(
        uri: Uri.parse(homeEntry['uri'] as String),
        state: homeEntry['state'],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    service.pendingRecords!.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ログアウト後の履歴と、再読込で失われた引数は安全な画面へ戻す', (tester) async {
    await mount(tester);
    await tester.tap(find.text('点検を開始'));
    await tester.pumpAndSettle();
    final oldEntry = checkpoint();
    AuthService().logout();
    await tester.pumpAndSettle();
    await browserBack(tester, oldEntry);
    expect(find.text('管理者ログイン'), findsOneWidget);
    AuthService().login(UserRole.admin, '4043');
    await tester.pumpAndSettle();
    router.go(AppPaths.input);
    await tester.pumpAndSettle();
    expect(find.byType(SiteSelectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('履歴へは不透明キーだけを保存し、別セッションのキーは復元しない', () {
    final codec = SessionRouteDataCodec();
    const data = AppRouteData(siteName: '非公開現場', inspectorName: '個人名');
    final encoded = codec.encode(data);
    expect(jsonEncode(encoded), isNot(contains('非公開現場')));
    expect(codec.decode(encoded), same(data));
    expect(SessionRouteDataCodec().decode(encoded), isNull);
    expect(codec.decode(null), isNull);
  });

  testWidgets('保存完了は点検フロー全体を閉じてホームへ戻る', (tester) async {
    await mount(tester);
    final machine = (await service.getMachineById('rtc_25t_01'))!;
    router.go(
      AppPaths.input,
      extra: AppRouteData(
        siteName: '検証工事',
        inspectorName: '確認者',
        machine: machine,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('未入力項目を一括で「⚪」にする'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点検結果を保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '完了'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
    expect((await db.collection('inspections').get()).docs, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('詳細で削除した検証記録は戻った一覧にも反映される', (tester) async {
    await mount(tester);
    await tester.tap(find.text('点検データ管理'));
    await tester.pumpAndSettle();
    final admin = tester.state(find.byType(AdminScreen));
    await tester.tap(find.text('25t'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(AdminScreen)), same(admin));
    expect((await db.collection('inspections').get()).docs, isEmpty);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('inspection-stat-総件数')))
          .data,
      '0',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOSの端スワイプはキャンセル時に画面を保持し、完了時に一つ戻る', (tester) async {
    await mount(tester, platform: TargetPlatform.iOS);
    final home = tester.state(find.byType(HomeScreen));
    await tester.tap(find.text('点検を開始'));
    await tester.pumpAndSettle();
    final site = tester.state(find.byType(SiteSelectionScreen));
    await tester.timedDragFrom(
      const Offset(1, 600),
      const Offset(40, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(SiteSelectionScreen)), same(site));
    await tester.dragFrom(const Offset(1, 600), const Offset(1100, 0));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(HomeScreen)), same(home));
    expect(tester.takeException(), isNull);
  });
}
