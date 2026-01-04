/// Excel出力ダウンロード - Mobile実装（機能無効）
class ExcelDownload {
  /// ファイルをダウンロード（Mobile版 - 未実装）
  static Future<void> downloadFile(List<int> bytes, String fileName) async {
    print('⚠️ Excel download is not supported on mobile platform');
    // Mobile版ではpath_providerを使ってファイル保存が可能ですが、
    // 現時点ではWeb専用機能として実装しています
  }
}
