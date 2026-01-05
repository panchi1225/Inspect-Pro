import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/inspection_record.dart';
import '../services/cloud_sync_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'record_detail_screen.dart';
// Excel出力ダイアログ（Web専用機能だが、ビルドには含める）
import 'excel_export_dialog.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<InspectionRecord> _records = [];
  List<InspectionRecord> _filteredRecords = [];
  List<String> _availableSites = [];
  String? _filterSite;
  String? _filterMachineType;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    // 画面描画後にデータをロード
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMasterData();
      _loadRecords();
    });
  }
  
  Future<void> _loadMasterData() async {
    try {
      final firestoreService = FirestoreService();
      final sites = await firestoreService.getMasterData('sites');
      setState(() {
        _availableSites = sites;
      });
    } catch (e) {
      print('❌ Failed to load master data: $e');
    }
  }

  Future<void> _loadRecords() async {
    try {
      // Firestoreから直接取得
      final firestoreService = FirestoreService();
      final inspectionData = await firestoreService.getInspections();
      print('✅ Admin screen loaded ${inspectionData.length} records from Firestore');
      
      // Map<String, dynamic> から InspectionRecord に変換
      final records = inspectionData.map((data) {
        return InspectionRecord(
          id: data['id'] ?? '',
          siteName: data['siteName'] ?? '',
          inspectorName: data['inspectorName'] ?? '',
          machineId: data['machineId'] ?? '',
          machineType: data['machineType'] ?? '',
          machineModel: data['machineModel'] ?? '',
          machineUnitNumber: data['machineUnitNumber'] ?? '',
          inspectionDate: _parseDate(data['date']),
          machineTypeId: data['machineTypeId'] ?? '', // machineTypeIdを追加
          results: (data['results'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              InspectionResult.fromMap(value as Map<String, dynamic>),
            ),
          ) ?? {},
        );
      }).toList();
      
      setState(() {
        _records = records;
        if (_records.isNotEmpty) {
          print('✅ Sample record: ${_records.first.siteName}, ${_records.first.machineType}');
        }
        _records.sort((a, b) => b.inspectionDate.compareTo(a.inspectionDate));
        _applyFilters();
        print('✅ After filter: ${_filteredRecords.length} records');
        if (_filteredRecords.isNotEmpty) {
          print('✅ Sample filtered record: ${_filteredRecords.first.siteName}');
        }
      });
    } catch (e) {
      // データ取得エラー時は空リストを使用
      print('❌ Failed to load records: $e');
      setState(() {
        _records = [];
        _applyFilters();
      });
    }
  }
  
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  void _applyFilters() {
    setState(() {
      _filteredRecords = _records.where((record) {
        // 現場フィルタ
        if (_filterSite != null && record.siteName != _filterSite) {
          return false;
        }

        // 重機種類フィルタ
        if (_filterMachineType != null &&
            record.machineType != _filterMachineType) {
          return false;
        }

        // 日付範囲フィルタ
        if (_filterStartDate != null &&
            record.inspectionDate.isBefore(_filterStartDate!)) {
          return false;
        }
        if (_filterEndDate != null &&
            record.inspectionDate.isAfter(_filterEndDate!)) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterSite = null;
      _filterMachineType = null;
      _filterStartDate = null;
      _filterEndDate = null;
      _applyFilters();
    });
  }

  String _getStatusSummary(InspectionRecord record) {
    final total = record.results.length;
    final good = record.results.values.where((r) => r.isGood).length;
    final bad = total - good;
    return '⚪:$good / ×:$bad';
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final dateFormat = DateFormat('yyyy/MM/dd');
    final machineTypes = _records.map((r) => r.machineType).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AuthService().currentRole?.screenTitle ?? '点検データ'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // フィルタセクション
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor,
            child: Column(
              children: [
                // 現場フィルタ
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: '現場',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('すべて'),
                          ),
                          ..._availableSites.map((site) => DropdownMenuItem(
                                value: site,
                                child: Text(
                                  site,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterSite = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: '重機種類',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('すべて'),
                          ),
                          ...machineTypes.map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterMachineType = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _filterStartDate != null
                              ? '期間: ${DateFormat('MM/dd').format(_filterStartDate!)} - ${DateFormat('MM/dd').format(_filterEndDate!)}'
                              : '期間を選択',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_filterSite != null ||
                    _filterMachineType != null ||
                    _filterStartDate != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('フィルタをクリア'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 統計情報
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  '総件数',
                  _filteredRecords.length.toString(),
                  Icons.list_alt,
                  Colors.blue,
                ),
                _buildStatCard(
                  '今月',
                  _filteredRecords
                      .where((r) =>
                          r.inspectionDate.month == DateTime.now().month &&
                          r.inspectionDate.year == DateTime.now().year)
                      .length
                      .toString(),
                  Icons.calendar_today,
                  Colors.green,
                ),
                _buildStatCard(
                  '今日',
                  _filteredRecords
                      .where((r) =>
                          r.inspectionDate.day == DateTime.now().day &&
                          r.inspectionDate.month == DateTime.now().month &&
                          r.inspectionDate.year == DateTime.now().year)
                      .length
                      .toString(),
                  Icons.today,
                  Colors.orange,
                ),
              ],
            ),
          ),

          // 記録リスト
          Expanded(
            child: _filteredRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _records.isEmpty
                              ? '点検記録がありません\n\n点検を実施してデータを作成してください'
                              : 'フィルタ条件に一致する記録がありません',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadRecords,
                          icon: const Icon(Icons.refresh),
                          label: const Text('再読み込み'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = _filteredRecords[index];
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      RecordDetailScreen(record: record),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          record.machineType,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        record.machineUnitNumber,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _getStatusSummary(record),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        record.inspectorName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateFormat.format(record.inspectionDate),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              // データを再読み込み
              _loadRecords();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ データを再読み込みしました (${_filteredRecords.length}件)'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            heroTag: 'sync',
            icon: const Icon(Icons.refresh),
            label: const Text('再読み込み'),
            backgroundColor: Colors.blue,
          ),
          const SizedBox(height: 12),
          // Excel出力ボタン(管理者のみ表示、Web専用)
          if (authService.isAdmin && kIsWeb) ...[
            FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ExcelExportDialog(),
                );
              },
              heroTag: 'export',
              icon: const Icon(Icons.download),
              label: const Text('Excel出力'),
              backgroundColor: Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
