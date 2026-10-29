import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'package:go_router/go_router.dart';
import '../navigation/app_navigation.dart';
import '../navigation/app_back_button.dart';
import '../widgets/master_name_registration_dialog.dart';

class InspectorSelectionScreen extends StatefulWidget {
  final String siteName;
  final FirestoreService? dataSource;

  const InspectorSelectionScreen({
    super.key,
    required this.siteName,
    this.dataSource,
  });

  @override
  State<InspectorSelectionScreen> createState() =>
      _InspectorSelectionScreenState();
}

class _InspectorSelectionScreenState extends State<InspectorSelectionScreen> {
  late final FirestoreService _firestoreService = widget.dataSource ?? FirestoreService();
  String? _selectedInspector;
  String? _selectedCompanyId;
  String? _selectedCompanyName;
  bool _isChoosingCompany = true;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allInspectors = [];
  List<Map<String, dynamic>> _filteredInspectors = [];
  List<Map<String, String>> _companies = [];
  bool _isLoading = true;
  bool _isLoadingInspectors = true;
  bool _refreshing = false;
  String? _companyError;
  String? _inspectorsError;
  final Map<String, Map<String, String>> _registeredCompanies = {};
  final Map<String, Map<String, dynamic>> _registeredInspectors = {};

  @override
  void initState() {
    super.initState();
    _loadInspectors();
  }

  Future<void> _loadInspectors({bool refresh = false}) async {
    if (_refreshing) return;
    final cachedCompanies = _firestoreService.cachedInspectionCompanies;
    final cachedInspectors = _firestoreService.cachedInspectionInspectors;
    setState(() {
      _refreshing = true;
      _companyError = null;
      _inspectorsError = null;
      if (cachedCompanies != null) _companies = cachedCompanies;
      if (cachedInspectors != null) _allInspectors = cachedInspectors;
      _isLoading = cachedCompanies == null && _companies.isEmpty;
      _isLoadingInspectors = cachedInspectors == null && _allInspectors.isEmpty;
    });
    final companies = _firestoreService.getInspectionCompanyOptions(refresh: refresh);
    final inspectors = _firestoreService.getInspectionInspectors(companies: companies, refresh: refresh);
    await Future.wait<void>([
      companies.then<void>((rows) {
        if (!mounted) return;
        setState(() {
          _companies = {for (final row in rows) row['id']!: row,
            ..._registeredCompanies}.values.toList();
          _isLoading = false;
        });
      }).catchError((Object _) {
        if (!mounted) return;
        setState(() { _isLoading = false; _companyError = '会社一覧を取得できませんでした。'; });
      }),
      inspectors.then<void>((rows) {
        if (!mounted) return;
        setState(() {
          _allInspectors = {for (final row in rows) row['id'] as String: row,
            ..._registeredInspectors}.values.toList();
          _isLoadingInspectors = false;
        });
        _filterInspectors(_searchController.text);
      }).catchError((Object _) {
        if (!mounted) return;
        setState(() { _isLoadingInspectors = false; _inspectorsError = '点検者一覧を取得できませんでした。'; });
      }),
    ]);
    if (mounted) setState(() { _refreshing = false; });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _compareByName(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aName = (a['name'] as String? ?? '').trim();
    final bName = (b['name'] as String? ?? '').trim();
    return aName.compareTo(bName);
  }

  void _filterInspectors(String query) {
    if (_selectedCompanyId == null) {
      setState(() {
        _filteredInspectors = [];
      });
      return;
    }

    final inspectorsInCompany = _allInspectors.where((inspector) {
      final companyId = inspector['companyId'] as String?;
      return companyId == _selectedCompanyId;
    }).toList()
      ..sort(_compareByName);

    setState(() {
      if (query.isEmpty) {
        _filteredInspectors = inspectorsInCompany;
      } else {
        _filteredInspectors = inspectorsInCompany
            .where((inspector) =>
                (inspector['name'] as String? ?? '').contains(query))
            .toList();
      }
    });
  }

  void _selectCompany(Map<String, String> company) {
    setState(() {
      _selectedCompanyId = company['id'];
      _selectedCompanyName = company['name'];
      _selectedInspector = null;
      _isChoosingCompany = false;
      _searchController.clear();
    });
    _filterInspectors('');
  }

  Future<void> _addCompany() async {
    final company = await showDialog<Map<String, String>>(
      context: context, barrierDismissible: false,
      builder: (_) => MasterNameRegistrationDialog(label: '会社名',
        onRegister: _firestoreService.registerCompanyForInspection),
    );
    if (!mounted || company == null) return;
    setState(() {
      _registeredCompanies[company['id']!] = company;
      if (!_companies.any((c) => c['id'] == company['id'])) _companies.add(company);
    });
    _selectCompany(company);
  }

  Future<void> _addInspector() async {
    final companyId = _selectedCompanyId;
    if (companyId == null) return;
    final inspector = await showDialog<Map<String, String>>(
      context: context, barrierDismissible: false,
      builder: (_) => MasterNameRegistrationDialog(label: '点検者名',
        initialName: _searchController.text, companyName: _selectedCompanyName,
        onRegister: (name) => _firestoreService.registerInspectorForInspection(
          inspectorName: name, companyId: companyId)),
    );
    if (!mounted || inspector == null) return;
    setState(() {
      _registeredInspectors[inspector['id']!] = inspector;
      if (!_allInspectors.any((i) => i['id'] == inspector['id'])) _allInspectors.add(inspector);
      _isLoadingInspectors = false;
      _inspectorsError = null;
      _selectedInspector = inspector['name'];
      _selectedCompanyName = inspector['companyName'];
      _searchController.clear();
    });
    _filterInspectors('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('点検者を選択'),
        elevation: 0,
        actions: [IconButton(tooltip: '会社・点検者を更新',
          onPressed: _refreshing ? null : () => _loadInspectors(refresh: true),
          icon: const Icon(Icons.refresh))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            if (_companyError != null || _inspectorsError != null)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: Text(_companyError ?? _inspectorsError!)),
                  TextButton(onPressed: _refreshing ? null : () => _loadInspectors(refresh: true),
                    child: const Text('再読込')),
                ])),
            // 現場情報表示
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
                      fontSize: 14,
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
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 検索バー
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: TextField(
                controller: _searchController,
                onChanged: _filterInspectors,
                enabled: !_isChoosingCompany,
                decoration: InputDecoration(
                  hintText: _isChoosingCompany ? '先に会社を選択してください' : '点検者名で検索...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            
            if (!_isChoosingCompany && _selectedCompanyName != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '選択中の会社: $_selectedCompanyName',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isChoosingCompany = true;
                          _selectedInspector = null;
                          _searchController.clear();
                        });
                      },
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('会社を変更'),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _isChoosingCompany ? _addCompany : _addInspector,
                icon: Icon(_isChoosingCompany ? Icons.add_business : Icons.person_add),
                label: Text(_isChoosingCompany ? '会社名を追加' : '点検者名を追加'),
              )),
            ),
            // 点検者リスト
            Expanded(
              child: _isChoosingCompany
                  ? _buildCompanyList()
                  : _isLoadingInspectors && _filteredInspectors.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _inspectorsError != null && _filteredInspectors.isEmpty
                  ? const Center(child: Text('点検者を表示できません。再読込してください。'))
                  : _filteredInspectors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '該当する点検者が見つかりません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredInspectors.length,
                      itemBuilder: (context, index) {
                        final inspector = _filteredInspectors[index]['name'] as String? ?? '';
                        final isSelected = _selectedInspector == inspector;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            elevation: isSelected ? 4 : 2,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedInspector = inspector;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue.shade50
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey.shade200,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        inspector,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Colors.blue.shade900
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.blue,
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
            
            // 次へボタン
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
                    child: ElevatedButton(
                      onPressed: _selectedInspector == null
                          ? null
                          : () {
                        context.go(AppPaths.machines, extra: AppRouteData(
                          siteName: widget.siteName, inspectorName: _selectedInspector!));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '次へ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyList() {
    if (_companies.isEmpty) {
      return Center(
        child: Text(
          _companyError == null ? '会社が登録されていません' : '会社情報を表示できません。',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _companies.length,
      itemBuilder: (context, index) {
        final company = _companies[index];
        final companyId = company['id'] ?? '';
        final count = _allInspectors.where((inspector) {
          final inspectorCompanyId = inspector['companyId'] as String?;
          return inspectorCompanyId == companyId;
        }).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _selectCompany(company),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.business, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        company['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _isLoadingInspectors ? '読込中' : _inspectorsError != null ? '—' : '$count名',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
