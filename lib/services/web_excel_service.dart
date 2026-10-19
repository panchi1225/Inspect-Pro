import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/machine.dart';
import '../data/rough_terrain_crane.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/inspection_record.dart';
import '../models/inspection_item.dart';
import 'firestore_service.dart';

// 条件付きimport: Web/Mobile別のExcelダウンロード実装
import 'excel_download_stub.dart'
    if (dart.library.html) 'excel_download_web.dart'
    if (dart.library.io) 'excel_download_mobile.dart';

/// Web専用のExcel生成サービス（テンプレート方式）
class WebExcelService {
  /// 月次点検レポートをExcelで生成（テンプレート使用）
  static Future<String?> generateMonthlyReport({
    required String machineId,
    required int year,
    required int month,
    String? siteName,
    String? companyName,
    String? responsiblePerson,
    String? primeContractorInspector,
    FirestoreService? dataSource,
    void Function(List<int> bytes, String fileName)? output,
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 Web Excel生成開始（テンプレート方式）');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final firestoreService = dataSource ?? FirestoreService();
      
      // 1. 重機情報を取得
      final machine = await firestoreService.getMachineById(machineId);
      if (machine == null) {
        print('❌ エラー: 重機が見つかりません (ID: $machineId)');
        return null;
      }
      print('✅ 重機: ${machine.type} ${machine.model} ${machine.unitNumber}');

      // 2. 点検記録を取得
      final inspectionData = await firestoreService.getMonthlyInspections(
        machineId: machineId, year: year, month: month);
      final allRecords = inspectionData.map((data) {
        return InspectionRecord(
          id: data['id'] ?? '',
          siteName: data['siteName'] ?? '',
          inspectorName: data['inspectorName'] ?? '',
          machineId: data['machineId'] ?? '',
          machineType: data['machineType'] ?? '',
          machineModel: data['machineModel'] ?? '',
          machineUnitNumber: data['machineUnitNumber'] ?? '',
          inspectionDate: _parseDate(data['date']),
          machineTypeId: data['machineTypeId'] ?? '',
          results: (data['results'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              InspectionResult.fromMap(value as Map<String, dynamic>),
            ),
          ) ?? {},
        );
      }).toList();
      
      final monthRecords = allRecords.where((r) {
        return r.machineId == machineId &&
            r.inspectionDate.year == year &&
            r.inspectionDate.month == month &&
            (siteName == null || siteName.isEmpty || r.siteName == siteName);
      }).toList();
      
      // 日付順にソート
      monthRecords.sort((a, b) => a.inspectionDate.compareTo(b.inspectionDate));
      
      print('✅ 対象月の記録数: ${monthRecords.length}件');

      // 3. 点検項目を取得
      if (machine.typeId == null) {
        print('❌ エラー: 重機のtypeIdがありません');
        return null;
      }
      final items = await firestoreService.getInspectionItems(machine.typeId!);
      print('✅ 点検項目数: ${items.length}項目');

      final excel = buildMonthlyWorkbook(machine: machine, items: items,
        monthRecords: monthRecords, year: year, month: month, siteName: siteName,
        companyName: companyName, responsiblePerson: responsiblePerson,
        primeContractorInspector: primeContractorInspector);
      final fileBytes = encodeWorkbook(excel,
        roughTerrain: machine.typeId == RoughTerrainCrane.typeId);

      String fileName = machine.typeId == RoughTerrainCrane.typeId
          ? '$year年$month月_${machine.type}_${machine.model}_${machine.unitNumber}.xlsx'
          : '${month}月度_${machine.type}_${machine.unitNumber}.xlsx';
      if (output != null) { output(fileBytes, fileName); return fileName; }

      if (kIsWeb) {
        downloadExcelWeb(fileBytes, fileName);
        print('✅ Webダウンロード開始: $fileName');
        return fileName;
      } else {
        print('❌ この機能はWeb専用です');
        return null;
      }

    } catch (e, stackTrace) {
      print('❌ Excel生成エラー: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Web出力とテストが共用する帳票生成。取得・保存方式は呼出元で扱う。
  static Excel buildMonthlyWorkbook({
    required Machine machine, required List<InspectionItem> items,
    required List<InspectionRecord> monthRecords, required int year, required int month,
    String? siteName, String? companyName, String? responsiblePerson,
    String? primeContractorInspector,
  }) {
    final roughTerrain = machine.typeId == RoughTerrainCrane.typeId;
    if (roughTerrain) items = RoughTerrainCrane.validateItems(items);
    if (items.isEmpty) throw StateError('点検項目を取得できません');
      // 4. テンプレートExcelを読み込み
      print('📄 テンプレート読み込み開始');
      
      // アップロードされたテンプレートファイルを読み込み
      // Web環境では直接ファイルアクセスできないため、assetsに配置する必要があります
      // 今回はテンプレートを使わず、詳細な書式設定で生成します
      
      var excel = Excel.createExcel();
      // デフォルトシートの名前を変更
      if (excel.tables.containsKey('Sheet1')) {
        excel.rename('Sheet1', '月次点検表');
      }
      Sheet sheet = excel['月次点検表'];
      
      print('✅ 新規Excel作成');
      
      // ========================================
      // 5. 列幅設定（ピクセル ÷ 7 ≈ Excel単位）
      // ========================================
      sheet.setColumnWidth(0, 36 / 7);        // A列: 36px
      for (int i = 1; i <= 36; i++) {         // B～AK列: 24px
        sheet.setColumnWidth(i, 24 / 7);
      }
      sheet.setColumnWidth(37, 48 / 7);       // AL列: 48px
      for (int i = 38; i < 100; i++) {        // AM列以降: 32px
        sheet.setColumnWidth(i, 32 / 7);
      }
      
      // ========================================
      // 6. 行の高さ設定（ピクセル * 0.75 = Excel単位）
      // ========================================
      for (int i = 0; i <= 3; i++) {          // 1～4行: 31px
        sheet.setRowHeight(i, 31 * 0.75);
      }
      sheet.setRowHeight(4, 58 * 0.75);       // 5行: 58px
      sheet.setRowHeight(5, 24 * 0.75);       // 6行: 24px
      sheet.setRowHeight(6, 42 * 0.75);       // 7行: 42px
      sheet.setRowHeight(7, 11 * 0.75);       // 8行: 11px
      for (int i = 8; i <= 25; i++) {         // 9～26行: 42px
        sheet.setRowHeight(i, 42 * 0.75);
      }
      sheet.setRowHeight(26, 96 * 0.75);      // 27行: 96px
      for (int i = 27; i <= 30; i++) {        // 28～31行: 49px
        sheet.setRowHeight(i, 49 * 0.75);
      }
      sheet.setRowHeight(29, 65 * 0.75);      // 30行: 65px
      sheet.setRowHeight(30, 65 * 0.75);      // 31行: 65px
      
      // ========================================
      // 7. 基本情報の入力
      // ========================================
      
      // A1: 「工事名」
      _setCell(sheet, 'A1', '工事名', fontSize: 18, bold: true);
      
      // D1とE1を結合して「：」
      sheet.merge(CellIndex.indexByString('D1'), CellIndex.indexByString('E1'));
      _setCell(sheet, 'D1', '：', fontSize: 18, hAlign: HorizontalAlign.Center);
      
      // F1: 工事名（現場名）
      _setCell(sheet, 'F1', siteName ?? '', fontSize: 18);
      
      // A2: 削除（年月は記載しない）
      // _setCell(sheet, 'A2', '$year年$month月', fontSize: 14);
      
      // A3: ・★は法的要求事項（J3から移動）
      _setCell(sheet, 'A3', '・★は法的要求事項', fontSize: 14);
      
      // A4: ・その他は点検すべき事項とみなした箇所（J4から移動）
      _setCell(sheet, 'A4', '・その他は点検すべき事項とみなした箇所', fontSize: 14);
      
      // R3, R4: 機械種類ごとの法令記載
      final machineType = machine.type;
      if (!roughTerrain && (machineType == '油圧ショベル' ||
          machineType == 'ブルドーザー' || 
          machineType == 'タイヤショベル' || 
          machineType == 'コンバインドローラー' || 
          machineType == '振動ローラー' || 
          machineType == 'タイヤローラー')) {
        // R3: 【安衛則 第170条】
        _setCell(sheet, 'R3', '【安衛則 第170条】', fontSize: 14);
      } else if (machineType == '不整地運搬車') {
        // R3: 【安衛則 第151条57】
        _setCell(sheet, 'R3', '【安衛則 第151条57】', fontSize: 14);
      }
      
      if (!roughTerrain && machineType == '油圧ショベル') {
        // R4: 【クレーン則 第78条】
        _setCell(sheet, 'R4', '【クレーン則 第78条】', fontSize: 14);
      }
      
      // J3, J4は削除（A3, A4に移動したため）
      // _setCell(sheet, 'J3', '・★は法的要求事項', fontSize: 14);
      // _setCell(sheet, 'J4', '・その他は点検すべき事項とみなした箇所', fontSize: 14);
      
      // A5: 月度 機械名 作業開始前点検表
      _setCell(sheet, 'A5', '${month}月度　${machine.type}　作業開始前点検表', 
        fontSize: 24, bold: true, italic: true, vAlign: VerticalAlign.Bottom);
      
      // A7: 注意事項（下線は罫線処理後に設定）
      var a7Cell = sheet.cell(CellIndex.indexByString('A7'));
      a7Cell.value = TextCellValue('※点検時、作業時問わず異常を認めたときは、元請点検責任者に報告及び速やかに補修その他必要な措置を取ること');
      
      // AM3～AW3: 所有会社名ラベル（太字）
      sheet.merge(CellIndex.indexByString('AM3'), CellIndex.indexByString('AW3'));
      _setCell(sheet, 'AM3', '所有会社名', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      // AX3～BD3: 取扱責任者（点検者）ラベル（太字）
      sheet.merge(CellIndex.indexByString('AX3'), CellIndex.indexByString('BD3'));
      _setCell(sheet, 'AX3', '取扱責任者（点検者）', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      // BE3～BH3: 型式ラベル（太字）
      sheet.merge(CellIndex.indexByString('BE3'), CellIndex.indexByString('BH3'));
      _setCell(sheet, 'BE3', '型式', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      // BI3～BL3: 機械番号ラベル（太字）
      sheet.merge(CellIndex.indexByString('BI3'), CellIndex.indexByString('BL3'));
      _setCell(sheet, 'BI3', '機械番号', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      // BN3～BQ3: 作業所長確認ラベル（太字）
      sheet.merge(CellIndex.indexByString('BN3'), CellIndex.indexByString('BQ3'));
      _setCell(sheet, 'BN3', '作業所長確認', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      // AM4～AW5: 所有会社名入力（太字解除）
      sheet.merge(CellIndex.indexByString('AM4'), CellIndex.indexByString('AW5'));
      _setCell(sheet, 'AM4', companyName ?? '', fontSize: 14, hAlign: HorizontalAlign.Center);
      
      // AX4～BD5: 取扱責任者（点検者）入力（太字解除）
      sheet.merge(CellIndex.indexByString('AX4'), CellIndex.indexByString('BD5'));
      _setCell(sheet, 'AX4', responsiblePerson ?? '', fontSize: 14, hAlign: HorizontalAlign.Center);
      
      // BE4～BH5: 型式入力（太字解除）
      sheet.merge(CellIndex.indexByString('BE4'), CellIndex.indexByString('BH5'));
      _setCell(sheet, 'BE4', machine.model, fontSize: 14, hAlign: HorizontalAlign.Center);
      
      // BI4～BL5: 号機入力（太字解除）
      sheet.merge(CellIndex.indexByString('BI4'), CellIndex.indexByString('BL5'));
      _setCell(sheet, 'BI4', machine.unitNumber, fontSize: 14, hAlign: HorizontalAlign.Center);
      
      // BN4～BQ5: 作業所長確認欄（太字解除）
      sheet.merge(CellIndex.indexByString('BN4'), CellIndex.indexByString('BQ5'));
      
      // ========================================
      // 8. 点検項目ヘッダー（9行目）
      // ========================================
      
      // A9～Q9: 点検項目（中央配置）
      _setCell(sheet, 'A9', '点検項目', fontSize: 14, bold: true, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center, bgColor: '#D3D3D3');
      sheet.merge(CellIndex.indexByString('A9'), CellIndex.indexByString('Q9'));
      
      // R9～AL9: 点検ポイント（中央配置）
      _setCell(sheet, 'R9', '点検ポイント', fontSize: 14, bold: true, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center, bgColor: '#D3D3D3');
      sheet.merge(CellIndex.indexByString('R9'), CellIndex.indexByString('AL9'));
      
      // ========================================
      // 9. 点検項目の入力（A10～A23: ★、B10～B23: 項目名、R10～R23: 点検ポイント）
      // ========================================
      int row = 10;
      for (var item in items) {
        if (row > 23) break;
        
        // A列: ★（法的要求事項の場合）
        if (item.isRequired) {
          _setCell(sheet, 'A$row', '★', fontSize: 14, bold: true, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center);
        }
        
        // B列: 項目名
        _setCell(sheet, 'B$row', item.name, fontSize: 14);
        
        // R列: 点検ポイント
        _setCell(sheet, 'R$row', item.checkPoint, fontSize: 14);
        
        row++;
      }
      
      // ========================================
      // 9. 日付列と点検結果（AM9～BQ23）
      // ========================================
      int daysInMonth = DateTime(year, month + 1, 0).day;
      
      for (int day = 1; day <= daysInMonth; day++) {
        String colName = _getColumnName(38 + day - 1); // AM列から開始
        
        // デバッグ: 最初の日付ヘッダーをログ出力
        if (day == 1) {
          print('🔍 日付ヘッダー最初のセル: ${colName}9 (day=$day)');
        }
        
        // 日付ヘッダー（9行目） - 太字、中央配置、薄いグレー背景
        _setCell(sheet, '${colName}9', day.toString(), fontSize: 11, bold: true, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center,
          bgColor: '#D3D3D3');
        
        // この日の点検記録を探す
        var dayRecord = monthRecords.where((r) => r.inspectionDate.day == day).toList();
        
        if (dayRecord.isNotEmpty) {
          var record = dayRecord.first;
          
          // 点検者名（24～26行結合、横書き）
          sheet.merge(CellIndex.indexByString('${colName}24'), CellIndex.indexByString('${colName}26'));
          _setCell(sheet, '${colName}24', record.inspectorName, fontSize: 9, hAlign: HorizontalAlign.Center);
          
          // 点検結果（10～23行）
          int resultRow = 10;
          for (var item in items) {
            if (resultRow > 23) break;
            
            String value = roughTerrain ? '未' : '-';
            String? bgColorHex;
            if (record.results.containsKey(item.code)) {
              bool isGood = record.results[item.code]!.isGood;
              value = isGood ? '○' : '×';
              // 文字は黒、背景色を明るい黄緑（○）またはピンク（×）に
              bgColorHex = isGood ? '#D4ED91' : '#FFE6F0';
            }
            
            _setCell(sheet, '$colName$resultRow', value, 
              fontSize: 10, bold: true, hAlign: HorizontalAlign.Center, bgColor: bgColorHex);
            
            resultRow++;
          }
        }
      }
      
      // ========================================
      // 10. 24～26行（点検時の注記）
      // ========================================
      _setCell(sheet, 'A24', '１．点検時', fontSize: 14, vAlign: VerticalAlign.Center);
      _setCell(sheet, 'B25', 'チェック記号', fontSize: 14);
      _setCell(sheet, 'AK27', '元請点検\n責任者\n確認欄', fontSize: 9, hAlign: HorizontalAlign.Center);
    sheet.cell(CellIndex.indexByString('AK27')).cellStyle!.wrap = TextWrapping.WrapText;
    _setCell(sheet, 'BL28', '元請点検\n責任者', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
    sheet.cell(CellIndex.indexByString('BL28')).cellStyle!.wrap = TextWrapping.WrapText;
    _setCell(sheet, 'J24', '良好…○　要調整、修理…×（使用禁止）　・該当なし…－', fontSize: 14);
      _setCell(sheet, 'J25', '調整または補修したとき…×を○で囲む', fontSize: 14);
      _setCell(sheet, 'A26', '２．元請点検責任者は毎月上旬・中旬・下旬毎に１回は点検状況を確認すること。', fontSize: 14, vAlign: VerticalAlign.Center);
      
      // AL24～AL26: 点検者ラベル（横書き）
      sheet.merge(CellIndex.indexByString('AL24'), CellIndex.indexByString('AL26'));
      _setCell(sheet, 'AL24', '点検者', fontSize: 12, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center);
      
      // ========================================
      // 11. 27～31行（補修情報エリア）
      // ========================================
      
      // A27～AJ31: 重機画像エリア
      sheet.merge(CellIndex.indexByString('A27'), CellIndex.indexByString('AJ31'));
      _setCell(sheet, 'A27', '※重機画像添付※', fontSize: 14, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center);
      
      // AK27～AL27: 元請点検責任者確認欄（文字サイズ10）
      sheet.merge(CellIndex.indexByString('AK27'), CellIndex.indexByString('AL27'));
      _setCell(sheet, 'AK27', '元請点検\n責任者\n確認欄', fontSize: 10, hAlign: HorizontalAlign.Center);
      
      // AM27～AT27, AW27～BD27, BG27～BO27の結合と元請点検責任者の自動記載
      sheet.merge(CellIndex.indexByString('AM27'), CellIndex.indexByString('AT27'));
      _setCell(sheet, 'AM27', primeContractorInspector ?? '', fontSize: 14, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center);
      
      sheet.merge(CellIndex.indexByString('AW27'), CellIndex.indexByString('BD27'));
      _setCell(sheet, 'AW27', primeContractorInspector ?? '', fontSize: 14, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center);
      
      sheet.merge(CellIndex.indexByString('BG27'), CellIndex.indexByString('BO27'));
      _setCell(sheet, 'BG27', primeContractorInspector ?? '', fontSize: 14, hAlign: HorizontalAlign.Center, vAlign: VerticalAlign.Center);
      
      // 28行: 補修情報ヘッダー（太字）
      sheet.merge(CellIndex.indexByString('AK28'), CellIndex.indexByString('BE28'));
      _setCell(sheet, 'AK28', '補修内容', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      sheet.merge(CellIndex.indexByString('BF28'), CellIndex.indexByString('BH28'));
      _setCell(sheet, 'BF28', '補修日', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      sheet.merge(CellIndex.indexByString('BI28'), CellIndex.indexByString('BK28'));
      _setCell(sheet, 'BI28', '補修者', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      sheet.merge(CellIndex.indexByString('BL28'), CellIndex.indexByString('BN28'));
      _setCell(sheet, 'BL28', '元請点検\n責任者', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      sheet.merge(CellIndex.indexByString('BO28'), CellIndex.indexByString('BQ28'));
      _setCell(sheet, 'BO28', '作業所長', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
      
      // 29～31行: 補修情報入力欄
      sheet.merge(CellIndex.indexByString('AK29'), CellIndex.indexByString('BE29'));
      sheet.merge(CellIndex.indexByString('BF29'), CellIndex.indexByString('BH29'));
      sheet.merge(CellIndex.indexByString('BI29'), CellIndex.indexByString('BK29'));
      sheet.merge(CellIndex.indexByString('BL29'), CellIndex.indexByString('BN29'));
      sheet.merge(CellIndex.indexByString('BO29'), CellIndex.indexByString('BQ29'));
      
      sheet.merge(CellIndex.indexByString('AK30'), CellIndex.indexByString('BE30'));
      sheet.merge(CellIndex.indexByString('BF30'), CellIndex.indexByString('BH30'));
      sheet.merge(CellIndex.indexByString('BI30'), CellIndex.indexByString('BK30'));
      sheet.merge(CellIndex.indexByString('BL30'), CellIndex.indexByString('BN30'));
      sheet.merge(CellIndex.indexByString('BO30'), CellIndex.indexByString('BQ30'));
      
      sheet.merge(CellIndex.indexByString('AK31'), CellIndex.indexByString('BE31'));
      sheet.merge(CellIndex.indexByString('BF31'), CellIndex.indexByString('BH31'));
      sheet.merge(CellIndex.indexByString('BI31'), CellIndex.indexByString('BK31'));
      sheet.merge(CellIndex.indexByString('BL31'), CellIndex.indexByString('BN31'));
      sheet.merge(CellIndex.indexByString('BO31'), CellIndex.indexByString('BQ31'));
      
      // ========================================
      // 12. 罫線の追加（指示に従って実装）
      // ========================================
      _addAllBorders(sheet);
      
      // ========================================
      // 13. A7セルのスタイル設定（罫線処理後に実行）
      // ========================================
      var a7CellFinal = sheet.cell(CellIndex.indexByString('A7'));
      a7CellFinal.cellStyle = CellStyle(
        fontFamily: 'HG明朝E',
        fontSize: 12,
        bold: false,
        underline: Underline.Single,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Bottom,
      );
      
      print('✅ A7セル設定完了（罫線処理後）');
      print('   underline: ${a7CellFinal.cellStyle?.underline}');
      print('   bold: ${a7CellFinal.cellStyle?.isBold}');
      print('   fontSize: ${a7CellFinal.cellStyle?.fontSize}');
      
      print('✅ Excel生成完了');
      
      if (roughTerrain) _formatRoughTerrain(sheet, year, month);
      return excel;
  }

  static List<int> encodeWorkbook(Excel excel, {required bool roughTerrain}) {
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Excelの生成に失敗しました');
    if (!roughTerrain) return bytes;
    // excel 4.xには印刷設定APIがないため、生成したOOXMLに印刷設定を追加する。
    final archive = ZipDecoder().decodeBytes(bytes);
    final result = Archive();
    for (final file in archive.files) {
      var content = file.content as List<int>;
      if (file.name == 'xl/worksheets/sheet1.xml') {
        final xml = XmlDocument.parse(utf8.decode(content));
        final root = xml.rootElement;
        final props = root.getElement('sheetPr') ?? XmlElement(XmlName('sheetPr'));
        if (props.parent == null) root.children.insert(0, props);
        final fit = props.getElement('pageSetUpPr') ?? XmlElement(XmlName('pageSetUpPr'));
        fit.setAttribute('fitToPage', '1');
        if (fit.parent == null) props.children.add(fit);
        final margins = root.getElement('pageMargins') ?? XmlElement(XmlName('pageMargins'));
        for (final key in ['left', 'right', 'top', 'bottom']) {
          margins.setAttribute(key, '0.2');
        }
        margins.setAttribute('header', '0'); margins.setAttribute('footer', '0');
        if (margins.parent == null) root.children.add(margins);
        final setup = root.getElement('pageSetup') ?? XmlElement(XmlName('pageSetup'));
        for (final entry in {'paperSize': '9', 'orientation': 'landscape',
          'fitToWidth': '1', 'fitToHeight': '1'}.entries) {
          setup.setAttribute(entry.key, entry.value);
        }
        if (setup.parent == null) root.children.add(setup);
        content = utf8.encode(xml.toXmlString());
      } else if (file.name == 'xl/workbook.xml') {
        final xml = XmlDocument.parse(utf8.decode(content));
        final root = xml.rootElement;
        final names = root.getElement('definedNames') ?? XmlElement(XmlName('definedNames'));
        names.children.add(XmlElement(XmlName('definedName'), [
          XmlAttribute(XmlName('name'), '_xlnm.Print_Area'),
          XmlAttribute(XmlName('localSheetId'), '0')], [XmlText("'月次点検表'!\$A\$1:\$BQ\$31")]));
        if (names.parent == null) {
          final calc = root.getElement('calcPr');
          if (calc == null) { root.children.add(names); }
          else { root.children.insert(root.children.indexOf(calc), names); }
        }
        content = utf8.encode(xml.toXmlString());
      }
      result.addFile(ArchiveFile(file.name, content.length, content));
    }
    return ZipEncoder().encode(result)!;
  }

  static void _formatRoughTerrain(Sheet sheet, int year, int month) {
    void merge(String from, String to) => sheet.merge(
      CellIndex.indexByString(from), CellIndex.indexByString(to));
    merge('F1', 'BQ1');
    merge('A3', 'AL3'); merge('A4', 'AL4');
    _setCell(sheet, 'A3', RoughTerrainCrane.starLegend, fontSize: 14);
    _setCell(sheet, 'A4', RoughTerrainCrane.additionalLegend, fontSize: 14);
    merge('A5', 'AL5');
    _setCell(sheet, 'A5', '$year年$month月度 ラフタークレーン 作業開始前点検表', fontSize: 20, bold: true);
    merge('A6', 'BQ6');
    _setCell(sheet, 'A6', '日常点検の月次集計（クレーン則第78条）。月例自主検査の代替ではありません。', fontSize: 12);
    merge('A7', 'BQ7');
    _setCell(sheet, 'A7', '異常時は使用中止・責任者へ報告し補修等を実施（第80条）。記録の保存は使用許可ではありません。', fontSize: 12);
    for (var row = 10; row <= 23; row++) {
      merge('B$row', 'Q$row'); merge('R$row', 'AL$row');
      // 結合後に下辺全体へ罫線を戻す（Excelでは左上セルだけの罫線は延長されない）。
      for (var col = 1; col <= 37; col++) {
        _addBorder(sheet, col, row - 1, bottom: true);
      }
      for (final col in ['B', 'R']) {
        final cell = sheet.cell(CellIndex.indexByString('$col$row'));
        cell.cellStyle!.wrap = TextWrapping.WrapText;
      }
    }
    // 複数行の長い氏名も列外へはみ出さない。
    for (var col = 38; col <= 68; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 23));
      cell.cellStyle ??= CellStyle();
      cell.cellStyle!.wrap = TextWrapping.WrapText;
    }
    merge('A24', 'H24'); merge('B25', 'H25');
    merge('J24', 'AK24'); merge('J25', 'AK25'); merge('A26', 'AK26');
    _setCell(sheet, 'AK27', '元請点検\n責任者\n確認欄', fontSize: 9, hAlign: HorizontalAlign.Center);
    sheet.cell(CellIndex.indexByString('AK27')).cellStyle!.wrap = TextWrapping.WrapText;
    _setCell(sheet, 'BL28', '元請点検\n責任者', fontSize: 11, bold: true, hAlign: HorizontalAlign.Center);
    sheet.cell(CellIndex.indexByString('BL28')).cellStyle!.wrap = TextWrapping.WrapText;
    _setCell(sheet, 'J24', '良好：○  不良：×（使用禁止）  空欄：記録なし', fontSize: 12);
    _setCell(sheet, 'J25', '未：未点検。非装備部分と未点検は区別し、14項目すべて確認。', fontSize: 11);
  }

  /// セルに値とスタイルを設定
  static void _setCell(
    Sheet sheet,
    String cellAddress,
    String value, {
    int fontSize = 14,
    bool bold = false,
    bool italic = false,
    bool underline = false,
    HorizontalAlign? hAlign,
    VerticalAlign? vAlign,
    String? fontColor,
    String? bgColor,
  }) {
    var cell = sheet.cell(CellIndex.indexByString(cellAddress));
    cell.value = TextCellValue(value);
    
    // デバッグログ: 詳細なパラメータ確認
    if (cellAddress == 'A9' || cellAddress == 'R9' || cellAddress == 'A24' || cellAddress == 'A26') {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔍 _setCell呼び出し: セル=$cellAddress');
      print('   値: $value');
      print('   fontSize: $fontSize');
      print('   bold: $bold');
      print('   hAlign: $hAlign');
      print('   vAlign: $vAlign');
      print('   fontColor: $fontColor');
      print('   bgColor: $bgColor');
    }
    CellStyle style;
    
    if (fontColor != null && bgColor != null) {
      style = CellStyle(
        fontFamily: 'HG明朝E',
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        underline: underline ? Underline.Single : Underline.None,
        horizontalAlign: hAlign ?? HorizontalAlign.Left,
        verticalAlign: vAlign ?? VerticalAlign.Center,
        fontColorHex: ExcelColor.fromHexString(fontColor),
        backgroundColorHex: ExcelColor.fromHexString(bgColor),
      );
    } else if (fontColor != null) {
      style = CellStyle(
        fontFamily: 'HG明朝E',
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        underline: underline ? Underline.Single : Underline.None,
        horizontalAlign: hAlign ?? HorizontalAlign.Left,
        verticalAlign: vAlign ?? VerticalAlign.Center,
        fontColorHex: ExcelColor.fromHexString(fontColor),
      );
    } else if (bgColor != null) {
      style = CellStyle(
        fontFamily: 'HG明朝E',
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        underline: underline ? Underline.Single : Underline.None,
        horizontalAlign: hAlign ?? HorizontalAlign.Left,
        verticalAlign: vAlign ?? VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString(bgColor),
      );
    } else {
      style = CellStyle(
        fontFamily: 'HG明朝E',
        fontSize: fontSize,
        bold: bold,
        italic: italic,
        underline: underline ? Underline.Single : Underline.None,
        horizontalAlign: hAlign ?? HorizontalAlign.Left,
        verticalAlign: vAlign ?? VerticalAlign.Center,
      );
    }
    
    cell.cellStyle = style;
    
    // デバッグ: 特定セルのフォント確認
    if (cellAddress == 'A9' || cellAddress == 'R9' || cellAddress == 'A24' || cellAddress == 'A26' || cellAddress == 'A7') {
      print('✅ セル$cellAddress CellStyle作成完了');
      print('   style.fontFamily: ${style.fontFamily}');
      print('   style.fontSize: ${style.fontSize}');
      print('   style.bold: ${style.isBold}');
      print('   style.underline: ${style.underline}');
      print('   style.horizontalAlign: ${style.horizontalAlignment}');
      print('   style.verticalAlign: ${style.verticalAlignment}');
      print('   cell.cellStyle.fontFamily: ${cell.cellStyle?.fontFamily}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }
  
  /// 列名を取得（0-indexed → 列名）
  static String _getColumnName(int colIndex) {
    String name = '';
    colIndex += 1;
    while (colIndex > 0) {
      colIndex -= 1;
      name = String.fromCharCode(colIndex % 26 + 65) + name;
      colIndex ~/= 26;
    }
    return name;
  }
  
  /// 罫線を追加
  static void _addAllBorders(Sheet sheet) {
    // ========================================
    // 既存の罫線
    // ========================================
    
    // A9～BQ9の上部に罫線
    for (int col = 0; col <= 68; col++) {
      _addBorder(sheet, col, 8, top: true);
    }
    
    // A9～A31の左側に罫線
    for (int row = 8; row <= 30; row++) {
      _addBorder(sheet, 0, row, left: true);
    }
    
    // A31～BQ31の下部に罫線
    for (int col = 0; col <= 68; col++) {
      _addBorder(sheet, col, 30, bottom: true);
    }
    
    // BQ9～BQ31の右側に罫線
    for (int row = 8; row <= 30; row++) {
      _addBorder(sheet, 68, row, right: true);
    }
    
    // ========================================
    // 新規追加の罫線
    // ========================================
    
    // A3、A4セルの左に罫線
    _addBorder(sheet, 0, 2, left: true);  // A3 (row index 2)
    _addBorder(sheet, 0, 3, left: true);  // A4 (row index 3)
    
    // A3～Z3までのセルの上部に罫線 (col 0-25)
    for (int col = 0; col <= 25; col++) {
      _addBorder(sheet, col, 2, top: true);
    }
    
    // A4～Z4までのセルの下部に罫線 (col 0-25)
    for (int col = 0; col <= 25; col++) {
      _addBorder(sheet, col, 3, bottom: true);
    }
    
    // AM3～AM5までのセルの左に罫線 (AM=col 38, rows 2-4)
    for (int row = 2; row <= 4; row++) {
      _addBorder(sheet, 38, row, left: true);
    }
    
    // AM3～BL3までのセルの上部に罫線 (col 38-63)
    for (int col = 38; col <= 63; col++) {
      _addBorder(sheet, col, 2, top: true);
    }
    
    // BL3～BL5のセルの右側に罫線 (BL=col 63, rows 2-4)
    for (int row = 2; row <= 4; row++) {
      _addBorder(sheet, 63, row, right: true);
    }
    
    // AM5～BL5までのセルの下部に罫線 (col 38-63)
    for (int col = 38; col <= 63; col++) {
      _addBorder(sheet, col, 4, bottom: true);
    }
    
    // BN3～BN5までのセルの左に罫線 (BN=col 65, rows 2-4)
    for (int row = 2; row <= 4; row++) {
      _addBorder(sheet, 65, row, left: true);
    }
    
    // BN3～BQ3までのセルの上部に罫線 (col 65-68)
    for (int col = 65; col <= 68; col++) {
      _addBorder(sheet, col, 2, top: true);
    }
    
    // BQ3～BQ5までのセルの右側に罫線 (BQ=col 68, rows 2-4)
    for (int row = 2; row <= 4; row++) {
      _addBorder(sheet, 68, row, right: true);
    }
    
    // BN5～BQ5までのセルの下部に罫線 (col 65-68)
    for (int col = 65; col <= 68; col++) {
      _addBorder(sheet, col, 4, bottom: true);
    }
    
    // 行9～23までの列A～BQまでのセルの下部に罫線 (rows 8-22, col 0-68)
    for (int row = 8; row <= 22; row++) {
      for (int col = 0; col <= 68; col++) {
        _addBorder(sheet, col, row, bottom: true);
      }
    }
    
    // 行25の列A～AKまでのセルの下部に罫線 (row 24, col 0-36)
    for (int col = 0; col <= 36; col++) {
      _addBorder(sheet, col, 24, bottom: true);
    }
    
    // 行26の列A～BQまでのセルの下部に罫線 (row 25, col 0-68)
    for (int col = 0; col <= 68; col++) {
      _addBorder(sheet, col, 25, bottom: true);
    }
    
    // 行27～30までの列AK～BQまでのセルの下部に罫線 (rows 26-29, col 36-68)
    for (int row = 26; row <= 29; row++) {
      for (int col = 36; col <= 68; col++) {
        _addBorder(sheet, col, row, bottom: true);
      }
    }
    
    // ========================================
    // 追加の罫線（右側）
    // ========================================
    
    // Z3、Z4セルの右側に罫線 (Z=col 25, rows 2-3)
    _addBorder(sheet, 25, 2, right: true);
    _addBorder(sheet, 25, 3, right: true);
    
    // AW3～AW5までのセルの右側に罫線 (AW=col 48, rows 2-4)
    for (int row = 2; row <= 4; row++) {
      _addBorder(sheet, 48, row, right: true);
    }
    
    // AM3～BL3までのセルの下部に罫線 (col 38-63, row 2)
    for (int col = 38; col <= 63; col++) {
      _addBorder(sheet, col, 2, bottom: true);
    }
    
    // BN3～BQ3までのセルの下部に罫線 (col 65-68, row 2)
    for (int col = 65; col <= 68; col++) {
      _addBorder(sheet, col, 2, bottom: true);
    }
    
    // BD3～BD5までのセルの右側に罫線 (BD=col 55, rows 2-4)
    for (int row = 2; row <= 4; row++) {
      _addBorder(sheet, 55, row, right: true);
    }
    
    // BH3～BH5までのセルの右側に罫線 (BH=col 59, rows 2-4)
    for (int row = 2; row <= 4; row++) {
      _addBorder(sheet, 59, row, right: true);
    }
    
    // A10～A23までのセルの右側に罫線 (col 0, rows 9-22)
    for (int row = 9; row <= 22; row++) {
      _addBorder(sheet, 0, row, right: true);
    }
    
    // H24、H25のセルの右側に罫線 (H=col 7, rows 23-24)
    _addBorder(sheet, 7, 23, right: true);
    _addBorder(sheet, 7, 24, right: true);
    
    // AK24～AK26までのセルの右側に罫線 (AK=col 36, rows 23-25)
    for (int row = 23; row <= 25; row++) {
      _addBorder(sheet, 36, row, right: true);
    }
    
    // Q9～Q23までのセルの右側に罫線 (Q=col 16, rows 8-22)
    for (int row = 8; row <= 22; row++) {
      _addBorder(sheet, 16, row, right: true);
    }
    
    // 行9～26の列AL～BPまでのセルの右側に罫線 (rows 8-25, col 37-67)
    for (int row = 8; row <= 25; row++) {
      for (int col = 37; col <= 67; col++) {
        _addBorder(sheet, col, row, right: true);
      }
    }
    
    // AJ27～AJ31までのセルの右側に罫線 (AJ=col 35, rows 26-30)
    for (int row = 26; row <= 30; row++) {
      _addBorder(sheet, 35, row, right: true);
    }
    
    // AL27のセルの右側に罫線 (AL=col 37, row 26)
    _addBorder(sheet, 37, 26, right: true);
    
    // AV27、BF27のセルの右側に罫線 (AV=col 47, BF=col 57, row 26)
    _addBorder(sheet, 47, 26, right: true);
    _addBorder(sheet, 57, 26, right: true);
    
    // BE28～BE31までのセルの右側に罫線 (BE=col 56, rows 27-30)
    for (int row = 27; row <= 30; row++) {
      _addBorder(sheet, 56, row, right: true);
    }
    
    // BH28～BH31までのセルの右側に罫線 (BH=col 59, rows 27-30)
    for (int row = 27; row <= 30; row++) {
      _addBorder(sheet, 59, row, right: true);
    }
    
    // BK28～BK31までのセルの右側に罫線 (BK=col 62, rows 27-30)
    for (int row = 27; row <= 30; row++) {
      _addBorder(sheet, 62, row, right: true);
    }
    
    // BN28～BN31までのセルの右側に罫線 (BN=col 65, rows 27-30)
    for (int row = 27; row <= 30; row++) {
      _addBorder(sheet, 65, row, right: true);
    }
  }
  
  /// セルに罫線を追加
  static void _addBorder(Sheet sheet, int col, int row,
      {bool top = false, bool bottom = false, bool left = false, bool right = false}) {
    var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    var currentStyle = cell.cellStyle;
    
    if (currentStyle == null) {
      cell.cellStyle = CellStyle(
        topBorder: top ? Border(borderStyle: BorderStyle.Thin) : null,
        bottomBorder: bottom ? Border(borderStyle: BorderStyle.Thin) : null,
        leftBorder: left ? Border(borderStyle: BorderStyle.Thin) : null,
        rightBorder: right ? Border(borderStyle: BorderStyle.Thin) : null,
      );
    } else {
      // 既存のスタイルを維持しつつ罫線を追加
      cell.cellStyle = CellStyle(
        fontFamily: currentStyle.fontFamily,  // ← フォントファミリーを維持
        fontSize: currentStyle.fontSize,
        bold: currentStyle.isBold,
        italic: currentStyle.isItalic,
        underline: currentStyle.underline,
        horizontalAlign: currentStyle.horizontalAlignment,
        verticalAlign: currentStyle.verticalAlignment,
        fontColorHex: currentStyle.fontColor,
        backgroundColorHex: currentStyle.backgroundColor,
        topBorder: top ? Border(borderStyle: BorderStyle.Thin) : currentStyle.topBorder,
        bottomBorder: bottom ? Border(borderStyle: BorderStyle.Thin) : currentStyle.bottomBorder,
        leftBorder: left ? Border(borderStyle: BorderStyle.Thin) : currentStyle.leftBorder,
        rightBorder: right ? Border(borderStyle: BorderStyle.Thin) : currentStyle.rightBorder,
      );
    }
  }
  
  /// 日付文字列をDateTimeに変換
  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    try {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }
}
