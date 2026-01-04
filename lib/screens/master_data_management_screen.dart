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
  final FirestoreService _firestoreService = FirestoreService();

  List<String> _sites = [];
  List<String> _inspectors = [];
  List<String> _companies = [];

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
      final inspectors = await _firestoreService.getMasterData('inspectors');
      final companies = await _firestoreService.getMasterData('companies');

      setState(() {
        _sites = sites;
        _inspectors = inspectors;
        _companies = companies;
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
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('点検者名を追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '点検者名',
            hintText: '例: 田中太郎',
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
        await _firestoreService.addMasterData('inspectors', result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点検者名「$result」を追加しました')),
        );
        await _loadMasterData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteInspector(String inspector) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('点検者名を削除'),
        content: Text('点検者名「$inspector」を削除しますか？'),
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
        await _firestoreService.deleteMasterData('inspectors', inspector);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点検者名「$inspector」を削除しました')),
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
                _buildSection(
                  title: '点検者名（取扱責任者）',
                  icon: Icons.person,
                  items: _inspectors,
                  onAdd: _addInspector,
                  onDelete: _deleteInspector,
                  emptyMessage: '点検者名が登録されていません',
                ),
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
