# miloa における Area（関心領域）

## 定義

`Area` は GTD の「Area of Responsibility（責任領域）」に相当する。Project は完了可能な成果を目指すが、Area は継続的に維持・改善する関心領域である。

- **Project**: 完了条件が明確で、達成すると終了する（例: 「5/28 輪読発表」）
- **Area**: 継続的に関心を持ち続ける領域で、終了がない（例: 「SuteraVR」「miloa」「健康」「大学」）

Project は Area の中で特定の成果を目指す完了可能な単位とする。Area 自体に「完了」はないが、Area に紐づく Project は完了する。

## Area スキーマ

miloa の `Area` エントリは以下のフィールドを持つ：

- `Name`: 領域名（例: SuteraVR, miloa, 大学, 健康）
- `StrategicBlock`: `true` | `false` — 戦略Area枠の対象とするか
- `WeeklyReview`: `true` | `false` — 週次レビューで進捗確認する対象とするか
- `Description`: 現在の重点目標、方針、注意事項を自由に記述

## Area と Project/Task の関係

- 1つの Area に複数の Project が紐づく
- 1つの Project は 1つの Area に紐づく（`Project::Area` フィールドで参照）
- Task は Project 経由、または直接 Area に紐づく（`Task::Area`）
- Area の Description はユーザーが手軽に編集し、Codex はそれを参照する

## 戦略Area枠

日次計画における戦略Area枠は以下のルールで選定する：

1. `StrategicBlock = true` の Area を全件検索する
2. 各戦略Areaに紐づく `Bucket = Next` かつ `Status != Done` のTaskを確認する
3. その日に進める候補を、**各戦略Areaから最低1件ずつ**選定する
4. ユーザーが拒否しない限り、**毎日確保する**
5. 現実的でない場合は、「今日は省略する」ではなく「○曜日と△曜日に集中して確保する」など、**特定の日に徹底する案をユーザーに提案する**
6. 戦略Area枠は、原則として **30〜90分** のまとまった時間で扱う。短い隙間に無理やりねじ込まない

## 週次レビューでの Area 扱い

週次レビューでは `WeeklyReview = true` の Area を全てレビューする：

1. 各AreaのDescriptionを確認し、重点目標や方針の変更がないか確認する
2. 各Areaに紐づくProjectの進捗を確認する
3. 各戦略Area（`StrategicBlock = true`）の週次目標を1文で設定する
4. **ユーザーに同意を得てから**、Descriptionや週次目標を更新する

## 禁止事項

- Area を Project の代替として使わない。「SuteraVRの〇〇を完了する」はProject、「SuteraVR」はArea
- `StrategicBlock` と `WeeklyReview` を区別して扱う。戦略枠を消費しないAreaでも週次レビュー対象にできる
- Area の Name をタスクタイトルに使わない。タスクタイトルは `[動詞] + [対象] + [完了条件]` の形を保つ
- Skill ファイルに特定の Area 名（SuteraVR, miloa など）をハードコードしない。全て miloa の `Area` エントリから動的に解決する
