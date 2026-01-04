import '../models/machine.dart';

class MasterData {
  // 現場リスト（マスタデータ管理画面で管理）
  static final List<String> sites = [];

  // 点検者リスト（マスタデータ管理画面で管理）
  static final List<String> inspectors = [];

  // 油圧ショベルの点検項目
  static final List<Map<String, dynamic>> hydraulicExcavatorItems = [
    {
      'code': 'H1',
      'name': 'ブレーキ・旋回ロック',
      'checkPoint': '正常に作動し、確実にロックされるか。',
      'isRequired': true,
    },
    {
      'code': 'H2',
      'name': 'クラッチ',
      'checkPoint': '正常に作動するか。（操作レバーの動き等）',
      'isRequired': true,
    },
    {
      'code': 'H3',
      'name': 'コントローラー（各操作レバー・ペダル）',
      'checkPoint': 'スムーズに作動し、異音や異常な動きがないか。',
      'isRequired': true,
    },
    {
      'code': 'H4',
      'name': '過負荷警報装置',
      'checkPoint': '正常に作動するか。',
      'isRequired': true,
    },
    {
      'code': 'H5',
      'name': 'エンジンの状態',
      'checkPoint': '異音や黒煙・白煙などの異常な排気はないか。',
      'isRequired': false,
    },
    {
      'code': 'H6',
      'name': '走行モータ・旋回モータ・減速機',
      'checkPoint': '異音や異常な振動はないか。',
      'isRequired': false,
    },
    {
      'code': 'H7',
      'name': '各種メーター・警報器',
      'checkPoint': '各メーターは正常に作動するか、ホーンは鳴るか。',
      'isRequired': false,
    },
    {
      'code': 'H8',
      'name': '油圧シリンダー・ホース',
      'checkPoint': '傷やひび割れはないか、油漏れはないか。',
      'isRequired': false,
    },
    {
      'code': 'H9',
      'name': 'フック・ワイヤ外れ止め等つり具',
      'checkPoint': '確実に機能するか、損傷・変形はないか。',
      'isRequired': false,
    },
    {
      'code': 'H10',
      'name': 'ブーム・アーム・バケット・リンク機構',
      'checkPoint': '曲がりや損傷はないか、スムーズに作動するか。',
      'isRequired': false,
    },
    {
      'code': 'H11',
      'name': '落下防止装置（機能）',
      'checkPoint': '正常に作動するか。',
      'isRequired': false,
    },
    {
      'code': 'H12',
      'name': '水・油・燃料漏れ',
      'checkPoint': '機体全体に漏れはないか。',
      'isRequired': false,
    },
    {
      'code': 'H13',
      'name': 'バックミラー',
      'checkPoint': '汚れや損傷はないか、向きは適切か。',
      'isRequired': false,
    },
    {
      'code': 'H14',
      'name': '計器（油圧・水温・油温等）',
      'checkPoint': '正常な数値を示しているか。',
      'isRequired': false,
    },
  ];

  // ブルドーザの点検項目
  static final List<Map<String, dynamic>> bulldozerItems = [
    {
      'code': 'B1',
      'name': 'ブレーキ',
      'checkPoint': '制動機能及び駐車ブレーキが正常に作動するか。',
      'isRequired': true,
    },
    {
      'code': 'B2',
      'name': 'クラッチ',
      'checkPoint': '切れ具合や、操作レバー・ペダルの作動は正常か。',
      'isRequired': true,
    },
    {
      'code': 'B3',
      'name': '操縦装置（ステアリングレバー等）',
      'checkPoint': 'スムーズに機能するか。',
      'isRequired': true,
    },
    {
      'code': 'B4',
      'name': 'エンジンの状態',
      'checkPoint': '異音や黒煙・白煙などの異常な排気はないか。',
      'isRequired': false,
    },
    {
      'code': 'B5',
      'name': '走行モータ・減速機',
      'checkPoint': '異音や異常な振動はないか。',
      'isRequired': false,
    },
    {
      'code': 'B6',
      'name': '各種メーター・警報器',
      'checkPoint': '各メーターは正常に作動するか、ホーンは鳴るか。',
      'isRequired': false,
    },
    {
      'code': 'B7',
      'name': 'ドーザブレード・リッパー',
      'checkPoint': '損傷や変形はないか、また、その作動はスムーズか 。',
      'isRequired': false,
    },
    {
      'code': 'B8',
      'name': '履帯または車輪',
      'checkPoint': '摩耗、亀裂、損傷はないか、タイヤの空気圧は適正か。',
      'isRequired': false,
    },
    {
      'code': 'B9',
      'name': '水・油・燃料漏れ',
      'checkPoint': '機体全体に漏れはないか。',
      'isRequired': false,
    },
    {
      'code': 'B10',
      'name': 'バックミラー',
      'checkPoint': '汚れや損傷はないか、向きは適切か。',
      'isRequired': false,
    },
    {
      'code': 'B11',
      'name': '計器（油圧・水温・油温等）',
      'checkPoint': '正常な数値を示しているか。',
      'isRequired': false,
    },
  ];

  // 不整地運搬車の点検項目
  static final List<Map<String, dynamic>> roughTerrainCarrierItems = [
    {
      'code': 'R1',
      'name': '制動装置（ブレーキ）',
      'checkPoint': '制動機能及び駐車ブレーキが正常に作動するか。',
      'isRequired': true,
    },
    {
      'code': 'R2',
      'name': '操縦装置（ステアリングやレバー）',
      'checkPoint': '正常に機能しているか。',
      'isRequired': true,
    },
    {
      'code': 'R3',
      'name': 'クラッチ（クラッチペダルやレバー）',
      'checkPoint': 'スムーズに動き、遊びや操作力が適切か。',
      'isRequired': true,
    },
    {
      'code': 'R4',
      'name': '荷役装置',
      'checkPoint': '荷台の上下動作に異音やガタつきがないか。',
      'isRequired': true,
    },
    {
      'code': 'R5',
      'name': '油圧装置',
      'checkPoint': '作動油量は適正か、ホースや配管に油漏れはないか。',
      'isRequired': true,
    },
    {
      'code': 'R6',
      'name': '履帯または車輪',
      'checkPoint': '摩耗、亀裂、損傷はないか、タイヤの空気圧は適正か。',
      'isRequired': true,
    },
    {
      'code': 'R7',
      'name': '前照灯・尾灯・方向指示器',
      'checkPoint': '正常に点灯、点滅するか。',
      'isRequired': true,
    },
    {
      'code': 'R8',
      'name': '警報装置',
      'checkPoint': 'ホーン、バックアップアラームは正常に作動するか。',
      'isRequired': true,
    },
    {
      'code': 'R9',
      'name': 'エンジンの状態',
      'checkPoint': '異音や異常な排気色はないか。',
      'isRequired': false,
    },
    {
      'code': 'R10',
      'name': '各種メーター・警報器',
      'checkPoint': '各メーターは正常に作動するか、警告ランプはないか。',
      'isRequired': false,
    },
    {
      'code': 'R11',
      'name': '水・油・燃料漏れ',
      'checkPoint': '機体全体に漏れはないか。',
      'isRequired': false,
    },
    {
      'code': 'R12',
      'name': '運転室・運転操作関連',
      'checkPoint': '操作に支障をきたす物や、損傷はないか。',
      'isRequired': false,
    },
    {
      'code': 'R13',
      'name': 'バックミラー',
      'checkPoint': '汚れや損傷はないか、向きは適切か。',
      'isRequired': false,
    },
    {
      'code': 'R14',
      'name': '計器（油圧・水温・油温等）',
      'checkPoint': '正常な数値を示しているか。',
      'isRequired': false,
    },
  ];

  // コンバインドローラーの点検項目
  static final List<Map<String, dynamic>> combinedRollerItems = [
    {
      'code': 'C1',
      'name': '操向・駐車ブレーキ・ロック',
      'checkPoint': '効きはよいか。確実にロックできるか。',
      'isRequired': true,
    },
    {
      'code': 'C2',
      'name': '主クラッチ',
      'checkPoint': '作動はよいか。ペダル等の遊びはないか。',
      'isRequired': true,
    },
    {
      'code': 'C3',
      'name': '逆転機（クラッチ）',
      'checkPoint': '切れはよいか。滑りはないか。',
      'isRequired': true,
    },
    {
      'code': 'C4',
      'name': 'エンジン駆動',
      'checkPoint': '始動・排気色はよいか。異音はないか。',
      'isRequired': false,
    },
    {
      'code': 'C5',
      'name': '走行用油圧ポンプ',
      'checkPoint': '異音はないか。作動はよいか。',
      'isRequired': false,
    },
    {
      'code': 'C6',
      'name': '駆動油圧モータ',
      'checkPoint': '作動はよいか。油漏れ・異音はないか。',
      'isRequired': false,
    },
    {
      'code': 'C7',
      'name': '操向ハンドル',
      'checkPoint': '作動はよいか。ガタはないか。',
      'isRequired': false,
    },
    {
      'code': 'C8',
      'name': 'バックミラー',
      'checkPoint': '角度はよいか。汚れはないか。',
      'isRequired': false,
    },
    {
      'code': 'C9',
      'name': '警報装置・灯火装置',
      'checkPoint': '警報は鳴るか。点滅するか。',
      'isRequired': false,
    },
    {
      'code': 'C10',
      'name': '計器（油圧､水温､油温等）',
      'checkPoint': '正常の範囲を示しているか。',
      'isRequired': false,
    },
  ];

  // 振動ローラーの点検項目
  static final List<Map<String, dynamic>> vibratoryRollerItems = [
    {
      'code': 'V1',
      'name': '主クラッチ',
      'checkPoint': '作動はよいか。ペダル等の遊びはないか。',
      'isRequired': true,
    },
    {
      'code': 'V2',
      'name': '駐車ブレーキ・ロック',
      'checkPoint': '効きはよいか。確実にロックできるか。',
      'isRequired': true,
    },
    {
      'code': 'V3',
      'name': '計器（油圧､水温､油温等）',
      'checkPoint': '正常の範囲を示しているか。',
      'isRequired': false,
    },
    {
      'code': 'V4',
      'name': 'エンジン駆動',
      'checkPoint': '始動・排気色はよいか。異音はないか。',
      'isRequired': false,
    },
    {
      'code': 'V5',
      'name': '操向ハンドル',
      'checkPoint': '作動はよいか。ガタはないか。',
      'isRequired': false,
    },
    {
      'code': 'V6',
      'name': 'バックミラー',
      'checkPoint': '角度はよいか。汚れはないか。',
      'isRequired': false,
    },
    {
      'code': 'V7',
      'name': '警報装置・灯火装置',
      'checkPoint': '警報は鳴るか。点滅するか。',
      'isRequired': false,
    },
  ];

  // ハンドガイド式除草機の点検項目
  static final List<Map<String, dynamic>> handGuidedWeederItems = [
    {
      'code': 'G1',
      'name': '燃料・オイル',
      'checkPoint': '漏れがなく、量は適正か。',
      'isRequired': false,
    },
    {
      'code': 'G2',
      'name': '冷却系統',
      'checkPoint': '詰まりや異常はないか。',
      'isRequired': false,
    },
    {
      'code': 'G3',
      'name': '刃（ハンマー刃・ナイフ）',
      'checkPoint': '摩耗・欠けがなく、確実に固定されているか。',
      'isRequired': false,
    },
    {
      'code': 'G4',
      'name': 'ベルト・駆動部',
      'checkPoint': '摩耗・損傷がなく、適正に張られているか。',
      'isRequired': false,
    },
    {
      'code': 'G5',
      'name': '安全カバー・ガード類',
      'checkPoint': '正しく取り付けられ、破損はないか。',
      'isRequired': false,
    },
    {
      'code': 'G6',
      'name': '操作レバー・クラッチ',
      'checkPoint': '正常に作動するか。',
      'isRequired': false,
    },
    {
      'code': 'G7',
      'name': 'ブレーキ・走行部',
      'checkPoint': '正常に作動するか。',
      'isRequired': false,
    },
    {
      'code': 'G8',
      'name': '電装・点火装置',
      'checkPoint': '正常に作動するか。',
      'isRequired': false,
    },
    {
      'code': 'G9',
      'name': 'ボルト・ナット類',
      'checkPoint': '緩みや脱落はないか。',
      'isRequired': false,
    },
    {
      'code': 'G10',
      'name': '外観・漏れ・異常音',
      'checkPoint': '損傷や漏れがなく、異常音はないか。',
      'isRequired': false,
    },
    {
      'code': 'G11',
      'name': '消火器',
      'checkPoint': '使用可能な状態か。',
      'isRequired': false,
    },
  ];

  // 重機リスト
  static List<Machine> getMachines() {
    final List<Machine> machines = [];
    int machineId = 1;

    // 油圧ショベル
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '1号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '2号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '3号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '4号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '5号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '6号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '7号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '8号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '9号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC200',
      unitNumber: '10号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC138',
      unitNumber: '1号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC138',
      unitNumber: '2号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC138',
      unitNumber: '3号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC138',
      unitNumber: '4号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC138',
      unitNumber: '5号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC58',
      unitNumber: '1号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC58',
      unitNumber: '2号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC58',
      unitNumber: '3号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC58',
      unitNumber: '4号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC58',
      unitNumber: '5号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC30',
      unitNumber: '1号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC30',
      unitNumber: '2号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC30',
      unitNumber: '3号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC30',
      unitNumber: '4号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '油圧ショベル',
      model: 'PC30',
      unitNumber: '5号機',
      inspectionItems: hydraulicExcavatorItems,
    ));
    machineId++;

    // ブルドーザ
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D37PXi',
      unitNumber: '1号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D37PXi',
      unitNumber: '2号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D37PXi',
      unitNumber: '3号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D37PXi',
      unitNumber: '4号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D37PXi',
      unitNumber: '5号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D39PX',
      unitNumber: '1号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D39PX',
      unitNumber: '2号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D39PX',
      unitNumber: '3号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D39PX',
      unitNumber: '4号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D39PX',
      unitNumber: '5号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D51PXi',
      unitNumber: '1号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D51PXi',
      unitNumber: '2号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D51PXi',
      unitNumber: '3号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D51PXi',
      unitNumber: '4号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ブルドーザ',
      model: 'D51PXi',
      unitNumber: '5号機',
      inspectionItems: bulldozerItems,
    ));
    machineId++;

    // 不整地運搬車
    machines.add(Machine(
      id: machineId.toString(),
      type: '不整地運搬車',
      model: '4ｔ',
      unitNumber: '1号機',
      inspectionItems: roughTerrainCarrierItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '不整地運搬車',
      model: '4ｔ',
      unitNumber: '2号機',
      inspectionItems: roughTerrainCarrierItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '不整地運搬車',
      model: '4ｔ',
      unitNumber: '3号機',
      inspectionItems: roughTerrainCarrierItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '不整地運搬車',
      model: '4ｔ',
      unitNumber: '4号機',
      inspectionItems: roughTerrainCarrierItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '不整地運搬車',
      model: '4ｔ',
      unitNumber: '5号機',
      inspectionItems: roughTerrainCarrierItems,
    ));
    machineId++;

    // 振動ローラー
    machines.add(Machine(
      id: machineId.toString(),
      type: '振動ローラー',
      model: '1ｔ',
      unitNumber: '1号機',
      inspectionItems: vibratoryRollerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '振動ローラー',
      model: '1ｔ',
      unitNumber: '2号機',
      inspectionItems: vibratoryRollerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '振動ローラー',
      model: '1ｔ',
      unitNumber: '3号機',
      inspectionItems: vibratoryRollerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '振動ローラー',
      model: '1ｔ',
      unitNumber: '4号機',
      inspectionItems: vibratoryRollerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: '振動ローラー',
      model: '1ｔ',
      unitNumber: '5号機',
      inspectionItems: vibratoryRollerItems,
    ));
    machineId++;

    // コンバインドローラー
    machines.add(Machine(
      id: machineId.toString(),
      type: 'コンバインドローラー',
      model: '4ｔ',
      unitNumber: '1号機',
      inspectionItems: combinedRollerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'コンバインドローラー',
      model: '4ｔ',
      unitNumber: '2号機',
      inspectionItems: combinedRollerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'コンバインドローラー',
      model: '4ｔ',
      unitNumber: '3号機',
      inspectionItems: combinedRollerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'コンバインドローラー',
      model: '4ｔ',
      unitNumber: '4号機',
      inspectionItems: combinedRollerItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'コンバインドローラー',
      model: '4ｔ',
      unitNumber: '5号機',
      inspectionItems: combinedRollerItems,
    ));
    machineId++;

    // ハンドガイド式除草機
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ハンドガイド式除草機',
      model: '※型式なし',
      unitNumber: '1号機',
      inspectionItems: handGuidedWeederItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ハンドガイド式除草機',
      model: '※型式なし',
      unitNumber: '2号機',
      inspectionItems: handGuidedWeederItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ハンドガイド式除草機',
      model: '※型式なし',
      unitNumber: '3号機',
      inspectionItems: handGuidedWeederItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ハンドガイド式除草機',
      model: '※型式なし',
      unitNumber: '4号機',
      inspectionItems: handGuidedWeederItems,
    ));
    machineId++;
    machines.add(Machine(
      id: machineId.toString(),
      type: 'ハンドガイド式除草機',
      model: '※型式なし',
      unitNumber: '5号機',
      inspectionItems: handGuidedWeederItems,
    ));
    machineId++;

    return machines;
  }

  // 重機種類の一覧を取得
  static List<String> getMachineTypes() {
    // getMachines()を呼び出してツリーシェイキングを防ぐ
    final allMachines = getMachines();
    // 実際の重機種類を取得
    final uniqueTypes = allMachines.map((m) => m.type).toSet();
    
    // 表示順序を定義
    const typeOrder = [
      '油圧ショベル',
      'ブルドーザ',
      '不整地運搬車',
      'コンバインドローラー',
      '振動ローラー',
      'ハンドガイド式除草機',
    ];
    
    // 存在する重機種類のみ、定義された順序で返す
    return typeOrder.where((type) => uniqueTypes.contains(type)).toList();
  }

  // 指定された重機種類の号機リストを取得
  static List<String> getUnitNumbersForType(String machineType) {
    final machines = getMachines();
    final units = machines
        .where((m) => m.type == machineType)
        .map((m) => m.unitNumber)
        .toSet()
        .toList();
    return units;
  }
}
