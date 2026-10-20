import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inspect_pro/screens/admin_screen.dart';
import 'package:inspect_pro/services/firestore_service.dart';

Map<String, dynamic> record(int index) {
  final now = DateTime.now();
  return {
    'siteName': index.isEven ? '現場A' : '現場B',
    'inspectorName': '検証者',
    'machineId': 'existing-machine',
    'machineType': '油圧ショベル',
    'machineModel': '既存型式',
    'machineUnitNumber': '1号機',
    'machineTypeId': 'excavator',
    'date':
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    'results': {
      'item_01': {'itemCode': 'item_01', 'isGood': true},
    },
  };
}

Future<void> seed(FakeFirebaseFirestore db, int count) async {
  for (var i = 0; i < count; i++) {
    await db
        .doc('inspections/record_${i.toString().padLeft(5, '0')}')
        .set(record(i));
  }
  for (final name in ['現場A', '現場B']) {
    await db.collection('sites').doc(name).set({
      'name': name,
      'isActive': true,
    });
  }
}

class RetryService extends FirestoreService {
  RetryService(super.firestore) : super.forTesting();
  bool fail = true;
  @override
  Future<List<Map<String, dynamic>>> getInspections() {
    if (fail) return Future.error(StateError('取得失敗'));
    return super.getInspections();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final count in [0, 500, 1000, 1001, 1505]) {
    test('$count件を末尾まで取得し、重複・欠落なし', () async {
      final db = FakeFirebaseFirestore();
      await seed(db, count);
      final service = FirestoreService.forTesting(db);
      final records = await service.getInspections();
      expect(records, hasLength(count));
      expect(records.map((r) => r['id']).toSet(), hasLength(count));
      if (count > 0) {
        expect(
          records.any(
            (r) =>
                r['id'] == 'record_${(count - 1).toString().padLeft(5, '0')}',
          ),
          isTrue,
        );
      }
    });
  }

  test('1000件より後の最新記録と日付なしの旧記録も取得する', () async {
    final db = FakeFirebaseFirestore();
    await seed(db, 1001);
    await db.doc('inspections/record_01000').update({'date': '2099-12-31'});
    await db.doc('inspections/legacy-without-date').set({
      'siteName': '旧現場',
      'results': {},
    });
    final records = await FirestoreService.forTesting(db).getInspections();
    expect(records, hasLength(1002));
    expect(records.first['id'], 'record_01000');
    expect(records.last['id'], 'legacy-without-date');
  });

  testWidgets('総件数1001と、全ページを対象にした現場別件数501を表示', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = FakeFirebaseFirestore();
    await seed(db, 1001);
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(dataSource: FirestoreService.forTesting(db)),
      ),
    );
    await tester.pumpAndSettle();
    String? total() => tester
        .widget<Text>(find.byKey(const ValueKey('inspection-stat-総件数')))
        .data;
    expect(total(), '1001');
    final siteField = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .first;
    siteField.onChanged!('現場A');
    await tester.pumpAndSettle();
    expect(total(), '501');
    await tester.tap(find.text('フィルタをクリア'));
    await tester.pumpAndSettle();
    expect(total(), '1001');
  });

  testWidgets('取得失敗を0件と表示せず、再読み込みで1001件を表示', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = FakeFirebaseFirestore();
    await seed(db, 1001);
    final service = RetryService(db);
    await tester.pumpWidget(
      MaterialApp(home: AdminScreen(dataSource: service)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('inspection-stat-総件数')))
          .data,
      '取得失敗',
    );
    expect(find.text('点検記録の読み込みに失敗しました'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('再読み込み').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('inspection-stat-総件数')))
          .data,
      '1001',
    );
    expect(find.text('✅ データを再読み込みしました (1001件)'), findsOneWidget);
  });
}
