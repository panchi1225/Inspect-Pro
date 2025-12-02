import 'package:flutter/material.dart';
import '../models/machine.dart';
import '../data/master_data.dart';
import 'inspection_input_screen.dart';

class MachineSelectionScreenV2 extends StatefulWidget {
  final String siteName;
  final String inspectorName;

  const MachineSelectionScreenV2({
    super.key,
    required this.siteName,
    required this.inspectorName,
  });

  @override
  State<MachineSelectionScreenV2> createState() => _MachineSelectionScreenV2State();
}

class _MachineSelectionScreenV2State extends State<MachineSelectionScreenV2> {
  // 重機データ（CSVから）
  final List<Map<String, String>> _machineData = [
    {'type': '油圧ショベル', 'model': 'PC200', 'unit': '1号機'},
    {'type': '油圧ショベル', 'model': 'PC200', 'unit': '2号機'},
    {'type': '油圧ショベル', 'model': 'PC200', 'unit': '3号機'},
    {'type': '油圧ショベル', 'model': 'PC200', 'unit': '4号機'},
    {'type': '油圧ショベル', 'model': 'PC200', 'unit': '5号機'},
    {'type': '油圧ショベル', 'model': 'PC200', 'unit': '6号機'},
    {'type': '油圧ショベル', 'model': 'PC200', 'unit': '7号機'},
    {'type': '油圧ショベル', 'model': 'PC200', 'unit': '8号機'},
    {'type': '油圧ショベル', 'model': 'PC138', 'unit': '1号機'},
    {'type': '油圧ショベル', 'model': 'PC138', 'unit': '2号機'},
    {'type': '油圧ショベル', 'model': 'PC138', 'unit': '3号機'},
    {'type': '油圧ショベル', 'model': 'PC138', 'unit': '4号機'},
    {'type': '油圧ショベル', 'model': 'PC138', 'unit': '5号機'},
    {'type': '油圧ショベル', 'model': 'PC58', 'unit': '1号機'},
    {'type': '油圧ショベル', 'model': 'PC30', 'unit': '1号機'},
    {'type': 'ブルドーザ', 'model': 'D37PXi', 'unit': '1号機'},
    {'type': 'ブルドーザ', 'model': 'D39PX', 'unit': '1号機'},
    {'type': 'ブルドーザ', 'model': 'D51PXi', 'unit': '1号機'},
  ];

  String? _selectedType;
  String? _selectedModel;
  String? _selectedUnit;

  List<String> get _machineTypes {
    final types = _machineData.map((m) => m['type']!).toSet().toList();
    return types;
  }

  List<String> get _models {
    if (_selectedType == null) return [];
    final models = _machineData
        .where((m) => m['type'] == _selectedType)
        .map((m) => m['model']!)
        .toSet()
        .toList();
    return models;
  }

  List<String> get _units {
    if (_selectedType == null || _selectedModel == null) return [];
    final units = _machineData
        .where((m) => m['type'] == _selectedType && m['model'] == _selectedModel)
        .map((m) => m['unit']!)
        .toList();
    return units;
  }

  // マスタデータから対応するMachineオブジェクトを検索
  Machine? _findMachine() {
    if (_selectedType == null || _selectedModel == null || _selectedUnit == null) {
      return null;
    }

    // マスタデータから重機を検索
    // type形式: "油圧ショベル(PC200)" または "ブルドーザ(D37PXi)"
    final typeWithModel = '$_selectedType($_selectedModel)';
    
    // 既存のgetMachines()から検索
    final machines = MasterData.getMachines();
    for (var machine in machines) {
      if (machine.type == typeWithModel && machine.unitNumber == _selectedUnit) {
        return machine;
      }
    }
    
    return null;
  }

  void _onTypeChanged(String? type) {
    setState(() {
      _selectedType = type;
      _selectedModel = null;
      _selectedUnit = null;
    });
  }

  void _onModelChanged(String? model) {
    setState(() {
      _selectedModel = model;
      _selectedUnit = null;
    });
  }

  void _onUnitChanged(String? unit) {
    setState(() {
      _selectedUnit = unit;
    });
  }

  void _proceedToInspection() {
    final machine = _findMachine();
    if (machine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('重機情報が見つかりません')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionInputScreen(
          siteName: widget.siteName,
          inspectorName: widget.inspectorName,
          machine: machine,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('重機選択'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // ヘッダー情報
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.siteName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.inspectorName,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3段階選択UI
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ステップ1: 重機種類選択
                    _buildSelectionCard(
                      step: '1',
                      title: '重機種類',
                      value: _selectedType,
                      items: _machineTypes,
                      onChanged: _onTypeChanged,
                      icon: Icons.category,
                    ),

                    const SizedBox(height: 16),

                    // ステップ2: 型式選択
                    _buildSelectionCard(
                      step: '2',
                      title: '型式',
                      value: _selectedModel,
                      items: _models,
                      onChanged: _onModelChanged,
                      icon: Icons.settings,
                      enabled: _selectedType != null,
                    ),

                    const SizedBox(height: 16),

                    // ステップ3: 号機選択
                    _buildSelectionCard(
                      step: '3',
                      title: '号機',
                      value: _selectedUnit,
                      items: _units,
                      onChanged: _onUnitChanged,
                      icon: Icons.numbers,
                      enabled: _selectedModel != null,
                    ),

                    const SizedBox(height: 32),

                    // 確定ボタン
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _selectedUnit != null ? _proceedToInspection : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '点検を開始',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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

  Widget _buildSelectionCard({
    required String step,
    required String title,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: enabled ? Colors.orange : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: enabled ? Colors.orange : Colors.grey),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              hintText: '$titleを選択してください',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
