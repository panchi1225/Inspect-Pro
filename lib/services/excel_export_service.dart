import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'database_service.dart';
import 'cloud_sync_service.dart';

// 条件付きimport: Web/Mobile別のExcelダウンロード実装
import 'excel_download_stub.dart'
    if (dart.library.html) 'excel_download_web.dart'
    if (dart.library.io) 'excel_download_mobile.dart';

class ExcelExportService {
  /// 月次Excel帳票を生成（完全仕様準拠版）
  static Future<String?> generateMonthlyReport({
    required String machineId,
    required int year,
    required int month,
    String? siteName,
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 Excel生成開始（完全仕様準拠版）');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 1. 重機情報を取得
      final machine = DatabaseService.getMachineById(machineId);
      if (machine == null) {
        print('❌ エラー: 重機が見つかりません (ID: $machineId)');
        return null;
      }
      print('✅ 重機: ${machine.model} ${machine.unitNumber}');

      // 2. 点検記録を取得（サーバーAPIから全媒体のデータを取得）
      print('\n📅 点検記録取得:');
      
      // CloudSyncServiceを使用してサーバーから全データを取得
      final cloudSync = CloudSyncService();
      final allRecords = await cloudSync.fetchAllRecordsFromCloud();
      print('  - 全記録数（サーバー）: ${allRecords.length}件');
      
      final monthRecords = allRecords.where((r) {
        return r.machineId == machineId &&
            r.inspectionDate.year == year &&
            r.inspectionDate.month == month;
      }).toList();
      print('  - 対象月の記録数: ${monthRecords.length}件');

      // 3. 点検項目を取得
      final items = machine.getInspectionItems();
      print('\n📋 点検項目数: ${items.length}項目');

      // 4. Excelファイル作成
      print('\n📄 Excel作成（完全仕様準拠）');
      final excel = Excel.createExcel();
      final sheetName = '油圧ｼｮﾍﾞﾙ';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      // ============================================================
      // スタイル定義
      // ============================================================
      
      // 基本スタイル（左寄せ、14pt、HG明朝E）
      final normalStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        fontSize: 14,
        fontFamily: 'HG明朝E',
      );
      
      // 18ptスタイル（行1用）
      final style18pt = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        fontSize: 18,
        fontFamily: 'HG明朝E',
      );
      
      // 22pt太字スタイル（行5のタイトル用）
      final style22ptBold = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        fontSize: 22,
        bold: true,
        fontFamily: 'HG明朝E',
      );
      
      // 16ptスタイル（行7用）
      final style16pt = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        fontSize: 16,
        fontFamily: 'HG明朝E',
      );
      
      // 16pt太字下線スタイル（行7のA列用）
      final style16ptBoldUnderline = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        fontSize: 16,
        bold: true,
        underline: Underline.Single,
        fontFamily: 'HG明朝E',
      );
      
      // 中央揃えスタイル（特定セル用、14pt）
      final centerStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 14,
        fontFamily: 'HG明朝E',
      );
      
      // 12pt中央揃えスタイル（点検者欄用）
      final center12ptStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 12,
        fontFamily: 'HG明朝E',
      );
      
      // 9pt中央揃えスタイル（点検者名用）
      final center9ptStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 9,
        fontFamily: 'HG明朝E',
      );
      
      // 11pt中央揃えスタイル（日付ヘッダー用と行28用）
      final center11ptStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 11,
        fontFamily: 'HG明朝E',
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D3D3D3'),
      );
      
      // 11pt中央揃えスタイル（行28用、背景なし）
      final center11ptNoBgStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 11,
        fontFamily: 'HG明朝E',
      );
      
      // 16pt太字下線左下寄せスタイル（行7のA列用）
      final style16ptBoldUnderlineBottomLeft = CellStyle(
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Bottom,
        fontSize: 16,
        bold: true,
        underline: Underline.Single,
        fontFamily: 'HG明朝E',
      );
      
      // 縦書き中央揃えスタイル（点検者欄用、12pt）
      // 注: excelパッケージはtextRotationをサポートしていないため、通常の中央揃えを使用
      final verticalCenter12ptStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 12,
        fontFamily: 'HG明朝E',
      );

      // ヘッダースタイル（グレー背景、中央、14pt、太字）
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D3D3D3'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 14,
        fontFamily: 'HG明朝E',
      );

      // 良好スタイル（緑背景、⚪）
      final goodStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#90EE90'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 14,
        fontFamily: 'HG明朝E',
      );

      // 要補修スタイル（赤背景、×）
      final badStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#FF6B6B'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 14,
        fontFamily: 'HG明朝E',
      );

      // ============================================================
      // 列幅設定（全列）
      // ============================================================
      
      // A列（0）: 36ピクセル = 約5文字幅
      sheet.setColumnWidth(0, 5.0);
      
      // B～AK列（1～36）: 24ピクセル = 約3.3文字幅
      for (int col = 1; col <= 36; col++) {
        sheet.setColumnWidth(col, 3.3);
      }
      
      // AL列（37）: 48ピクセル = 約6.7文字幅
      sheet.setColumnWidth(37, 6.7);
      
      // AM列以降（38～）: 32ピクセル = 約4.5文字幅
      for (int col = 38; col < 70; col++) {
        sheet.setColumnWidth(col, 4.5);
      }

      // ============================================================
      // 行高設定
      // ============================================================
      
      // 行1～4: 31ピクセル
      for (int row = 0; row < 4; row++) {
        sheet.setRowHeight(row, 31);
      }
      
      // 行5: 58ピクセル
      sheet.setRowHeight(4, 58);
      
      // 行6: 24ピクセル
      sheet.setRowHeight(5, 24);
      
      // 行7: 42ピクセル
      sheet.setRowHeight(6, 42);
      
      // 行8: 10ピクセル
      sheet.setRowHeight(7, 10);
      
      // 行9～26: 42ピクセル
      for (int row = 8; row < 26; row++) {
        sheet.setRowHeight(row, 42);
      }
      
      // 行27: 96ピクセル
      sheet.setRowHeight(26, 96);
      
      // 行28～29: 49ピクセル
      for (int row = 27; row < 29; row++) {
        sheet.setRowHeight(row, 49);
      }
      
      // 行30～31: 65ピクセル
      sheet.setRowHeight(29, 65);
      sheet.setRowHeight(30, 65);
      
      // 行32以降: 49ピクセル
      for (int row = 31; row < 35; row++) {
        sheet.setRowHeight(row, 49);
      }

      // ============================================================
      // 行1: 工事名
      // ============================================================
      print('  - 行1: 工事名（18pt）');
      setCellWithStyle(sheet, 0, 0, '工事名', style18pt);
      
      // D1:E1を結合して「：」を中央配置
      sheet.merge(CellIndex.indexByString('D1'), CellIndex.indexByString('E1'));
      setCellWithStyle(sheet, 0, 3, '：', centerStyle);
      
      if (siteName != null && siteName.isNotEmpty) {
        setCellWithStyle(sheet, 0, 5, siteName, style18pt);
      }

      // ============================================================
      // 行2: 空白行（必要に応じて後で追加）
      // ============================================================

      // ============================================================
      // 行3: 法的要求事項（J3から移動）
      // ============================================================
      print('  - 行3: 法的要求事項（J3から移動）');
      setCellWithStyle(sheet, 2, 0, '・★は法的要求事項', normalStyle);
      
      // R3: 機械種類ごとの法令記載
      var machineTypeForLaw = machine.type;
      if (machineTypeForLaw == '油圧ショベル' || 
          machineTypeForLaw == 'ブルドーザー' || 
          machineTypeForLaw == 'タイヤショベル' || 
          machineTypeForLaw == 'コンバインドローラー' || 
          machineTypeForLaw == '振動ローラー' || 
          machineTypeForLaw == 'タイヤローラー') {
        // R3: 【安衛則 第170条】
        setCellWithStyle(sheet, 2, 17, '【安衛則 第170条】', normalStyle);
      } else if (machineTypeForLaw == '不整地運搬車') {
        // R3: 【安衛則 第151条57】
        setCellWithStyle(sheet, 2, 17, '【安衛則 第151条57】', normalStyle);
      }
      
      // AM3:AW3（38～48列）を結合して「所有会社名」
      sheet.merge(CellIndex.indexByString('AM3'), CellIndex.indexByString('AW3'));
      setCellWithStyle(sheet, 2, 38, '所有会社名', center11ptNoBgStyle);
      
      // AX3:BD3（49～55列）を結合して「元請点検責任者」
      sheet.merge(CellIndex.indexByString('AX3'), CellIndex.indexByString('BD3'));
      setCellWithStyle(sheet, 2, 49, '元請点検責任者', center11ptNoBgStyle);
      
      // BE3:BH3（56～59列）を結合して「型式」
      sheet.merge(CellIndex.indexByString('BE3'), CellIndex.indexByString('BH3'));
      setCellWithStyle(sheet, 2, 56, '型式', center11ptNoBgStyle);
      
      // BI3:BL3（60～63列）を結合して「機械番号」
      sheet.merge(CellIndex.indexByString('BI3'), CellIndex.indexByString('BL3'));
      setCellWithStyle(sheet, 2, 60, '機械番号', center11ptNoBgStyle);
      
      // BN3:BQ3（65～69列）を結合して「作業所長確認」
      sheet.merge(CellIndex.indexByString('BN3'), CellIndex.indexByString('BQ3'));
      setCellWithStyle(sheet, 2, 65, '作業所長確認', center11ptNoBgStyle);

      // ============================================================
      // 行4: 点検すべき事項（J4から移動）
      // ============================================================
      print('  - 行4: 点検すべき事項（J4から移動）');
      setCellWithStyle(sheet, 3, 0, '・その他は点検すべき事項とみなした箇所', normalStyle);
      
      // R4: 油圧ショベルの場合のみクレーン則記載
      if (machineTypeForLaw == '油圧ショベル') {
        // R4: 【クレーン則 第78条】
        setCellWithStyle(sheet, 3, 17, '【クレーン則 第78条】', normalStyle);
      }
      
      // AM4:AW4（38～48列）を結合
      sheet.merge(CellIndex.indexByString('AM4'), CellIndex.indexByString('AW4'));
      
      // AM4:AM5を結合
      sheet.merge(CellIndex.indexByString('AM4'), CellIndex.indexByString('AM5'));
      
      // AX4:BD4（49～55列）を結合
      sheet.merge(CellIndex.indexByString('AX4'), CellIndex.indexByString('BD4'));
      
      // AX4:AX5を結合
      sheet.merge(CellIndex.indexByString('AX4'), CellIndex.indexByString('AX5'));
      
      // BE4:BH4（56～59列）を結合して型式のみを自動入力（中央配置）
      // 型式部分のみ抽出（括弧内の文字）
      // 例: "油圧ショベル（PC200）" → "PC200"
      String modelSpec = '';
      if (machine.model.contains('（') && machine.model.contains('）')) {
        final startIdx = machine.model.indexOf('（') + 1;
        final endIdx = machine.model.indexOf('）');
        modelSpec = machine.model.substring(startIdx, endIdx);
      }
      sheet.merge(CellIndex.indexByString('BE4'), CellIndex.indexByString('BH4'));
      setCellWithStyle(sheet, 3, 56, modelSpec, centerStyle);
      
      // BN4:BQ4（65～69列）を結合
      sheet.merge(CellIndex.indexByString('BN4'), CellIndex.indexByString('BQ4'));
      
      // BN4:BN5を結合
      sheet.merge(CellIndex.indexByString('BN4'), CellIndex.indexByString('BN5'));
      
      // BI4:BL4（60～63列）を結合して号機番号を自動入力（中央配置）
      sheet.merge(CellIndex.indexByString('BI4'), CellIndex.indexByString('BL4'));
      setCellWithStyle(sheet, 3, 60, machine.unitNumber, centerStyle);
      
      // ============================================================
      // 行5: タイトル（22pt太字）- 機械の型式を除外
      // ============================================================
      print('  - 行5: タイトル（22pt太字）');
      // 重機タイプから型式部分を除外（例: "油圧ショベル（0.7m3）" → "油圧ショベル"）
      String machineType = machine.type;
      if (machineType.contains('（')) {
        machineType = machineType.substring(0, machineType.indexOf('（'));
      }
      setCellWithStyle(sheet, 4, 0, '${month}月度　${machineType}　作業開始前点検表', style22ptBold);
      
      // BE5:BH5を結合（BE4:BH4との重複を避けるため、BE5:BH5のみ結合）
      sheet.merge(CellIndex.indexByString('BE5'), CellIndex.indexByString('BH5'));
      
      // BI4:BI5を結合
      sheet.merge(CellIndex.indexByString('BI4'), CellIndex.indexByString('BI5'));
      
      // BN5:BQ5（65～69列）を結合
      sheet.merge(CellIndex.indexByString('BN5'), CellIndex.indexByString('BQ5'));

      // ============================================================
      // 行6: 空白行または追加情報
      // ============================================================

      // ============================================================
      // 行7: 注意書き（16pt、太字下線、左下寄せ）
      // ============================================================
      print('  - 行7: 注意書き（16pt、太字下線、左下寄せ）');
      setCellWithStyle(sheet, 6, 0, '※点検時、作業時問わず異常を認めたときは、元請点検責任者に報告及び速やかに補修その他必要な措置を取ること', style16ptBoldUnderlineBottomLeft);

      // ============================================================
      // 行8: 空白行（11ピクセル）
      // ============================================================

      // ============================================================
      // 行9: ヘッダー行（セル結合、14pt）
      // ============================================================
      print('  - 行9: ヘッダー行（セル結合、14pt）');
      
      // A9:Q9（0～16列）を結合して「点検項目」
      sheet.merge(CellIndex.indexByString('A9'), CellIndex.indexByString('Q9'));
      setCellWithStyle(sheet, 8, 0, '点検項目', headerStyle);
      
      // R9:AL9（17～37列）を結合して「点検ポイント」
      sheet.merge(CellIndex.indexByString('R9'), CellIndex.indexByString('AL9'));
      setCellWithStyle(sheet, 8, 17, '点検ポイント', headerStyle);
      
      // AM9～BQ9（38～69列）に1～31日（11pt中央揃え）
      for (int day = 1; day <= 31; day++) {
        final col = 38 + (day - 1);
        if (col < 70) {
          setCellWithStyle(sheet, 8, col, day.toString(), center11ptStyle);
        }
      }
      
      // 注記用セル（もし特定列に注記がある場合）
      // 例: BM9に「※」などを追加する場合はここに記述

      // ============================================================
      // 行10～23: 点検項目とデータ（14項目想定、14pt）
      // ============================================================
      print('  - 行10～23: 点検項目とデータ（14pt）');
      int dataWritten = 0;
      
      for (int i = 0; i < items.length && i < 14; i++) {
        final item = items[i];
        final row = 9 + i;
        
        // A列: ★マーク
        if (item.isRequired) {
          setCellWithStyle(sheet, row, 0, '★', normalStyle);
        }
        
        // B列: 項目名
        setCellWithStyle(sheet, row, 1, item.name, normalStyle);
        
        // R列(17): 点検ポイント
        setCellWithStyle(sheet, row, 17, item.checkPoint, normalStyle);
        
        // AM列～（38～）: ⚪×データ
        int cellsWritten = 0;
        for (int day = 1; day <= 31; day++) {
          final dayRecords = monthRecords.where((r) => r.inspectionDate.day == day).toList();
          
          if (dayRecords.isNotEmpty) {
            final record = dayRecords.first;
            final result = record.results[item.code];
            
            if (result != null) {
              final col = 38 + (day - 1);
              if (col < 70) {
                final cell = sheet.cell(CellIndex.indexByColumnRow(
                  columnIndex: col,
                  rowIndex: row,
                ));
                
                if (result.isGood) {
                  cell.value = TextCellValue('⚪');
                  cell.cellStyle = goodStyle;
                } else {
                  cell.value = TextCellValue('×');
                  cell.cellStyle = badStyle;
                }
                cellsWritten++;
              }
            }
          }
        }
        
        if (cellsWritten > 0) {
          dataWritten++;
        }
      }
      
      print('    データ書き込み完了: $dataWritten行');

      // ============================================================
      // 行24: 点検時の説明行（14pt）
      // ============================================================
      print('  - 行24: 点検時の説明');
      setCellWithStyle(sheet, 23, 0, '１．点検時', normalStyle);
      setCellWithStyle(sheet, 23, 9, '良好…○　要調整、修理…×（使用禁止）　・該当なし…－', normalStyle);

      // ============================================================
      // 行25: チェック記号の説明行（14pt）
      // ============================================================
      print('  - 行25: チェック記号の説明');
      setCellWithStyle(sheet, 24, 1, 'チェック記号', normalStyle);
      setCellWithStyle(sheet, 24, 9, '調整または補修したとき…×を○で囲む', normalStyle);

      // ============================================================
      // 行26: 元請点検責任者の確認指示（14pt）
      // ============================================================
      print('  - 行26: 元請点検責任者の確認指示');
      setCellWithStyle(sheet, 25, 0, '２．元請点検責任者は毎月上旬・中旬・下旬毎に１回は点検状況を確認すること。', normalStyle);

      // ============================================================
      // 行24～26のAL列: 点検者（縦書き、中央、12pt）
      // ============================================================
      print('  - 行24～26のAL列: 点検者欄（縦書き、12pt）');
      sheet.merge(CellIndex.indexByString('AL24'), CellIndex.indexByString('AL26'));
      setCellWithStyle(sheet, 23, 37, '点検者', verticalCenter12ptStyle);

      // ============================================================
      // 行24～26のAM～BQ列: 点検者名（縦書き風、中央、9pt）
      // ============================================================
      print('  - 行24～26のAM～BQ列: 点検者名（縦書き風、9pt）');
      // 縦書き風9ptスタイル
      // 注: excelパッケージはtextRotationをサポートしていないため、通常の中央揃えを使用
      final vertical9ptStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        fontSize: 9,
        fontFamily: 'HG明朝E',
      );
      
      for (int day = 1; day <= 31; day++) {
        final col = 38 + (day - 1);
        if (col < 70) {
          final dayRecords = monthRecords.where((r) => r.inspectionDate.day == day).toList();
          if (dayRecords.isNotEmpty) {
            // 行24、25、26を結合
            sheet.merge(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 23),
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 25),
            );
            setCellWithStyle(sheet, 23, col, dayRecords.first.inspectorName, vertical9ptStyle);
          }
        }
      }

      // ============================================================
      // 行27: 元請点検責任者確認欄（14pt）
      // ============================================================
      print('  - 行27: 元請点検責任者確認欄（12pt、中央）');
      
      // AK27とAL27を結合して「元請点検\n責任者\n確認欄」（改行付き）
      sheet.merge(CellIndex.indexByString('AK27'), CellIndex.indexByString('AL27'));
      setCellWithStyle(sheet, 26, 36, '元請点検\n責任者\n確認欄', center12ptStyle);
      
      // AM27:AT27を結合
      sheet.merge(CellIndex.indexByString('AM27'), CellIndex.indexByString('AT27'));
      
      // AW27:BD27を結合
      sheet.merge(CellIndex.indexByString('AW27'), CellIndex.indexByString('BD27'));
      
      // BG27:BO27を結合
      sheet.merge(CellIndex.indexByString('BG27'), CellIndex.indexByString('BO27'));

      // ============================================================
      // 行28: 補修関連ヘッダー（中央、11pt）
      // ============================================================
      print('  - 行28: 補修関連ヘッダー（中央、11pt）');
      
      // AK28:BE28を結合して「補修内容」
      sheet.merge(CellIndex.indexByString('AK28'), CellIndex.indexByString('BE28'));
      setCellWithStyle(sheet, 27, 36, '補修内容', center11ptNoBgStyle);
      
      // BF28:BH28を結合して「補修日」
      sheet.merge(CellIndex.indexByString('BF28'), CellIndex.indexByString('BH28'));
      setCellWithStyle(sheet, 27, 57, '補修日', center11ptNoBgStyle);
      
      // BI28:BK28を結合して「補修者」
      sheet.merge(CellIndex.indexByString('BI28'), CellIndex.indexByString('BK28'));
      setCellWithStyle(sheet, 27, 60, '補修者', center11ptNoBgStyle);
      
      // BL28:BN28を結合して「元請点検\n責任者\n確認欄」（改行付き）
      sheet.merge(CellIndex.indexByString('BL28'), CellIndex.indexByString('BN28'));
      setCellWithStyle(sheet, 27, 63, '元請点検\n責任者\n確認欄', center11ptNoBgStyle);
      
      // BO28:BQ28を結合して「作業所長」
      sheet.merge(CellIndex.indexByString('BO28'), CellIndex.indexByString('BQ28'));
      setCellWithStyle(sheet, 27, 66, '作業所長', center11ptNoBgStyle);

      // ============================================================
      // 行29: 補修関連データ行（セル結合）
      // ============================================================
      print('  - 行29: 補修関連データ行（セル結合）');
      
      // AK29:BE29を結合
      sheet.merge(CellIndex.indexByString('AK29'), CellIndex.indexByString('BE29'));
      
      // BF29:BH29を結合
      sheet.merge(CellIndex.indexByString('BF29'), CellIndex.indexByString('BH29'));
      
      // BI29:BK29を結合
      sheet.merge(CellIndex.indexByString('BI29'), CellIndex.indexByString('BK29'));
      
      // BL29:BN29を結合
      sheet.merge(CellIndex.indexByString('BL29'), CellIndex.indexByString('BN29'));
      
      // BO29:BQ29を結合
      sheet.merge(CellIndex.indexByString('BO29'), CellIndex.indexByString('BQ29'));

      // ============================================================
      // 行30: 補修関連データ行（セル結合）
      // ============================================================
      print('  - 行30: 補修関連データ行（セル結合）');
      
      // AK30:BE30を結合
      sheet.merge(CellIndex.indexByString('AK30'), CellIndex.indexByString('BE30'));
      
      // BF30:BH30を結合
      sheet.merge(CellIndex.indexByString('BF30'), CellIndex.indexByString('BH30'));
      
      // BI30:BK30を結合
      sheet.merge(CellIndex.indexByString('BI30'), CellIndex.indexByString('BK30'));
      
      // BO30:BQ30を結合
      sheet.merge(CellIndex.indexByString('BO30'), CellIndex.indexByString('BQ30'));

      // ============================================================
      // 行31: 補修関連データ行（セル結合）
      // ============================================================
      print('  - 行31: 補修関連データ行（セル結合）');
      
      // AK31:BE31を結合
      sheet.merge(CellIndex.indexByString('AK31'), CellIndex.indexByString('BE31'));
      
      // BF31:BH31を結合
      sheet.merge(CellIndex.indexByString('BF31'), CellIndex.indexByString('BH31'));
      
      // BI31:BK31を結合
      sheet.merge(CellIndex.indexByString('BI31'), CellIndex.indexByString('BK31'));
      
      // BO31:BQ31を結合
      sheet.merge(CellIndex.indexByString('BO31'), CellIndex.indexByString('BQ31'));

      // ============================================================
      // 行27～31: 重機画像エリア（A27～AJ31を結合）
      // ============================================================
      print('  - 行27～31: 重機画像エリア（A27～AJ31を結合）');
      
      // A27:AJ31を結合して重機画像エリアを作成
      sheet.merge(CellIndex.indexByString('A27'), CellIndex.indexByString('AJ31'));
      
      // 注: Flutter excelパッケージ（4.0.6）は画像挿入をサポートしていないため、
      // 画像は実装できません。代わりに、説明テキストを配置します。
      setCellWithStyle(sheet, 26, 0, '※重機画像エリア※', centerStyle);

      // ============================================================
      // 罫線の設定
      // ============================================================
      // 注: Flutter excelパッケージ（4.0.6）は罫線APIをサポートしていないため、
      // 罫線機能は実装できません。代わりに、Excelファイルを開いた後に
      // 手動で罫線を追加するか、Pythonバックエンド（openpyxl）を使用する必要があります。
      print('  - 罫線の設定（現在のexcelパッケージではサポート対象外）');

      // ============================================================
      // ファイル保存
      // ============================================================
      final fileName = '点検表_${machine.model}_${machine.unitNumber}_${year}年${month}月.xlsx';
      final fileBytes = excel.encode();
      
      if (fileBytes == null) {
        print('❌ エラー: Excelエンコード失敗');
        return null;
      }

      print('\n✅ Excel生成成功！');
      print('  ファイル名: $fileName');
      print('  ファイルサイズ: ${fileBytes.length} bytes');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // プラットフォーム別保存処理
      if (kIsWeb) {
        await ExcelDownload.downloadFile(fileBytes, fileName);
        return fileName;
      } else {
        await ExcelDownload.downloadFile(fileBytes, fileName);
        return fileName;
      }
    } catch (e, stackTrace) {
      print('\n❌❌❌ Excel生成エラー ❌❌❌');
      print('エラー: $e');
      print('スタックトレース:\n$stackTrace');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      return null;
    }
  }

  /// セルに値を設定
  static void setCell(Sheet sheet, int row, int col, String value) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(
      columnIndex: col,
      rowIndex: row,
    ));
    cell.value = TextCellValue(value);
  }

  /// セルに値とスタイルを設定
  static void setCellWithStyle(Sheet sheet, int row, int col, String value, CellStyle style) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(
      columnIndex: col,
      rowIndex: row,
    ));
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
  }
}
