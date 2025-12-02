import 'package:flutter/material.dart';
import '../models/machine.dart';
import '../data/master_data.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../services/python_excel_service.dart';

class ExcelExportDialog extends StatefulWidget {
  final bool usePythonBackend;
  
  const ExcelExportDialog({super.key, this.usePythonBackend = false});

  @override
  State<ExcelExportDialog> createState() => _ExcelExportDialogState();
}

class _ExcelExportDialogState extends State<ExcelExportDialog> {
  String? _selectedSite;
  String? _selectedMachineId;
  String? _selectedCompanyName;
  String? _selectedResponsiblePerson;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isExporting = false;

  List<Machine> _machines = [];

  @override
  void initState() {
    super.initState();
    _loadMachines();
  }

  void _loadMachines() {
    setState(() {
      _machines = DatabaseService.getAllMachines();
    });
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
      final filePath = await PythonExcelService.generateMonthlyReportWithPython(
        machineId: _selectedMachineId!,
        year: _selectedYear,
        month: _selectedMonth,
        siteName: _selectedSite,
        companyName: _selectedCompanyName,
        responsiblePerson: _selectedResponsiblePerson,
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

            // 現場選択
            const Text(
              '現場を選択（任意）',
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
              hint: const Text('現場を選択（任意）'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('指定なし'),
                ),
                ...MasterData.sites.map((site) {
                  return DropdownMenuItem(
                    value: site,
                    child: Text(site, style: const TextStyle(fontSize: 13)),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedSite = value;
                });
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
              hint: const Text('重機を選択してください'),
              items: _machines.map((machine) {
                return DropdownMenuItem(
                  value: machine.id,
                  child: Text(
                    '${machine.type} ${machine.unitNumber} (${machine.model})',
                  ),
                );
              }).toList(),
              onChanged: (value) {
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
              items: const [
                DropdownMenuItem(
                  value: null,
                  child: Text('指定なし'),
                ),
                DropdownMenuItem(
                  value: '松浦建設(株)',
                  child: Text('松浦建設(株)', style: TextStyle(fontSize: 13)),
                ),
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
                ...MasterData.inspectors.map((inspector) {
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

            // 年月選択
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
