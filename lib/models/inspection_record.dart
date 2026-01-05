class InspectionRecord {
  final String id;
  final String siteName;
  final String inspectorName;
  final String machineId;
  final String machineType;
  final String machineModel;
  final String machineUnitNumber;
  final DateTime inspectionDate;
  final String machineTypeId; // 点検項目取得用のID
  final Map<String, InspectionResult> results; // 点検項目コード -> 結果

  InspectionRecord({
    required this.id,
    required this.siteName,
    required this.inspectorName,
    required this.machineId,
    required this.machineType,
    required this.machineModel,
    required this.machineUnitNumber,
    required this.inspectionDate,
    this.machineTypeId = '', // デフォルト値
    required this.results,
  });

  factory InspectionRecord.fromMap(Map<String, dynamic> map) {
    final resultsMap = map['results'] as Map<String, dynamic>;
    return InspectionRecord(
      id: map['id'] as String,
      siteName: map['siteName'] as String? ?? '現場名未設定',
      inspectorName: map['inspectorName'] as String,
      machineId: map['machineId'] as String,
      machineType: map['machineType'] as String,
      machineModel: map['machineModel'] as String,
      machineUnitNumber: map['machineUnitNumber'] as String,
      inspectionDate: DateTime.parse(map['inspectionDate'] as String),
      machineTypeId: map['machineTypeId'] as String? ?? '',
      results: resultsMap.map(
        (key, value) => MapEntry(
          key,
          InspectionResult.fromMap(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'siteName': siteName,
      'inspectorName': inspectorName,
      'machineId': machineId,
      'machineType': machineType,
      'machineModel': machineModel,
      'machineUnitNumber': machineUnitNumber,
      'inspectionDate': inspectionDate.toIso8601String(),
      'machineTypeId': machineTypeId,
      'results': results.map((key, value) => MapEntry(key, value.toMap())),
    };
  }
}

class InspectionResult {
  final String itemCode;
  final bool isGood; // true: ⚪, false: ×
  final String? photoPath; // 写真パス(×の場合)
  final String? memo; // メモ(×の場合)

  InspectionResult({
    required this.itemCode,
    required this.isGood,
    this.photoPath,
    this.memo,
  });

  factory InspectionResult.fromMap(Map<String, dynamic> map) {
    return InspectionResult(
      itemCode: map['itemCode'] as String,
      isGood: map['isGood'] as bool,
      photoPath: map['photoPath'] as String?,
      memo: map['memo'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemCode': itemCode,
      'isGood': isGood,
      'photoPath': photoPath,
      'memo': memo,
    };
  }
}
