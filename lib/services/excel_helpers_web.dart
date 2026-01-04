/// Excel出力ヘルパー - Web実装
import 'dart:html' as html;

class ExcelHelpers {
  /// ファイルをダウンロード（Web版）
  static Future<void> downloadFile(List<int> bytes, String fileName) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
  
  /// Excel APIにHTTPリクエストを送信（Web版）
  static Future<bool> sendExcelRequest(String url, String jsonData, String fileName) async {
    try {
      final xhr = html.HttpRequest();
      xhr.open('POST', url);
      xhr.setRequestHeader('Content-Type', 'application/json');
      xhr.responseType = 'blob';
      
      xhr.send(jsonData);
      await xhr.onLoadEnd.first;
      
      if (xhr.status == 200) {
        final blob = xhr.response;
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(blobUrl);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Excel API error: $e');
      return false;
    }
  }
}
