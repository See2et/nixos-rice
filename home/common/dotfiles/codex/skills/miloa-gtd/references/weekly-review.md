# miloa タスクによる週次レビュー

日次計画の上位互換。週の目標を立て、日々の計画が週全体の整合性を保つようにする。ここで作る WeeklyNote は、日次で参照される**rough plan**であり、固定化された日割り表そのものではない。

このスキルでは、**レビュー対象**と**時間配分対象**を混同しない。

- レビュー対象: `WeeklyReviewTarget` タグを持つ `Organization`
- 毎日最低限触る対象: `DailyFloorCommitment` タグを持つ commitment anchor (`Organization` / `Area` / `Project` / `Goal`)
- 週あたり必要時間を積む対象: `WeeklyQuotaCommitment` タグを持つ commitment anchor (`Organization` / `Area` / `Project` / `Goal`)

## 書き込み前ゲート

以下が終わるまで `WeeklyNote` 作成や Task 更新をしない：

- `list_tags` を読んだ
- `references/query-pack.md` にある週次レビュー必須取得順を完了した
- Google Calendar の今週予定を取得した
- **当日レビュー対象**の Organization を確認した

Google Calendar をまだ見ていない、または当日レビュー対象の確認が終わっていない状態で週次計画本文を書き始めない。

週次レビューの既定の書き込み先は `WeeklyNote` とする。Task の `ScheduledDate` / `DueDate` / `Bucket` や `Project::DueDate` を動かすのは、週次レビューの記録だけでは不十分で、変更意図を明確に説明できるときに限る。

## 当日レビュー対象の原則

- 通常の週次レビューでは、`WeeklyReviewTarget::Day = today` の Organization だけをレビューする。
- すべてのレビュー対象 Organization を同じ日に総ざらいしない。
- 全件横断レビューは、ユーザーが明示したときだけ行う。

## 週次レビューフロー

### ステップ1: 先週の振り返り

1. **当日レビュー対象 Organization の進捗確認**
   - 先週の課題と実績を比較する
   - 先週の DailyNote を参照し、関連作業が何日進んだかを見る
   - `DailyFloorCommitment` 対象なら、最低枠が実際に確保できていたかを見る
   - `WeeklyQuotaCommitment` 対象なら、予定した週内粗配分と優先順位が、実際の進み方に対して妥当だったかを見る

2. **締切タスクの実績確認**
   - 先週に `DueDate` が設定されていたタスクの完了率
   - 超過・延期が発生した場合、パターンを特定する

3. **締切 Project の実績確認**
   - 先週に `Project::DueDate` が設定されていた Project の進捗と完了可否
   - 締切を守れなかった場合、Task 粒度不足か週内配置不足かを切り分ける

4. **古い Next / Await の一掃状況**
   - 先週のレビュー時に存在した古い `Next` / `Await` が解消されたか

### ステップ2: 今週の全体把握

1. **今週の締切タスク洗い出し**
   - `DueDate` が今週内にある未完了タスクを全件リストアップ

2. **今週の締切 Project 洗い出し**
   - `Project::DueDate` が今週内にある `Active` Project を全件リストアップ
   - 各 Project について、締切を支える `Next` と必要作業日が見えるか確認する

3. **すべての Active Project の本文確認**
   - `Project::DueDate` が今週内かどうかにかかわらず、**すべての `Active` Project** を確認する
   - 特に `# Schedule` と `# Plan` に、今週内のマイルストーン、面接・発表・提出・レビューなどの外部イベント基準の日程感がないか確認する
   - 本文上の節目がある Project は、今週の締切 Project と同様に週内配置対象として扱う

4. **今週の ScheduledDate 分布確認**
   - `ScheduledDate` が今週内にある未完了タスクをリストアップ

5. **固定予定の確認**
   - Google Calendar で今週の予定を確認する
   - 大学登校日、会議、外出、締切などの固定要素をマッピングする

6. **抽象 Task 名の洗い出し**
   - 今週扱う `Next` / `ScheduledDate` / 締切付き Task に、抽象動詞やトピック名だけのものがないか確認する
   - 見つけたら、週内配置の前に具体動詞へ言い換えるか分割候補として扱う

### ステップ3: 週間タイムライン作成

月〜日の各日に以下をマッピングする：

```md
## 今週のタイムライン

| 曜日 | 固定予定 | 締切タスク | ScheduledDate | DailyFloor | WeeklyQuota | 可処分時間 |
|------|----------|------------|---------------|------------|-------------|------------|
| 月   | 授業A,B  | レポート   | 設計レビュー  | SuteraVR   | -           | 2h         |
| 火   | 授業C    | -          | -             | SuteraVR   | Comni.pl 2h | 4h         |
```

マッピングのルール：

- 大学登校日は、授業間の隙間を「基本使えない」として扱い、帰宅後の時間を可処分時間とする
- 締切タスクと締切 Project は、`DueDate` 当日ではなく、**完了に必要な作業日を逆算**して配置する
- `Project::DueDate` が遠くても、本文の `# Schedule` / `# Plan` に今週の節目がある Project は、同様に逆算して配置する
- `WeeklyQuotaCommitment` は、**この段階で週内の粗配分と優先順位を決める**
- `DailyFloorCommitment` は「毎日最低限置く必要があるか」を週間の現実に照らして確認する

### ステップ4: 当日レビュー対象 Organization の今週の課題を1つ決める

1. **当日レビュー対象 Organization について**:
   - 今週、**最も優先して解決すべき課題をちょうど1つ**選ぶ
   - 課題はボトルネックや未解決論点として書く
   - AI は候補を提案してよい
   - ただし、**どの課題を採用するかはユーザーに必ず確認する**
   - 課題が解消されたと判断できる最小の到達点を1文で添える

2. **`WeeklyQuotaCommitment` を持つ commitment anchor について**:
   - `TargetHours` を今週のどの日で進めるかの粗配分と優先順位を決める
   - これは WeeklyNote の責務であり、日次に丸投げしない
   - ただし日次では、この rough plan を前倒しして消化してよい。後ろ倒しは、週内の吸収先と締切影響を確認してから行う

3. **`DailyFloorCommitment` を持つ commitment anchor について**:
   - 今週も毎日最低枠を置く前提でよいか確認する
   - 習慣系 anchor では、毎日その場で中身を決める運用を許容する
   - `StretchPolicy = MaximizeWhenPossible` なら、余剰時間の寄せ先としても明記する

### ステップ5: WeeklyNote エントリの作成

週次レビューが完了したら、結果を miloa の `WeeklyNote` エントリとして記録する。

**推奨 WeeklyNote 本文**:

```md
## 今週レビューするOrganization
### :entry{#org-a}
今週の課題: ...

### :entry{#org-b}
今週の課題: ...

## 今週の時間コミットメント
- DailyFloor
  - :entry{#sutera} 30-60分/日
- WeeklyQuota
  - :entry{#comnipl} 火2h, 木2h, 日1h

## 今週のタイムライン
### 月曜日: yyyy-mm-dd
- 可処分時間: 4h
- DailyFloor: :entry{#sutera}
- WeeklyQuota: :entry{#comnipl} 2h
- 18:00-19:00 研究室定例（Google Calendar）
必要ならこの日の備考を書く
```

Task / Project / Organization / commitment anchor を本文中で参照するときは、可能な限り `:entry{#...}` を使う。`:entry{#...}` だけで十分な箇所では名称を繰り返さない。Google Calendar 予定など対応する Entry がないものだけを平文で書く。特に WeeklyNote では、表ではなく Organization ごと / 日ごとの見出しを優先する。

**WeeklyNote の運用ルール**:

- 週次レビュー毎に**新規作成**する
- 日次計画時に、その週の WeeklyNote を参照し、週次目標と quota 配分に沿っているか確認する
- 日次計画で前倒しが起きても、週次目標と quota 総量が守られている限りは正常とみなす
- 週の途中で quota 配分や課題を**後ろ倒し方向に**変更した場合、または週の焦点自体を変える場合は、WeeklyNote に追記し変更理由を記録する
- 当日レビュー対象の各 Organization について、本文中に**課題を1つだけ**残す
- `WeeklyQuotaCommitment` 対象の時間配分は、本文中に具体的に残す
- `Project::DueDate` の有無にかかわらず、本文の `# Schedule` / `# Plan` に今週の節目がある `Active` Project は WeeklyNote に反映する
- Task の `ScheduledDate` / `DueDate` や `Project::DueDate` を変更した場合は、なぜ WeeklyNote だけでは足りず更新が必要だったかを本文に短く残す
- 単に「今週の焦点」や「今週の粗配分」を決めるだけなら、Task を触らず WeeklyNote への記録で止める

### ステップ6: 日次計画への派生

週次レビューが完了したら、各日の日次計画は以下を満たすように作成する：

- その日の `DailyFloorCommitment` が見落とされていないか
- その日の `WeeklyQuotaCommitment` が、前倒しを含めて週全体として妥当に反映されているか
- 締切タスクが週間タイムライン通りに進んでいるか

## 週次レビューでの健全性チェック

1. **締切の集中**: `DueDate` が同じ日または連続する日に複数集中していないか
2. **Project 締切の作業不足**: `Project::DueDate` が近いのに、支える `Next` や週内配置が不足していないか
3. **本文マイルストーンの未反映**: `Project::DueDate` が近くなくても、本文の `# Schedule` / `# Plan` にある今週の節目が WeeklyNote に反映されていない `Active` Project がないか
4. **quota 未配置**: `WeeklyQuotaCommitment` があるのに、今週どこで時間を積むか決まっていない commitment anchor がないか
5. **DailyFloor の形骸化**: 毎日最低限触るはずなのに、実質的に置けない週になっていないか
6. **繰り返し延期パターン**: 同じタスクが `ScheduledDate` を変更し続けていないか
7. **過積載週**: 可処分時間の合計に対して必要作業時間が明らかに超過していないか
8. **ポリシー競合**: 同じ commitment anchor に `DailyFloorCommitment` と `WeeklyQuotaCommitment` が同時についていないか
9. **課題未決定のレビュー対象**: 当日レビュー対象なのに、今週解くべき課題が決まっていない Organization がないか
10. **抽象 Task 名**: 今週の締切対応や quota 配分に使う Task が、`考える` `進める` `対応する` のような抽象動詞で止まっていないか
11. **後ろ倒し依存の週**: 週前半で消化できたはずの quota や重要作業を、根拠なく週後半へ寄せる前提になっていないか

## 週次レビューの完了基準

- [ ] 当日レビュー対象の各 Organization の先週進捗を確認した
- [ ] 今週の締切タスクと締切 Project を全件リストアップし、作業日を逆算して配置した
- [ ] **すべての Active Project を確認し**、本文の `# Schedule` / `# Plan` にある今週の節目を必要に応じて週内配置へ反映した
- [ ] 今週のタイムライン（月〜日）を作成し、各日の可処分時間を概算した
- [ ] 当日レビュー対象の各 Organization に、今週解くべき課題を1つ設定した
- [ ] その課題の最終決定をユーザーから引き出した
- [ ] `WeeklyQuotaCommitment` 対象の週内粗配分を WeeklyNote に書いた
- [ ] `DailyFloorCommitment` 対象の最低枠方針を確認した
- [ ] 締切集中、Project 締切の作業不足、過積載、quota 未配置、課題未決定、ポリシー競合などの異常を検出し、調整方針を決定した
- [ ] 今週配置した Task が、抽象動詞やトピック名のまま残っていない
- [ ] **WeeklyNote エントリを作成した**

## 週次レビューと日次計画の関係

```text
週次レビュー
├── 当日レビュー対象Organizationごとの課題決定
├── 全 Active Project の本文確認
├── 週間タイムライン作成
└── WeeklyQuota の週内粗配分と優先順位決定
    ↓
日次計画
├── Pre-flight Check
├── その日の DailyFloor 確認
├── その日の WeeklyQuota 反映
└── タイムスケジュール作成
```

**原則**: 日次計画は週次計画の**派生**である。WeeklyNote は rough plan として参照し、前倒しは許容する。ただし、週次計画で見込んだ quota や締切対応を後ろ倒しする場合は、週全体の成立性を再確認する。
