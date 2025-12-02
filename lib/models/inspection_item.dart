class InspectionItem {
  final String code;
  final String name;
  final String checkPoint;
  final bool isRequired; // ★マーク付きかどうか

  InspectionItem({
    required this.code,
    required this.name,
    required this.checkPoint,
    this.isRequired = false,
  });

  factory InspectionItem.fromMap(Map<String, dynamic> map) {
    return InspectionItem(
      code: map['code'] as String,
      name: map['name'] as String,
      checkPoint: map['checkPoint'] as String,
      isRequired: map['isRequired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'checkPoint': checkPoint,
      'isRequired': isRequired,
    };
  }
}
