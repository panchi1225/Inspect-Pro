import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/inspection_record.dart';
import '../models/inspection_item.dart';
import 'firestore_service.dart';

// 条件付きimport: Web/Mobile別のExcelダウンロード実装
import 'excel_download_stub.dart'
    if (dart.library.html) 'excel_download_web.dart'
    if (dart.library.io) 'excel_download_mobile.dart';

/// Web専用のExcel生成サービス（クライアント側で完結）
class WebExcelService {
  /// 月次点検レポートをExcelで生成（Web版）
  static Future<String?> generateMonthlyReport({
    required String machineId,
    required int year,
    required int month,
    String? siteName,
    String? companyName,
    String? responsiblePerson,
    String? primeContractorInspector,
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 Web Excel生成開始（クライアント側）');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final firestoreService = FirestoreService();
      
      // 1. 重機情報を取得
      final machine = await firestoreService.getMachineById(machineId);
      if (machine == null) {
        print('❌ エラー: 重機が見つかりません (ID: $machineId)');
        return null;
      }
      print('✅ 重機: ${machine.model} ${machine.unitNumber}');

      // 2. 点検記録を取得
      final inspectionData = await firestoreService.getInspections();
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

      // 4. Excelファイル生成
      var excel = Excel.createExcel();
      excel.rename('Sheet1', '月次点検表');
      Sheet sheet = excel['月次点検表'];
      
      // 5. ヘッダー情報
      int currentRow = 0;
      
      // タイトル
      sheet.merge(
        CellIndex.indexByString('A${currentRow + 1}'),
        CellIndex.indexByString('AG${currentRow + 1}'),
      );
      var titleCell = sheet.cell(CellIndex.indexByString('A${currentRow + 1}'));
      titleCell.value = TextCellValue('日々点検表（$year年$month月）');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
      );
      currentRow += 2;
      
      // 基本情報
      _setCellValue(sheet, 'A$currentRow', '現場名：');
      _setCellValue(sheet, 'B$currentRow', siteName ?? '');
      currentRow++;
      
      _setCellValue(sheet, 'A$currentRow', '所有会社：');
      _setCellValue(sheet, 'B$currentRow', companyName ?? '');
      currentRow++;
      
      _setCellValue(sheet, 'A$currentRow', '責任者：');
      _setCellValue(sheet, 'B$currentRow', responsiblePerson ?? '');
      currentRow++;
      
      _setCellValue(sheet, 'A$currentRow', '元請点検責任者：');
      _setCellValue(sheet, 'B$currentRow', primeContractorInspector ?? '');
      currentRow++;
      
      _setCellValue(sheet, 'A$currentRow', '機種：');
      _setCellValue(sheet, 'B$currentRow', machine.type);
      currentRow++;
      
      _setCellValue(sheet, 'A$currentRow', '型式：');
      _setCellValue(sheet, 'B$currentRow', machine.model);
      currentRow++;
      
      _setCellValue(sheet, 'A$currentRow', '号機：');
      _setCellValue(sheet, 'B$currentRow', machine.unitNumber);
      currentRow += 2;
      
      // 6. 点検表ヘッダー
      int headerRow = currentRow;
      
      // 日付ヘッダー（縦書き風）
      _setCellValue(sheet, 'A$headerRow', '点検項目');
      _setCellValue(sheet, 'B$headerRow', '点検者');
      
      // 月の日数分の列を作成
      int daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        int colIndex = 2 + day; // C列から開始（0-indexed: A=0, B=1, C=2）
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: headerRow));
        cell.value = TextCellValue(day.toString());
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
      currentRow++;
      
      // 7. 点検項目行
      for (var item in items) {
        int itemRow = currentRow;
        
        // 項目名
        _setCellValue(sheet, 'A$itemRow', item.name);
        
        // 点検者名と各日の結果
        Map<int, InspectionRecord> dayRecords = {};
        for (var record in monthRecords) {
          int day = record.inspectionDate.day;
          dayRecords[day] = record;
        }
        
        // 点検者名（最初の記録から取得）
        String inspectorName = monthRecords.isNotEmpty ? monthRecords.first.inspectorName : '';
        _setCellValue(sheet, 'B$itemRow', inspectorName);
        
        // 各日の結果
        for (int day = 1; day <= daysInMonth; day++) {
          int colIndex = 2 + day;
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: itemRow));
          
          if (dayRecords.containsKey(day)) {
            var record = dayRecords[day]!;
            if (record.results.containsKey(item.code)) {
              var result = record.results[item.code]!;
              cell.value = TextCellValue(result.isGood ? '○' : '×');
              cell.cellStyle = CellStyle(
                horizontalAlign: HorizontalAlign.Center,
                verticalAlign: VerticalAlign.Center,
                fontColorHex: ExcelColor.fromHexString(result.isGood ? '#00AA00' : '#FF0000'),
              );
            } else {
              cell.value = TextCellValue('-');
              cell.cellStyle = CellStyle(
                horizontalAlign: HorizontalAlign.Center,
                verticalAlign: VerticalAlign.Center,
              );
            }
          } else {
            cell.value = TextCellValue('');
          }
        }
        
        currentRow++;
      }
      
      print('✅ Excel生成完了');
      
      // 8. ファイル保存
      var fileBytes = excel.save();
      if (fileBytes == null) {
        print('❌ Excelファイルのバイト変換に失敗');
        return null;
      }
      
      String fileName = '日々点検表_${machine.model}_${machine.unitNumber}_${year}年${month}月.xlsx';
      
      if (kIsWeb) {
        // Web環境でのダウンロード
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
  
  /// セルに値を設定（ヘルパーメソッド）
  static void _setCellValue(Sheet sheet, String cellAddress, String value) {
    var cell = sheet.cell(CellIndex.indexByString(cellAddress));
    cell.value = TextCellValue(value);
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
