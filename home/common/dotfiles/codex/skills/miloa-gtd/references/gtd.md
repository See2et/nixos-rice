# miloa における GTD ルール

## 原則

`Task::Bucket = Next` は、未解決の前提条件なしに今すぐ着手できるアクションに限定する。将来の Project ステップは、それが実行可能になるまで Project 本文内に置き、通常は `# Plan` の下に記載する。

## GTD マッピング

| GTD 概念 | miloa での表現 |
|---|---|
| Area of Responsibility | `Area` |
| Organization context | `Project::Organization` |
| Inbox | `Bucket` と `Project` が未設定の `Task` |
| Next Action | `Task::Bucket = Next` |
| Next 化した日 | `Task::Bucket::Next::ActivatedDate` |
| Someday/Maybe | `Task::Bucket = Someday` |
| Waiting For | `Task::Bucket = Await` |
| 待ち始めた日 | `Task::Bucket::Await::WaitingSince` |
| Project | `Project::Status = Active` |
| Project の厳格な締切 | `Project::DueDate` |
| Done | `Task::Status = Done` |
| 着手・確認・催促日 | `Task::ScheduledDate` |
| Task の厳格な締切 | `Task::DueDate` |
| 見込み時間 | `Task::EstimatedMinutes` |
| 毎日最低限確保したい対象 | `DailyFloorCommitment` タグを持つ commitment anchor (`Organization` / `Area` / `Project` / `Goal`) |
| 週あたり必要時間を積みたい対象 | `WeeklyQuotaCommitment` タグを持つ commitment anchor (`Organization` / `Area` / `Project` / `Goal`) |
| 曜日ごとにレビューする対象 | `WeeklyReviewTarget` タグを持つ `Organization` |
| 将来の Project ステップ | Project 本文の `# Plan` |

## タスクタイトル

タイトルは次の形を優先する：

`[動詞] + [対象] + [完了条件]`

良い例：

- `山田さんに確認メッセージを送る`
- `The Sybil Attackの要約メモを作る`
- `レポートの導入を400字で下書きする`

`レポート`、`xxx改善`、`発表準備`、`考える`、`対応する` のような曖昧なトピック名は避ける。

抽象動詞も避ける。特に `考える` `検討する` `確認する` `対応する` `進める` `整理する` `見直す` `詰める` は、そのままでは Task 名として弱いことが多い。

### 具体動詞テスト

Task を作る前に、少なくとも次を満たすか確認する：

- タイトルを見た瞬間に、最初の5分で何をするか説明できる
- 完了後に何が残るかを言える
- 他人が見ても、作業対象と終わり方を大きく誤読しない

言い換え例：

- `レポートを考える` -> `レポート導入の論点を3つ箇条書きする`
- `発表準備を進める` -> `発表スライド1-5枚目の見出しを下書きする`
- `論文を確認する` -> `論文の関連研究節を読んで比較ポイントを3つメモする`
- `問い合わせ対応` -> `X社に請求番号の確認メールを送る`

`確認する` を使うなら、「何を確認し、確認後に何を決めるか」が補助説明なしで分かる形まで具体化する。

## Bucket ルール

### Next

以下すべてが真の場合のみ使用する：

- 未完了の前提条件がタスクをブロックしていない。
- タイトルに、明確な物理的または認知的なアクション動詞が含まれている。
- タイトルが抽象動詞やトピック名だけで止まっておらず、完了条件まで見える。
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

- `Project::DueDate`: その日までに Project の成果が成立していなければならない厳格な締切。
- `DueDate`: その日までに Task が完了していなければならない厳格な締切。
- `ScheduledDate`: ユーザーがそのタスクを開始、確認、または催促すると決めた日付。
- `ActivatedDate`: その Task が `Next` として実行可能になった日付。
- `WaitingSince`: その Task が `Await` として外部待ちになった日付。

`Project::DueDate` と `Task::DueDate` は、どちらもゆるい優先度マーカーとして使ってはならない。ユーザーが十分な情報を提供していない限り、`Project::DueDate`、`DueDate`、`ScheduledDate`、`Project` を推測して設定しない。

整合性ルール：

- 子 Task の `DueDate` は、原則として親 `Project::DueDate` を後ろ倒ししない。
- `Project::DueDate` があっても、全ての子 Task に `DueDate` を強制しない。
- ただし、`Project::DueDate` が近いのに有効な `Next` や週内配置が全く見えない状態は異常候補として扱う。

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

必要な場合のみ `Project::DueDate` を持たせる。これは成果レベルの締切であり、全子 Task の締切を自動生成するためのものではない。

トピック名ではなく、成果志向のタイトルを使う：

- `5/28 輪読発表：The Sybil Attack`
- `任意中間レポートを提出可能な状態にする`
- `xxxの限定公開画面をユーザーが試せる状態にする`

`Project::Status = Active` の最低本文：

```md
# Purpose

# Principles

# Outcome

# Plan
- [ ] 手順1
- [ ] 手順2
```

- `Purpose`: なぜこの Project をやるのか。誰にとって何が重要か。
- `Principles`: 制約、判断基準、今回はやらないこと。背景説明よりも、意思決定に効くルールを書く。
- `Outcome`: 成功状態の像、または観測可能な完了条件を 2〜5 項目程度で書く。
- `Plan`: brainstorming の生ログではなく、整理済みの塊・順序・既存 Task 参照を書く。

Natural Planning Model の `Brainstorming` は、本文に必須ではない。必要なら `Plan` を作る前段のメモとして残してよいが、Active Project の最低要件には含めない。

Natural Planning Model の `Next Actions` は本文に重複管理しない。実行単位は通常どおり `Task` と `Bucket = Next` で持つ。

Project 計画から既存タスクを参照する場合は、entry mention を使う：

```md
- [ ] :entry{#<entry_id>}
```

日程感が重要な Project では、本文に `# Schedule` セクションを置くことを強く推奨する。ここには、厳格な `Project::DueDate` や `Task::DueDate` に落とし切らないが、実際の計画で強く尊重すべき節目を書く。

例：

```md
# Schedule
- 6/25 面接本番
- 6/23 までに想定問答の叩き台
- 6/24 夜に30分だけ通し練習
```

このセクションにある日程感は、`Project::DueDate` の代替ではないが、WeeklyNote と DailyNote で拾うべき一次情報として扱う。本文に近接したマイルストーンがあるのに、それを支える `Next` や週内配置が見えない状態は異常候補である。

## Organization 運用ルール

- `Organization` は組織・ブランド・チームの文脈タグ。Area と混同しない。
- Project は必ず1つの Area に紐づける。Organization は任意（未設定も許容）。
- 組織名を Area にしない。「SuteraVR」は Organization、「技術開発」は Area。
- Organization をタスクタイトルに含めない。タスクタイトルは `[動詞] + [対象] + [完了条件]` を保つ。
- Organization 間の移行がある場合、Project の Organization を更新する。Area は変わらないことが多い。

### 推奨 Organization / commitment anchor ポリシー構造

Organization 自体はハブとして残し、レビュー対象・時間コミットメントは**追加タグ**として表すのを推奨する。レビュー曜日は `Organization` にだけ付け、時間コミットメントは `Organization` / `Area` / `Project` / `Goal` のいずれかの commitment anchor に付ける。

#### 1. `WeeklyReviewTarget`

- このタグが付いている Organization だけが週次レビュー対象。
- `Day` は必須。曜日なしレビュー対象を作らない。
- `ReviewEnabled` のような boolean は使わない。

#### 2. `DailyFloorCommitment`

- `MinimumMinutes` を持つ。
- `Organization` / `Area` / `Project` / `Goal` の commitment anchor に対する「毎日最低限触るべき対象」を表す。
- これは「対応する `Next` Task が存在するときだけ使える」タグではない。習慣や継続テーマでは、anchor 自体に対して時間枠を先に確保してよい。
- 任意で `StretchPolicy` を持つ。`MaximizeWhenPossible` の場合、約束済みタスクと当日 quota を守ったあと、余剰時間を優先的に寄せる。

#### 3. `WeeklyQuotaCommitment`

- `TargetHours` を持つ。
- `Organization` / `Area` / `Project` / `Goal` の commitment anchor に対する「1週間あたり n 時間を確保したい対象」を表す。
- 実際の配分の見取り図と優先順位は WeeklyNote で決める。日次にゼロから先送りしない。

### 無効状態を避けるルール

- 同じ commitment anchor に `DailyFloorCommitment` と `WeeklyQuotaCommitment` を同時に付けない。
- `WeeklyReviewTarget` がない Organization にレビュー曜日だけを持たせない。
- quota の存在だけを作って、WeeklyNote 側に週内の粗配分や優先順位を書かない状態を放置しない。
- `DailyFloorCommitment` は「最低限触るだけ」で終わらせない。`StretchPolicy = MaximizeWhenPossible` なら、余剰時間の寄せ先としても扱う。
- 数学のように組織ではない継続テーマへ毎日 30 分積みたい場合は、`Area` や `Goal` など適切な anchor を作り、そこへ `DailyFloorCommitment` を付ける。

### 旧式スキーマとの付き合い方

実スキーマがまだ `Organization::StrategicBlock` / `Organization::WeeklyReview` の boolean しか持たない場合：

- それを唯一の実スキーマとして尊重する。
- ただし、boolean の意味を本文運用で無理に拡張しない。
- 新しい運用を本格採用するなら、ユーザー合意のもとで `WeeklyReviewTarget` / `DailyFloorCommitment` / `WeeklyQuotaCommitment` を導入する。
- 旧式 boolean を残す場合も、新タグに移行後は二重の正を作らない。どちらを正にするかを決める。

## タスクを作成する前に

1. 関連するアクティブな Project を検索する。
2. 類似する Task を検索する。
3. 重複が存在する場合は、既存の Task を更新するか、Project 本文から言及する。
4. 曖昧な依頼は、書き込む前に具体的な Next Action に変換する。
5. 変換後の Task 名が抽象動詞で止まるなら、さらに「何を出力するか」「誰に送るか」「どこまで作るか」を補ってから作成する。

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

#### 4. 古い Next / Await

- `Next`: `ActivatedDate` から 3 / 7 / 14 日の目安で滞留を判定する
- `Await`: `WaitingSince` から 3 / 7 / 14 日の目安で滞留を判定する

目安ごとの扱い：

- 3日: 単なる優先度不足ではなく、粒度・前提条件・置き場所の見直し候補として扱う
- 7日: 実行、分解、`ScheduledDate` 設定、`Await` 化、`Someday` 化のいずれかを具体的に決める
- 14日: そのまま据え置く前提を疑う。Project 計画の破綻、コミット過多、次行動の曖昧さを優先的に疑う

#### 5. 抽象動詞やトピック名だけの Task

- `考える` `検討する` `対応する` `進める` `整理する` などで止まっている
- `発表準備` `レポート` `就活` のようなトピック名だけで、何をするかが不明
- `確認する` だが、確認対象や確認後の判断が見えない

この場合は、優先度の問題ではなく**着手点の欠落**として扱う。`Next` に置いたままにせず、具体動詞への改名、分割、または Project `# Plan` への格納を検討する。

#### 6. DueDate / ScheduledDate 超過

- `DueDate < today` で `Status != Done`
- `ScheduledDate < today` で `Status != Done`
- `Project::DueDate < today` で `Project::Status = Active`

#### 7. Project ごとの Next 過多

直列型 Project では、原則として `Next` は 1 件、多くても 2〜3 件までに抑える。

#### 8. Project 本文の Plan と Task 状態のズレ

- `# Plan` にある未着手ステップが、Task 側では既に `Done` になっている
- `# Plan` に完了済みとして見える内容が、Task 側では未完了のまま

#### 9. Project 締切と子 Task の不整合

- `Project::DueDate` があるのに、関連する Task の `DueDate` がそれより後ろにある
- `Project::DueDate` が近いのに、有効な `Next` や今週内の配置が見えない
- `Project::DueDate` を支える Task 群が粗すぎて、週次・日次の計画に落ちない

#### 10. Project 本文の日程感が計画に反映されていない

- `# Schedule` や `# Plan` に今週内または直近数日のマイルストーンが書かれている
- それを支える `Next`、`ScheduledDate`、WeeklyNote 上の配置、または DailyNote 上の処遇が見えない
- `Project::DueDate` は遠くても、本文上は手前の節目があるのに放置されている

#### 11. Organization / commitment anchor ポリシーの破損

- `WeeklyReviewTarget` があるのに `Day` が欠けている
- 同じ commitment anchor に `DailyFloorCommitment` と `WeeklyQuotaCommitment` が同時に付いている

## レビュー結果の返し方

健全性レビューを返すときは、各指摘について少なくとも次を短く揃える：

- 問題: 何が壊れているか
- 根拠: どの field / Task / Project / Organization に基づくか
- 最小の修正方針: まず何を直せばよいか
- 抽象 Task 名が原因なら、可能なら 1 つ具体的な言い換え案を添える

推奨の粒度：

- 重大度順、または Project ごとにまとめる
- 自動修正を依頼されていない限り、大量変更の前に検出結果を先に返す
- 問題がない場合も、「問題なし」で終わらせず、未確認の残留リスクがあれば添える
- `WeeklyQuotaCommitment` があるのに、直近 WeeklyNote に週内の粗配分や優先順位が書かれていない
- `DailyFloorCommitment` の対象が長期間 DailyNote 上で一度も最低枠を確保できていない
- Active Project を一部しか見ず、本文の `# Schedule` / `# Plan` にある近接マイルストーンを落としている

## やってはいけないこと

- `Priority`、`Energy`、`Blocked`、`Goal`、`NextAction`、`WaitingFor` のような追加フィールドを気軽に増やす
- `Organization` だけでレビュー対象か時間コミットメント対象かを全部抱え込ませる
- 旧式 boolean と新タグの両方を更新し続けて、どちらが正か分からない状態を作る
- `DailyFloorCommitment` と `WeeklyQuotaCommitment` を曖昧に併用する
