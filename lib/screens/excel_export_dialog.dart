import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/machine.dart';
import '../models/inspection_record.dart';
import '../data/master_data.dart';
import '../services/database_service.dart';
import '../services/python_excel_service.dart';
import '../services/web_excel_service.dart';
import '../services/master_data_service.dart';
import '../services/firestore_service.dart';

class ExcelExportDialog extends StatefulWidget {
  final bool usePythonBackend;
  
  const ExcelExportDialog({super.key, this.usePythonBackend = false});

  @override
  State<ExcelExportDialog> createState() => _ExcelExportDialogState();
}

class _ExcelExportDialogState extends State<ExcelExportDialog> {
  final MasterDataService _masterDataService = MasterDataService();
  final FirestoreService _firestoreService = FirestoreService();
  
  String? _selectedSite;
  String? _selectedMachineId;
  String? _selectedCompanyName;
  String? _selectedResponsiblePerson;
  String? _selectedPrimeContractorInspector; // 元請点検責任者
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isExporting = false;
  bool _isLoading = true;

  List<Machine> _machines = [];
  List<Machine> _filteredMachines = [];
  List<String> _sites = [];
  List<String> _inspectors = [];
  List<String> _companies = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Firestoreからマスタデータを取得
      final sites = await _firestoreService.getMasterData('sites');
      final inspectors = await _firestoreService.getMasterData('inspectors');
      final companies = await _firestoreService.getMasterData('companies');
      final machines = await _firestoreService.getMachines();
      
      print('✅ Excel出力: 現場 ${sites.length}件, 点検者 ${inspectors.length}件, 会社 ${companies.length}件, 重機 ${machines.length}台');

      setState(() {
        _sites = sites.isNotEmpty ? sites : [];
        _inspectors = inspectors.isNotEmpty ? inspectors : [];
        _companies = companies.isNotEmpty ? companies : [];
        _machines = machines;
        _isLoading = false;
      });
      
      // 重機リストをフィルタリング
      await _updateFilteredMachines();
    } catch (e) {
      print('❌ マスタデータ読み込みエラー: $e');
      setState(() {
        _sites = [];
        _inspectors = [];
        _companies = [];
        _machines = [];
        _isLoading = false;
      });
    }
  }

  /// 選択された現場に関連する点検データがある重機のみをフィルタリング
  Future<void> _updateFilteredMachines() async {
    if (_selectedSite == null) {
      // 現場未選択時は全重機を表示
      setState(() {
        _filteredMachines = _machines;
      });
      print('🔍 現場未選択: 全重機を表示 (${_machines.length}台)');
    } else {
      print('🔍 現場選択: $_selectedSite');
      
      // Firestoreから点検記録を取得
      final inspectionData = await _firestoreService.getInspections();
      print('📦 取得した点検記録: ${inspectionData.length}件');
      
      // Map<String, dynamic>からInspectionRecordに変換
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
          machineTypeId: data['machineTypeId'] ?? '',
          results: (data['results'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              InspectionResult.fromMap(value as Map<String, dynamic>),
            ),
          ) ?? {},
        );
      }).toList();
      
      final siteRecords = records.where((r) => r.siteName == _selectedSite).toList();
      
      print('🔍 現場 "$_selectedSite" の点検記録: ${siteRecords.length}件（Firestoreから取得）');
      
      // 重機の機種・型式・号機の組み合わせでフィルタリング（IDではなく）
      final machineKeys = siteRecords
          .map((r) => '${r.machineType}|${r.machineModel}|${r.machineUnitNumber}')
          .toSet();
      
      print('🔍 点検データがある重機（機種|型式|号機）: ${machineKeys.join(", ")}');
      
      // 該当する重機のみフィルタリング
      setState(() {
        _filteredMachines = _machines
            .where((machine) {
              final key = '${machine.type}|${machine.model}|${machine.unitNumber}';
              return machineKeys.contains(key);
            })
            .toList();
      });
      
      print('✅ フィルタリング後の重機数: ${_filteredMachines.length}');
      
      if (_filteredMachines.isEmpty) {
        print('⚠️  該当する重機が見つかりません。');
        print('   登録されている重機:');
        for (var machine in _machines.take(5)) {
          print('      ${machine.type}|${machine.model}|${machine.unitNumber}');
        }
      }
    }
  }

  Future<void> _exportExcel() async {
    if (_selectedMachineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('重機を選択してください')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // Web環境ではクライアント側でExcel生成、それ以外はPython API使用
      final filePath = kIsWeb
          ? await WebExcelService.generateMonthlyReport(
              machineId: _selectedMachineId!,
              year: _selectedYear,
              month: _selectedMonth,
              siteName: _selectedSite,
              companyName: _selectedCompanyName,
              responsiblePerson: _selectedResponsiblePerson,
              primeContractorInspector: _selectedPrimeContractorInspector,
            )
          : await PythonExcelService.generateMonthlyReportWithPython(
              machineId: _selectedMachineId!,
              year: _selectedYear,
              month: _selectedMonth,
              siteName: _selectedSite,
              companyName: _selectedCompanyName,
              responsiblePerson: _selectedResponsiblePerson,
              primeContractorInspector: _selectedPrimeContractorInspector,
            );

      if (!mounted) return;

      if (filePath != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('出力完了'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Excelファイルを生成しました。'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '保存先:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        filePath,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Web版では、ダウンロードフォルダをご確認ください。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // ダイアログを閉じる
                  Navigator.pop(context); // Excel出力ダイアログを閉じる
                },
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel出力に失敗しました')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('マスタデータを読み込み中...'),
            ],
          ),
        ),
      );
    }
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.table_chart,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Excel出力',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '月次点検記録をExcel形式で出力',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 年月選択（最初に配置）
            const Text(
              '対象年月',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: InputDecoration(
                      labelText: '年',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: List.generate(5, (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text('$year年'),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedYear = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: InputDecoration(
                      labelText: '月',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text('$month月'),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedMonth = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 現場選択
            const Text(
              '現場を選択',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              hint: const Text('現場を選択'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('指定なし'),
                ),
                ..._sites.map((site) {
                  return DropdownMenuItem(
                    value: site,
                    child: Text(site, style: const TextStyle(fontSize: 13)),
                  );
                }),
              ],
              onChanged: (value) async {
                setState(() {
                  _selectedSite = value;
                  _selectedMachineId = null; // 現場変更時は重機選択をリセット
                });
                await _updateFilteredMachines(); // 重機リストを更新（サーバーから取得）
              },
            ),
            const SizedBox(height: 20),

            // 重機選択
            const Text(
              '重機を選択',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedMachineId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              hint: Text(
                _selectedSite != null && _filteredMachines.isEmpty
                    ? '選択した現場に点検データがありません'
                    : '重機を選択してください',
                style: TextStyle(
                  color: _selectedSite != null && _filteredMachines.isEmpty
                      ? Colors.red
                      : null,
                ),
              ),
              items: _filteredMachines.isEmpty
                  ? null
                  : _filteredMachines.map((machine) {
                      return DropdownMenuItem(
                        value: machine.id,
                        child: Text(
                          '${machine.type} ${machine.unitNumber} (${machine.model})',
                        ),
                      );
                    }).toList(),
              onChanged: _filteredMachines.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _selectedMachineId = value;
                      });
                    },
            ),
            const SizedBox(height: 20),

            // 所有会社名選択
            const Text(
              '所有会社名',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCompanyName,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              hint: const Text('所有会社名を選択（任意）'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('指定なし'),
                ),
                ..._companies.map((company) {
                  return DropdownMenuItem(
                    value: company,
                    child: Text(company, style: const TextStyle(fontSize: 13)),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCompanyName = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // 取扱責任者（点検者）選択
            const Text(
              '取扱責任者（点検者）',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedResponsiblePerson,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              hint: const Text('取扱責任者を選択（任意）'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('指定なし'),
                ),
                ..._inspectors.map((inspector) {
                  return DropdownMenuItem(
                    value: inspector,
                    child: Text(inspector, style: const TextStyle(fontSize: 13)),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedResponsiblePerson = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // 元請点検責任者選択
            const Text(
              '元請点検責任者',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPrimeContractorInspector,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              hint: const Text('元請点検責任者を選択（任意）'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('指定なし'),
                ),
                ..._inspectors.map((inspector) {
                  return DropdownMenuItem(
                    value: inspector,
                    child: Text(inspector, style: const TextStyle(fontSize: 13)),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPrimeContractorInspector = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isExporting ? null : () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportExcel,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isExporting ? '出力中...' : 'Excel出力'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
