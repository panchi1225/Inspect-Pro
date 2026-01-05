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
      
      // 5. 列幅設定
      sheet.setColumnWidth(0, 25);  // A列: 点検項目（幅25）
      sheet.setColumnWidth(1, 12);  // B列: 点検者（幅12）
      
      // 月の日数分の列幅設定（C列以降）
      int daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        sheet.setColumnWidth(2 + day, 4);  // 日付列（幅4）
      }
      
      // 6. ヘッダー情報
      int currentRow = 0;
      
      // タイトル（結合セル）
      int lastCol = 2 + daysInMonth;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: currentRow),
      );
      var titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      titleCell.value = TextCellValue('日々点検表（$year年$month月）');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 18,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
      );
      sheet.setRowHeight(currentRow, 30);
      currentRow += 2;
      
      // 基本情報
      _setInfoRow(sheet, currentRow, 'A', '現場名：', siteName ?? '');
      currentRow++;
      
      _setInfoRow(sheet, currentRow, 'A', '所有会社：', companyName ?? '');
      currentRow++;
      
      _setInfoRow(sheet, currentRow, 'A', '責任者：', responsiblePerson ?? '');
      currentRow++;
      
      _setInfoRow(sheet, currentRow, 'A', '元請点検責任者：', primeContractorInspector ?? '');
      currentRow++;
      
      _setInfoRow(sheet, currentRow, 'A', '機種：', machine.type);
      currentRow++;
      
      _setInfoRow(sheet, currentRow, 'A', '型式：', machine.model);
      currentRow++;
      
      _setInfoRow(sheet, currentRow, 'A', '号機：', machine.unitNumber);
      currentRow += 2;
      
      // 7. 点検表ヘッダー
      int headerRow = currentRow;
      sheet.setRowHeight(headerRow, 25);
      
      // 点検項目列ヘッダー
      var itemHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow));
      itemHeaderCell.value = TextCellValue('点検項目');
      itemHeaderCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#D0D0D0'),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );
      
      // 点検者列ヘッダー
      var inspectorHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow));
      inspectorHeaderCell.value = TextCellValue('点検者');
      inspectorHeaderCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#D0D0D0'),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );
      
      // 日付ヘッダー
      for (int day = 1; day <= daysInMonth; day++) {
        int colIndex = 2 + day;
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: headerRow));
        cell.value = TextCellValue(day.toString());
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString('#D0D0D0'),
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );
      }
      currentRow++;
      
      // 8. 点検項目行
      for (var item in items) {
        int itemRow = currentRow;
        sheet.setRowHeight(itemRow, 20);
        
        // 項目名
        var itemCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: itemRow));
        itemCell.value = TextCellValue(item.name);
        itemCell.cellStyle = CellStyle(
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );
        
        // 点検者名と各日の結果
        Map<int, InspectionRecord> dayRecords = {};
        for (var record in monthRecords) {
          int day = record.inspectionDate.day;
          dayRecords[day] = record;
        }
        
        // 点検者名セル
        String inspectorName = monthRecords.isNotEmpty ? monthRecords.first.inspectorName : '';
        var inspectorCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: itemRow));
        inspectorCell.value = TextCellValue(inspectorName);
        inspectorCell.cellStyle = CellStyle(
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
        );
        
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
                fontSize: 12,
                bold: true,
                horizontalAlign: HorizontalAlign.Center,
                verticalAlign: VerticalAlign.Center,
                fontColorHex: ExcelColor.fromHexString(result.isGood ? '#00AA00' : '#FF0000'),
                leftBorder: Border(borderStyle: BorderStyle.Thin),
                rightBorder: Border(borderStyle: BorderStyle.Thin),
                topBorder: Border(borderStyle: BorderStyle.Thin),
                bottomBorder: Border(borderStyle: BorderStyle.Thin),
              );
            } else {
              cell.value = TextCellValue('-');
              cell.cellStyle = CellStyle(
                fontSize: 10,
                horizontalAlign: HorizontalAlign.Center,
                verticalAlign: VerticalAlign.Center,
                fontColorHex: ExcelColor.fromHexString('#999999'),
                leftBorder: Border(borderStyle: BorderStyle.Thin),
                rightBorder: Border(borderStyle: BorderStyle.Thin),
                topBorder: Border(borderStyle: BorderStyle.Thin),
                bottomBorder: Border(borderStyle: BorderStyle.Thin),
              );
            }
          } else {
            cell.value = TextCellValue('');
            cell.cellStyle = CellStyle(
              leftBorder: Border(borderStyle: BorderStyle.Thin),
              rightBorder: Border(borderStyle: BorderStyle.Thin),
              topBorder: Border(borderStyle: BorderStyle.Thin),
              bottomBorder: Border(borderStyle: BorderStyle.Thin),
            );
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
  
  /// 情報行を設定（ラベル + 値）
  static void _setInfoRow(Sheet sheet, int row, String startCol, String label, String value) {
    // ラベルセル
    var labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    labelCell.value = TextCellValue(label);
    labelCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );
    
    // 値セル（B列から結合）
    var valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    valueCell.value = TextCellValue(value);
    valueCell.cellStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    
    sheet.setRowHeight(row, 20);
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
