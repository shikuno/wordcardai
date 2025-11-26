# WordCardAI

**英会話で思いついた日本語を即座に英語に変換して単語カードを作成する iOS アプリ**

<img src="WordCardAI/docs/assets/app-icon-placeholder.png" alt="WordCardAI Icon" width="100" />

## 概要

WordCardAI は、日常会話で「これって英語でなんて言うんだろう？」と思った瞬間に、すぐに記録してAIが英語候補を提案してくれる単語帳アプリです。オフラインで動作し、すべてのデータは端末内に安全に保存されます。

### 主な機能

- 📚 **複数のカード集管理**: テーマ別（日常会話、ビジネス、旅行など）にカードを整理
- 🤖 **AI翻訳候補生成**: 日本語入力時に最大5件の英語候補を自動生成
- 🎴 **フラッシュカード学習**: シャッフル機能付きの学習モード
- 🔍 **検索機能**: 日本語・英語・タグで素早く検索
- 🏷️ **タグ機能**: カードをカテゴリ分け
- 📝 **メモ機能**: 使い方や文脈を記録
- 🔒 **完全オフライン**: インターネット接続不要、データは端末内のみ
- 🌓 **ダークモード対応**: システム設定に自動追従

## スクリーンショット

*（開発完了後に追加予定）*

| カード集一覧 | カード作成 | 学習モード |
|:---:|:---:|:---:|
| ![Collections](WordCardAI/docs/assets/screenshot-collections.png) | ![Create Card](WordCardAI/docs/assets/screenshot-create.png) | ![Learn Mode](WordCardAI/docs/assets/screenshot-learn.png) |

## 必要要件

- iOS 16.0 以降
- Xcode 15.0 以降（開発者向け）
- Swift 5.9 以降（開発者向け）

## セットアップ（開発者向け）

### 1. リポジトリのクローン

```bash
git clone https://github.com/yourusername/WordCardAI.git
cd WordCardAI
```

### 2. Xcode で開く

```bash
open WordCardAI.xcodeproj
```

### 3. ファイルをプロジェクトに追加

詳細は [XCODE_SETUP.md](WordCardAI/docs/XCODE_SETUP.md) を参照してください。

### 4. ビルドと実行

1. シミュレーターまたは実機を選択
2. `⌘ + R` でビルド＆実行

## プロジェクト構成

```
WordCardAI/
├── Models/                    # データモデル
├── ViewModels/                # ビジネスロジック（MVVM）
├── Views/                     # UIコンポーネント
│   ├── Collections/          # カード集関連画面
│   ├── Cards/                # カード関連画面
│   ├── Learn/                # 学習モード画面
│   └── Settings/             # 設定画面
├── Services/                  # サービス層
│   ├── Storage/              # データ永続化
│   └── Translation/          # AI翻訳サービス
├── Utilities/                 # ユーティリティ
│   └── Extensions/           # 拡張機能
└── docs/                      # ドキュメント
```

## アーキテクチャ

- **パターン**: MVVM (Model-View-ViewModel)
- **UI フレームワーク**: SwiftUI
- **ナビゲーション**: NavigationStack (iOS 16+)
- **データ永続化**: UserDefaults + Codable (JSON)
- **AI 翻訳**: Mock Service（将来的に Apple Translation Framework 統合予定）

詳細は [ARCHITECTURE.md](WordCardAI/docs/ARCHITECTURE.md) を参照してください。

## ドキュメント

- [仕様書](WordCardAI/docs/SPEC.md) - 機能要件の詳細
- [データモデル](WordCardAI/docs/DATA_MODEL.md) - データ構造の説明
- [アーキテクチャ](WordCardAI/docs/ARCHITECTURE.md) - 設計思想とパターン
- [UI/UX デザイン](WordCardAI/docs/UI_DESIGN.md) - 画面設計と操作フロー
- [機能一覧](WordCardAI/docs/FEATURES.md) - MVP と将来の機能
- [ユーザーフロー](WordCardAI/docs/USER_FLOWS.md) - 主要な操作手順
- [タスク管理](WordCardAI/docs/TASKS_SPRINT1.md) - Sprint 1 のタスク
- [Xcode セットアップ](WordCardAI/docs/XCODE_SETUP.md) - 開発環境構築

## 使い方

### 1. カード集を作成

1. ホーム画面で `+` ボタンをタップ
2. カード集の名前を入力（例: "日常会話", "ビジネス英語"）
3. 「作成」をタップ

### 2. 単語カードを追加

1. カード集をタップして開く
2. `+` ボタンをタップ
3. 日本語を入力
4. 「候補を生成」ボタンで AI が英語候補を表示
5. 候補から選択、または手動で編集
6. 必要に応じてメモやタグを追加
7. 「保存」をタップ

### 3. 学習する

1. カード集を開く
2. 「学習モード」ボタンをタップ
3. フラッシュカードで学習開始
   - 「答えを見る」で英語を表示
   - スワイプまたはボタンで前後のカードに移動

### 4. 検索する

1. カード集を開く
2. 検索バーに日本語・英語・タグを入力
3. リアルタイムで絞り込み表示

## ロードマップ

### ✅ Phase 1 (MVP) - 完了！

- [x] カード集の作成・削除
- [x] 単語カードの CRUD 操作
- [x] AI 翻訳候補生成（モック）
- [x] フラッシュカード学習モード
- [x] 検索・フィルター機能
- [x] タグ・メモ機能
- [x] ローカルストレージ（UserDefaults）

### 🚧 Phase 2 - 予定

- [ ] Apple Translation Framework の統合（オンデバイス翻訳）
- [ ] Core Data / SwiftData への移行
- [ ] iCloud 同期機能
- [ ] ウィジェット対応
- [ ] 音声読み上げ機能
- [ ] 学習統計・進捗トラッキング
- [ ] カードのインポート・エクスポート（CSV）

### 🔮 Phase 3 - 将来

- [ ] Android 版（Kotlin Multiplatform）
- [ ] Apple Watch 対応
- [ ] Siri Shortcuts 対応
- [ ] コミュニティ共有機能

## 技術スタック

| カテゴリ | 技術 |
|:---|:---|
| 言語 | Swift 5.9 |
| UI | SwiftUI |
| アーキテクチャ | MVVM |
| データ永続化 | UserDefaults + Codable |
| AI 翻訳 | Mock Service → Apple Translation Framework（予定） |
| 最小バージョン | iOS 16.0 |

## 貢献

このプロジェクトは現在個人開発中です。バグ報告や機能提案は Issue からお願いします。

## ライセンス

MIT License

Copyright (c) 2025 Yuya Furuichi

詳細は [LICENSE](LICENSE) を参照してください。

## 作者

**Yuya Furuichi**

- GitHub: [@yuya]
- Email: your.email@example.com

## 謝辞

- SwiftUI コミュニティ
- Apple Developer Documentation
- すべてのテスターの皆様

---

**注意**: このアプリは個人の学習目的で開発されたものです。商用利用する場合は適切なライセンスを確認してください。
