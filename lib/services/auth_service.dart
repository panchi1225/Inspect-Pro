import 'package:flutter/material.dart';

/// 認証サービス - ユーザーロールとPASS検証を管理
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ユーザーロール
  UserRole? _currentRole;
  bool _isAuthenticated = false;

  // PASS設定
  static const String _inspectorPass = '1331'; // 点検者PASS
  static const String _adminPass = '4043';      // 管理者PASS

  // ゲッター
  UserRole? get currentRole => _currentRole;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInspector => _currentRole == UserRole.inspector;
  bool get isAdmin => _currentRole == UserRole.admin;

  /// PASS検証してログイン
  bool login(UserRole role, String pass) {
    final correctPass = role == UserRole.admin ? _adminPass : _inspectorPass;
    
    if (pass == correctPass) {
      _currentRole = role;
      _isAuthenticated = true;
      notifyListeners();
      print('✅ ログイン成功: ${role.displayName}');
      return true;
    } else {
      print('❌ ログイン失敗: PASS不一致');
      return false;
    }
  }

  /// ログアウト
  void logout() {
    _currentRole = null;
    _isAuthenticated = false;
    notifyListeners();
    print('🔓 ログアウト');
  }

  /// 管理者権限チェック
  bool checkAdminPermission(BuildContext context) {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('この機能は管理者のみ使用できます'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }
}

/// ユーザーロール
enum UserRole {
  inspector('点検者', '点検データ'),
  admin('管理者', '点検データ管理');

  final String displayName;
  final String screenTitle;

  const UserRole(this.displayName, this.screenTitle);
}
