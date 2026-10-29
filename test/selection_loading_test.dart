import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inspect_pro/data/rough_terrain_crane.dart';
import 'package:inspect_pro/models/machine.dart';
import 'package:inspect_pro/screens/inspection_input_screen.dart';
import 'package:inspect_pro/screens/inspector_selection_screen.dart';
import 'package:inspect_pro/services/firestore_service.dart';
import 'package:inspect_pro/services/selection_master_cache.dart';
import 'package:inspect_pro/widgets/master_name_registration_dialog.dart';

class DelayedSelectionService extends FirestoreService {
  DelayedSelectionService(super.firestore) : super.forTesting();
  var companies = Completer<List<Map<String, String>>>();
  var inspectors = Completer<List<Map<String, dynamic>>>();
  List<Map<String, String>>? companySnapshot;
  List<Map<String, dynamic>>? inspectorSnapshot;
  int companyRequests = 0;
  int inspectorRequests = 0;
  @override
  List<Map<String, String>>? get cachedInspectionCompanies => companySnapshot;
  @override
  List<Map<String, dynamic>>? get cachedInspectionInspectors =>
      inspectorSnapshot;
  @override
  Future<List<Map<String, String>>> getInspectionCompanyOptions({
    bool refresh = false,
  }) {
    companyRequests++;
    return companies.future;
  }

  @override
  Future<List<Map<String, dynamic>>> getInspectionInspectors({
    required Future<List<Map<String, String>>> companies,
    bool refresh = false,
  }) {
    inspectorRequests++;
    return inspectors.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const company = {'id': 'a', 'name': '既存会社'};
  Future<void> mount(WidgetTester tester, FirestoreService service) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: InspectorSelectionScreen(siteName: '検証', dataSource: service),
      ),
    );
    await tester.pump();
  }

  test('期限内は再取得せず、期限切れは古い表示を維持して同時取得をまとめる', () async {
    var now = DateTime(2026, 10, 29);
    var calls = 0;
    final cache = SelectionMasterCache<String>(now: () => now);
    Future<List<String>> first() async {
      calls++;
      return ['旧'];
    }

    expect(await cache.load(first), ['旧']);
    (await cache.load(first)).clear();
    expect(cache.snapshot, ['旧']);
    expect(calls, 1);
    now = now.add(const Duration(minutes: 2));
    final pending = Completer<List<String>>();
    Future<List<String>> refresh() {
      calls++;
      return pending.future;
    }

    final a = cache.load(refresh);
    final b = cache.load(refresh);
    expect(cache.snapshot, ['旧']);
    expect(calls, 2);
    pending.complete(['新']);
    expect(await a, ['新']);
    expect(await b, ['新']);
    expect(cache.snapshot, ['新']);
  });

  test('取得失敗を空一覧としてキャッシュせず、再試行できる', () async {
    final cache = SelectionMasterCache<String>();
    await expectLater(
      cache.load(() => Future.error(StateError('失敗'))),
      throwsStateError,
    );
    expect(cache.snapshot, isNull);
    expect(await cache.load(() async => ['成功']), ['成功']);
    await expectLater(
      cache.load(() => Future.error(StateError('失敗')), refresh: true),
      throwsStateError,
    );
    expect(cache.snapshot, ['成功']);
  });

  test('無効化前の遅い応答が更新後のキャッシュを上書きしない', () async {
    final cache = SelectionMasterCache<String>();
    final old = Completer<List<String>>();
    final oldRequest = cache.load(() => old.future);
    cache.invalidate();
    await cache.load(() async => ['更新後']);
    old.complete(['更新前']);
    await oldRequest;
    expect(cache.snapshot, ['更新後']);
  });

  test('先読み・キャッシュでも旧所属の補完は表示だけで、既存文書を書き換えない', () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService.forTesting(db);
    await db.doc('companies/default').set({
      'name': '松浦建設株式会社',
      'isActive': true,
    });
    await db.doc('inspectors/legacy').set({'name': '旧点検者', 'isActive': true});
    final before = (await db.doc('inspectors/legacy').get()).data();
    await service.preloadInspectionSelection();
    expect(service.cachedInspectionCompanies!.single['id'], 'default');
    expect(service.cachedInspectionInspectors!.single['companyId'], 'default');
    expect((await db.doc('inspectors/legacy').get()).data(), before);
    await db.doc('companies/remote').set({'name': '別端末の追加', 'isActive': true});
    expect(await service.getInspectionCompanyOptions(), hasLength(1));
    expect(
      await service.getInspectionCompanyOptions(refresh: true),
      hasLength(2),
    );
  });

  test('会社・点検者の登録と削除でキャッシュを無効化する', () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService.forTesting(db);
    await service.preloadInspectionSelection();
    final savedCompany = await service.registerCompanyForInspection('新会社');
    expect(service.cachedInspectionCompanies, isNull);
    await service.preloadInspectionSelection();
    final person = await service.registerInspectorForInspection(
      inspectorName: '新点検者',
      companyId: savedCompany['id']!,
    );
    expect(service.cachedInspectionInspectors, isNull);
    await service.preloadInspectionSelection();
    expect(service.cachedInspectionInspectors!.single['name'], '新点検者');
    await service.deleteInspectorById(person['id']!);
    expect(service.cachedInspectionInspectors, isNull);
    await service.preloadInspectionSelection();
    await service.addMasterData('companies', '管理画面の追加');
    expect(service.cachedInspectionCompanies, isNull);
    await service.preloadInspectionSelection();
    await service.deleteMasterData('companies', '管理画面の追加');
    expect(service.cachedInspectionCompanies, isNull);
  });

  testWidgets('会社・点検者を並行取得し、点検者を待たずに会社を表示', (tester) async {
    final service = DelayedSelectionService(FakeFirebaseFirestore());
    await mount(tester, service);
    expect(service.companyRequests, 1);
    expect(service.inspectorRequests, 1);
    service.companies.complete([company]);
    await tester.pumpAndSettle();
    expect(find.text('既存会社'), findsOneWidget);
    expect(find.text('読込中'), findsOneWidget);
    expect(find.text('0名'), findsNothing);
    await tester.tap(find.text('既存会社'));
    await tester.pump();
    expect(find.text('点検者名を追加'), findsOneWidget);
    expect(find.text('該当する点検者が見つかりません'), findsNothing);
    service.inspectors.complete([
      {'id': 'person', 'name': '確認者', 'companyId': 'a'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('確認者'), findsOneWidget);
  });

  testWidgets('キャッシュの会社名は新しい通信の完了前から表示', (tester) async {
    final service = DelayedSelectionService(FakeFirebaseFirestore())
      ..companySnapshot = [company]
      ..inspectorSnapshot = [];
    await mount(tester, service);
    expect(find.text('既存会社'), findsOneWidget);
    expect(find.text('0名'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    service.companies.complete([
      company,
      {'id': 'b', 'name': '更新会社'},
    ]);
    service.inspectors.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('更新会社'), findsOneWidget);
  });

  testWidgets('点検者の取得に失敗しても会社は表示し、0名とは表示しない', (tester) async {
    final service = DelayedSelectionService(FakeFirebaseFirestore());
    await mount(tester, service);
    service.companies.complete([company]);
    service.inspectors.completeError(StateError('ネットワーク失敗'));
    await tester.pumpAndSettle();
    expect(find.text('既存会社'), findsOneWidget);
    expect(find.text('0名'), findsNothing);
    expect(find.text('点検者一覧を取得できませんでした。'), findsOneWidget);
    expect(find.text('再読込'), findsOneWidget);
  });

  testWidgets('会社の取得失敗は未登録と混同せず、再読込で回復', (tester) async {
    final service = DelayedSelectionService(FakeFirebaseFirestore());
    await mount(tester, service);
    service.companies.completeError(StateError('ネットワーク失敗'));
    service.inspectors.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('会社一覧を取得できませんでした。'), findsOneWidget);
    expect(find.text('会社が登録されていません'), findsNothing);
    service.companies = Completer();
    service.inspectors = Completer();
    await tester.tap(find.text('再読込'));
    await tester.pump();
    service.companies.complete([company]);
    service.inspectors.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('既存会社'), findsOneWidget);
    expect(service.companyRequests, 2);
  });

  testWidgets('遅い更新が直前に登録した会社・点検者を消さない', (tester) async {
    final db = FakeFirebaseFirestore();
    final service = DelayedSelectionService(db)
      ..companySnapshot = [company]
      ..inspectorSnapshot = [];
    await db.doc('companies/a').set({'name': '既存会社', 'isActive': true});
    await mount(tester, service);
    await tester.tap(find.text('会社名を追加'));
    await tester.pumpAndSettle();
    Finder field() => find.descendant(
      of: find.byType(MasterNameRegistrationDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field(), '追加会社');
    await tester.tap(find.text('登録して選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点検者名を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(field(), '追加点検者');
    await tester.tap(find.text('登録して選択'));
    await tester.pumpAndSettle();
    service.companies.complete([company]);
    service.inspectors.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('追加点検者'), findsOneWidget);
    await tester.tap(find.text('会社を変更'));
    await tester.pumpAndSettle();
    expect(find.text('追加会社'), findsOneWidget);
  });

  for (final model in ['25t', '50t']) {
    testWidgets('$modelの入力画面は注意の展開欄を非表示、14項目・未入力状態は維持', (tester) async {
      final db = FakeFirebaseFirestore();
      final data =
          jsonDecode(
                File(
                  'scripts/data/rough_terrain_crane.json',
                ).readAsStringSync(),
              )
              as Map;
      for (final item in data['items'] as List) {
        await db
            .doc(
              'machine_types/${RoughTerrainCrane.typeId}/items/${item['code']}',
            )
            .set(Map<String, dynamic>.from(item));
      }
      await tester.pumpWidget(
        MaterialApp(
          home: InspectionInputScreen(
            siteName: '検証',
            inspectorName: '確認者',
            dataSource: FirestoreService.forTesting(db),
            machine: Machine(
              id: model,
              type: 'ラフタークレーン',
              typeId: RoughTerrainCrane.typeId,
              model: model,
              unitNumber: '1号機',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ラフターの点検区分・確認上の注意'), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('0 / 14'), findsOneWidget);
    });
  }
}
