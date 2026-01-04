/// Excel出力ヘルパー - Mobile実装（機能無効）
class ExcelHelpers {
  /// ファイルをダウンロード（Mobile版 - 未実装）
  static Future<void> downloadFile(List<int> bytes, String fileName) async {
    print('⚠️ Excel download is not supported on mobile platform');
    // Mobile版ではpath_providerを使ってファイル保存が可能ですが、
    // 現時点ではWeb専用機能として実装しています
  }
  
  /// Excel APIにHTTPリクエストを送信（Mobile版 - 未実装）
  static Future<bool> sendExcelRequest(String url, String jsonData, String fileName) async {
    print('⚠️ Excel API request is not supported on mobile platform');
    return false;
  }
}
