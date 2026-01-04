/// Excel出力ヘルパー - プラットフォーム非依存インターフェース
class ExcelHelpers {
  /// ファイルをダウンロード
  static Future<void> downloadFile(List<int> bytes, String fileName) async {
    throw UnimplementedError('ExcelHelpers.downloadFile() is not implemented for this platform');
  }
  
  /// Excel APIにHTTPリクエストを送信
  static Future<bool> sendExcelRequest(String url, String jsonData, String fileName) async {
    throw UnimplementedError('ExcelHelpers.sendExcelRequest() is not implemented for this platform');
  }
}
