import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:ui' as ui;

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    this.title = 'マニュアル',
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final String _iframeId = 'pdf-viewer-iframe';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerIframe();
    }
  }

  void _registerIframe() {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.pdfUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.menu_book),
            const SizedBox(width: 8),
            Text(widget.title),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '閉じる',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: kIsWeb
          ? HtmlElementView(viewType: _iframeId)
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    'Web版でご利用ください',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
    );
  }
}
