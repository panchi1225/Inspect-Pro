import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:inspect_pro/navigation/app_navigation.dart';
import 'package:inspect_pro/navigation/app_router.dart';
import 'package:inspect_pro/screens/machine_selection_screen_v2.dart';
import 'package:inspect_pro/services/auth_service.dart';
import 'package:inspect_pro/services/firestore_service.dart';
import 'package:inspect_pro/widgets/master_name_registration_dialog.dart';

class RegistrationService extends FirestoreService {
  RegistrationService(super.firestore) : super.forTesting();
  bool failCompany = false;
  bool failInspector = false;
  int companyCalls = 0;
  Completer<Map<String, String>>? pendingCompany;

  @override
  Future<Map<String, String>> registerCompanyForInspection(String name) {
    companyCalls++;
    if (failCompany) return Future.error(StateError('通信失敗'));
    return pendingCompany?.future ?? super.registerCompanyForInspection(name);
  }

  @override
  Future<Map<String, String>> registerInspectorForInspection({
    required String inspectorName,
    required String companyId,
  }) {
    if (failInspector) return Future.error(StateError('通信失敗'));
    return super.registerInspectorForInspection(
      inspectorName: inspectorName,
      companyId: companyId,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late RegistrationService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = RegistrationService(db);
    PackageInfo.setMockInitialValues(
      appName: 'Inspect Pro',
      packageName: 'inspect_pro',
      version: '1.4.3',
      buildNumber: '6',
      buildSignature: '',
    );
  });

  Future<void> company(String id, String name, {bool active = true}) =>
      db.doc('companies/$id').set({'name': name, 'isActive': active});

  Future<GoRouter> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthService().login(UserRole.inspector, '1331');
    final router = createAppRouter(dataSource: service);
    addTearDown(() {
      router.dispose();
      AuthService().logout();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.go(AppPaths.inspectors, extra: const AppRouteData(siteName: '検証工事'));
    await tester.pumpAndSettle();
    return router;
  }

  Finder dialogInput() => find.descendant(
    of: find.byType(MasterNameRegistrationDialog),
    matching: find.byType(TextFormField),
  );
  Future<void> submit(WidgetTester tester, String name) async {
    await tester.enterText(dialogInput(), name);
    await tester.tap(find.text('登録して選択'));
    await tester.pumpAndSettle();
  }

  test('会社の再登録・同時登録で重複せず、前後の空白を除いて保存', () async {
    final results = await Future.wait(
      List.generate(5, (_) => service.registerCompanyForInspection('　新規会社　')),
    );
    expect(results.map((r) => r['id']).toSet(), hasLength(1));
    final snapshot = await db.collection('companies').get();
    expect(snapshot.docs, hasLength(1));
    expect(snapshot.docs.single.data()['name'], '新規会社');
    expect(snapshot.docs.single.data()['isActive'], true);
    expect(snapshot.docs.single.data()['createdAt'], isNotNull);
    expect(
      (await service.registerCompanyForInspection('新規会社'))['id'],
      results.first['id'],
    );
    expect((await db.collection('companies').get()).docs, hasLength(1));
  });

  test('既存会社と既存点検者のID・フィールドを変えず再利用', () async {
    await company('legacy-company', '既存会社');
    await db.doc('inspectors/legacy-person').set({
      'name': '既存 太郎',
      'companyId': 'legacy-company',
      'companyName': '既存会社',
      'isActive': true,
      'legacy': '保持',
    });
    final before = (await db.doc('inspectors/legacy-person').get()).data();
    expect(
      (await service.registerCompanyForInspection(' 既存会社 '))['id'],
      'legacy-company',
    );
    final result = await service.registerInspectorForInspection(
      inspectorName: '　既存 太郎 ',
      companyId: 'legacy-company',
    );
    expect(result['id'], 'legacy-person');
    expect((await db.doc('inspectors/legacy-person').get()).data(), before);
    expect((await db.collection('companies').get()).docs, hasLength(1));
    expect((await db.collection('inspectors').get()).docs, hasLength(1));
  });

  test('同じ会社の同名点検者は重複せず、別会社の同姓同名は区別', () async {
    await company('a', '会社A');
    await company('b', '会社B');
    final results = await Future.wait(
      List.generate(
        5,
        (_) => service.registerInspectorForInspection(
          inspectorName: ' 新規 太郎 ',
          companyId: 'a',
        ),
      ),
    );
    expect(results.map((r) => r['id']).toSet(), hasLength(1));
    final second = await service.registerInspectorForInspection(
      inspectorName: '新規 太郎',
      companyId: 'b',
    );
    expect(second['id'], isNot(results.first['id']));
    final docs = (await db.collection('inspectors').get()).docs;
    expect(docs, hasLength(2));
    expect(docs.map((d) => d.data()['companyName']).toSet(), {'会社A', '会社B'});
    expect(
      docs.every(
        (d) => d.data()['isActive'] == true && d.data()['createdAt'] != null,
      ),
      true,
    );
  });

  test('空白だけ・存在しない会社・無効な会社では登録しない', () async {
    await company('inactive', '無効会社', active: false);
    await expectLater(
      service.registerCompanyForInspection('　 '),
      throwsArgumentError,
    );
    await expectLater(
      service.registerInspectorForInspection(
        inspectorName: ' ',
        companyId: 'inactive',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.registerInspectorForInspection(
        inspectorName: '確認者',
        companyId: 'missing',
      ),
      throwsStateError,
    );
    await expectLater(
      service.registerInspectorForInspection(
        inspectorName: '確認者',
        companyId: 'inactive',
      ),
      throwsStateError,
    );
    expect((await db.collection('inspectors').get()).docs, isEmpty);
  });

  testWidgets('点検者0名の会社も表示し、点検者ロールのまま追加できる', (tester) async {
    await company('empty', '点検者未登録会社');
    await company('inactive', '無効会社', active: false);
    await mount(tester);
    expect(find.text('点検者未登録会社'), findsOneWidget);
    expect(find.text('0名'), findsOneWidget);
    expect(find.text('無効会社'), findsNothing);
    await tester.tap(find.text('点検者未登録会社'));
    await tester.pumpAndSettle();
    expect(find.text('点検者名を追加'), findsOneWidget);
    await tester.tap(find.text('点検者名を追加'));
    await tester.pumpAndSettle();
    expect(find.text('所属会社：点検者未登録会社'), findsOneWidget);
    await submit(tester, '新規オペ');
    expect(find.text('新規オペ'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '次へ'))
          .onPressed,
      isNotNull,
    );
    expect(
      (await db.collection('inspectors').get()).docs.single.data()['companyId'],
      'empty',
    );
  });

  testWidgets('会社も点検者も未登録から追加・自動選択し、点検を保存できる', (tester) async {
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
    for (final item in fixture['items'] as List) {
      await db
          .doc('machine_types/rough_terrain_crane/items/${item['code']}')
          .set(Map<String, dynamic>.from(item));
    }
    final router = await mount(tester);
    expect(find.text('会社が登録されていません'), findsOneWidget);
    await tester.tap(find.text('会社名を追加'));
    await tester.pumpAndSettle();
    await submit(tester, ' 新規協力会社 ');
    expect(find.text('選択中の会社: 新規協力会社'), findsOneWidget);
    await tester.tap(find.text('点検者名を追加'));
    await tester.pumpAndSettle();
    await submit(tester, ' 新規オペ ');
    final savedCompany = (await db.collection('companies').get()).docs.single;
    final person = (await db.collection('inspectors').get()).docs.single.data();
    expect(person['companyId'], savedCompany.id);
    expect(person['companyName'], '新規協力会社');
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    expect(find.byType(MachineSelectionScreenV2), findsOneWidget);
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
    await tester.tap(find.text('未入力項目を一括で「⚪」にする'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('点検結果を保存'));
    await tester.tap(find.text('点検結果を保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存完了'), findsOneWidget);
    final record = (await db.collection('inspections').get()).docs.single
        .data();
    expect(record['inspectorName'], '新規オペ');
    expect((record['results'] as Map).length, 14);
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();
    router.go(AppPaths.inspectors, extra: const AppRouteData(siteName: '検証工事'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新規協力会社'));
    await tester.pumpAndSettle();
    expect(find.text('新規オペ'), findsOneWidget);
  });

  testWidgets('空入力とキャンセルでは会社を作らない', (tester) async {
    await mount(tester);
    await tester.tap(find.text('会社名を追加'));
    await tester.pumpAndSettle();
    await submit(tester, '　 ');
    expect(find.text('会社名を入力してください'), findsOneWidget);
    expect((await db.collection('companies').get()).docs, isEmpty);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('会社名を追加'), findsOneWidget);
    expect((await db.collection('companies').get()).docs, isEmpty);
  });

  testWidgets('会社登録の失敗は入力を残し、成功するまで選択しない', (tester) async {
    service.failCompany = true;
    await mount(tester);
    await tester.tap(find.text('会社名を追加'));
    await tester.pumpAndSettle();
    await submit(tester, '再試行会社');
    expect(find.textContaining('登録できませんでした。'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(dialogInput()).controller!.text,
      '再試行会社',
    );
    expect((await db.collection('companies').get()).docs, isEmpty);
    service.failCompany = false;
    await tester.tap(find.text('登録して選択'));
    await tester.pumpAndSettle();
    expect(find.text('選択中の会社: 再試行会社'), findsOneWidget);
  });

  testWidgets('点検者登録の失敗でも次へ進めず、再試行後に選択', (tester) async {
    await company('a', '会社A');
    service.failInspector = true;
    await mount(tester);
    await tester.tap(find.text('会社A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点検者名を追加'));
    await tester.pumpAndSettle();
    await submit(tester, '再試行オペ');
    expect(find.textContaining('登録できませんでした。'), findsOneWidget);
    expect((await db.collection('inspectors').get()).docs, isEmpty);
    service.failInspector = false;
    await tester.tap(find.text('登録して選択'));
    await tester.pumpAndSettle();
    expect(find.text('再試行オペ'), findsOneWidget);
  });

  testWidgets('保存中は連打を防ぎ、完了後だけ会社を選択する', (tester) async {
    service.pendingCompany = Completer();
    await mount(tester);
    await tester.tap(find.text('会社名を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogInput(), '保存待ち会社');
    await tester.tap(find.text('登録して選択'));
    await tester.pumpAndSettle();
    expect(service.companyCalls, 1);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '登録中…'))
          .onPressed,
      isNull,
    );
    final result = await FirestoreService.forTesting(
      db,
    ).registerCompanyForInspection('保存待ち会社');
    service.pendingCompany!.complete(result);
    await tester.pumpAndSettle();
    expect(find.text('選択中の会社: 保存待ち会社'), findsOneWidget);
    expect(service.companyCalls, 1);
  });

  testWidgets('スマートフォンでキーボードを表示しても登録フォームが崩れない', (tester) async {
    await company('a', '会社A');
    await mount(tester);
    await tester.tap(find.text('会社A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点検者名を追加'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await submit(tester, 'スマホオペ');
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('スマホオペ'), findsOneWidget);
  });
}
