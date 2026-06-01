# miloa における Area（関心領域）

## 定義

`Area` は GTD の「Area of Responsibility（責任領域）」に相当する。**機能的な責務領域**であり、組織名やブランド名そのものではない。

- **Project**: 完了条件が明確で、達成すると終了する（例: 「5/28 輪読発表」）
- **Area**: 継続的に維持・改善する責務領域で、終了がない（例: 「技術開発」「研究・学術」「学業」）
- **Organization**: 組織・チーム・ブランドの文脈。SuteraVR、Comni.pl、JVSL、チームみらい、Delight など。Area とは別次元

**組織名を Area にしない。** 「SuteraVR」は Organization、「技術開発」は Area。Project は Area（責務領域）と Organization（組織文脈）の両方に紐づく。

## Area スキーマ

miloa の `Area` エントリは以下のフィールドを持つ：

- `Name`: 領域名（例: 技術開発, 研究・学術, 創業・事業運営, コミュニティ・社会活動, 学業, 健康・生活）
- `Description`: 現在の重点目標、方針、注意事項を自由に記述
- `Goals`: Array of EntryRef (`Goal` タグ制約) — この Area が貢献する上位目標

Area は純粋な機能的分類タグ。戦略的優先度や週次レビューの対象は Organization で管理する。

## Organization との関係

- `Organization` は組織・ブランドの文脈タグ
- `Project` は `Organization` フィールドで属する組織を示す
- `Area` は Organization を知らない。責務領域と組織文脈は別次元
- 例: `Project::Area = 技術開発`, `Project::Organization = SuteraVR`

## Goal との関係

- `Goal` タグは H3 に相当する上位目標（12〜24ヶ月での達成目標）
- `Vision` タグは H4 に相当するビジョン（3〜5年先の成功像）。`Vision::ParentPurposes` で上位の `Purpose` に接続
- `Purpose` タグは H5 に相当する原理・価値観（「なぜやるのか」）
- `Area::Goals` は Array で、1つの Area が複数の Goal に貢献できる
- 因果リンク: `Purpose` → `Vision` → `Goal` → `Area` → `Project`
- Horizon Review では、この因果チェーンを `Goal::ParentVisions` → `Vision::ParentPurposes` まで辿って整合性を検証する
- 例: Purpose「研究者として社会に貢献する」→ Vision「学会で認められる研究者」→ Goal「2年以内に論文を1本通す」→ Area「研究・学術」→ Project「〇〇手法の実装評価」

## Area と Project/Task の関係

- 1つの Area に複数の Project が紐づく
- 1つの Project は 1つの Area に紐づく（`Project::Area` フィールドで参照）
- Task は Project 経由、または直接 Area に紐づく（`Task::Area`）
- Area の Description はユーザーが手軽に編集し、Codex はそれを参照する

## 禁止事項

- Area を Organization の代替として使わない。「SuteraVR」は Organization、「技術開発」はArea
- Area は機能的分類に徹する。戦略的優先度やレビュー対象の管理は Organization に任せる
- Area の Name をタスクタイトルに使わない。タスクタイトルは `[動詞] + [対象] + [完了条件]` の形を保つ
- Skill ファイルに特定の Area 名や Organization 名をハードコードしない。全て miloa のエントリから動的に解決する
- Horizon Review を依頼されていないのに、勝手に `Area::Goals` を設定・変更しない
