import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/inspection_record.dart';
import '../models/inspection_item.dart';
import 'firestore_service.dart';

// 条件付きimport: Web/Mobile別のExcelダウンロード実装
import 'excel_download_stub.dart'
    if (dart.library.html) 'excel_download_web.dart'
    if (dart.library.io) 'excel_download_mobile.dart';

class PythonExcelService {
  /// PythonバックエンドでExcel生成（画像・罫線付き）
  static Future<String?> generateMonthlyReportWithPython({
    required String machineId,
    required int year,
    required int month,
    String? siteName,
    String? companyName,
    String? responsiblePerson,
    String? primeContractorInspector, // 元請点検責任者
  }) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🐍 Python Excel生成開始（画像・罫線完全対応版）');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final firestoreService = FirestoreService();
      
      // 1. 重機情報を取得
      final machine = await firestoreService.getMachineById(machineId);
      if (machine == null) {
        print('❌ エラー: 重機が見つかりません (ID: $machineId)');
        return null;
      }
      print('✅ 重機: ${machine.model} ${machine.unitNumber}');

      // 2. 点検記録を取得（Firestoreから）
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
      print('✅ 全記録数（Firestore）: ${allRecords.length}件');
      
      final monthRecords = allRecords.where((r) {
        // machineId、年月、現場名がすべて一致するデータのみ
        return r.machineId == machineId &&
            r.inspectionDate.year == year &&
            r.inspectionDate.month == month &&
            (siteName == null || siteName.isEmpty || r.siteName == siteName);
      }).toList();
      print('✅ 対象月の記録数: ${monthRecords.length}件 (現場: ${siteName ?? "指定なし"})');

      // 3. 点検項目を取得
      if (machine.typeId == null) {
        print('❌ エラー: 重機のtypeIdがありません');
        return null;
      }
      final items = await firestoreService.getInspectionItems(machine.typeId!);
      print('✅ 点検項目数: ${items.length}項目');

      // 4. JSONデータ作成
      final jsonData = {
        'machine_type': machine.type,
        'machine_model': machine.model,
        'machine_unit': machine.unitNumber,
        'site_name': siteName ?? '',
        'company_name': companyName ?? '',
        'responsible_person': responsiblePerson ?? '',
        'prime_contractor_inspector': primeContractorInspector ?? '', // 元請点検責任者
        'month': month,
        'year': year,
        'records': monthRecords.map((r) {
          // 日付から日を抽出
          final day = r.inspectionDate.day;
          
          // 結果をマップに変換
          final results = <String, Map<String, dynamic>>{};
          for (final item in items) {
            if (r.results.containsKey(item.code)) {
              // r.results[item.code]はInspectionResultオブジェクト
              final inspectionResult = r.results[item.code];
              if (inspectionResult != null) {
                final isGood = inspectionResult.isGood;
                print('🔍 Item ${item.code}: isGood=${isGood} (type: ${isGood.runtimeType})');
                results[item.code] = {
                  'is_good': isGood,  // bool値をそのまま送信
                };
              }
            }
          }
          
          return {
            'day': day,
            'inspector_name': r.inspectorName,
            'results': results,
          };
        }).toList(),
        'items': items.map((item) {
          return {
            'code': item.code,
            'name': item.name,
            'check_point': item.checkPoint,
            'is_required': item.isRequired,
          };
        }).toList(),
      };

      print('✅ JSONデータ作成完了');
      print('📊 データサイズ: ${jsonEncode(jsonData).length}バイト');

      // 5. Pythonバックエンドを呼び出し
      if (kIsWeb) {
        // Web環境ではAPIエンドポイントを呼び出す
        return await _callPythonBackendWeb(jsonData, machine);
      } else {
        // モバイル環境では直接Pythonスクリプトを実行
        return await _callPythonBackendMobile(jsonData, machine);
      }
    } catch (e, stackTrace) {
      print('❌ Python Excel生成エラー: $e');
      print('スタックトレース: $stackTrace');
      return null;
    }
  }

  /// Web環境でPythonバックエンドを呼び出す
  static Future<String?> _callPythonBackendWeb(
    Map<String, dynamic> jsonData,
    dynamic machine,
  ) async {
    try {
      print('🌐 Web環境: Python APIエンドポイント呼び出し');
      
      // ファイル名生成
      final fileName = '点検表_${machine.model}_${machine.unitNumber}_${jsonData['year']}年${jsonData['month']}月.xlsx';
      
      // Python APIサーバーのURL（同一オリジン）
      final apiUrl = '/api/generate-excel';
      
      // JSONデータをPOST
      final jsonString = jsonEncode(jsonData);
      print('📤 APIリクエスト送信: $apiUrl');
      print('📊 データサイズ: ${jsonString.length}バイト');
      
      // Python APIに POST リクエスト
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonString,
      );
      
      if (response.statusCode == 200) {
        print('✅ Python API呼び出し成功');
        print('📥 Excelファイルダウンロード開始: $fileName');
        
        // プラットフォーム別ダウンロード処理
        await ExcelDownload.downloadFile(response.bodyBytes, fileName);
        return fileName;
      } else {
        print('❌ Python APIエラー: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Web環境でのPython呼び出しエラー: $e');
      return null;
    }
  }

  /// モバイル環境でPythonバックエンドを呼び出す
  static Future<String?> _callPythonBackendMobile(
    Map<String, dynamic> jsonData,
    dynamic machine,
  ) async {
    try {
      print('📱 モバイル環境: Pythonスクリプト直接実行');
      
      // モバイル環境ではPythonランタイムが必要
      print('⚠️ モバイル環境でのPython実行は今後実装予定');
      
      return null;
    } catch (e) {
      print('❌ モバイル環境でのPython呼び出しエラー: $e');
      return null;
    }
  }

  /// 日付文字列をDateTimeに変換（デフォルトは今日）
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
