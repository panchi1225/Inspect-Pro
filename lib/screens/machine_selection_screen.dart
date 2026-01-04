import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/master_data.dart';
import '../models/machine.dart';
import '../services/database_service.dart';
import 'inspection_input_screen.dart';

class MachineSelectionScreen extends StatefulWidget {
  final String siteName;
  final String inspectorName;

  const MachineSelectionScreen({
    super.key,
    required this.siteName,
    required this.inspectorName,
  });

  @override
  State<MachineSelectionScreen> createState() => _MachineSelectionScreenState();
}

class _MachineSelectionScreenState extends State<MachineSelectionScreen> {
  String? _selectedMachineType;
  String? _selectedUnitNumber;
  List<String> _machineTypes = [];
  List<String> _unitNumbers = [];

  @override
  void initState() {
    super.initState();
    _loadMachineTypes();
    
    // デバッグ: 全重機データを確認
    if (kDebugMode) {
      final allMachines = MasterData.getMachines();
      print('🔍 総重機台数: ${allMachines.length}台');
      print('🔍 重機リスト:');
      for (var machine in allMachines.take(5)) {
        print('   - ${machine.type} ${machine.model} ${machine.unitNumber}');
      }
      if (allMachines.length > 5) {
        print('   ... (他${allMachines.length - 5}台)');
      }
    }
  }

  void _loadMachineTypes() {
    setState(() {
      _machineTypes = MasterData.getMachineTypes();
      // デバッグ: コンソールに重機種類を出力
      if (kDebugMode) {
        print('🔍 読み込まれた重機種類: $_machineTypes');
        print('🔍 重機種類数: ${_machineTypes.length}');
      }
    });
  }

  void _onMachineTypeSelected(String? machineType) {
    setState(() {
      _selectedMachineType = machineType;
      _selectedUnitNumber = null; // 号機選択をリセット
      
      if (machineType != null) {
        // 選択した重機種類の号機リストを取得
        _unitNumbers = MasterData.getUnitNumbersForType(machineType);
      } else {
        _unitNumbers = [];
      }
    });
  }

  void _onUnitNumberSelected(String? unitNumber) {
    setState(() {
      _selectedUnitNumber = unitNumber;
    });
  }

  void _proceedToInspection() {
    if (_selectedMachineType == null || _selectedUnitNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('重機種類と号機を選択してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 選択した重機種類と号機から重機を特定
    final machines = DatabaseService.getAllMachines();
    final selectedMachine = machines.firstWhere(
      (m) => m.type == _selectedMachineType && m.unitNumber == _selectedUnitNumber,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionInputScreen(
          siteName: widget.siteName,
          inspectorName: widget.inspectorName,
          machine: selectedMachine,
        ),
      ),
    );
  }

  IconData _getMachineIcon(String type) {
    if (type.contains('ショベル')) {
      return Icons.agriculture;
    } else if (type.contains('ブルドーザ')) {
      return Icons.terrain;
    } else {
      return Icons.construction;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('重機を選択'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 現場・点検者情報表示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '現場',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.siteName,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '点検者',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.inspectorName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 重機選択エリア
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '重機種類を選択',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 重機種類選択ドロップダウン
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedMachineType,
                          hint: Row(
                            children: [
                              Icon(
                                Icons.construction,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              const Text('重機種類を選択してください'),
                            ],
                          ),
                          items: _machineTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Row(
                                children: [
                                  Icon(
                                    _getMachineIcon(type),
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      type,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _onMachineTypeSelected,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 号機選択ドロップダウン
                    if (_selectedMachineType != null) ...[
                      const Text(
                        '号機を選択',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedUnitNumber,
                            hint: Row(
                              children: [
                                Icon(
                                  Icons.tag,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                const Text('号機を選択してください'),
                              ],
                            ),
                            items: _unitNumbers.map((unitNumber) {
                              return DropdownMenuItem<String>(
                                value: unitNumber,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.tag,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(unitNumber),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _onUnitNumberSelected,
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // 次へボタン
                    ElevatedButton(
                      onPressed: (_selectedMachineType != null && _selectedUnitNumber != null)
                          ? _proceedToInspection
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: const Text(
                        '次へ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
