import 'inspection_item.dart';

class Machine {
  final String id;
  final String type; // 油圧ショベル、ブルドーザなど (typeName)
  final String? typeId; // machineTypes の typeId (excavator, bulldozer等)
  final String model; // 型式
  final String unitNumber; // 号機
  final List<Map<String, dynamic>>? inspectionItems; // 点検項目リスト（オプション）

  Machine({
    required this.id,
    required this.type,
    this.typeId,
    required this.model,
    required this.unitNumber,
    this.inspectionItems,
  });

  List<InspectionItem> getInspectionItems() {
    if (inspectionItems == null) return [];
    return inspectionItems!
        .map((item) => InspectionItem.fromMap(item))
        .toList();
  }

  factory Machine.fromMap(Map<String, dynamic> map) {
    return Machine(
      id: map['id'] as String,
      type: map['type'] as String,
      typeId: map['typeId'] as String?,
      model: map['model'] as String,
      unitNumber: map['unitNumber'] as String,
      inspectionItems: map['inspectionItems'] != null
          ? List<Map<String, dynamic>>.from(map['inspectionItems'] as List)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      if (typeId != null) 'typeId': typeId,
      'model': model,
      'unitNumber': unitNumber,
      if (inspectionItems != null) 'inspectionItems': inspectionItems,
    };
  }
}
