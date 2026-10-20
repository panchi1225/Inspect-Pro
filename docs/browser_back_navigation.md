# スワイプ・ブラウザ履歴で戻る際の白画面への対応

確認日：2026-10-20。対象：Flutter Web、公開版1.4.2+5。

## 調査と変更

旧版は `MaterialApp` と名前のない `MaterialPageRoute` を使っていた。
Flutter 3.38.5のNavigatorはこの構成でsingle-entry historyを使用し、ブラウザのpopstate時に代替の履歴エントリを再作成してからFlutterへpopRouteを送る。
戻るボタンの `Navigator.pop` とブラウザのスワイプが異なる履歴経路を通る構成であることを確認した。
端末固有の白画面の時間は、Windowsのブラウザでは再現・計測していない。

`MaterialApp.router` とFlutter公式の `go_router` 17.0.1に変更し、実画面の親子関係をブラウザの複数エントリ履歴と連動させる。
点検の現場→点検者→機械→入力、管理の一覧→詳細、マスタ管理を同じ仕組みにそろえる。
親ページのStateを保持するため、戻るたびに検索・選択・一覧を初期化・再取得しない。
WebはNoTransitionPageを使い、ブラウザのスワイプにFlutter側の別の画面アニメーションを重ねない。非WebのMaterial/iOSの画面遷移は維持する。

左上は共通 `AppBackButton` とし、Webでは同じブラウザ履歴を戻る。
直接URLを開いた場合などアプリ内の過去履歴がないときは `Navigator.maybePop` で一段戻る。
履歴の有無の判定は固定済みFlutter 3.38.5のmulti-entryのserialCountタグを使用する。
SDKを更新する場合はこの判定とボタン→スワイプを混在させるテストを再確認する。
非Webでは従来と同じNavigatorの戻る処理を使用する。

ブラウザ履歴に必要な引数は最大128件のセッション内レジストリで保持し、URL・history.stateへ保存するのは画面のパスと不透明なセッションキーのみ。
現場名・点検者名・点検結果・写真・認証情報を履歴へ書き込まない。
再読み込み・期限切れのキー・ログアウト後の履歴は、ログイン又は必要な選択画面へ安全に戻す。
記録詳細の削除通知は一覧へ伝え、保存後の完了はホームへ戻す。点検の保存内容・写真・マスタは変更しない。

## 変更ファイル

- `lib/navigation/app_router.dart`：画面階層、ログイン・引数不足時の遷移。
- `lib/navigation/app_navigation.dart`：パス、画面引数、セッション内codec。
- `lib/navigation/app_back_button.dart`：共通の戻る動作。
- `lib/main.dart`：Routerの初期化・破棄とMaterialApp.router。
- `lib/screens/login_screen.dart` / `home_screen.dart`：ログイン、メニュー、ログアウトをRouterへ接続。
- `lib/screens/site_selection_screen.dart` / `inspector_selection_screen.dart` / `machine_selection_screen_v2.dart` / `inspection_input_screen.dart`：既存の選択情報を次画面へ渡し、共通の戻る動作を使用。
- `lib/screens/admin_screen.dart` / `record_detail_screen.dart`：一覧→詳細、フィルタの選択値、削除通知、共通の戻る動作。
- `lib/screens/master_data_management_screen.dart`：共通の戻る動作。
- 各画面のデータ読込完了時：mountedを確認し、読込途中ですぐ戻っても破棄後にsetStateしない。
- `lib/platform/browser_actions*.dart`：Webの戻ると既存PDFマニュアル表示を条件付きimportへ分離。VM上でも実アプリのRouterをテスト可能にする。
- `pubspec.yaml` / `pubspec.lock`：go_routerの固定依存、公開版1.4.2+5。
- `test/navigation_test.dart`：実画面と模擬DBを使った9件の履歴テスト。
- `test/widget_test.dart`：実アプリと無関係な初期Counterテンプレートをログイン起動テストへ更新。

## 検証

- `flutter test --no-pub --concurrency=1`：全26件成功。既存のラフター8件・総件数8件に加え、履歴9件・ログイン起動1件。
- ブラウザからのルート通知で現場、点検者、機械、入力、詳細、マスタから戻る。親のStateが同一、現場検索・号機選択・一覧フィルタが保持され、一覧の再取得が増えない。
- single-entry historyを選択せず、multi-entry historyを使用することをプラットフォームチャネルで検証。
- 読込途中で戻り、読込完了しても破棄後の例外がない。
- ログアウト後の戻る、引数のない直接URL、別セッションのキーを確認。
- iOSテーマの端スワイプをウィジェットテストで実行し、短いスワイプのキャンセルで画面を保持、完了で一つ前の既存画面へ戻る。
- 検証記録の保存完了でホームへ戻り、詳細で削除した検証記録が戻った一覧へ反映される。本番記録に書込み・削除は行わない。
- 静的解析：エラー0、新規指摘0。既存314件（warning13・info301）。変更前mainは317件。dart:htmlの条件分離等により既存指摘3件減。
- `flutter build web --release --no-pub --base-href=/Inspect-Pro/`：成功。

実ブラウザ確認・公開SHA・配信照合は作業成果物の公開報告へ記録する。
Windowsの実ブラウザで、点検者→戻るボタン→現場→ブラウザ戻る→ホームを確認。履歴が混在しても一段ずつ戻り、アプリ再起動や白画面は観測しなかった。
実ブラウザ確認では、セッションキー生成の `1 << 32` がJavaScript上で0になる問題も公開前に検出し、Web/VMで共通に扱える31ビットの上限値へ修正した。
検証用ブラウザアプリはFakeFirestoreがassert有効を要求するためdebugビルドを使い、本番DBへ書き込まない。本番は通常のreleaseビルドを使用する。
iPhone/iPad等の物理端末でのSafariジェスチャーは、このWindows環境では未検証。

## 参照

- [Flutter Navigation and routing](https://docs.flutter.dev/ui/navigation)：Webのブラウザ履歴とRouterの連動。
- [Navigator.reportsRouteUpdateToEngine](https://api.flutter.dev/flutter/widgets/Navigator/reportsRouteUpdateToEngine.html)：Navigator単独構成のsingle-entry history。
- [go_router 17.0.1](https://pub.dev/packages/go_router/versions/17.0.1)：Flutter公式のRouterベースのルーティング。
- 実際の履歴動作はFlutter 3.38.5の `engine/src/flutter/lib/web_ui/lib/src/engine/navigation/history.dart` と `packages/flutter/lib/src/services/system_navigator.dart` も確認した。
