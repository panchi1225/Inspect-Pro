import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/machine.dart';
import '../models/inspection_item.dart';
import '../models/inspection_record.dart';
import '../services/firestore_service.dart';

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
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, InspectionResult> _results = {};
  final Map<String, TextEditingController> _memoControllers = {};
  final Map<String, List<int>> _tempPhotos = {}; // 一時的な画像データ保存用
  final ImagePicker _picker = ImagePicker();
  DateTime _selectedDate = DateTime.now(); // 選択された点検日
  
  List<InspectionItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInspectionItems();
  }

  Future<void> _loadInspectionItems() async {
    if (widget.machine.typeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('重機種類IDが取得できません')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final items = await _firestoreService.getInspectionItems(widget.machine.typeId!);
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 点検項目読み込みエラー: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('点検項目の読み込みに失敗しました: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _memoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

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
      // ローカルに一時保存（アップロードは保存時に実行）
      final bytes = await photo.readAsBytes();
      
      setState(() {
        final result = _results[itemCode];
        if (result != null) {
          _results[itemCode] = InspectionResult(
            itemCode: result.itemCode,
            isGood: result.isGood,
            photoPath: 'local_temp', // 一時マーカー
            memo: result.memo,
          );
          // 画像データを一時保存
          _tempPhotos[itemCode] = bytes;
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
    // 未入力項目を自動的に「良」に設定
    for (final item in _items) {
      if (!_results.containsKey(item.code)) {
        _results[item.code] = InspectionResult(
          itemCode: item.code,
          isGood: true,
        );
      }
    }

    if (widget.machine.typeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('重機種類IDが取得できません')),
      );
      return;
    }

    // ローディング表示
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 仮のInspection IDを生成（画像アップロード用）
      final tempInspectionId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      // 画像をFirebase Storageにアップロード
      final updatedResults = <String, InspectionResult>{};
      for (final entry in _results.entries) {
        final itemCode = entry.key;
        final result = entry.value;

        if (result.photoPath == 'local_temp' && _tempPhotos.containsKey(itemCode)) {
          // 画像をアップロード
          print('📤 画像アップロード中: $itemCode');
          final photoUrl = await _firestoreService.uploadInspectionPhoto(
            inspectionId: tempInspectionId,
            itemCode: itemCode,
            imageBytes: _tempPhotos[itemCode]!,
          );

          updatedResults[itemCode] = InspectionResult(
            itemCode: result.itemCode,
            isGood: result.isGood,
            photoPath: photoUrl, // Firebase StorageのURL
            memo: result.memo,
          );
        } else {
          updatedResults[itemCode] = result;
        }
      }

      // Firestoreに保存
      await _firestoreService.saveInspection(
        siteName: widget.siteName,
        inspectorName: widget.inspectorName,
        machineId: widget.machine.id,
        machineTypeId: widget.machine.typeId!,
        machineType: widget.machine.type,
        machineModel: widget.machine.model,
        machineUnitNumber: widget.machine.unitNumber,
        date: _selectedDate,
        results: updatedResults,
      );

      print('✅ 点検記録を保存しました');

      // ローディングを閉じる
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      print('❌ 保存エラー: $e');
      // ローディングを閉じる
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
      return;
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildInspectionForm(),
    );
  }

  Widget _buildInspectionForm() {
    return Column(
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
      );
  }
}
