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
          typeId: data['typeId'],
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

  /// IDで重機を取得
  Future<Machine?> getMachineById(String id) async {
    try {
      final doc = await _firestore.collection('machines').doc(id).get();
      if (!doc.exists) {
        print('⚠️ 重機が見つかりません: $id');
        return null;
      }
      
      final data = doc.data()!;
      return Machine(
        id: doc.id,
        type: data['typeName'] ?? '',
        typeId: data['typeId'],
        model: data['model'] ?? '',
        unitNumber: data['unitNumber'] ?? '',
      );
    } catch (e) {
      print('❌ 重機取得エラー (ID: $id): $e');
      return null;
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
          name: data['label'] ?? '',
          checkPoint: data['description'] ?? '',
          isRequired: data['lawRequired'] == true,
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
    required String siteName,
    required String inspectorName,
    required String machineId,
    required String machineTypeId,
    required String machineType,
    required String machineModel,
    required String machineUnitNumber,
    required DateTime date,
    required Map<String, InspectionResult> results,
    String? memo,
  }) async {
    try {
      final resultsMap = results.map((key, value) => MapEntry(key, value.toMap()));

      await _firestore.collection('inspections').add({
        'siteName': siteName,
        'inspectorName': inspectorName,
        'machineId': machineId,
        'machineTypeId': machineTypeId,
        'machineType': machineType,
        'machineModel': machineModel,
        'machineUnitNumber': machineUnitNumber,
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
      // シンプルなクエリ（インデックス不要）
      final snapshot = await _firestore
          .collection('inspections')
          .limit(1000)
          .get();

      final inspections = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // クライアント側でソート（日付の降順）
      inspections.sort((a, b) {
        final aDate = a['date'] as String?;
        final bDate = b['date'] as String?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate); // 降順（新しい→古い）
      });
      
      return inspections;
    } catch (e) {
      print('❌ 点検記録取得エラー: $e');
      return [];
    }
  }

  // ============================================================
  // 汎用マスタデータメソッド（マスタデータ管理画面用）
  // ============================================================

  /// マスタデータを取得（現場名・点検者名・所有会社名）
  /// collectionName: 'sites', 'inspectors', 'companies'
  Future<List<String>> getMasterData(String collectionName) async {
    try {
      // 複合インデックス不要のシンプルなクエリ
      final snapshot = await _firestore
          .collection(collectionName)
          .where('isActive', isEqualTo: true)
          .get();

      // クライアント側でソート（createdAtがnullの場合は先頭へ）
      // 最後に追加したものが下部に表示されるよう昇順ソート
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'];
        final bTime = b.data()['createdAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1; // nullは先頭
        if (bTime == null) return 1;
        return aTime.compareTo(bTime); // 昇順（古い→新しい）
      });

      return docs
          .map((doc) => doc.data()['name'] as String)
          .toList();
    } catch (e) {
      print('❌ $collectionName取得エラー: $e');
      return [];
    }
  }

  /// マスタデータを追加
  Future<void> addMasterData(String collectionName, String name) async {
    try {
      await _firestore.collection(collectionName).add({
        'name': name,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ $collectionName「$name」を追加しました');
    } catch (e) {
      print('❌ $collectionName追加エラー: $e');
      throw Exception('$collectionName追加に失敗しました: $e');
    }
  }

  /// マスタデータを削除（name で検索して削除）
  Future<void> deleteMasterData(String collectionName, String name) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('$collectionName「$name」が見つかりません');
      }

      await snapshot.docs.first.reference.delete();
      print('✅ $collectionName「$name」を削除しました');
    } catch (e) {
      print('❌ $collectionName削除エラー: $e');
      throw Exception('$collectionName削除に失敗しました: $e');
    }
  }

  /// 現場を削除（関連する点検データも削除）
  Future<void> deleteSiteWithInspections(String siteName) async {
    try {
      print('🗑️ 現場「$siteName」と関連データを削除中...');

      // 1. siteNameで現場ドキュメントを取得
      final siteSnapshot = await _firestore
          .collection('sites')
          .where('name', isEqualTo: siteName)
          .limit(1)
          .get();

      if (siteSnapshot.docs.isEmpty) {
        throw Exception('現場「$siteName」が見つかりません');
      }

      final siteId = siteSnapshot.docs.first.id;

      // 2. 関連する点検データを削除（最大500件ずつ）
      while (true) {
        final inspections = await _firestore
            .collection('inspections')
            .where('siteId', isEqualTo: siteId)
            .limit(500)
            .get();

        if (inspections.docs.isEmpty) {
          break;
        }

        final batch = _firestore.batch();
        for (final doc in inspections.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        print('🗑️ 点検データ ${inspections.docs.length}件を削除しました');
      }

      // 3. 現場自体を削除
      await _firestore.collection('sites').doc(siteId).delete();
      print('✅ 現場「$siteName」を削除しました');
    } catch (e) {
      print('❌ 現場削除エラー: $e');
      throw Exception('現場削除に失敗しました: $e');
    }
  }
}
