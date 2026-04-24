import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// マスタデータ管理画面
/// 現場名、点検者名、所有会社名の追加・削除を管理
class MasterDataManagementScreen extends StatefulWidget {
  const MasterDataManagementScreen({super.key});

  @override
  State<MasterDataManagementScreen> createState() =>
      _MasterDataManagementScreenState();
}

class _MasterDataManagementScreenState
    extends State<MasterDataManagementScreen> {
  int _compareInspectorByName(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aName = (a['name'] as String? ?? '').trim();
    final bName = (b['name'] as String? ?? '').trim();
    return aName.compareTo(bName);
  }

  final FirestoreService _firestoreService = FirestoreService();

  List<String> _sites = [];
  List<Map<String, dynamic>> _inspectors = [];
  List<String> _companies = [];
  List<Map<String, String>> _companyOptions = [];
  final Set<String> _expandedCompanyIds = <String>{};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sites = await _firestoreService.getMasterData('sites');
      final inspectors = await _firestoreService.getInspectorsWithCompany();
      final companies = await _firestoreService.getMasterData('companies');
      final companyOptions = await _firestoreService.getCompanyOptions();

      setState(() {
        _sites = sites;
        _inspectors = inspectors;
        _companies = companies;
        _companyOptions = companyOptions;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ マスタデータ読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSite() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('現場名を追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '現場名',
            hintText: '例: 〇〇建設現場',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _firestoreService.addMasterData('sites', result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('現場名「$result」を追加しました')),
        );
        await _loadMasterData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteSite(String site) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('現場名を削除'),
        content: Text(
          '現場名「$site」を削除しますか？\n\nこの現場に関連する点検記録もすべて削除されます。',
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 現場削除時は関連する点検データも削除
        await _firestoreService.deleteSiteWithInspections(site);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('現場名「$site」を削除しました')),
        );
        await _loadMasterData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _addInspector() async {
    if (_companyOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に「所有会社名」を登録してください')),
      );
      return;
    }

    final controller = TextEditingController();
    String? selectedCompanyId =
        _companyOptions.isNotEmpty ? _companyOptions.first['id'] : null;
    String? selectedCompanyName =
        _companyOptions.isNotEmpty ? _companyOptions.first['name'] : null;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('点検者名を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '点検者名',
                  hintText: '例: 田中太郎',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCompanyId,
                decoration: const InputDecoration(
                  labelText: '所属会社',
                ),
                items: _companyOptions.map((company) {
                  return DropdownMenuItem<String>(
                    value: company['id'],
                    child: Text(company['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedCompanyId = value;
                    selectedCompanyName = _companyOptions
                        .firstWhere((company) => company['id'] == value)['name'];
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'name': controller.text,
                'companyId': selectedCompanyId ?? '',
                'companyName': selectedCompanyName ?? '',
              }),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );

    if (result != null &&
        (result['name'] ?? '').isNotEmpty &&
        (result['companyId'] ?? '').isNotEmpty) {
      try {
        await _firestoreService.addInspectorWithCompany(
          inspectorName: result['name']!,
          companyId: result['companyId']!,
          companyName: result['companyName'] ?? '',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点検者名「${result['name']}」を追加しました')),
        );
        await _loadMasterData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteInspector(Map<String, dynamic> inspector) async {
    final inspectorId = inspector['id'] as String? ?? '';
    final inspectorName = inspector['name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('点検者名を削除'),
        content: Text('点検者名「$inspectorName」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (inspectorId.isEmpty) {
          throw Exception('削除対象のIDが取得できません');
        }
        await _firestoreService.deleteInspectorById(inspectorId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点検者名「$inspectorName」を削除しました')),
        );
        await _loadMasterData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _addCompany() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('所有会社名を追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '所有会社名',
            hintText: '例: 松浦建設(株)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _firestoreService.addMasterData('companies', result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('所有会社名「$result」を追加しました')),
        );
        await _loadMasterData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteCompany(String company) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('所有会社名を削除'),
        content: Text('所有会社名「$company」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteMasterData('companies', company);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('所有会社名「$company」を削除しました')),
        );
        await _loadMasterData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マスタデータ管理'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 現場名セクション
                _buildSection(
                  title: '現場名',
                  icon: Icons.location_on,
                  items: _sites,
                  onAdd: _addSite,
                  onDelete: _deleteSite,
                  emptyMessage: '現場名が登録されていません',
                ),
                const SizedBox(height: 24),

                // 点検者名セクション
                _buildInspectorSection(),
                const SizedBox(height: 24),

                // 所有会社名セクション
                _buildSection(
                  title: '所有会社名',
                  icon: Icons.business,
                  items: _companies,
                  onAdd: _addCompany,
                  onDelete: _deleteCompany,
                  emptyMessage: '所有会社名が登録されていません',
                ),
              ],
            ),
    );
  }

  Widget _buildInspectorSection() {
    final groupedInspectors = <String, List<Map<String, dynamic>>>{};
    for (final company in _companyOptions) {
      final companyId = company['id'] ?? '';
      groupedInspectors[companyId] = [];
    }

    for (final inspector in _inspectors) {
      final companyId = inspector['companyId'] as String?;
      if (companyId != null && groupedInspectors.containsKey(companyId)) {
        groupedInspectors[companyId]!.add(inspector);
      }
    }

    for (final inspectors in groupedInspectors.values) {
      inspectors.sort(_compareInspectorByName);
    }

    final orderedCompanyIds = [
      ..._companyOptions
          .map((company) => company['id'] ?? '')
          .where((companyId) => (groupedInspectors[companyId] ?? []).isNotEmpty),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  '点検者名（取扱責任者）',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addInspector,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_inspectors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '点検者名が登録されていません',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...orderedCompanyIds.map((companyId) {
                final inspectors = groupedInspectors[companyId] ?? [];
                final companyName = (_companyOptions
                        .firstWhere((company) => company['id'] == companyId)['name'] ??
                    '');
                final isExpanded = _expandedCompanyIds.contains(companyId);

                return Column(
                  children: [
                    Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedCompanyIds.remove(companyId);
                            } else {
                              _expandedCompanyIds.add(companyId);
                            }
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.business, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$companyName (${inspectors.length})',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isExpanded)
                      ...inspectors.map((inspector) => Padding(
                            padding: const EdgeInsets.only(left: 14, top: 8),
                            child: ListTile(
                              tileColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: const Icon(Icons.person, size: 20),
                              title: Text(inspector['name'] as String? ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteInspector(inspector),
                              ),
                            ),
                          )),
                    const SizedBox(height: 10),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required VoidCallback onAdd,
    required Function(String) onDelete,
    required String emptyMessage,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...items.map((item) => ListTile(
                    leading: const Icon(Icons.label, size: 20),
                    title: Text(item),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onDelete(item),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
