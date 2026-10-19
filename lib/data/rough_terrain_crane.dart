import '../models/inspection_item.dart';
import '../models/inspection_record.dart';

/// 25t・50tは能力区分。実作業の能力は対象機の定格荷重表で確認する。
class RoughTerrainCrane {
  static const typeId = 'rough_terrain_crane';
  static const typeName = 'ラフタークレーン';
  static const starLegend = '★：クレーン則第78条の作業開始前点検項目';
  static const additionalLegend = 'その他：関連法令・メーカー資料等に基づく追加確認事項';
  static const guidance =
      '$starLegend\n$additionalLegend\n'
      '★の有無にかかわらず14項目すべてを確認してください。非装備部分は対象外ですが、装備される部分の未点検を良好にしないでください。'
      '機能確認・点検条件は対象機の取扱説明書に従い、主巻・補巻の停止・警報、装備されるクラッチと各操作装置を確認してください。'
      '過負荷防止装置の設定を実機（張出幅、ブーム・ジブ、巻掛本数、カウンタウエイト等）と一致させてください。'
      '異常時は使用を中止し、責任者に報告して補修等を行ってください。記録の保存は使用許可を意味しません。'
      '25t・50tだけでつれる重量は判断できません。作業半径・姿勢・張出幅等に応じた定格荷重表で管理してください。';

  static List<String> sortedUnits(Iterable<String> units) =>
      units.toList()..sort(
        (a, b) => int.parse(
          a.replaceAll('号機', ''),
        ).compareTo(int.parse(b.replaceAll('号機', ''))),
      );

  /// クライアントで並べるため既存機種のorder欠落を除外しない。
  static List<InspectionItem> validateItems(List<InspectionItem> items) {
    final sorted = List<InspectionItem>.of(items)
      ..sort((a, b) => a.code.compareTo(b.code));
    if (sorted.length != 14) throw StateError('ラフターの点検項目は14件必要です');
    for (var i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      if (item.code != 'rtc_${(i + 1).toString().padLeft(2, '0')}' ||
          item.isRequired != (i < 5) ||
          item.name.isEmpty ||
          item.checkPoint.isEmpty) {
        throw StateError('ラフターの点検マスタが不完全です');
      }
    }
    return sorted;
  }

  static bool complete(
    List<InspectionItem> items,
    Map<String, InspectionResult> results,
  ) {
    validateItems(items);
    return items.every((i) => results[i.code]?.itemCode == i.code) &&
        results.length == items.length;
  }
}
