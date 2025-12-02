import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/machine.dart';
import '../models/inspection_record.dart';
import '../data/master_data.dart';

class DatabaseService {
  static const String machineBoxName = 'machines';
  static const String recordBoxName = 'inspection_records';

  // Hiveの初期化
  static Future<void> init() async {
    try {
      if (kIsWeb) {
        // Web環境: pathを指定せずに初期化
        await Hive.initFlutter();
      } else {
        // モバイル環境: 通常の初期化
        await Hive.initFlutter();
      }
      
      // ボックスを開く
      if (!Hive.isBoxOpen(machineBoxName)) {
        await Hive.openBox<Map>(machineBoxName);
      }
      if (!Hive.isBoxOpen(recordBoxName)) {
        await Hive.openBox<Map>(recordBoxName);
      }
      
      // 初回起動時にマスタデータを登録
      await _initializeMasterData();
    } catch (e) {
      if (kIsWeb) {
        // Web環境でエラーが出た場合、何もしない（メモリストレージ）
        print('Hive initialization warning (Web): $e');
      } else {
        rethrow;
      }
    }
  }

  // マスタデータの初期化
  static Future<void> _initializeMasterData() async {
    final machineBox = Hive.box<Map>(machineBoxName);
    
    // 既存のマスタデータをクリア（常に最新のマスタデータを使用）
    await machineBox.clear();
    
    // マスタデータを登録
    final machines = MasterData.getMachines();
    for (var machine in machines) {
      await machineBox.put(machine.id, machine.toMap());
    }
    print('✅ Initialized ${machines.length} machines');
  }

  // すべての重機を取得
  static List<Machine> getAllMachines() {
    try {
      if (!Hive.isBoxOpen(machineBoxName)) {
        return [];
      }
      final machineBox = Hive.box<Map>(machineBoxName);
      return machineBox.values
          .map((map) => Machine.fromMap(Map<String, dynamic>.from(map)))
          .toList();
    } catch (e) {
      print('Error getting machines: $e');
      return [];
    }
  }

  // 重機をIDで取得
  static Machine? getMachineById(String id) {
    try {
      if (!Hive.isBoxOpen(machineBoxName)) {
        return null;
      }
      final machineBox = Hive.box<Map>(machineBoxName);
      final map = machineBox.get(id);
      if (map == null) return null;
      return Machine.fromMap(Map<String, dynamic>.from(map));
    } catch (e) {
      print('Error getting machine: $e');
      return null;
    }
  }

  // 点検記録を保存
  static Future<void> saveInspectionRecord(InspectionRecord record) async {
    try {
      if (!Hive.isBoxOpen(recordBoxName)) {
        print('📦 Opening record box...');
        await Hive.openBox<Map>(recordBoxName);
      }
      final recordBox = Hive.box<Map>(recordBoxName);
      final recordMap = record.toMap();
      await recordBox.put(record.id, recordMap);
      print('✅ Record saved: ${record.id}');
      print('📊 Total records in box: ${recordBox.length}');
      print('🔍 Saved data: Site=${record.siteName}, Machine=${record.machineType} ${record.machineModel}');
    } catch (e) {
      print('❌ Error saving record: $e');
      rethrow;
    }
  }

  // すべての点検記録を取得
  static List<InspectionRecord> getAllRecords() {
    try {
      if (!Hive.isBoxOpen(recordBoxName)) {
        print('⚠️ Record box is not open');
        return [];
      }
      final recordBox = Hive.box<Map>(recordBoxName);
      print('📦 Record box contains ${recordBox.length} items');
      
      final records = <InspectionRecord>[];
      for (var entry in recordBox.values) {
        try {
          final map = Map<String, dynamic>.from(entry);
          final record = InspectionRecord.fromMap(map);
          records.add(record);
        } catch (e) {
          print('⚠️ Failed to parse record: $e');
        }
      }
      
      print('✅ Successfully loaded ${records.length} records');
      return records;
    } catch (e) {
      print('❌ Error getting records: $e');
      return [];
    }
  }

  // 日付範囲で点検記録を取得
  static List<InspectionRecord> getRecordsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    final records = getAllRecords();
    return records.where((record) {
      return record.inspectionDate.isAfter(startDate) &&
          record.inspectionDate.isBefore(endDate);
    }).toList();
  }

  // 特定の重機の点検記録を取得
  static List<InspectionRecord> getRecordsByMachine(String machineId) {
    final records = getAllRecords();
    return records.where((record) => record.machineId == machineId).toList();
  }

  // 特定の月の点検記録を取得
  static List<InspectionRecord> getRecordsByMonth(int year, int month) {
    final records = getAllRecords();
    return records.where((record) {
      return record.inspectionDate.year == year &&
          record.inspectionDate.month == month;
    }).toList();
  }

  // IDで点検記録を取得
  Future<InspectionRecord?> getRecordById(String id) async {
    try {
      if (!Hive.isBoxOpen(recordBoxName)) {
        return null;
      }
      final recordBox = Hive.box<Map>(recordBoxName);
      final map = recordBox.get(id);
      if (map == null) return null;
      return InspectionRecord.fromMap(Map<String, dynamic>.from(map));
    } catch (e) {
      print('Error getting record: $e');
      return null;
    }
  }

  // 点検記録を保存（非static版）
  Future<void> saveRecord(InspectionRecord record) async {
    await saveInspectionRecord(record);
  }

  // 点検記録を更新
  Future<void> updateRecord(InspectionRecord record) async {
    await saveInspectionRecord(record);
  }

  // すべての記録を取得（非static版）
  Future<List<InspectionRecord>> fetchAllRecords() async {
    return DatabaseService.getAllRecords();
  }
}
