# Area と Organization の関係

## 基本原則

- **Area**: 継続的な責務領域。技術開発、学業、コミュニティ運営など
- **Organization**: 組織・チーム・ブランドの文脈。SuteraVR、Comni.pl、JVSL、チームみらい、Delight など

**組織名を Area にしない。** 「SuteraVR」は Organization、「技術開発」は Area。Project は Area（責務領域）と Organization（組織文脈）の両方に紐づく。

## Area の役割

- Area は純粋な機能的分類タグ
- Project の責務領域を示す
- Horizon Review では `Area::Goals` を通じて上位 Goal とつながる

Area は「毎日触る対象」「週に何時間積む対象」「何曜日にレビューする対象」を表現しない。そうした運用は Organization 側の追加タグで扱う。

## Area スキーマ

Area エントリは、少なくとも次を持つ前提で読む：

- `Name`: 領域名
- `Description`: 現在の重点、方針、注意点
- `Goals`: 上位 `Goal` への参照配列

実スキーマがこれと異なる場合は、`list_tags` で見えた現在の形を正とする。

## Organization との関係

- `Organization` は組織・ブランド・チームの文脈タグ
- `Project` は `Organization` フィールドで属する組織を示す
- `Area` は Organization を知らない。責務領域と組織文脈は別次元
- 例: `Project::Area = 技術開発`, `Project::Organization = SuteraVR`

## Goal / Vision / Purpose との関係

- `Goal` は H3 に相当する到達目標
- `Vision` は H4 に相当する中長期像
- `Purpose` は H5 に相当する原理・価値観
- `Area::Goals` により、1つの Area は複数 Goal に貢献できる
- Horizon Review では `Purpose -> Vision -> Goal -> Area -> Project` の流れで整合性を見る

例: Purpose「研究者として社会に貢献する」 -> Vision「学会で認められる研究者」 -> Goal「2年以内に論文を1本通す」 -> Area「研究・学術」 -> Project「〇〇手法の実装評価」

## Area と Project / Task の関係

- 1つの Area に複数の Project が紐づく
- 1つの Project は 1つの主要な Area に紐づく
- `Task` は `Project` 経由、または直接 `Area` に紐づきうる
- Area の Description は、責務の重点や最近の注意点を読むための補助情報として扱う

## 推奨ポリシー構造

Organization 自体は文脈のハブに留め、次を追加タグで表すのを推奨する：

- `WeeklyReviewTarget`: その Organization を何曜日にレビューするか
- `DailyFloorCommitment`: 毎日最低限どれだけ触るか
- `WeeklyQuotaCommitment`: 週あたり何時間積むか

この設計では、

- Area は責務の分類
- Organization は文脈の分類
- 追加タグはレビュー / 時間配分ポリシー

という役割分担になる。

## 避けること

- Area を Organization の代替として使う
- Area に時間コミットメントやレビュー曜日の意味を持たせる
- Skill ファイルに特定の Area 名や Organization 名をハードコードする
