/// Excel出力ダウンロード - プラットフォーム非依存インターフェース
class ExcelDownload {
  /// ファイルをダウンロード
  static Future<void> downloadFile(List<int> bytes, String fileName) async {
    throw UnimplementedError('ExcelDownload.downloadFile() is not implemented for this platform');
  }
}
