# Data Model

## Word
- id: UUID (例: "6F9619FF-8B86-D011-B42D-00C04FC964FF")
- term: String (必須) - 単語
- meaning: String (必須) - 意味
- example: String? - 例文（任意）
- tags: [String] - タグ（任意）
- difficulty: Int? - 難易度（0-5, 任意）
- isLearned: Bool - 学習済フラグ
- createdAt: Date
- updatedAt: Date?

### JSON サンプル
```json
{
  "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
  "term": "apple",
  "meaning": "リンゴ",
  "example": "I ate an apple.",
  "tags": ["fruits"],
  "difficulty": 1,
  "isLearned": false,
  "createdAt": "2025-11-23T12:00:00Z",
  "updatedAt": null
}
```

### 永続化の選択肢（メモ）
- UserDefaults + JSON: 小規模MVPには最適
- File (JSON)/Realm: 中規模向け
- Core Data: 将来的な拡張におすすめ
- CloudKit/Firebase: 同期が必要な場合
