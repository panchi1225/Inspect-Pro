import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/inspection_record.dart';
import 'database_service.dart';

/// クラウド同期サービス
/// 複数端末間でのデータ共有を実現
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  // サーバーのベースURL（相対パスで同一オリジンのAPIにアクセス）
  static const String _baseUrl = '/api';
  
  // 同期状態管理
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _autoSyncTimer;
  
  final DatabaseService _databaseService = DatabaseService();

  /// 自動同期を開始（5分ごと）
  void startAutoSync() {
    if (_autoSyncTimer != null) return;
    
    print('🔄 自動同期サービス開始');
    
    // 初回同期を即座に実行
    syncAllData();
    
    // 5分ごとに自動同期
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!_isSyncing) {
        syncAllData();
      }
    });
    
    print('✅ 自動同期開始（5分間隔）');
  }

  /// 自動同期を停止
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    
    print('⏸️ 自動同期停止');
  }

  /// すべてのデータを同期
  Future<SyncResult> syncAllData() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: '既に同期中です',
        created: 0,
        updated: 0,
        conflicts: 0,
      );
    }

    _isSyncing = true;
    
    try {
      print('🔄 データ同期開始...');

      // ローカルの全記録を取得
      final localRecords = await _databaseService.fetchAllRecords();
      
      print('   ローカル記録数: ${localRecords.length}');

      // サーバーに送信するデータを準備
      final recordsJson = localRecords.map((record) {
        return {
          'id': record.id,
          'machineId': record.machineId,
          'siteName': record.siteName,
          'inspectorName': record.inspectorName,
          'inspectionDate': record.inspectionDate.toIso8601String(),
          'results': record.results.map((key, value) => MapEntry(key, value.toMap())),
          'createdAt': record.inspectionDate.toIso8601String(),
          'updatedAt': record.inspectionDate.toIso8601String(),
        };
      }).toList();

      // サーバーと同期
      print('📤 同期リクエスト送信: $_baseUrl/sync');
      print('   送信レコード数: ${recordsJson.length}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'records': recordsJson}),
      );
      
      print('📥 同期レスポンス: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final serverRecords = data['records'] as List;
        final syncResult = data['result'];

        print('   サーバー記録数: ${serverRecords.length}');
        print('   作成: ${syncResult['created']}, 更新: ${syncResult['updated']}, 競合: ${syncResult['conflicts']}');

        // サーバーから取得したデータをローカルに保存
        for (var recordData in serverRecords) {
          try {
            // resultsをInspectionResultオブジェクトに変換
            final resultsMap = recordData['results'] as Map<String, dynamic>;
            final results = resultsMap.map(
              (key, value) => MapEntry(
                key,
                InspectionResult.fromMap(value as Map<String, dynamic>),
              ),
            );

            // Machine情報を取得
            final machine = DatabaseService.getMachineById(recordData['machineId']);
            if (machine == null) continue;

            final record = InspectionRecord(
              id: recordData['id'],
              machineId: recordData['machineId'],
              siteName: recordData['siteName'].isEmpty ? '現場名未設定' : recordData['siteName'],
              inspectorName: recordData['inspectorName'],
              machineType: machine.type,
              machineModel: machine.model,
              machineUnitNumber: machine.unitNumber,
              inspectionDate: DateTime.parse(recordData['inspectionDate']),
              results: results,
            );

            // ローカルに存在するか確認
            final existingRecord = await _databaseService.getRecordById(record.id);
            
            if (existingRecord == null) {
              // 新規作成
              await _databaseService.saveRecord(record);
            } else {
              // 既存レコードがあれば更新しない（競合回避）
              // サーバーが最新データを持っている場合のみ更新
              final serverUpdatedAt = DateTime.parse(recordData['updatedAt']);
              if (serverUpdatedAt.isAfter(existingRecord.inspectionDate)) {
                await _databaseService.updateRecord(record);
              }
            }
          } catch (e) {
            print('⚠️ レコード処理エラー: $e');
          }
        }

        _lastSyncTime = DateTime.now();
        
        print('✅ データ同期完了');

        return SyncResult(
          success: true,
          message: '同期完了',
          created: syncResult['created'],
          updated: syncResult['updated'],
          conflicts: syncResult['conflicts'],
        );
      } else {
        throw Exception('サーバーエラー: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ データ同期エラー: $e');
      print('   エラー詳細: ${e.toString()}');
      
      if (e is http.ClientException) {
        print('   ネットワークエラー: ${e.message}');
      }
      
      return SyncResult(
        success: false,
        message: 'エラー: $e',
        created: 0,
        updated: 0,
        conflicts: 0,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// 点検記録をクラウドに保存
  Future<bool> saveRecordToCloud(InspectionRecord record) async {
    try {
      print('💾 クラウドに保存開始: ${record.id}');
      print('   URL: $_baseUrl/records');

      final recordJson = {
        'id': record.id,
        'machineId': record.machineId,
        'siteName': record.siteName,
        'inspectorName': record.inspectorName,
        'inspectionDate': record.inspectionDate.toIso8601String(),
        'results': record.results.map((key, value) => MapEntry(key, value.toMap())),
      };
      
      print('   送信データ: ID=${record.id}, 現場=${record.siteName}');

      final response = await http.post(
        Uri.parse('$_baseUrl/records'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(recordJson),
      );
      
      print('   レスポンス: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ クラウド保存完了: ${record.id}');
        return true;
      } else if (response.statusCode == 409) {
        print('⚠️ レコード重複 - 更新を試みます');
        // 既に存在する場合は更新
        return await updateRecordInCloud(record);
      } else {
        print('❌ 保存失敗: ${response.statusCode} - ${response.body}');
        throw Exception('保存失敗: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ クラウド保存エラー: $e');
      print('   エラー詳細: ${e.toString()}');
      return false;
    }
  }

  /// 点検記録をクラウドで更新
  Future<bool> updateRecordInCloud(InspectionRecord record) async {
    try {
      print('🔄 クラウドで更新: ${record.id}');

      final recordJson = {
        'id': record.id,
        'machineId': record.machineId,
        'siteName': record.siteName,
        'inspectorName': record.inspectorName,
        'inspectionDate': record.inspectionDate.toIso8601String(),
        'results': record.results.map((key, value) => MapEntry(key, value.toMap())),
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/records/${record.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(recordJson),
      );

      if (response.statusCode == 200) {
        print('✅ クラウド更新完了');
        return true;
      } else {
        throw Exception('更新失敗: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ クラウド更新エラー: $e');
      return false;
    }
  }

  /// クラウドから全記録を取得
  Future<List<InspectionRecord>> fetchAllRecordsFromCloud() async {
    try {
      print('📥 クラウドから全記録取得...');

      final response = await http.get(
        Uri.parse('$_baseUrl/records'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final recordsList = data['records'] as List;

        final records = <InspectionRecord>[];
        for (var recordData in recordsList) {
          try {
            // resultsをInspectionResultオブジェクトに変換
            final resultsMap = recordData['results'] as Map<String, dynamic>;
            final results = resultsMap.map(
              (key, value) => MapEntry(
                key,
                InspectionResult.fromMap(value as Map<String, dynamic>),
              ),
            );

            // Machine情報を取得
            final machine = DatabaseService.getMachineById(recordData['machineId']);
            if (machine == null) continue;

            records.add(InspectionRecord(
              id: recordData['id'],
              machineId: recordData['machineId'],
              siteName: recordData['siteName'].isEmpty ? '現場名未設定' : recordData['siteName'],
              inspectorName: recordData['inspectorName'],
              machineType: machine.type,
              machineModel: machine.model,
              machineUnitNumber: machine.unitNumber,
              inspectionDate: DateTime.parse(recordData['inspectionDate']),
              results: results,
            ));
          } catch (e) {
            print('⚠️ レコード変換エラー: $e');
          }
        }

        print('✅ クラウドから${records.length}件の記録を取得');

        return records;
      } else {
        throw Exception('取得失敗: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ クラウド取得エラー: $e');
      return [];
    }
  }

  /// 最終同期時刻を取得
  DateTime? get lastSyncTime => _lastSyncTime;
  
  /// 同期中かどうか
  bool get isSyncing => _isSyncing;
}

/// 同期結果
class SyncResult {
  final bool success;
  final String message;
  final int created;
  final int updated;
  final int conflicts;

  SyncResult({
    required this.success,
    required this.message,
    required this.created,
    required this.updated,
    required this.conflicts,
  });
}
