import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/machine.dart';
import '../models/inspection_item.dart';
import '../models/inspection_record.dart';
import '../services/database_service.dart';
import '../services/cloud_sync_service.dart';

class InspectionInputScreen extends StatefulWidget {
  final String siteName;
  final String inspectorName;
  final Machine machine;

  const InspectionInputScreen({
    super.key,
    required this.siteName,
    required this.inspectorName,
    required this.machine,
  });

  @override
  State<InspectionInputScreen> createState() => _InspectionInputScreenState();
}

class _InspectionInputScreenState extends State<InspectionInputScreen> {
  final Map<String, InspectionResult> _results = {};
  final Map<String, TextEditingController> _memoControllers = {};
  final ImagePicker _picker = ImagePicker();
  DateTime _selectedDate = DateTime.now(); // 選択された点検日

  @override
  void dispose() {
    for (var controller in _memoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<InspectionItem> get _items => widget.machine.getInspectionItems();

  int get _completedCount => _results.length;
  int get _totalCount => _items.length;
  double get _progress => _totalCount > 0 ? _completedCount / _totalCount : 0;

  void _setResult(String itemCode, bool isGood) {
    setState(() {
      _results[itemCode] = InspectionResult(
        itemCode: itemCode,
        isGood: isGood,
      );
      if (!isGood) {
        _memoControllers[itemCode] ??= TextEditingController();
      }
    });
  }

  void _setAllGood() {
    setState(() {
      for (var item in _items) {
        if (!_results.containsKey(item.code)) {
          _results[item.code] = InspectionResult(
            itemCode: item.code,
            isGood: true,
          );
        }
      }
    });
  }

  Future<void> _takePicture(String itemCode) async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        final result = _results[itemCode];
        if (result != null) {
          _results[itemCode] = InspectionResult(
            itemCode: result.itemCode,
            isGood: result.isGood,
            photoPath: photo.path,
            memo: result.memo,
          );
        }
      });
    }
  }

  void _showMemoDialog(String itemCode) {
    final controller = _memoControllers[itemCode]!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('不良詳細メモ'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '不良の詳細を記入してください...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final result = _results[itemCode];
                if (result != null) {
                  _results[itemCode] = InspectionResult(
                    itemCode: result.itemCode,
                    isGood: result.isGood,
                    photoPath: result.photoPath,
                    memo: controller.text,
                  );
                }
              });
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectInspectionDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), // 過去の日付を許可
      lastDate: DateTime(2100), // 未来の日付を許可
      locale: const Locale('ja', 'JP'),
      helpText: '点検日を選択',
      cancelText: 'キャンセル',
      confirmText: '決定',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveInspection() async {
    if (_completedCount < _totalCount) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('確認'),
          content: Text(
            '未入力の項目が${_totalCount - _completedCount}件あります。\nこのまま保存しますか?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存する'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final record = InspectionRecord(
      id: '${widget.machine.id}_${DateTime.now().millisecondsSinceEpoch}',
      siteName: widget.siteName,
      inspectorName: widget.inspectorName,
      machineId: widget.machine.id,
      machineType: widget.machine.type,
      machineModel: widget.machine.model,
      machineUnitNumber: widget.machine.unitNumber,
      inspectionDate: _selectedDate, // 選択された日付を使用
      results: _results,
    );

    await DatabaseService.saveInspectionRecord(record);
    print('✅ Inspection record saved locally: ${record.id}');

    // クラウドに同期
    try {
      final cloudSync = CloudSyncService();
      await cloudSync.saveRecordToCloud(record);
      print('✅ Record synced to cloud: ${record.id}');
    } catch (e) {
      print('⚠️ Cloud sync warning: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('保存完了'),
          ],
        ),
        content: const Text('点検結果を保存しました。'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // ダイアログを閉じる
              Navigator.pop(context); // 点検画面を閉じる
              Navigator.pop(context); // 重機選択画面を閉じる
              Navigator.pop(context); // 点検者選択画面を閉じる
              Navigator.pop(context); // 現場選択画面を閉じる（ホーム画面に戻る）
            },
            child: const Text('完了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('点検入力'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_completedCount / $_totalCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ヘッダー情報
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 現場名
                const Text(
                  '現場',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  widget.siteName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '点検者',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            widget.inspectorName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '重機',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '${widget.machine.type} ${widget.machine.unitNumber}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 点検日選択ボタン
                InkWell(
                  onTap: _selectInspectionDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white54),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '点検日: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit, color: Colors.white70, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),

          // 一括入力ボタン
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _setAllGood,
                icon: const Icon(Icons.done_all),
                label: const Text(
                  '未入力項目を一括で「⚪」にする',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // 点検項目リスト
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final result = _results[item.code];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: result != null
                            ? (result.isGood
                                ? Colors.green.shade50
                                : Colors.red.shade50)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: result != null
                              ? (result.isGood ? Colors.green : Colors.red)
                              : Colors.grey.shade300,
                          width: result != null ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item.isRequired)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '★',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (item.isRequired) const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.checkPoint,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // ⚪×ボタン
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _setResult(item.code, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: result?.isGood == true
                                        ? Colors.green
                                        : Colors.white,
                                    foregroundColor: result?.isGood == true
                                        ? Colors.white
                                        : Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: Colors.green,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    '⚪ 良好',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _setResult(item.code, false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: result?.isGood == false
                                        ? Colors.red
                                        : Colors.white,
                                    foregroundColor: result?.isGood == false
                                        ? Colors.white
                                        : Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: Colors.red,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    '× 不良',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // 不良時の追加入力
                          if (result?.isGood == false) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _takePicture(item.code),
                                    icon: Icon(
                                      result!.photoPath != null
                                          ? Icons.check_circle
                                          : Icons.camera_alt,
                                    ),
                                    label: Text(
                                      result.photoPath != null
                                          ? '写真撮影済み'
                                          : '写真を撮る',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: result.photoPath != null
                                          ? Colors.green
                                          : Colors.blue,
                                      side: BorderSide(
                                        color: result.photoPath != null
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showMemoDialog(item.code),
                                    icon: Icon(
                                      result.memo?.isNotEmpty == true
                                          ? Icons.check_circle
                                          : Icons.edit_note,
                                    ),
                                    label: Text(
                                      result.memo?.isNotEmpty == true
                                          ? 'メモ入力済み'
                                          : 'メモを書く',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          result.memo?.isNotEmpty == true
                                              ? Colors.green
                                              : Colors.blue,
                                      side: BorderSide(
                                        color: result.memo?.isNotEmpty == true
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 保存ボタン
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _saveInspection,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    '点検結果を保存',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
