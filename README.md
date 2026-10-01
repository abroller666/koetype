# KoeType

Swift製のmacOS向け音声入力アプリです。メニューバーに常駐し、**⌥Space（Option + Space）** で録音を開始・停止します。OpenAI APIで日本語を文字起こしし、フィラーや言い直しを整えて、フォーカス中のアプリに貼り付けます。

## 主な機能

- グローバルホットキーによる録音開始・停止、Escによる録音キャンセル
- 日本語の文字起こしと、フィラー除去・言い直し統合・句読点の整形
- メニューバーで待機・録音・処理中の状態を表示
- APIキーをmacOS Keychainに保存
- 文字起こしモデル・整形モデルの変更と接続テスト
- 整形APIの失敗時は、文字起こし結果をそのまま使用
- アクセシビリティ権限がない場合は、結果をクリップボードにコピー

## 必要な環境

- macOS 14以降
- Swift 5.9以降に対応するツールチェーン（XcodeまたはCommand Line Tools）
- OpenAI APIキーとインターネット接続
- マイク入力デバイス

外部Swiftパッケージへの依存はありません。ビルドスクリプトは実行したMac向けのバイナリを生成します。Intel Macでの動作は未検証です。

macOS 27（SDK 27 / Swift 6.4）でも、Xcodeを入れずCommand Line Toolsだけでビルドできます。Xcodeやツールチェーンが必要なのはビルドするときだけで、ビルド済みの `KoeType.app` を実行するMacには不要です。

## ビルドと起動

Command Line Toolsが未導入の場合は、以下を実行してインストールします。

```bash
xcode-select --install
```

このリポジトリのルートで実行します。

```bash
bash scripts/build-app.sh
open build/KoeType.app
```

スクリプトはリリースビルドを行い、`build/KoeType.app` を組み立て、ad-hoc署名します。再実行すると同パスのアプリバンドルを置き換えます。配布用のDeveloper ID署名・公証は行いません。

## 初回セットアップ

1. 起動時に開く設定画面でOpenAI APIキーを入力し、**保存**します。設定はメニューバーの「設定…」からも開けます。
2. **接続テスト**でAPIへの接続を確認します。この操作は入力中のキーでモデル一覧APIに接続するもので、設定の保存や録音・各モデルの実行確認は行いません。
3. 「システム設定 → プライバシーとセキュリティ → アクセシビリティ」でKoeTypeを許可します。自動貼り付けに必要です。
4. 初回録音時にマイクへのアクセスを許可します。エラー等を通知で受け取る場合は通知も許可します。

## 使い方

入力先のテキスト欄にカーソルを置いて操作します。

| 操作 | 動作 |
| --- | --- |
| ⌥Space | 録音を開始（赤いマイクアイコン） |
| 録音中に⌥Space | 録音を停止し、文字起こし・整形後に貼り付け |
| 録音中にEsc | 録音をキャンセル |
| メニューバーの「録音を開始」「録音を停止して入力」 | ホットキーと同じ録音操作 |

録音は最大5分で自動停止し、処理に進みます。約0.5秒未満の録音はファイルサイズを基準に短すぎると判定されます。処理中は砂時計アイコンになり、新しい録音は開始できません。

貼り付け先は**処理完了時にフォーカスされているアプリ**です。処理が終わるまで入力先のフォーカスを維持してください。

## 設定と処理の流れ

以下はコードに設定されている初期値です。

| 設定 | 初期値 | 保存先 |
| --- | --- | --- |
| APIキー | 未設定 | macOS Keychain |
| 文字起こしモデル | `gpt-4o-transcribe` | UserDefaults |
| 整形モデル | `gpt-4o-mini` | UserDefaults |

```text
マイク入力
  → 16 kHz / モノラル / 16 bit WAVの一時ファイル
  → POST /v1/audio/transcriptions（language: ja）
  → POST /v1/chat/completions（日本語整形）
  → クリップボード経由で⌘Vを送出
```

整形では内容の追加・要約・翻訳を避け、話者の語調を保つようプロンプトで指示しています。生成結果の正確さを保証するものではありません。文字起こしが空の場合や、整形結果が空の場合は挿入しません。

モデル名は設定画面から変更できますが、上記エンドポイントと実装のリクエスト形式に対応したモデルが必要です。言語、ホットキー、録音上限、整形プロンプトを変更する設定UIはありません。

## データの取り扱いと制限

- 録音音声と文字起こしテキストは、処理のためにOpenAI APIへ送信されます。オフライン処理には対応していません。
- APIキーはKeychainのサービス `com.maruko.koetype`、アカウント `openai-api-key` に保存します。ソースコードやリポジトリへの記入は不要です。
- 録音はシステムの一時ディレクトリに `koetype-<UUID>.wav` として保存され、処理終了時やキャンセル時に削除を試みます。異常終了などで残る可能性があります。
- 自動貼り付けの約0.5秒後に、元のクリップボードの**文字列のみ**を復元します。画像・ファイル等の内容は復元しません。この間にコピーした内容も上書きされる可能性があります。
- アクセシビリティ権限がない場合は結果をクリップボードに残すので、手動で⌘Vを押してください。
- 入力先アプリの⌘V対応やフォーカス状態によっては、自動貼り付けできない場合があります。

## トラブルシューティング

| 症状 | 確認事項 |
| --- | --- |
| マイクを使えない | システム設定のマイク権限と入力デバイスを確認 |
| 自動貼り付けされない | アクセシビリティ権限と入力先のフォーカスを確認 |
| 再ビルド後に貼り付けできない | ad-hoc署名が変わるため、アクセシビリティ一覧から削除して再登録が必要になる場合があります |
| ⌥Spaceが反応しない | 他アプリのショートカットとの競合を確認し、メニューバーから録音を試す |
| APIエラーが出る | 通知のエラー内容、保存したキー、モデル名、ネットワーク接続を確認 |
| 接続テストは成功するが音声入力に失敗する | 接続テストは文字起こし・整形モデルの実行までは確認しません |
| エラー通知が表示されない | システム設定の通知でKoeTypeを許可 |
| ビルド時に `SwiftUIMacros` のプラグインが見つからないエラーが出る | SwiftUIのマクロ（`@State` など）を使っています。マクロを使わない書き方に変えるか、Xcodeを入れてビルドしてください（下記「開発・確認」を参照） |

## ソース構成

```text
Package.swift                 # SwiftPMの実行ターゲットとmacOS要件
Resources/Info.plist           # アプリ情報、常駐設定、マイク使用理由
scripts/build-app.sh           # リリースビルド・バンドル生成・署名
Sources/KoeType/
├── main.swift                # NSApplicationの起動
├── AppDelegate.swift         # idle / recording / processingの状態と処理制御
├── MenuBarController.swift   # メニューバー表示と操作
├── HotkeyManager.swift       # Carbonによるグローバルホットキー
├── AudioRecorder.swift       # AVAudioEngineによる録音・形式変換
├── OpenAIClient.swift        # 文字起こし・整形APIクライアント
├── TextInserter.swift        # クリップボード操作と⌘V送出
├── SettingsStore.swift       # Keychain / UserDefaultsへの保存
├── SettingsWindow.swift      # SwiftUIの設定画面（ObservableObjectで状態を保持）
└── Notifier.swift            # システム通知
```

## 開発・確認

```bash
swift build
bash scripts/build-app.sh
codesign --verify --verbose=2 build/KoeType.app
plutil -lint Resources/Info.plist
```

macOS 27 SDKではSwiftUIの `@State` がマクロ（`SwiftUIMacros`、Xcodeにのみ同梱）に変わったため、Command Line Toolsだけではプラグインが見つからずビルドに失敗します。設定画面は `@State` を使わず `ObservableObject` で状態を保持しています。2026-10-01にApple Silicon / macOS 27.0.1 / Command Line ToolsのSwift 6.4環境で、`swift build` とリリースビルド・署名検証の成功を確認しました。録音・API連携の実機動作は未確認です。

Command Line Toolsだけでビルドできる状態を保つため、SwiftUIのコードでは `@State`、`@Entry`、`@Animatable`、`@Previewable`、`#Preview` など、`SwiftUIMacros` や `PreviewsMacros` に依存するマクロを使わないでください。状態は `ObservableObject` / `@Published` / `@ObservedObject` で扱います。これらのマクロを使う場合は、Xcodeでのビルドが必須になります。

通常の利用・動作確認は権限設定を含む `.app` バンドルで行います。自動テストターゲットはまだありません。手動では録音開始・停止、Escキャンセル、整形後の貼り付け、権限未許可時のコピー動作を確認してください。APIを使う動作確認には自身のキーが必要です。

`.gitignore` でビルド成果物、Xcodeの個人設定、ローカル環境ファイルなどを除外しています。ソース変更は次の流れで管理できます。

```bash
git status
git add README.md Sources Resources Package.swift scripts .gitignore
git commit -m "Describe your change"
git push
```
