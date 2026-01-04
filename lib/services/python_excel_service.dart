import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'database_service.dart';
import 'cloud_sync_service.dart';
// Web用
import 'dart:html' as html;

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
      
      // 1. 重機情報を取得
      final machine = DatabaseService.getMachineById(machineId);
      if (machine == null) {
        print('❌ エラー: 重機が見つかりません (ID: $machineId)');
        return null;
      }
      print('✅ 重機: ${machine.model} ${machine.unitNumber}');

      // 2. 点検記録を取得（サーバーAPIから全媒体のデータを取得）
      final cloudSync = CloudSyncService();
      final allRecords = await cloudSync.fetchAllRecordsFromCloud();
      print('✅ 全記録数（サーバー）: ${allRecords.length}件');
      
      final monthRecords = allRecords.where((r) {
        // machineId、年月、現場名がすべて一致するデータのみ
        return r.machineId == machineId &&
            r.inspectionDate.year == year &&
            r.inspectionDate.month == month &&
            (siteName == null || siteName.isEmpty || r.siteName == siteName);
      }).toList();
      print('✅ 対象月の記録数: ${monthRecords.length}件 (現場: ${siteName ?? "指定なし"})');

      // 3. 点検項目を取得
      final items = machine.getInspectionItems();
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
      
      // XHRリクエストを作成
      final xhr = html.HttpRequest();
      xhr.open('POST', apiUrl);
      xhr.setRequestHeader('Content-Type', 'application/json');
      xhr.responseType = 'blob';
      
      // リクエスト送信
      xhr.send(jsonString);
      
      // レスポンスを待つ
      await xhr.onLoadEnd.first;
      
      if (xhr.status == 200) {
        print('✅ Python API呼び出し成功');
        
        // Blobを取得
        final blob = xhr.response;
        
        // ダウンロード用のリンクを作成
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        
        html.Url.revokeObjectUrl(url);
        
        print('📥 Excelファイルダウンロード開始: $fileName');
        return fileName;
      } else {
        print('❌ Python APIエラー: ${xhr.status} ${xhr.statusText}');
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
}
