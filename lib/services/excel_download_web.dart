/// Excel出力ダウンロード - Web実装
import 'dart:html' as html;

class ExcelDownload {
  /// ファイルをダウンロード（Web版）
  static Future<void> downloadFile(List<int> bytes, String fileName) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
