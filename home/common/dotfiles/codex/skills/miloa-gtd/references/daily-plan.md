# miloa タスクによる日次計画

最初に `gtd.md` を読む。日次計画では、GTD における `Next` の意味を保たなければならない。すべての `Next` タスクを今日のリストに平坦化してはならない。

## 確認する入力

1. 今日の日付。
2. **Google Calendar の今日の予定**。各イベントのタイトル・開始時刻・終了時刻・場所/種別の手がかりを確認する。
3. 今日の `DailyNote` エントリ。存在する場合。
4. 未完了の `Task` エントリ。
5. `DueDate` が近いタスク。
6. `Project::DueDate` が近いアクティブな Project。
7. `ScheduledDate` が今日以前のタスク。
8. `Task::Bucket = Next` のタスクと、その `ActivatedDate`。
9. `Task::Bucket = Await` のタスクのうち、`WaitingSince` が古いもの、または `ScheduledDate` が今日以前のもの。
10. Task に `EstimatedMinutes` がある場合はその値。
11. 関連するアクティブな `Project` エントリと、必要に応じてその `# Plan` セクション。
12. 今日の `Event` エントリ。予定の負荷が利用可能時間に影響する場合。
13. 今日に関係する commitment anchor ポリシー（`Organization` / `Area` / `Project` / `Goal`）：
   - `DailyFloorCommitment`
   - 直近 `WeeklyNote` で今日に割り当て済みの `WeeklyQuotaCommitment`
   - `StretchPolicy = MaximizeWhenPossible` の対象

追加で、日次計画の前に以下を確認する：

1. **今日は大学登校日か**。平日はまず登校日である可能性を考え、授業間の休み時間を作業時間として安易に数えない。
2. **外出予定に移動時間が含まれているか**。Google Calendar に外出予定があるのに移動時間が明記されていなければ、移動時間を必ずユーザーに確認する。
3. **ご飯・洗濯・お風呂の時間が必要か**。カレンダーや既存計画から読めない場合は、必要の有無と概算時間をユーザーに確認する。
4. **希望する起床時刻・就寝時刻**。大学登校日でなければ必ず把握する。
5. **今日の quota 配分が決まっているか**。`WeeklyQuotaCommitment` 対象があるのに、今週の `WeeklyNote` に今日の枠が書かれていなければ、日次の場で勝手に埋めず、週次の粗配分不足として扱う。

## 書き込み前ゲート

以下が終わるまで DailyNote 作成や Task 更新をしない：

- `list_tags` を読んだ
- `references/query-pack.md` にある日次計画必須取得順を完了した
- Pre-flight Check を完了した
- Google Calendar の当日予定をタイトル付きで取得した

Google Calendar 未取得、Pre-flight 未完了、移動時間未確認のいずれかなら停止する。

## Pre-flight Check (Stale Task Radar)

日次計画を開始する前に、**必ず以下の検索を実行し、該当タスクが存在するか確認する**。これらのタスクが存在する場合、**新規タスク選定や DailyNote 確定を行う前に処遇を決定する**。

### 検索クエリ（毎日必須）

1. **古い Next**: `Task::Bucket = Next` かつ `Status != Done` かつ `ActivatedDate` が3日以上前
2. **古い Await**: `Task::Bucket = Await` かつ `Status != Done` かつ `WaitingSince` が3日以上前
3. **期限超過**: `DueDate < today` かつ `Status != Done`
4. **Project 締切超過/接近**: `Project::DueDate <= today`、または直近で `Project::Status = Active`
5. **予定超過**: `ScheduledDate <= today` かつ `Status != Done`

### 処遇決定フロー

1. **期限超過（DueDate < today）**
   - 最優先で扱う。即座に今日の Deep Work または Shallow Work 枠に割り当てる。
   - どうしても今日実行不可能な場合のみ、**理由を DailyNote に記録した上で** `DueDate` を再設定する。

2. **Project 締切超過/接近**
   - `Project::DueDate` を守るために、今日どの Task を進めるかを先に決める。
   - どうしても締切の再設定が必要なら、**理由を DailyNote に記録した上で** `Project::DueDate` を更新する。
   - 子 Task に `DueDate` がある場合、それが `Project::DueDate` を後ろ倒ししていないか確認する。

3. **予定超過（ScheduledDate <= today）**
   - 今日のスケジュールに含めるか、**意図的に延期するか**を決定する。
   - 延期する場合は、**新しい `ScheduledDate` と延期理由を DailyNote に記録する**。

4. **古い Next（ActivatedDate >= 3日前）**
   - 実行、分解、`ScheduledDate` 設定、`Someday` 化、`Await` 化のいずれかを必ず決める。

5. **古い Await（WaitingSince >= 3日前）**
   - 催促・再連絡・別経路確認を検討。必要なら `ScheduledDate` に催促日を設定する。

### Pre-flight 完了基準

- [ ] 期限超過タスクが0件、または全てに今日の処遇が決定済み
- [ ] 締切超過または直近の `Project::DueDate` を持つ Active Project が0件、または全てに今日の処遇が決定済み
- [ ] 予定超過タスクが0件、または全てに今日の処遇（実行 or 延期理由記録）が決定済み
- [ ] 古い `Next` / `Await` が0件、または全てに具体的なアクションが決定済み

Pre-flight が終わる前に、通常タスクやコミットメント枠の時間割り当てに進まない。

## 日次計画における commitment anchor コミットメント

日次計画では、commitment anchor 由来の時間確保を次の順番で扱う。

### 1. `DailyFloorCommitment`

- その日も最低限触りたい対象。
- `MinimumMinutes` を満たす枠を、約束済みタスクを壊さない範囲で先に置く。
- 対応する `Next` Task がなくても、commitment anchor 自体に対する作業枠として置いてよい。
- 習慣や継続テーマでは、その枠の中で「今日解く問題を選ぶ」「復習する範囲を決める」「ノートを見返して1問だけ解く」のように、その場で具体化してよい。
- `Project` 由来の floor で次行動が曖昧な場合は、枠を消すのではなく、その枠の前半を「今日の着手点を決める」時間として扱ってよい。

### 2. `WeeklyQuotaCommitment`

- 今日の配分は、**今週の WeeklyNote で決められた粗配分を尊重する**。
- 日次の場で「今週どこかでやればいい」と棚上げしない。
- もし WeeklyNote 側の配分が曖昧なら、その場で ad-hoc に最適化するより、週次レビュー側の不備として明示する。

### 3. `StretchPolicy = MaximizeWhenPossible`

- `DailyFloorCommitment` 対象にこのポリシーがある場合、`Task::DueDate` / `ScheduledDate` / `Project::DueDate` と quota 配分を守ったあと、余剰時間を優先的に寄せる。
- これは「最低限だけ触る」で終わらせないためのバイアスである。

## 稼働可能時間の計算とタイムスケジュール作成

Google Calendar の予定から実際の稼働可能時間を割り出し、**タスクを具体的な時間枠に配置する**。

### ステップ1: 予定の取得と時間マップ作成

1. 予定を取得し、各イベントについてタイトルを必ず保持する
2. タイムラインを作成する
   - 大学登校日でなければ、起床時刻・就寝時刻から計画対象時間帯を設定する
   - 大学登校日なら、登校・授業・帰宅を中心に時間帯を構成し、授業間の短い休み時間はまず移動/準備バッファとして置く
   - 固定予定を配置する
   - ご飯・洗濯・お風呂の必要時間を先にブロックする
   - 昼休憩を確保する
   - 空き時間ブロックを特定する

外出イベントで移動時間の明示がない場合は、そこで止まってユーザーに確認する。勝手に短く見積もって詰め込まない。

### ステップ2: 空き時間ブロックの評価

評価基準：

- 大学登校日の授業間ギャップは、原則は移動・準備・小休憩
- 長めの空きコマでも、場所や食事条件が不明なら Deep Work 枠にしない
- 予定直後/直前のギャップは、移動や準備を差し引いてから可処分時間を出す
- 細切れの 10〜20 分枠は、無理に埋めない

### ステップ3: タスクの時間割り当て

**割り当ての原則**:

0. **約束を先に守る**:
   - `DueDate <= today` と `ScheduledDate <= today` と `Project::DueDate` が近い Project を先に扱う
   - 直近 WeeklyNote で今日に割り当てられた quota 枠を確認する

1. **`DailyFloorCommitment` を置く**:
   - 毎日最低限確保したい対象に、まず最低枠を置く
   - 一般に 30〜90 分のまとまった枠が望ましい
   - 対応する `Task` がなくても、anchor 自体を `:entry{#...}` で参照して枠を置いてよい

2. **今日の `WeeklyQuotaCommitment` を置く**:
   - WeeklyNote の粗配分どおりに置く
   - quota を残日数に丸投げしない

3. **Deep Work は大きなブロックに配置**:
   - 90〜120分必要なら、連続したブロックに置く

4. **Shallow Work は隙間に配置**:
   - 30〜60分のブロックに短い作業を入れる

5. **余剰時間を `MaximizeWhenPossible` 対象へ寄せる**:
   - その日まだ余力がある場合、優先的に追加配分する

6. **EstimatedMinutes は弱い制約として使う**:
   - `240` は、そのまま4時間確保するより、今日着手する部分を切り出せないか先に検討する

## 選定とスケジューリングの原則

- **実質稼働可能時間を上限**としてタスクを選定する。
- **選定したタスクには必ず時間枠を割り当てる**。
- `EstimatedMinutes` は詰め込み防止や枠の大きさ判断には使ってよいが、厳密な消化義務として扱わない。
- すべての `Next` タスクを機械的に含めない。
- `ActivatedDate` が古い `Next` は、そのまま今日の実行候補に入れるのではなく、粒度・前提・コミットの破綻を疑って扱う。
- **日次計画は週次計画の派生**である。今日の quota 配分やその日の最低枠を、日次で勝手に無視して再構成しない。

### Promise Lock（日付の遵守ルール）

`ScheduledDate` と `DueDate` と `Project::DueDate` は**「優先度マーカー」ではなく「約束」**として扱う。

- `ScheduledDate <= today` または `DueDate <= today` の未完了タスク、または `Project::DueDate` が近い Active Project がある場合、それらを**今日のスケジュールに含めるか、意図的に延期するか**を最初に決定する。
- `ScheduledDate` や `DueDate` や `Project::DueDate` を変更した場合は、**変更理由を DailyNote の「日次振り返り」セクションに必ず記録する**。

## Deep Work / Shallow Work

### Deep Work

- 読書、設計、執筆、スライド作成、レビュー反映、難しい判断、長時間の集中が必要な作業に使う。
- `DailyFloorCommitment` や quota 枠が設計・実装・調査系なら、まず Deep Work 候補として評価する。
- 90〜120分のブロックを優先する。

### Shallow Work

- 日程調整、メッセージ、確認、ファイル整理、短い提出、軽いメモ、単純な反復作業に使う。

## DailyNote への書き方

- `## 今日のスケジュール` 配下に、各時間枠を `### HH:MM-HH:MM` 見出しで並べる
- 各時間枠は plain text だけでも読める形にする
- 対象となる Entry がある時間枠は、各時間枠の直下に `:entry{#...}` を単独で書けばよく、タイトルを別に書かない
- Google Calendar の予定など対応する Entry がない時間枠は平文で書く
- 別立ての `## 参照` セクションは作らない
- quota 枠と daily floor 枠は、本文中で区別して書いてよい

例：

```md
## 今日のスケジュール
### 09:30-10:30
:entry{#...}
必要なら補足を書く

### 11:00-11:30
研究室ミーティング（Google Calendar）

### 20:30-21:30
:entry{#...}
今週 quota 枠
```

## 出力前チェック

- [ ] すべてのタスクに具体的な時間枠が割り当てられているか
- [ ] `DueDate` / `ScheduledDate` を持つタスクや `Project::DueDate` を持つ Active Project を見落としていないか
- [ ] `DailyFloorCommitment` を置くべき対象を後回しにしていないか
- [ ] 今日の quota 配分を WeeklyNote とズラしていないか
- [ ] `MaximizeWhenPossible` 対象への追加配分は、約束済みタスクを壊していないか
- [ ] `ScheduledDate` / `DueDate` / `Project::DueDate` を変更した場合、理由を記録したか

## 避けること

- 週内 quota を「今日は気分じゃないから後で」で流す
- `DailyFloorCommitment` を「余ったらやるもの」として最後に回す
- 旧 `StrategicBlock` 的な発想で、すべての対象に毎日均等に1件ずつ置こうとする
- 現実的でない日に無理に最低枠や quota 枠を積み上げる
