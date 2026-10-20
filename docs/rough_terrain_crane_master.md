# ラフター専用マスタ追加

調査基点：`main` `abe0165783daa25e1bd479944bca48e3b8a07977`（2026-10-20取得）。
Flutter Web → `MachineSelectionScreenV2` → `FirestoreService.getMachines` → `machines`。
入力・詳細・Web Excelはいずれも `getInspectionItems(typeId)` → `machine_types/{typeId}/items`、点検ポイントは `checkpoint`。
`InspectionItem.isRequired` は★表示。Webの実使用経路は `ExcelExportDialog` → `WebExcelService.generateMonthlyReport`。
`lib/data/master_data.dart` は今回の実使用Firestore経路では使わないため変更しない。

## 実行

既存スクリプトの証明書直書きパスや削除インポートは使用しない。
信頼できる管理環境でADC（Application Default Credentials）を準備する。鍵をリポジトリに保存しない。

```sh
python -m pip install -r scripts/requirements-rough-terrain.txt
# 既定は読取のみ。対象を明示する。
python scripts/add_rough_terrain_crane.py --project inspect-pro-22e0a --output dry-run.json
# dry-runの成功・対象・45文書の予定を確認後、同じプロジェクトへ追加
python scripts/add_rough_terrain_crane.py --project inspect-pro-22e0a --apply --output apply.json
# 再実行は追加0件になる
python scripts/add_rough_terrain_crane.py --project inspect-pro-22e0a --apply --output repeat.json
```

`--database` の既定は `(default)`。`FIRESTORE_EMULATOR_HOST` があれば結果にも表示する。
結果JSONはプロジェクト・DB・モード・対象パス・予定数・追加数・失敗理由を出す。
通信・認証失敗時は終了コード1、追加処理は行わない。出力先の親ディレクトリは予め作成する。

## 保全

追加文書は `machine_types/rough_terrain_crane` 1件、配下 `items/rtc_01`～`rtc_14` 14件、
`machines/rtc_25t_01`～`rtc_25t_15` と `rtc_50t_01`～`rtc_50t_15` 30件の計45件。
全台に `typeId`、`isActive: true`、`sortOrder` を設定する。
既存の最大表示順の後ろに25t 1～15、50t 1～15を追加し、既存ID・sortOrder・項目・記録は変更しない。
画面ではラフターのみ号機を数値で並べる。既存の10台補完処理はラフターを除外する。

既存データをトランザクション内で読み、既存の同じID・種別名・対象項目・ラフター機械を照合する。
異なる値、別IDで登録されたラフター、余分なラフター項目があれば、黙って上書きせず全件中止。
文書は `transaction.create` のみ。追加予定の同時作成も既存文書の上書きにはならない。
管理対象フィールドが一致する既存文書は変更しない。正規の部分反映からの再開は不足分だけ追加する。
初回の表示順起点をテンプレートに保持するため、再実行時にID・表示順を変更しない。
全マスタを毎回画面表示時に登録する方式ではない。

`order` のない既存項目を除外しないよう、Firestoreに全機種共通の `orderBy('order')` は追加しない。
ラフターだけ文書IDで整列し、14個の固定ID・★区分・空の名称／ポイントがないことを検証する。

## 既存Firebase CLI認証を使用する場合

ADCを優先する。ADC未設定でも既にFirebase CLIへログインしている管理環境では、任意の認証アダプターを使用できる。
PythonのFirestore依存に加え、Node.jsとFirebase CLIが必要。Firebase CLI内部APIを使用するため、CLI更新後はまずdry-runで動作を確認する。

```powershell
# PowerShell例。トークン値を表示・コピーしない。
$env:NODE_PATH = (npm root -g)
node scripts/run_rough_terrain_with_firebase_cli.cjs --project inspect-pro-22e0a --output dry-run.json
node scripts/run_rough_terrain_with_firebase_cli.cjs --project inspect-pro-22e0a --apply --output apply.json
```

このアダプターは既存CLIログインの短期アクセストークンを子Pythonプロセスのメモリへ渡すだけで、同じ追加スクリプトを実行する。
認証情報をコマンド引数・コード・実行結果・ファイルに出さない。子プロセスでは認証環境変数もすぐ除去する。

2026-10-20の本番反映：dry-run45件予定、初回45件追加、再実行0件、各15台・14項目を読戻し確認済み。
既存のマスタ・点検項目444文書の追加前後ハッシュは同一。アプリコードのmainへのマージ・公開は別途必要。
