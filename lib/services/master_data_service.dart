import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/master_data.dart';

/// マスタデータサービス
/// 現場名、点検者名、所有会社名の管理とクラウド同期
class MasterDataService {
  static const String _baseUrl = '/api/master';

  /// 現場名一覧を取得
  Future<List<String>> getSites() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/sites'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return List<String>.from(data['sites']);
      } else {
        // サーバーエラー時は空のリストを返す（マスタデータへのフォールバックを無効化）
        print('⚠️ 現場名取得エラー（空リスト返却）: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('⚠️ 現場名取得エラー（空リスト返却）: $e');
      return [];
    }
  }

  /// 点検者名一覧を取得
  Future<List<String>> getInspectors() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/inspectors'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return List<String>.from(data['inspectors']);
      } else {
        print('⚠️ 点検者名取得エラー（空リスト返却）: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('⚠️ 点検者名取得エラー（空リスト返却）: $e');
      return [];
    }
  }

  /// 所有会社名一覧を取得
  Future<List<String>> getCompanies() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/companies'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return List<String>.from(data['companies']);
      } else {
        return ['指定なし', '松浦建設(株)'];
      }
    } catch (e) {
      print('⚠️ 所有会社名取得エラー（ローカルデータ使用）: $e');
      return ['指定なし', '松浦建設(株)'];
    }
  }

  /// 現場名を追加
  Future<void> addSite(String site) async {
    print('📤 現場名追加: $site');
    final response = await http.post(
      Uri.parse('$_baseUrl/sites'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'siteName': site}),
    );

    if (response.statusCode != 201) {
      throw Exception('現場名の追加に失敗しました');
    }
    print('✅ 現場名追加完了: $site');
  }

  /// 現場名を削除（関連する点検記録も削除）
  Future<void> deleteSite(String site) async {
    print('📤 現場名削除: $site');
    final response = await http.delete(
      Uri.parse('$_baseUrl/sites'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'siteName': site}),
    );

    if (response.statusCode != 200) {
      throw Exception('現場名の削除に失敗しました');
    }
    print('✅ 現場名削除完了: $site');
  }

  /// 点検者名を追加
  Future<void> addInspector(String inspector) async {
    print('📤 点検者名追加: $inspector');
    final response = await http.post(
      Uri.parse('$_baseUrl/inspectors'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'inspectorName': inspector}),
    );

    if (response.statusCode != 201) {
      throw Exception('点検者名の追加に失敗しました');
    }
    print('✅ 点検者名追加完了: $inspector');
  }

  /// 点検者名を削除
  Future<void> deleteInspector(String inspector) async {
    print('📤 点検者名削除: $inspector');
    final response = await http.delete(
      Uri.parse('$_baseUrl/inspectors'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'inspectorName': inspector}),
    );

    if (response.statusCode != 200) {
      throw Exception('点検者名の削除に失敗しました');
    }
    print('✅ 点検者名削除完了: $inspector');
  }

  /// 所有会社名を追加
  Future<void> addCompany(String company) async {
    print('📤 所有会社名追加: $company');
    final response = await http.post(
      Uri.parse('$_baseUrl/companies'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'companyName': company}),
    );

    if (response.statusCode != 201) {
      throw Exception('所有会社名の追加に失敗しました');
    }
    print('✅ 所有会社名追加完了: $company');
  }

  /// 所有会社名を削除
  Future<void> deleteCompany(String company) async {
    print('📤 所有会社名削除: $company');
    final response = await http.delete(
      Uri.parse('$_baseUrl/companies'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'companyName': company}),
    );

    if (response.statusCode != 200) {
      throw Exception('所有会社名の削除に失敗しました');
    }
    print('✅ 所有会社名削除完了: $company');
  }
}
