/// Excel出力ダウンロード - プラットフォーム非依存インターフェース

/// ダウンロード実装（スタブ）
void downloadExcelWeb(List<int> bytes, String fileName) {
  throw UnimplementedError('downloadExcelWeb() is not implemented for this platform');
}

class ExcelDownload {
  /// ファイルをダウンロード
  static Future<void> downloadFile(List<int> bytes, String fileName) async {
    throw UnimplementedError('ExcelDownload.downloadFile() is not implemented for this platform');
  }
}
