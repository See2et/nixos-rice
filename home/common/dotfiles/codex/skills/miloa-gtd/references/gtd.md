
# miloa における GTD ルール

## 原則

`Task::Bucket = Next` は、未解決の前提条件なしに今すぐ着手できるアクションに限定する。将来の Project ステップは、それが実行可能になるまで Project 本文内に置き、通常は `# Plan` の下に記載する。

## GTD マッピング

| GTD 概念 | miloa での表現 |
|---|---|
| Area of Responsibility | `Area` |
| 日次で先に時間枠を確保する対象 | `Organization::StrategicBlock = true` |
| Inbox | `Bucket` と `Project` が未設定の `Task` |
| Next Action | `Task::Bucket = Next` |
| Next 化した日 | `Task::Bucket::Next::ActivatedDate` |
| Someday/Maybe | `Task::Bucket = Someday` |
| Waiting For | `Task::Bucket = Await` |
| 待ち始めた日 | `Task::Bucket::Await::WaitingSince` |
| Project | `Project::Status = Active` |
| Done | `Task::Status = Done` |
| 着手・確認・催促日 | `Task::ScheduledDate` |
| 厳格な締切 | `Task::DueDate` |
| 見込み時間 | `Task::EstimatedMinutes` |
| Organization context | `Project::Organization` |
| 将来の Project ステップ | Project 本文の `# Plan` |

## タスクタイトル

タイトルは次の形を優先する：

`[動詞] + [対象] + [完了条件]`

良い例：

- `山田さんに確認メッセージを送る`
- `The Sybil Attackの要約メモを作る`
- `レポートの導入を400字で下書きする`

`レポート`、`xxx改善`、`発表準備`、`考える`、`対応する` のような曖昧なトピック名は避ける。

## Bucket ルール

### Next

以下すべてが真の場合のみ使用する：

- 未完了の前提条件がタスクをブロックしていない。
- タイトルに、明確な物理的または認知的なアクション動詞が含まれている。
- 今始めても大きな手戻りが発生しない。
- Project 計画内の単なる将来ステップではない。

直列型 Project では、原則として有効な `Next` は最大1件に保つ。作業が本当に並行して進められる場合のみ、2〜3件を許容する。

`Next` に変更する場合は、原則として `Task::Bucket::Next::ActivatedDate = today` を設定する。レビューで見送っただけなら更新しない。

### Await

他者、システム、承認、返信、外部プロセスなど、外部依存がある場合のみ使用する。

設定するもの：

- `Task::Bucket = Await`
- `Task::Bucket::Await::Reason` に、誰／何を待っているのかを設定する。
- `Task::Bucket::Await::WaitingSince = today` を設定する。
- 必要なら `Task::ScheduledDate` に催促・再確認する日を設定する。

「アウトラインを作ってから下書きする」のような内部的な順序関係には `Await` を使わない。それは Project 計画に置く。

### Someday

ユーザーが現時点でコミットしていない任意の候補に使用する。アクティブな Project に必要な将来ステップを `Someday` に入れない。

### Bucket 未設定

未処理の Inbox 項目、またはキャプチャだけが目的の軽量なバックログに使用する。

## 日付

- `DueDate`: その日までにタスクが完了していなければならない厳格な締切。
- `ScheduledDate`: ユーザーがそのタスクを開始、確認、または催促すると決めた日付。
- `ActivatedDate`: その Task が `Next` として実行可能になった日付。
- `WaitingSince`: その Task が `Await` として外部待ちになった日付。

`DueDate` をゆるい優先度マーカーとして使ってはならない。ユーザーが十分な情報を提供していない限り、`DueDate`、`ScheduledDate`、`Project` を推測して設定しない。

`ActivatedDate` と `WaitingSince` は鮮度管理用の日付であり、Bucket を変えずにレビューで見送っただけでは更新しない。

## EstimatedMinutes

- `Task::EstimatedMinutes` は任意の Enum で、`5`, `15`, `30`, `60`, `90`, `120`, `240` を想定する。
- これは工数実績や厳密見積もりではなく、**Task の重さと日次計画の載せやすさを見るための補助情報**として使う。
- 未設定は許容する。設定されていない Task を自動で不備扱いしない。
- `240` は「4時間ブロックを確保すべき」という意味ではなく、**Task 分割や中間完了条件の切り出しを検討すべき警告値**として扱う。
- 長い見込み時間の Task でも、1日で全部を消化しなくてよい。必要なら「今日は最初の30分だけ」「ここまで進める」と切って扱う。

## Bucket 変更時の日付ルール

- `Next` にする場合: `ActivatedDate = today`。`WaitingSince` は持たせない。
- `Await` にする場合: `WaitingSince = today`。`Reason` を必ず書く。`ActivatedDate` は持たせない。
- `Someday` にする場合: `ActivatedDate` と `WaitingSince` は原則不要。
- `Done` にする場合: 完了状態が分かればよく、鮮度日付を更新しない。
- Bucket を変えずにレビューで見送るだけの場合: `ActivatedDate` / `WaitingSince` を更新しない。

## Project ルール

望ましい成果が2ステップ以上を必要とする場合、Project を作成する。

Project は `Area` に紐づける。Area は継続的な責務領域で終了がなく、Project は Area の中で特定の成果を目指す完了可能な単位である。

Project は `Organization` にも紐づける。Organization は組織・ブランドの文脈で、Area とは別次元である。例: `Project::Area = 技術開発`, `Project::Organization = SuteraVR`。

トピック名ではなく、成果志向のタイトルを使う：

- `5/28 輪読発表：The Sybil Attack`
- `任意中間レポートを提出可能な状態にする`
- `xxxの限定公開画面をユーザーが試せる状態にする`

推奨 Project 本文：

```md
# 目的

# 完了条件

# Plan
- [ ] 手順1
- [ ] 手順2

# メモ
```

Project 計画から既存タスクを参照する場合は、entry mention を使う：

```md
- [ ] :entry{#<entry_id>}
```

## Organization 運用ルール

- `Organization` は組織・ブランド・チームの文脈タグ。Area と混同しない。
- Project は必ず1つの Area に紐づける。Organization は任意（未設定も許容）。
- 組織名を Area にしない。「SuteraVR」は Organization、「技術開発」は Area。
- Organization をタスクタイトルに含めない。タスクタイトルは `[動詞] + [対象] + [完了条件]` を保つ。
- Organization 間の移行（例: SuteraVR の活動を Comni.pl に移管する）がある場合、Project の Organization を更新する。Area は変わらないことが多い。

### Organization スキーマ

- `Name`: 組織名（例: SuteraVR, Comni.pl, JVSL, チームみらい, Delight）
- `StrategicBlock`: `true` | `false` — 日次計画で先に時間枠を確保する対象とするか
- `WeeklyReview`: `true` | `false` — 週次レビューで進捗確認し、今週解くべき課題を1つ決める対象とするか
- `Description`: 現在の重点目標、方針、注意事項を自由に記述

### 戦略Organization枠

日次計画における戦略Organization枠は以下のルールで選定する：

1. `StrategicBlock = true` の Organization を全件検索する
2. 各戦略Organizationに紐づく `Bucket = Next` かつ `Status != Done` のTaskを確認する
3. その日に進める候補を、**各戦略Organizationから最低1件ずつ**選定する
4. ユーザーが拒否しない限り、**毎日確保する**
5. 現実的でない場合は、「今日は省略する」ではなく「○曜日と△曜日に集中して確保する」など、**特定の日に徹底する案をユーザーに提案する**
6. 戦略Organization枠は、原則として **30〜90分** のまとまった時間で扱う。短い隙間に無理やりねじ込まない

`StrategicBlock` は、あくまで**日次で確保する時間枠の優先対象**を示すフラグである。週次レビューにおける目標設定、論点選定、解決すべき課題の決定は `WeeklyReview` 側で扱い、`StrategicBlock` 自体を週次目標タグとして使わない。

### 週次レビューでの Organization 扱い

週次レビューでは `WeeklyReview = true` の Organization を全てレビューする：

1. 各OrganizationのDescriptionを確認し、重点目標や方針の変更がないか確認する
2. 各Organizationに紐づくProjectの進捗を確認する
3. 各Organizationについて、**今週必ず解くべき課題をちょうど1つ**定義する
4. AI は課題候補を提案してよいが、**最終決定は必ずユーザーに選んでもらう**
5. `StrategicBlock = true` の Organization については、その課題を進めるための時間枠を日次計画でどう確保するかを別途考える
6. **ユーザーに同意を得てから**、Descriptionや WeeklyNote 上の課題定義を更新する

## タスクを作成する前に

1. 関連するアクティブな Project を検索する。
2. 類似する Task を検索する。
3. 重複が存在する場合は、既存の Task を更新するか、Project 本文から言及する。
4. 曖昧な依頼は、書き込む前に具体的な Next Action に変換する。

## Inbox 処理

各項目について、必要なことだけを判断する：

- 実行可能か？
- 1ステップか、Project か？
- 今すぐ実行可能か？
- 外部待ちか？
- ユーザーが締切または予定日を明示したか？

必要最小限のフィールドを設定する。曖昧なフィールドは未設定のままにする。

## Project レビュー

- 全体の手順は `# Plan` に置く。
- すぐに実行可能な作業だけを `Next` に昇格させる。
- Task が完了したら、`# Plan` を確認し、次に実行可能なステップだけを昇格させる。
- 次のステップが不明確な場合は、Task を捏造せず、レビュー対象として残す。

### 健全性レビューで確認すること

レビュー依頼では、以下を優先して検出する。

#### 1. Active Project に有効な Next がない

- `Project::Status = Active`
- 関連する未完了 Task はあるが、`Bucket = Next` の有効タスクがない

これは「止まっている Project」の最優先シグナルとして扱う。

#### 2. Active Project が Await だけで止まっている

- 関連する未完了 Task が `Await` のみ
- 自分側で進められる別 `Next` が存在しない

この場合は、待機理由が妥当か、催促日が必要か、待ちながら進められる別行動がないかを確認する。

#### 3. Await 必須情報の欠落

`Bucket = Await` の Task では、少なくとも以下を確認する：

- `Task::Bucket::Await::Reason` があるか
- `Task::Bucket::Await::WaitingSince` があるか
- 催促や再確認が必要なのに `ScheduledDate` が空で放置されていないか

`ScheduledDate` は常に必須ではないが、フォローアップ時期が明らかに必要なら欠落として扱う。

#### 4. 古い Next / Await

- `Next`: `ActivatedDate` から 3 / 7 / 14 日の目安で滞留を判定する
- `Await`: `WaitingSince` から 3 / 7 / 14 日の目安で滞留を判定する

古さ自体を悪とみなすのではなく、粒度・前提・催促方針・Project の持ち方が壊れていないかを見る。

#### 5. DueDate / ScheduledDate 超過

- `DueDate < today` で `Status != Done`
- `ScheduledDate < today` で `Status != Done`

期限超過は、見落とし、再計画不足、あるいは Task 粒度の問題のシグナルとして扱う。

#### 6. Project ごとの Next 過多

直列型 Project では、原則として `Next` は 1 件、多くても 2〜3 件までに抑える。

- 4件以上の `Next` がぶら下がっている
- 明らかに前後関係があるのに複数 `Next` が同時に開いている

この場合は、実行可能なものだけを残し、それ以外は `# Plan` に戻す候補として扱う。

#### 7. Project 本文の Plan と Task 状態のズレ

以下のズレを確認する：

- `# Plan` にある未着手ステップが、Task 側では既に `Done` になっている
- `# Plan` に完了済みとして見える内容が、Task 側では未完了のまま
- 実行タスクが進んでいるのに、`# Plan` が古いまま
- `# Plan` の entry mention が存在しない、または別の内容を指している

Project 本文は将来手順の正本、Task は現在の実行状態の正本として扱い、片方だけが更新されていない状態を検出する。

#### 8. 重複 Task / Project

次のようなものを重複候補として扱う：

- タイトルがほぼ同じ
- 同じ成果物・同じ締切・同じ Project に紐づく
- 片方が `Next`、片方が Inbox のように状態だけ違う

自動で統合せず、どちらを正本にするかを慎重に決める。

#### 9. 状態矛盾

以下を検出する：

- `Status = Done` なのに `Bucket = Next` / `Await`
- `Project::Status != Active` なのに未完了の実行タスクが複数残る
- 内部順序待ちなのに `Await` が使われている

#### 10. レビュー結果の返し方

レビューでは、各指摘について以下を短くまとめる：

- 何が壊れているか
- どの entry が該当するか
- なぜ GTD 的に問題か
- 最小の修正方針は何か

自動修正依頼がない限り、大量の Bucket 変更や日付更新を先に行わない。

#### 11. EstimatedMinutes の使い方

レビューでは `EstimatedMinutes` を厳格採点に使わず、以下のような軽い診断シグナルとして使う：

- `EstimatedMinutes = 240` なのに、タイトルや完了条件が大きすぎて分割前提に見える
- 長い見込み時間なのに、Task が抽象的で「どこまでやれば一段落か」が見えない
- `Context` と見込み時間の組み合わせが、実際の実行場所や道具に対して重すぎる

この場合は「見積もりが間違い」と断定するのではなく、Task 分割、完了条件の明確化、今日着手する部分の切り出しを最小の修正方針として提案する。

#### 12. Area の状態確認

- `Organization::StrategicBlock = true` なのに、有効な `Next` が1件もないOrganization
- `Organization::WeeklyReview = true` なのに、週次レビューで見送られ続けているOrganization
- Organization の Description が古く、現在の重点目標とズレている
- Project と Area の紐付けが欠落している、または誤っている
- `Area::Goals` が未設定の Area が多すぎる（Horizon Review で検出するもの。通常レビューでは軽く触れるに留める）

## 放置判定

### 古い Next

`Bucket = Next` かつ `Status != Done` で、`ActivatedDate` から時間が経っている Task は放置候補として扱う。

目安:

- 3日以上: レビュー対象
- 7日以上: 実行、分解、`ScheduledDate` 設定、`Someday` 化、`Await` 化のいずれかを行う
- 14日以上: 原則としてそのまま `Next` に残さない

古い `Next` を見つけたら、優先度を上げるのではなく、粒度・前提・コミットのどれが壊れているかを判断する。

### 古い Await

`Bucket = Await` かつ `Status != Done` で、`WaitingSince` から時間が経っている Task は滞留候補として扱う。

目安:

- 3日以上: 状況確認候補
- 7日以上: 催促・再連絡・別経路確認を検討
- 14日以上: そのまま `Await` に残さず、Project 方針を見直す

古い `Await` を見つけたら、催促、別ルート確認、`ScheduledDate` 設定、Done 化、Someday 化、自分側で進められる別 Next 作成のいずれかを判断する。

## 禁止事項

- `Next` を一般的な「やること」リストとして使う。
- Project 計画のすべてのステップを `Next` Task に変換する。
- 必須の Project フォローアップを `Someday` に入れる。
- 内部的な順序依存に `Await` を使う。
- `DueDate` を優先度として使う。
- レビューで見送っただけで `ActivatedDate` / `WaitingSince` を更新する。
- 少しだけタイトルが違う重複 Task を作成する。
- `Priority`、`Energy`、`Blocked`、`Goal`、`NextAction`、`WaitingFor` などのフィールドを気軽に追加する。`Area`、`Organization`、`Horizon` はスキーマとして確立済みであるが、Horizon Review 以外で勝手に上位目標に触れない。
