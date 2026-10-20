import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';
import 'package:inspect_pro/screens/machine_selection_screen_v2.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inspect_pro/data/rough_terrain_crane.dart';
import 'package:inspect_pro/models/inspection_record.dart';
import 'package:inspect_pro/models/machine.dart';
import 'package:inspect_pro/models/inspection_item.dart';
import 'package:inspect_pro/screens/inspection_input_screen.dart';
import 'package:inspect_pro/screens/record_detail_screen.dart';
import 'package:inspect_pro/services/firestore_service.dart';
import 'package:inspect_pro/services/web_excel_service.dart';

const rtc = RoughTerrainCrane.typeId;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = FirestoreService.forTesting(db);
    final master = jsonDecode(
      File('scripts/data/rough_terrain_crane.json').readAsStringSync(),
    );
    for (final item in master['items']) {
      await db
          .doc('machine_types/$rtc/items/${item['code']}')
          .set(Map<String, dynamic>.from(item));
    }
    for (var m = 0; m < 2; m++) {
      final model = m == 0 ? '25t' : '50t';
      for (var unit = 1; unit <= 15; unit++) {
        await db
            .doc('machines/rtc_${model}_${unit.toString().padLeft(2, '0')}')
            .set({
              'type': 'ラフタークレーン',
              'typeId': rtc,
              'model': model,
              'unitNumber': '$unit号機',
              'isActive': true,
              'sortOrder': 100 + m * 15 + unit,
            });
      }
    }
  });

  Future<void> save(String machineId, {bool badRope = false}) async {
    final machine = (await service.getMachineById(machineId))!;
    final items = await service.getInspectionItems(rtc);
    final results = {
      for (final i in items)
        i.code: InspectionResult(
          itemCode: i.code,
          isGood: !(badRope && i.code == 'rtc_06'),
          memo: badRope && i.code == 'rtc_06' ? '断線を確認。使用中止し責任者へ報告。' : null,
          photoPath: badRope && i.code == 'rtc_06' ? 'cGhvdG8=' : null,
        ),
    };
    expect(
      await service.saveInspection(
        siteName: '検証工事',
        inspectorName: '確認 太郎',
        machineId: machineId,
        machineTypeId: rtc,
        machineType: machine.type,
        machineModel: machine.model,
        machineUnitNumber: machine.unitNumber,
        date: DateTime(2026, 10, badRope ? 31 : 1),
        results: results,
      ),
      isTrue,
    );
  }

  Future<List<int>> report(String machineId) async {
    List<int>? bytes;
    final name = await WebExcelService.generateMonthlyReport(
      machineId: machineId,
      year: 2026,
      month: 10,
      siteName: '検証工事',
      responsiblePerson: '確認 太郎',
      companyName: '検証会社',
      primeContractorInspector: '確認 次郎',
      dataSource: service,
      output: (data, name) => bytes = data,
    );
    expect(name, isNotNull);
    return bytes!;
  }

  test('25t 1号機 / 50t 15号機: 保存・再読込・一覧・実Web出力経路', () async {
    for (final id in ['rtc_25t_01', 'rtc_50t_15']) {
      await save(id, badRope: id.contains('50t'));
      final records = await service.getMonthlyInspections(
        machineId: id,
        year: 2026,
        month: 10,
      );
      expect(records, hasLength(1));
      expect(
        (await service.getSiteInspections(
          '検証工事',
        )).any((r) => r['machineId'] == id),
        isTrue,
      );
      expect(await service.getSiteInspections('別現場'), isEmpty);
      final results = records.single['results'] as Map;
      expect(results, hasLength(14));
      expect(results['rtc_06']['isGood'], id.contains('25t'));
      if (id.contains('50t')) {
        expect(results['rtc_06']['memo'], contains('断線'));
        expect(results['rtc_06']['photoPath'], 'cGhvdG8=');
      }
      expect(
        (await service.getInspections()).any((r) => r['machineId'] == id),
        isTrue,
      );
      final bytes = await report(id);
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['月次点検表'];
      String? value(String cell) =>
          sheet.cell(CellIndex.indexByString(cell)).value?.toString();
      expect(
        [
          for (var row = 10; row <= 23; row++) value('A$row'),
        ].where((v) => v == '★'),
        hasLength(5),
      );
      expect(value('B15'), 'ウインチロープ・シーブ');
      expect(
        value(id.contains('50t') ? 'BQ15' : 'AM15'),
        id.contains('50t') ? '×' : '○',
      );
      expect(value('BQ9'), '31');
      expect(value('BE4'), id.contains('50t') ? '50t' : '25t');
      expect(value('BI4'), id.contains('50t') ? '15号機' : '1号機');
      expect(value('A3'), RoughTerrainCrane.starLegend);
      final zip = ZipDecoder().decodeBytes(bytes);
      final sheetXml = utf8.decode(
        zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
      );
      expect(sheetXml, contains('orientation="landscape"'));
      expect(
        XmlDocument.parse(sheetXml).rootElement.findElements('pageMargins'),
        hasLength(1),
      );
      expect(
        XmlDocument.parse(
          utf8.decode(zip.findFile('xl/workbook.xml')!.content as List<int>),
        ).rootElement.findElements('definedNames'),
        hasLength(1),
      );
      expect(sheetXml, contains('fitToHeight="1"'));
      expect(
        utf8.decode(zip.findFile('xl/workbook.xml')!.content as List<int>),
        contains(r'$A$1:$BQ$31'),
      );
      final dir = const String.fromEnvironment('REPORT_OUTPUT');
      if (dir.isNotEmpty) {
        Directory(dir).createSync(recursive: true);
        File('$dir/$id.xlsx').writeAsBytesSync(bytes);
      }
    }
  });

  test('30台・数値順・ラフターは画面表示時の自動補完対象外', () async {
    expect(await service.ensureAllModelsHaveInitialTenUnits(), 0);
    final machines = await service.getMachines();
    expect(machines, hasLength(30));
    for (final model in ['25t', '50t']) {
      final labels = RoughTerrainCrane.sortedUnits(
        machines
            .where((m) => m.model == model)
            .map((m) => m.unitNumber)
            .toList()
            .reversed,
      );
      expect(labels, [for (var n = 1; n <= 15; n++) '$n号機']);
    }
    await db.doc('machines/rtc_25t_01').delete();
    expect(await service.ensureAllModelsHaveInitialTenUnits(), 0);
  });

  test('14件未満・未点検・誤ったキーでは保存しない', () async {
    final machine = (await service.getMachineById('rtc_25t_01'))!;
    expect(
      await service.saveInspection(
        siteName: '検証',
        inspectorName: '検証',
        machineId: machine.id,
        machineTypeId: rtc,
        machineType: machine.type,
        machineModel: machine.model,
        machineUnitNumber: machine.unitNumber,
        date: DateTime(2026, 10, 1),
        results: {},
      ),
      isFalse,
    );
    await db.doc('machine_types/$rtc/items/rtc_14').delete();
    await expectLater(service.getInspectionItems(rtc), throwsStateError);
    expect((await db.collection('inspections').get()).docs, isEmpty);
  });

  test('orderのない既存機種・過去記録と帳票を維持', () async {
    await db.doc('machines/old-machine-id').set({
      'type': '油圧ショベル',
      'typeId': 'excavator',
      'model': '既存型式',
      'unitNumber': '1号機',
      'isActive': true,
      'sortOrder': 1,
    });
    await db.doc('machine_types/excavator/items/item_01').set({
      'name': '既存項目',
      'checkpoint': '既存ポイント',
      'isRequired': true,
    });
    final items = await service.getInspectionItems('excavator');
    expect(items.single.name, '既存項目');
    await db.doc('inspections/old-record-id').set({
      'machineId': 'old-machine-id',
      'date': '2024-10-01',
      'machineTypeId': 'excavator',
      'results': {
        'item_01': {'itemCode': 'item_01', 'isGood': false, 'memo': '既存メモ'},
      },
    });
    final machines = await service.getMachines();
    expect(machines.first.id, 'old-machine-id');
    expect((await service.getInspections()).single['id'], 'old-record-id');
    List<int>? bytes;
    expect(
      await WebExcelService.generateMonthlyReport(
        machineId: 'old-machine-id',
        year: 2024,
        month: 10,
        dataSource: service,
        output: (data, name) => bytes = data,
      ),
      isNotNull,
    );
    final sheet = Excel.decodeBytes(bytes!)['月次点検表'];
    expect(sheet.cell(CellIndex.indexByString('AM10')).value.toString(), '×');
    expect(
      sheet.cell(CellIndex.indexByString('A3')).value.toString(),
      '・★は法的要求事項',
    );
    expect(
      (await db.doc('inspections/old-record-id').get())
          .data()!['results']['item_01']['memo'],
      '既存メモ',
    );
  });

  test('変更前mainの油圧ショベル帳票と全OOXMLが一致', () {
    // Fixture hashes were generated with the unchanged abe0165 WebExcelService.
    final machine = Machine(
      id: 'old',
      type: '油圧ショベル',
      typeId: 'excavator',
      model: '既存型式',
      unitNumber: '1号機',
    );
    final items = [
      InspectionItem(
        code: 'item_01',
        name: '既存項目',
        checkPoint: '既存ポイント',
        isRequired: true,
      ),
    ];
    final records = [
      InspectionRecord(
        id: 'old-record',
        siteName: '検証工事',
        inspectorName: '確認 太郎',
        machineId: 'old',
        machineType: '油圧ショベル',
        machineModel: '既存型式',
        machineUnitNumber: '1号機',
        inspectionDate: DateTime(2024, 10, 1),
        results: {
          'item_01': InspectionResult(
            itemCode: 'item_01',
            isGood: false,
            memo: '既存メモ',
          ),
        },
      ),
    ];
    final workbook = WebExcelService.buildMonthlyWorkbook(
      machine: machine,
      items: items,
      monthRecords: records,
      year: 2024,
      month: 10,
      siteName: '検証工事',
    );
    final archive = ZipDecoder().decodeBytes(
      WebExcelService.encodeWorkbook(workbook, roughTerrain: false),
    );
    final expected = jsonDecode(
      File('test/fixtures/legacy_workbook_parts.json').readAsStringSync(),
    );
    expect({
      for (final f in archive.files)
        f.name: sha256.convert(f.content as List<int>).toString(),
    }, expected);
  });

  testWidgets('選択画面の両能力区分で1～15号機を数値順表示', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MachineSelectionScreenV2(
          siteName: '検証',
          inspectorName: '確認',
          dataSource: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    var fields = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList();
    // Dropdownのコールバック経由で能力を選び、実表示用itemsを確認する。
    fields[0].onChanged!('ラフタークレーン');
    await tester.pumpAndSettle();
    for (final model in ['25t', '50t']) {
      fields = tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .toList();
      fields[1].onChanged!(model);
      await tester.pumpAndSettle();
      final dropdowns = tester
          .widgetList<DropdownButton<String>>(
            find.byType(DropdownButton<String>),
          )
          .toList();
      expect(dropdowns[2].items!.map((i) => i.value).toList(), [
        for (var i = 1; i <= 15; i++) '$i号機',
      ]);
    }
  });

  testWidgets('読込失敗画面から保存・一括良好はできない', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await db.doc('machine_types/$rtc/items/rtc_14').delete();
    final machine = (await service.getMachineById('rtc_25t_01'))!;
    await tester.pumpWidget(
      MaterialApp(
        home: InspectionInputScreen(
          siteName: '検証',
          inspectorName: '確認',
          machine: machine,
          dataSource: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('点検項目を読み込めません。保存できません。'), findsOneWidget);
    expect(find.text('点検結果を保存'), findsNothing);
    expect(find.text('未入力項目を一括で「⚪」にする'), findsNothing);
  });

  testWidgets('25t入力は明示操作で14件良好にして保存、50t詳細はメモ・不良を表示', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final machine = (await service.getMachineById('rtc_25t_01'))!;
    await tester.pumpWidget(
      MaterialApp(
        home: InspectionInputScreen(
          siteName: '検証工事',
          inspectorName: '確認',
          machine: machine,
          dataSource: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 / 14'), findsOneWidget);
    await tester.tap(find.text('未入力項目を一括で「⚪」にする'));
    await tester.pumpAndSettle();
    expect(find.text('14 / 14'), findsOneWidget);
    await tester.tap(find.text('点検結果を保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存完了'), findsOneWidget);
    expect((await service.getInspections()).single['results'].length, 14);
    await save('rtc_50t_15', badRope: true);
    final data = (await service.getInspections()).firstWhere(
      (r) => r['machineId'] == 'rtc_50t_15',
    );
    final record = InspectionRecord.fromMap({
      ...data,
      'inspectionDate': data['date'],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(record: record, dataSource: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ウインチロープ・シーブ'), 400);
    expect(find.text('× 不良'), findsOneWidget);
    expect(find.text('断線を確認。使用中止し責任者へ報告。'), findsOneWidget);
  });
}
