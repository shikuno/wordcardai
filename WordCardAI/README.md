# WordCardAI

iOS 向けの単語帳アプリ（個人用途の MVP を目指す）。

目的
- まずは Swift + SwiftUI で iOS 向け MVP を素早く作り、将来的に Android 対応を検討する。

このリポジトリについて
- `WordCardAI.xcodeproj` に Xcode プロジェクトがある（SwiftUI ベース）。
- ドキュメントは `docs/` に集約する。設計決定は ADR に残す。

セットアップ（開発者向け）
1. Xcode を開き `WordCardAI.xcodeproj` を開く
2. シミュレータで実行する

ドキュメントの場所
- `docs/FEATURES.md`：機能一覧（MVP/優先順位）
- `docs/DATA_MODEL.md`：データモデルと JSON サンプル
- `docs/USER_FLOWS.md`：主要画面とユーザーフロー
- `docs/ADR-0001-KMM-Decision.md`：アーキテクチャ決定記録
- `CHANGELOG.md`：変更履歴

今後の流れ（提案）
- まずは MVP の Must-have を確定し、`docs/FEATURES.md` を最終化する。
- その後、AI に実装を依頼する単位（例: `Word` モデル + `WordStore` + `ContentView`）を切り出す。

連絡先
- 作成者: Yuya

