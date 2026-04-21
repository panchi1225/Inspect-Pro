import 'package:flutter/material.dart';
import '../models/machine.dart';
import '../services/firestore_service.dart';
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
  final FirestoreService _firestoreService = FirestoreService();
  
  List<Machine> _allMachines = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedType;
  String? _selectedModel;
  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadMachines();
  }

  Future<void> _loadMachines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _firestoreService.ensureAllModelsHaveInitialTenUnits();
      final machines = await _firestoreService.getMachines();
      setState(() {
        _allMachines = machines;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 重機データ読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> get _machineTypes {
    // CSV順を保持しながら重複を除去
    final seen = <String>{};
    final types = <String>[];
    for (var machine in _allMachines) {
      if (!seen.contains(machine.type)) {
        seen.add(machine.type);
        types.add(machine.type);
      }
    }
    return types;
  }

  List<String> get _models {
    if (_selectedType == null) return [];
    // CSV順を保持しながら重複を除去
    final seen = <String>{};
    final models = <String>[];
    for (var machine in _allMachines) {
      if (machine.type == _selectedType && !seen.contains(machine.model)) {
        seen.add(machine.model);
        models.add(machine.model);
      }
    }
    return models;
  }

  List<String> get _units {
    if (_selectedType == null || _selectedModel == null) return [];
    // CSV順をそのまま保持（FirestoreでsortOrder順に取得済み）
    final units = _allMachines
        .where((m) => m.type == _selectedType && m.model == _selectedModel)
        .map((m) => m.unitNumber)
        .toList();
    
    return units;
  }

  // マスタデータから対応するMachineオブジェクトを検索
  Machine? _findMachine() {
    if (_selectedType == null || _selectedModel == null || _selectedUnit == null) {
      return null;
    }

    // マスタデータから重機を検索（type、model、unitNumberで照合）
    for (var machine in _allMachines) {
      if (machine.type == _selectedType && 
          machine.model == _selectedModel && 
          machine.unitNumber == _selectedUnit) {
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showAddModelDialog() async {
    if (_selectedType == null) return;

    final controller = TextEditingController();
    final model = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('型式を追加'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '追加する型式名',
              hintText: '例: PC200-11',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('追加する'),
            ),
          ],
        );
      },
    );

    if (model == null) return;
    final modelName = model.trim();
    if (modelName.isEmpty) {
      _showSnackBar('型式名を入力してください');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestoreService.addModelWithInitialUnits(
        type: _selectedType!,
        model: modelName,
      );
      await _loadMachines();
      setState(() {
        _selectedModel = modelName;
        _selectedUnit = '1号機';
      });
      _showSnackBar('型式「$modelName」を追加しました（1号機〜10号機を作成）');
    } catch (e) {
      _showSnackBar('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addNextUnit() async {
    if (_selectedType == null || _selectedModel == null) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final machine = await _firestoreService.addNextUnitForModel(
        type: _selectedType!,
        model: _selectedModel!,
      );
      await _loadMachines();
      setState(() {
        _selectedUnit = machine.unitNumber;
      });
      _showSnackBar('号機「${machine.unitNumber}」を追加しました');
    } catch (e) {
      _showSnackBar('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('重機選択'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_selectedType != null && !_isSaving)
                            ? _showAddModelDialog
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('型式を追加'),
                      ),
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            (_selectedType != null && _selectedModel != null && !_isSaving)
                                ? _addNextUnit
                                : null,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('号機を追加'),
                      ),
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
