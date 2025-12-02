import 'inspection_item.dart';

class Machine {
  final String id;
  final String type; // 油圧ショベル、ブルドーザなど
  final String model; // 型式
  final String unitNumber; // 号機
  final List<Map<String, dynamic>> inspectionItems; // 点検項目リスト

  Machine({
    required this.id,
    required this.type,
    required this.model,
    required this.unitNumber,
    required this.inspectionItems,
  });

  List<InspectionItem> getInspectionItems() {
    return inspectionItems
        .map((item) => InspectionItem.fromMap(item))
        .toList();
  }

  factory Machine.fromMap(Map<String, dynamic> map) {
    return Machine(
      id: map['id'] as String,
      type: map['type'] as String,
      model: map['model'] as String,
      unitNumber: map['unitNumber'] as String,
      inspectionItems: List<Map<String, dynamic>>.from(
        map['inspectionItems'] as List,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'model': model,
      'unitNumber': unitNumber,
      'inspectionItems': inspectionItems,
    };
  }
}
