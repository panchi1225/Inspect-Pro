import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/machine.dart';
import '../models/inspection_item.dart';
import '../models/inspection_record.dart';

/// Firestoreサービス - Firebase Cloud Firestoreとの統合
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // マスタデータ管理
  // ============================================================

  /// 現場リストを取得（isActive == true のみ）
  Future<List<Map<String, dynamic>>> getSites() async {
    try {
      final snapshot = await _firestore
          .collection('sites')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ 現場取得エラー: $e');
      return [];
    }
  }

  /// 現場を追加
  Future<bool> addSite(String siteName) async {
    try {
      await _firestore.collection('sites').add({
        'name': siteName,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ 現場追加: $siteName');
      return true;
    } catch (e) {
      print('❌ 現場追加エラー: $e');
      return false;
    }
  }

  /// 現場を削除（関連する点検データもすべて削除）
  Future<bool> deleteSite(String siteId) async {
    try {
      // 1. 関連する点検データを取得
      final inspections = await _firestore
          .collection('inspections')
          .where('siteId', isEqualTo: siteId)
          .get();

      print('🗑️ 現場削除: 関連点検データ ${inspections.docs.length}件を削除します');

      // 2. バッチで点検データを削除（500件ずつ）
      final batches = <WriteBatch>[];
      var currentBatch = _firestore.batch();
      var operationCount = 0;

      for (final doc in inspections.docs) {
        currentBatch.delete(doc.reference);
        operationCount++;

        if (operationCount >= 500) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      // バッチコミット
      for (final batch in batches) {
        await batch.commit();
      }

      print('✅ 点検データ ${inspections.docs.length}件を削除しました');

      // 3. 現場自体を削除
      await _firestore.collection('sites').doc(siteId).delete();
      print('✅ 現場を削除しました');

      return true;
    } catch (e) {
      print('❌ 現場削除エラー: $e');
      return false;
    }
  }

  /// 点検者リストを取得
  Future<List<Map<String, dynamic>>> getInspectors() async {
    try {
      final snapshot = await _firestore
          .collection('inspectors')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ 点検者取得エラー: $e');
      return [];
    }
  }

  /// 点検者を追加
  Future<bool> addInspector(String inspectorName) async {
    try {
      await _firestore.collection('inspectors').add({
        'name': inspectorName,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('❌ 点検者追加エラー: $e');
      return false;
    }
  }

  /// 点検者を削除
  Future<bool> deleteInspector(String inspectorId) async {
    try {
      await _firestore.collection('inspectors').doc(inspectorId).delete();
      return true;
    } catch (e) {
      print('❌ 点検者削除エラー: $e');
      return false;
    }
  }

  /// 所有会社リストを取得
  Future<List<Map<String, dynamic>>> getCompanies() async {
    try {
      final snapshot = await _firestore
          .collection('companies')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ 所有会社取得エラー: $e');
      return [];
    }
  }

  /// 所有会社を追加
  Future<bool> addCompany(String companyName) async {
    try {
      await _firestore.collection('companies').add({
        'name': companyName,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('❌ 所有会社追加エラー: $e');
      return false;
    }
  }

  /// 所有会社を削除
  Future<bool> deleteCompany(String companyId) async {
    try {
      await _firestore.collection('companies').doc(companyId).delete();
      return true;
    } catch (e) {
      print('❌ 所有会社削除エラー: $e');
      return false;
    }
  }

  // ============================================================
  // 重機データ
  // ============================================================

  /// 重機リストを取得
  Future<List<Machine>> getMachines() async {
    try {
      final snapshot = await _firestore
          .collection('machines')
          .where('isActive', isEqualTo: true)
          .get();

      final machines = <Machine>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        machines.add(Machine(
          id: doc.id,
          type: data['typeName'] ?? '',
          model: data['model'] ?? '',
          unitNumber: data['unitNumber'] ?? '',
        ));
      }

      return machines;
    } catch (e) {
      print('❌ 重機取得エラー: $e');
      return [];
    }
  }

  /// 重機種類別の点検項目を取得
  Future<List<InspectionItem>> getInspectionItems(String typeId) async {
    try {
      final snapshot = await _firestore
          .collection('machineTypes')
          .doc(typeId)
          .collection('items')
          .orderBy('order')
          .get();

      final items = <InspectionItem>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        items.add(InspectionItem(
          code: doc.id,
          label: data['label'] ?? '',
          description: data['description'] ?? '',
          type: data['type'] ?? 'choice',
          choices: (data['choices'] as List?)?.cast<String>() ?? ['good', 'bad'],
          lawRequired: data['lawRequired'] == true,
        ));
      }

      return items;
    } catch (e) {
      print('❌ 点検項目取得エラー: $e');
      return [];
    }
  }

  // ============================================================
  // 点検記録
  // ============================================================

  /// 点検記録を保存
  Future<bool> saveInspection({
    required String siteId,
    required String inspectorId,
    required String machineId,
    required String machineTypeId,
    required DateTime date,
    required Map<String, InspectionResult> results,
    String? memo,
  }) async {
    try {
      final resultsMap = results.map((key, value) => MapEntry(key, value.toMap()));

      await _firestore.collection('inspections').add({
        'siteId': siteId,
        'inspectorId': inspectorId,
        'machineId': machineId,
        'machineTypeId': machineTypeId,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'results': resultsMap,
        'memo': memo ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ 点検記録を保存しました');
      return true;
    } catch (e) {
      print('❌ 点検記録保存エラー: $e');
      return false;
    }
  }

  /// 点検記録を取得（管理画面用）
  Future<List<Map<String, dynamic>>> getInspections() async {
    try {
      final snapshot = await _firestore
          .collection('inspections')
          .orderBy('date', descending: true)
          .limit(1000)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ 点検記録取得エラー: $e');
      return [];
    }
  }
}
