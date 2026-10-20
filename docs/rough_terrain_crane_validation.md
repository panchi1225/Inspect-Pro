# 実装・検証報告

実施日：2026-10-20。基点：既定ブランチ `main`、`abe0165783daa25e1bd479944bca48e3b8a07977`。
公開前にも `main` が同じSHAであることを再確認した。

## 変更ファイルと理由

|ファイル|変更理由|
|---|---|
|`lib/data/rough_terrain_crane.dart`|専用typeId、凡例・安全説明、固定14ID・★5件の検証、数値順・全項目入力判定。|
|`lib/services/firestore_service.dart`|ラフターを既存10台補完から除外。項目を固定ID順に検証し読込エラーを伝達。保存前の14件確認。帳票用の機械別・現場別クエリ、テスト用DB注入。|
|`lib/screens/machine_selection_screen_v2.dart`|ラフターだけ1～15号機を数値順に表示。テスト用データソース注入。|
|`lib/screens/inspection_input_screen.dart`|能力区分表示、★凡例と補足、読込失敗時の再試行・保存防止。保存失敗なのに完了表示する既存挙動を修正。|
|`lib/screens/record_detail_screen.dart`|ラフター専用凡例・補足。写真・メモ・結果の既存表示を使用。|
|`lib/screens/excel_export_dialog.dart`|現場別候補を対象現場へ直接問い合わせ、一覧の1000件制限で新しい機械が除外されることを防止。|
|`lib/services/web_excel_service.dart`|実使用生成経路を検証可能に分離。ラフターだけ10～23行の結合・折返し・罫線、根拠・凡例、年・能力区分入りファイル名、未点検表示、A4横1ページ・印刷範囲を追加。|
|`lib/services/excel_download_mobile.dart`|条件付きimportがVM上でも解決するよう非Webのダウンロード関数を追加。モバイル出力機能の新規実装はしない。|
|`scripts/data/rough_terrain_crane.json`|指定14項目・短文の正本。1～5がtrue、6～14がfalse。|
|`scripts/add_rough_terrain_crane.py`|専用の安全な追加処理。既定dry-run、ADC、競合検査、原子的create、再実行時の重複防止、JSON結果。|
|`scripts/run_rough_terrain_with_firebase_cli.cjs`|既存Firebase CLIログインをメモリ内の短期認証としてPython追加処理へ渡す任意アダプター。鍵・トークンを出力・保存しない。|
|`scripts/requirements-rough-terrain.txt`|専用追加処理のFirestore SDK依存。|
|`scripts/test_add_rough_terrain_crane.py`|追加件数、既存保全、衝突、部分再開の単体テスト。|
|`scripts/test_rough_terrain_emulator.py`|ローカルEmulatorで実スクリプトのdry-run・初回・再実行・競合中止を検証。|
|`test/rough_terrain_crane_test.dart`|Firestore模擬DB、入力・詳細・選択画面と実Web帳票生成経路の8テスト。|
|`test/fixtures/legacy_workbook_parts.json`|変更前mainで生成した既存帳票の全OOXMLのSHA-256。既存レイアウトを継続確認する基準。|
|`pubspec.yaml` / `pubspec.lock`|OOXML印刷設定用archive/xmlの直接依存と、検証用fake_cloud_firestore/crypto。Flutter SDK指定依存によるlock更新。|
|`docs/rough_terrain_crane_inspection_basis.md`|一次資料A～H、確認日・URL、全14項目の範囲・理由と法令の区別。|
|`docs/rough_terrain_crane_master.md` / 本資料|実行方法・保全方法と検証・未反映事項の記録。|

`lib/data/master_data.dart`、既存機種の項目、既存ID、既存記録は変更しない。
`lib/models/inspection_item.dart` はisRequiredが★フラグであることを確認済みで、モデル変更は不要。
詳細の採用項目・根拠対応は [根拠対応資料](rough_terrain_crane_inspection_basis.md) を参照。

## 検証結果

実行環境：Windows、Flutter 3.38.5、Dart 3.10.4。

|確認|方法・結果|
|---|---|
|25t・1号機|FirestoreServiceへ14件良好を保存し、一覧・再読込を確認。入力画面も0/14から利用者の一括操作で14/14へ進み保存。実generateMonthlyReportで14行・★5行・10月1日の○・型式・号機を検証。|
|50t・15号機|10月31日、rtc_06を不良、詳細メモ・写真データを保存。再読込で不良・メモ・写真データを維持、詳細画面に不良とメモを表示。帳票BQ15へ×、他13行は○。|
|数値順|両能力区分の実選択画面の選択肢が1～15号機の数値順。既存10号機補完はラフターを変更しない。|
|読込失敗・未点検|13項目の不完全マスタはエラー。入力画面に保存・一括良好ボタンを出さず、保存サービスでも空の結果を拒否。初期値は0/14で、自動良好なし。|
|既存の油圧ショベル|orderのない項目、旧機械ID・旧記録ID・不良メモを取得。既存帳票の全10個のOOXML部品が変更前mainの基準と一致（値・書式・結合を含む）。|
|専用追加処理の単体テスト|3件成功。45件追加予定・再実行0件・30台/14項目・既存不変・別IDや改変項目との競合・部分再開を確認。|
|Emulatorでの実追加処理|テスト専用 `demo-inspect-pro-rtc`、`127.0.0.1:8787`、default DB。dry-run45件予定で書込0、初回45件追加、再実行0件。各15台・計30台、項目14件。旧機械・項目・記録を維持。rtc_06の既存値を変更すると競合終了・追加0件・全状態不変。|
|静的解析|コンパイルエラー0、新規指摘0。変更前mainは323件（warning18・info305）、最終コードは318件（warning14・info304）。既存のunused import等は対象外として残した。|
|Webビルド|`flutter build web --release --no-pub --base-href=/Inspect-Pro/` 成功。既存home_screenのdart:htmlに対するWasm事前確認警告あり。通常のWeb JavaScriptビルドは成功。|
|既存の全テスト|既存 `test/widget_test.dart` は変更前もVMでdart:htmlが使用できず失敗。変更後も同じ既存テストが失敗。新規テストは8件成功。|

再現コマンド：

```sh
python -B -m unittest discover -s scripts -p test_add_rough_terrain_crane.py -v
# ローカルFirestore Emulator起動後。空の使い捨てdemoプロジェクトを使用。
FIRESTORE_EMULATOR_HOST=127.0.0.1:8787 python -m unittest discover -s scripts -p test_rough_terrain_emulator.py -v
flutter test --no-pub test/rough_terrain_crane_test.dart
flutter analyze --no-pub
flutter build web --release --no-pub --base-href=/Inspect-Pro/
```

WindowsではEmulatorの環境変数をPowerShellの `$env:FIRESTORE_EMULATOR_HOST` 等で設定する。
確認用Excelを出力する場合はテストに `--dart-define=REPORT_OUTPUT=<絶対出力先>` を付ける。
出力は本番と同じ `generateMonthlyReport` の取得・フィルタ・生成・encodeを通し、ブラウザへのダウンロードだけファイル保存コールバックへ置換する。

## 印刷確認

確認用データ：2026年10月（31日）、検証工事、確認 太郎。実在の本番点検記録ではない。
`rtc_25t_01.xlsx`、`rtc_50t_15.xlsx` を同じWebサービスから生成。
インストール済みMicrosoft Excelで正常に開き、PageSetupを読み取ってPDFへ出力した。

- PrintArea：`$A$1:$BQ$31`
- Orientation：2（横）、PaperSize：9（A4）、FitToPagesWide/Height：1/1
- PDF：いずれも1ページ、841.68 × 595.20 pt（A4横）
- 両PDFのページ画像を目視確認。14行、★5行、項目名・ポイントの文字、31日目の右端、補修・確認・点検者欄が表示される。
- 50tは31日目のウインチロープ行に×。不良メモは詳細記録に保存し、帳票点検欄へ長文を追加しない。
- 最初の印刷検証で見つけたOOXMLのdefinedNames/pageMargins重複、結合後の罫線不足、確認欄の折返しを修正後、Excelで再生成・再確認した。

## 本番反映状況と未検証事項

本番 `inspect-pro-22e0a` / `(default)` に反映済み。
ADC未設定による最初のdry-run失敗後、既存Firebase CLIログインを確認し、短期認証をメモリ内だけでPythonスクリプトへ渡して実行した。認証情報のコード埋込み・出力・ファイル保存は行っていない。

- 本番dry-run：成功、45文書予定、競合なし。
- 本番初回apply：成功、45文書追加（テンプレート1・項目14・機械30）。
- 本番再実行：成功、追加0文書。
- 読戻し：25t・50t各15台、双方1～15号機の数値順、rtc_01～rtc_14、★5件。
- 既存の機械・テンプレート・項目444文書：追加前後のSHA-256が一致（`f85fb7143d3fa8ca1d14f8e808ecfff2085071bcecc5805559638d1318395cfa`）。
- 保存済み点検記録を変更する書込は行っていない。削除インポートも実行していない。

本番の実行結果は `production-master-dry-run.json`、`production-master-apply.json`、`production-master-repeat.json`、`production-master-before.json`、`production-master-after.json` に保存した。
再実行手順は [専用手順](rough_terrain_crane_master.md) を参照。

本番データでの画面保存・再読込、公開中アプリでのブラウザダウンロード、実カメラ撮影・写真アップロード操作は未検証。
保存・詳細・帳票の確認には模擬DBと検証データを使用し、マスタ追加処理にはローカルFirestore Emulatorも使用した。
ネイティブモバイルのPython帳票経路は今回の対象Web経路とは別で、追加実装・検証していない。
ユーザーの本番公開指示を受け、追加の件数表示修正も同じPR #6にまとめてmainへマージし、既存GitHub Actionsから公開する。
件数修正の検証と公開確認方法は [件数修正の検証記録](inspection_count_validation.md) を参照。
