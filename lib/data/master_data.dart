import '../models/machine.dart';

class MasterData {
  // 現場リスト
  static final List<String> sites = [
    'Ｒ７稲戸井調節池土砂掘削その５工事',
    'Ｒ６江戸川左岸平方村新田地先堤防整備工事',
    'Ｒ７江戸川右岸下内川地先堤防整備工事',
    'R5・6・7江戸川上流左岸河川維持工事',
    'R7・8・9江戸川上流左岸河川維持工事',
    'Ｒ７・Ｒ８目吹管内右岸河川維持工事',
    '公共運動公園周辺地区整備工事（Ｒ７芝崎地区粗造成その２',
    '県単舗装道路修繕工事（次木）',
  ];

  // 点検者リスト
  static final List<String> inspectors = [
    '松浦 善統',
    '大須賀 久敬',
    '大山 聖人',
    '品村 正人',
    '北林 信也',
    '新田 健二',
    '佐藤 和則',
    '福士 和久',
    '鳥山 潤人',
    '片野 茂夫',
    '舘松 末吉',
    '柏木 健',
    '廣崎 錦也',
    '深津 裕司',
    '新田 琳央',
    '古橋 歩夢',
    '阪本 朋樹',
    '王田 博文',
    '竹内 勝',
  ];

  // 油圧ショベルの点検項目
  static final List<Map<String, dynamic>> hydraulicExcavatorItems = [
    {
      'code': 'B2',
      'name': 'ブレーキ・旋回ロック',
      'checkPoint': '正常に作動し、確実にロックされるか。',
      'isRequired': true,
    },
    {
      'code': 'B3',
      'name': 'クラッチ',
      'checkPoint': '操作レバーの動き等は正常に作動するか。',
      'isRequired': true,
    },
    {
      'code': 'B4',
      'name': '各操作レバー及びペダル',
      'checkPoint': 'スムーズに作動し、異音や異常な動きがないか。',
      'isRequired': true,
    },
    {
      'code': 'B5',
      'name': '過負荷警報装置',
      'checkPoint': '正常に作動するか。',
      'isRequired': true,
    },
    {
      'code': 'B6',
      'name': 'エンジンの状態',
      'checkPoint': '異音や黒煙・白煙などの異常な排気はないか。',
      'isRequired': false,
    },
    {
      'code': 'B7',
      'name': '走行モータ・旋回モータ・減速',
      'checkPoint': '異音や異常な振動はないか。',
      'isRequired': false,
    },
    {
      'code': 'B8',
      'name': '各種メーター・警報器',
      'checkPoint': '各メーターは正常に作動するか、ホーンは鳴るか。',
      'isRequired': false,
    },
    {
      'code': 'B9',
      'name': '油圧シリンダー・ホース',
      'checkPoint': '傷やひび割れはないか、油漏れはないか。',
      'isRequired': false,
    },
    {
      'code': 'B10',
      'name': 'フック・ワイヤ外れ止め等つり具',
      'checkPoint': '確実に機能するか、損傷・変形はないか。',
      'isRequired': false,
    },
    {
      'code': 'B11',
      'name': 'ブーム・アーム・バケット・リンク機構',
      'checkPoint': '曲がりや損傷はないか、スムーズに作動するか。',
      'isRequired': false,
    },
    {
      'code': 'B12',
      'name': '落下防止装置',
      'checkPoint': '正常に作動するか。',
      'isRequired': false,
    },
    {
      'code': 'B13',
      'name': '水・油・燃料漏れ',
      'checkPoint': '機体全体に漏れはないか。',
      'isRequired': false,
    },
    {
      'code': 'B14',
      'name': 'バックミラー 及びモニター',
      'checkPoint': '汚れや損傷はないか、向きは適切か。',
      'isRequired': false,
    },
    {
      'code': 'B15',
      'name': '計器',
      'checkPoint': '油圧・水温・油温等は正常な数値を示しているか。',
      'isRequired': false,
    },
  ];

  // ブルドーザの点検項目
  static final List<Map<String, dynamic>> bulldozerItems = [
    {
      'code': 'B16',
      'name': 'ブレーキ',
      'checkPoint': '制動機能及び駐車ブレーキが正常に作動するか。',
      'isRequired': true,
    },
    {
      'code': 'B17',
      'name': 'クラッチ',
      'checkPoint': '切れ具合や、操作レバー・ペダルの作動は正常か。',
      'isRequired': true,
    },
    {
      'code': 'B18',
      'name': '操縦装置',
      'checkPoint': 'ステアリングレバー等はスムーズに機能するか。',
      'isRequired': true,
    },
    {
      'code': 'B19',
      'name': 'エンジンの状態',
      'checkPoint': '異音や黒煙・白煙などの異常な排気はないか。',
      'isRequired': false,
    },
    {
      'code': 'B20',
      'name': '走行モータ・減速機',
      'checkPoint': '異音や異常な振動はないか。',
      'isRequired': false,
    },
    {
      'code': 'B21',
      'name': '各種メーター・警報器',
      'checkPoint': '各メーターは正常に作動するか、ホーンは鳴るか。',
      'isRequired': false,
    },
    {
      'code': 'B22',
      'name': 'ドーザブレード',
      'checkPoint': '損傷や変形はないか、また、その作動はスムーズか。',
      'isRequired': false,
    },
    {
      'code': 'B23',
      'name': '履帯または車輪',
      'checkPoint': '摩耗、亀裂、損傷はないか、タイヤの空気圧は適正か。',
      'isRequired': false,
    },
    {
      'code': 'B24',
      'name': '水・油・燃料漏れ',
      'checkPoint': '機体全体に漏れはないか。',
      'isRequired': false,
    },
    {
      'code': 'B25',
      'name': 'バックミラー 及びモニター',
      'checkPoint': '汚れや損傷はないか、向きは適切か。',
      'isRequired': false,
    },
    {
      'code': 'B26',
      'name': '計器',
      'checkPoint': '油圧・水温・油温等は正常な数値を示しているか。',
      'isRequired': false,
    },
  ];

  // 重機マスタデータ（CSVデータに基づく）
  static List<Machine> getMachines() {
    int machineId = 1;
    final machines = <Machine>[];
    
    // 油圧ショベル(PC200) - 1～8号機
    for (int i = 1; i <= 8; i++) {
      machines.add(Machine(
        id: 'machine_${machineId.toString().padLeft(2, '0')}',
        type: '油圧ショベル(PC200)',
        model: '油圧ショベル(PC200)',
        unitNumber: '${i}号機',
        inspectionItems: hydraulicExcavatorItems,
      ));
      machineId++;
    }
    
    // 油圧ショベル(PC138) - 1～5号機
    for (int i = 1; i <= 5; i++) {
      machines.add(Machine(
        id: 'machine_${machineId.toString().padLeft(2, '0')}',
        type: '油圧ショベル(PC138)',
        model: '油圧ショベル(PC138)',
        unitNumber: '${i}号機',
        inspectionItems: hydraulicExcavatorItems,
      ));
      machineId++;
    }
    
    // 油圧ショベル(PC58) - 1号機
    machines.add(Machine(
      id: 'machine_${machineId.toString().padLeft(2, '0')}',
      type: '油圧ショベル(PC58)',
      model: '油圧ショベル(PC58)',
      unitNumber: '1号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    
    // 油圧ショベル(PC30) - 1号機
    machines.add(Machine(
      id: 'machine_${machineId.toString().padLeft(2, '0')}',
      type: '油圧ショベル(PC30)',
      model: '油圧ショベル(PC30)',
      unitNumber: '1号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    
    // ブルドーザ(D37PXi) - 1号機
    machines.add(Machine(
      id: 'machine_${machineId.toString().padLeft(2, '0')}',
      type: 'ブルドーザ(D37PXi)',
      model: 'ブルドーザ(D37PXi)',
      unitNumber: '1号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    
    // ブルドーザ(D39PX) - 1号機
    machines.add(Machine(
      id: 'machine_${machineId.toString().padLeft(2, '0')}',
      type: 'ブルドーザ(D39PX)',
      model: 'ブルドーザ(D39PX)',
      unitNumber: '1号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    
    // ブルドーザ(D51PXi) - 1号機
    machines.add(Machine(
      id: 'machine_${machineId.toString().padLeft(2, '0')}',
      type: 'ブルドーザ(D51PXi)',
      model: 'ブルドーザ(D51PXi)',
      unitNumber: '1号機',
      inspectionItems: bulldozerItems,
    ));
    
    return machines;
  }
  
  // 重機種類のリストを取得（重複なし）
  static List<String> getMachineTypes() {
    final machines = getMachines();
    final types = <String>{};
    for (var machine in machines) {
      types.add(machine.type);
    }
    return types.toList();
  }
  
  // 指定した重機種類の号機リストを取得
  static List<String> getUnitNumbersForType(String machineType) {
    final machines = getMachines();
    return machines
        .where((m) => m.type == machineType)
        .map((m) => m.unitNumber)
        .toList();
  }
}
