# Sprint 1 — タスク分解（2 週間想定）

期間: 2 週間（1エンジニア想定）
目的: CardStore とカード一覧 + カード作成（AIモック）を完成させ、ローカルで動作する最小のカード作成フローを実現する。

優先度キー: P0 = 必須 (MVP), P1 = 高 (MVP直後), P2 = 中

---

## Epic: 基盤 & 環境 (共通)

T1.1: ブランチ戦略と開発ルールの追加 (P0) — 0.5d
- 説明: `main`/`develop` のブランチ運用、PR テンプレ、コミットメッセージ方針を README に追記する。
- 成果物: README の更新 / `.github/PULL_REQUEST_TEMPLATE.md` (簡易)
- 受け入れ基準: README にブランチ運用が明記されていること。
- 依存: なし
- ブランチ: `chore/gitflow`

T1.2: CI の簡易ビルド確認を追加/確認 (P0) — 0.5d
- 説明: 既存の GitHub Actions（iOS Build）が動作することを確認。必要なら軽微修正。
- 成果物: CI が push/pull_request で成功すること
- 受け入れ基準: PR を作った際に macos-latest 上でビルドジョブが成功すること
- 依存: T1.1
- ブランチ: `chore/ci-check`

---

## Epic: データ層（P0）

T2.1: `WordCard` / `CardCollection` モデルの型定義 (P0) — 0.5d
- 説明: `docs/DATA_MODEL.md` に記載のスキーマを Swift の struct に落とす。
- 成果物: `Models/WordCard.swift`, `Models/CardCollection.swift`
- 受け入れ基準: モデルが Codable, Identifiable を満たすこと
- 依存: なし
- ブランチ: `feat/models`

T2.2: 永続化プロトコル定義と UserDefaults 実装 (P0) — 1.0d
- 説明: 永続化を抽象化する `protocol Storage { func save... load... }` を作り、UserDefaults+JSON 実装を用意する。
- 成果物: `Storage/Storage.swift`, `Storage/UserDefaultsStorage.swift`
- 受け入れ基準: 単体テストで save/load が round-trip すること
- 依存: T2.1
- ブランチ: `feat/storage`

T2.3: `CardStore`（ObservableObject）実装 (P0) — 1.5d
- 説明: add/remove/move/load/save を持つ `CardStore` を実装し、Storage を注入できる形にする。
- 成果物: `Stores/CardStore.swift`
- 受け入れ基準: UI から add/remove が反映され、UserDefaults に保存されること
- 依存: T2.1, T2.2
- ブランチ: `feat/cardstore`

---

## Epic: UI — 一覧 & CRUD (P0)

T3.1: カード集一覧画面 (P0) — 0.75d
- 説明: 複数の CardCollection を表示・追加・削除・名前編集する簡易画面。
- 成果物: `Views/CollectionsListView.swift`
- 受け入れ基準: 新しいコレクションを作成してタップで遷移できる
- 依存: T2.1, T2.3
- ブランチ: `feat/collections-ui`

T3.2: カード一覧画面（Collection 内） (P0) — 1.0d
- 説明: CardStore のカード一覧を List で表示。検索、削除、並び替え（EditButton）を提供。
- 成果物: `Views/CardsListView.swift`
- 受け入れ基準: カードが一覧表示され、削除・移動ができること。検索でフィルタがかかること
- 依存: T2.3, T3.1
- ブランチ: `feat/cards-ui`

T3.3: カード追加・編集画面（UI）(P0) — 1.0d
- 説明: 日本語テキスト入力欄、英語フィールド（候補選択後に編集可）、メタ（タグ/ノート）を入力できるフォーム
- 成果物: `Views/CreateEditCardView.swift`
- 受け入れ基準: term（日本語）入力後、保存で CardStore に反映されること
- 依存: T2.3
- ブランチ: `feat/create-card-ui`

---

## Epic: AI 候補ワークフロー（P0 — モック）

T4.1: AI モック API クライアント (P0) — 0.5d
- 説明: 実際の生成は未接続なので、`POST /generate` を模するローカルモッククライアントを作る（固定の 1〜3 候補を返す）。
- 成果物: `Services/MockAIClient.swift`
- 受け入れ基準: CreateCardView の「生成」ボタンで候補が返り UI に表示されること
- 依存: T3.3
- ブランチ: `feat/ai-mock`

T4.2: CreateCardView と AI クライアントの連携 (P0) — 1.0d
- 説明: 日本語を送信→候補取得→候補をリスト表示→タップで英語欄に反映→保存
- 成果物: `Views/CreateEditCardView.swift` の AI 呼び出し実装
- 受け入れ基準: 候補を選択して保存すると CardStore に候補が反映されること
- 依存: T4.1, T2.3
- ブランチ: `feat/create-card-ai`

T4.3: ユーザ設定：AI候補数とサーバフォールバックのフラグ (P1) — 0.5d
- 説明: 設定画面または設定項目として、AI候補数（1-5）とサーバフォールバック許可のトグルを追加
- 成果物: `Views/SettingsView.swift`, `Settings/SettingsStore.swift`
- 受け入れ基準: 設定が保存され、CreateCardView の候補数に反映される
- 依存: T4.2
- ブランチ: `feat/settings`

---

## Epic: 学習モード & テスト (P0)

T5.1: シンプルな学習モード（Flashcard） (P0) — 1.0d
- 説明: Collection 内のカードをランダム表示、答えを表示する UI を実装
- 成果物: `Views/StudyView.swift`
- 受け入れ基準: 表→裏の切替ができ、全カードを確認できること
- 依存: T3.2
- ブランチ: `feat/study-mode`

T5.2: 単体テスト（重要なロジック）(P0) — 1.0d
- 説明: CardStore の save/load、AIモックの出力、モデルの Codable 性をテスト
- 成果物: `Tests/CardStoreTests.swift`, `Tests/AIClientTests.swift`
- 受け入れ基準: テストがローカルで実行できること (`xcodebuild test`)
- 依存: T2.2, T4.1
- ブランチ: `test/cardstore`

---

## バッファ & レビュー (P0)

T6.1: バグ修正・UI 微調整・ドキュメント更新 — 2.0d
- 説明: Sprint の最終で残件を解消し、`docs/SPEC.md` と `docs/FEATURES.md` を更新
- 成果物: 修正 PR、更新されたドキュメント
- 受け入れ基準: Sprint の P0 タスクがすべて完了していること
- ブランチ: `chore/sprint1-finish`

---

# 合計見積り（目安）
- 合計: 約 12.75 日（バッファ・レビュー含めて 2 週間で収まる想定）

# 提案の運用方法（簡単）
- 各タスクは小さめの PR でマージする（1PR = 1機能／1ファイル群）
- タスクは issue として登録し、`P0/P1/P2` ラベルと見積（d）を付ける
- 毎日短いスタンドアップ（5分）で進捗共有、2-3日に1回レビュー PR を作成

# 次のアクション（私が代行できます）
- このタスク一覧を GitHub Issues として自動作成します（リポジトリに GH トークンでアクセス権が必要です）。
- あるいは、あなたがやりやすい形式（Jira/Trello/Notion）に変換します。

質問: Issues を作成しましょうか？それともまず 1〜2 タスクを実装するための優先順位をさらに詰めますか？
