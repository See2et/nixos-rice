---
name: miloa-gtd
description: Manage GTD-style tasks, projects, areas, inbox cleanup, Next actions, Waiting For, Someday items, review hygiene, weekly reviews, and realistic daily plans in the user's miloa workspace. Use when Codex is asked to create, review, audit, organize, or update miloa Task/Project/Area/DailyNote/WeeklyNote/Event entries; process an inbox; preserve a trustworthy Next list; detect stale or malformed Project/Task/Area states; choose today's tasks; run weekly reviews; or write a DailyNote plan from miloa tasks.
---

# miloa GTD

ユーザーの miloa タスクシステムを扱うときは、このスキルを使用する。目的は構造を増やすことではない。目的は `Next` の信頼性を保ち、`Await` を放置されない待ちリストとして保ち、現実的に完了できる日次計画を作ることである。また、miloaにはMCP経由でアクセスすることができる。

## 必須コンテキスト

miloa のエントリを書き込む、または更新する前に：

1. `list_tags` で最新の miloa タグスキーマを読み込む。
2. 新規作成する前に、既存の `Task` と `Project` エントリを検索する。
3. 重複を作成するよりも、既存エントリの更新・リンク・言及を優先する。
4. ユーザーが明示的に依頼した場合、または持続的なワークフロー上の問題に必要な場合を除き、新しいタグやフィールドを作成しない。

## コアスキーマ

miloa の現在のスキーマを唯一の正として使用する。このスキル作成時点で、関連するタグは以下の通り：

- `Area`: `Name`, `Description`, `Goals`.
  - 機能的な責務領域。純粋な分類タグ。
  - `Area::Goals` は Array of EntryRef (`Goal` タグ制約)。この Area が貢献する上位目標。
- `Organization`: `Name`, `StrategicBlock`, `WeeklyReview`, `Description`.
  - 組織・チーム・ブランドの文脈。Project に紐付ける。
  - `Organization::StrategicBlock`: 戦略的に注力する Organization かどうか。
  - `Organization::WeeklyReview`: 週次レビューで進捗確認する対象とするか。
- `Task`: `Status`, `Bucket`, `Context`, `DueDate`, `ScheduledDate`, `Project`, `Area`, `EstimatedMinutes`.
  - `Task::Bucket = Next` のときは `Task::Bucket::Next::ActivatedDate` を使う。
  - `Task::Bucket = Await` のときは `Task::Bucket::Await::Reason` と `Task::Bucket::Await::WaitingSince` を使う。
  - `Task::EstimatedMinutes` は任意の Enum で、想定値は `5`, `15`, `30`, `60`, `90`, `120`, `240`.
- `Project`: `Status`, `Area`, `Organization`.
  - `Project::Organization` は EntryRef (`Organization` タグ制約)。この Project が属する組織・ブランド。
- `Purpose` (H5): `Name`, `Status`, `Description`.
  - 原理・価値観。「なぜやるのか」。
- `Vision` (H4): `Name`, `Status`, `ParentPurposes`, `Description`.
  - `Vision::ParentPurposes` は Array of EntryRef (`Purpose` タグ制約)。導かれる上位原理。
- `Goal` (H3): `Name`, `Status`, `ParentVisions`, `TargetDate`, `Description`.
  - `Goal::ParentVisions` は Array of EntryRef (`Vision` タグ制約)。導かれる上位ビジョン。
  - `Goal::TargetDate` は Date。12〜24ヶ月での達成目標日。
- `DailyNote`: `Date`.
- `WeeklyNote`: `Date`.
- `Event`: `StartDate`, `EndDate`, `参加者`.

**外部データソース**: Google Calendar（日次計画時に参照し、実質稼働可能時間を計算する）

## EstimatedMinutes の扱い

- `EstimatedMinutes` は**必須ではない**。未設定だからといって Task を壊れている扱いにしない。
- これは厳密な工数ではなく、**日次計画で詰め込みを防ぐための見込み時間**として使う。
- `Context` と組み合わせて、その場で実行しやすい長さか、今の場所や道具で着手しやすいかを判断する。
- `240` は「今日は4時間これをやる」と読むのではなく、**分割や再設計を検討すべき警告値**として扱う。
- 見積もりが長い Task でも、状況に応じて「今日は半分だけ進める」「30分だけ着手して次の具体的な行動を切り出す」といった扱いを許容する。
- DailyNote では、`EstimatedMinutes` をそのまま消費義務として扱わない。**今日確保する時間枠**と**Task の見込み時間**は別物でありうる。

## Bucket 運用の要点

- `Next` は「今すぐ、前提なしで着手できる次の行動」に限定する。
- `Await` は「外部の返信・承認・対応を待っている状態」に限定する。
- Bucket を `Next` / `Await` に変更したら、それぞれ `ActivatedDate` / `WaitingSince` を設定する。
- レビューで見送るだけなら、`ActivatedDate` / `WaitingSince` を更新しない。
- 詳細な Bucket 判断、日付ルール、`Reason` / `ScheduledDate` の使い分けは `references/gtd.md` を正とする。

## 鮮度管理

- 古い `Next` / `Await` は、優先度の高さではなく、粒度・前提・待機方針の見直しが必要かもしれないシグナルとして扱う。
- 日数ベースの目安と具体的な見直しアクションは `references/gtd.md` と `references/daily-plan.md` を参照する。

## GTD 健全性レビュー

Project / Task のレビュー依頼では、単に一覧を読むのではなく、GTD として壊れている箇所を優先して検出する。

最初に `references/gtd.md` を読み、未完了の `Project` / `Task` を検索して以下を確認する：

1. `Project::Status = Active` なのに、有効な `Next` が1件もない Project。
2. `Project::Status = Active` なのに、残タスクが `Await` だけで止まっている Project。
3. `Await` に必要な `Reason` / `WaitingSince` / 必要に応じた `ScheduledDate` が欠けている Task。
4. 古い `Next` / 古い `Await`。
5. `DueDate` / `ScheduledDate` が今日より前なのに未完了の Task。
6. 1 Project に `Next` が多すぎる状態。
7. Project 本文の `# Plan` と実際の Task 状態のズレ。
8. 重複していそうな Task / Project。
9. `Status` と `Bucket` の差分が実務上問題を起こしていそうな Task。
10. Active でない Project に、未完了の実行タスクがぶら下がっていないか。
11. `EstimatedMinutes = 240` の Task や、明らかに粒度が粗く日次計画に載せにくい Task。

ユーザー運用で `Status` の信頼度が `Bucket` より高い場合は、まず `Status` を正として読む。`Status = Done` かつ `Bucket = Next` / `Await` は即座に破損扱いせず、必要なら Bucket 整備候補として軽く触れる。

レビューでは「壊れている理由」と「最小の修正方針」をセットで返す。自動修正を依頼されていない限り、いきなり大量変更せず、まず検出結果を整理して伝える。

`EstimatedMinutes` はレビューの補助シグナルとして使うが、未設定や多少のズレを過剰に問題化しない。特に `240` は見積精度の問題というより、Task 分割や「今日どこまでやるか」の切り方を見直す候補として扱う。

## 日次計画で必ず確認すること

1. **Pre-flight Check（Stale Task Radar）を実行する**。`ActivatedDate` から3日以上経った `Next`、`WaitingSince` から3日以上経った `Await`、`DueDate < today` の未完了タスク、`ScheduledDate <= today` の未完了タスクを検索し、**全てに処遇（実行/分割/再設定/Bucket変更）を決定してから**新規タスク選定に進む。詳細は `references/daily-plan.md` の「Pre-flight Check」を参照。
2. Google Calendar の当日予定は、**開始時刻・終了時刻に加えてイベントタイトルも必ず取得する**。
3. 予定と予定の間の時間は機械的に「空き時間」とみなさず、**その場で実行可能な時間か**を判定する。
4. 日次計画では、**戦略Organization枠を締切タスクより先に検討する**。戦略Organizationとは `Organization::StrategicBlock = true` の Organization である。詳細は `references/gtd.md` の Organization 運用節を参照。
5. 戦略Organization枠は、ユーザーが拒否しない限り**毎日確保する**。現実的でない場合は、特定の日に集中して確保するよう提案する。
6. 平日は大学の登校日である可能性をまず考慮する。大学登校日では、授業間の休み時間は原則として**次の講義室への移動、授業準備、短い休憩**に使われるものとして扱い、タスク時間に自動変換しない。
7. Google Calendar に外出予定があり、前後の移動時間が明記されていない場合は、**移動時間の見積もりを必ずユーザーに確認する**。
8. ご飯・洗濯・お風呂の時間が予定に明記されていない場合は、それぞれについて**その日に確保が必要かどうか、必要ならどれくらい見込むかをユーザーに確認する**。
9. 大学登校日でない日次計画では、ユーザーの希望する**起床時刻と就寝時刻**を把握してから、計画可能時間帯を確定する。大学登校日は、起床後すぐ登校する前提として起床時刻の確認は省略してよい。
10. 上の確認が済んでいない場合は、見切り発車で DailyNote を確定しない。まず不足情報を短く確認する。
11. DailyNote のタイムスケジュール表は、**mention 展開に依存せず plain text だけでも読める形**で書く。`:entry{#...}` は参照情報として別セクションに分けるか、plain text の補助としてのみ使う。
12. `EstimatedMinutes` がある Task は参考にしてよいが、**見込み時間をそのまま一日で消化しようとしない**。必要なら、その日の枠では一部だけ進める前提で計画する。
13. **`ScheduledDate` や `DueDate` を変更した場合は、理由を DailyNote の「日次振り返り」セクションに必ず記録する**。
14. その日の**作業終了時刻**を確認する。原則として月〜木は27〜28時まで許容し、金〜日は23時頃までを目安とする。夜遅くまで外出がある日は、帰宅後の作業時間は確保できない前提とする。詳細は `references/daily-plan.md` の「作業終了時刻の確認」を参照。

## ワークフロー

Area の定義、スキーマ、Area と Project/Task / Organization / Goal の関係については、`references/area.md` を読む。

Organization の定義、スキーマ、`StrategicBlock` / `WeeklyReview` の運用、Organization と Project の関係については、`references/gtd.md` を読む。

タスクとプロジェクトのキャプチャ、インボックス処理、Next/Await/Someday の判断、`ActivatedDate` / `WaitingSince` を含む Bucket 更新ルール、Project 計画、Organization 運用については、`references/gtd.md` を読む。

Project / Task の健全性レビュー、停滞検出、Plan と Task の整合性確認、重複候補の扱いについては、`references/gtd.md` のレビュー節を読む。

「今日やること」、日次タスク選定、Deep Work/Shallow Work 分類、Eisenhower トリアージ、古い `Next` / `Await` の扱い、DailyNote 作成については、`references/gtd.md` の後に `references/daily-plan.md` を読む。

**週次レビュー（週1回、日曜または月曜）**：
1. `references/weekly-review.md` を読み、週次レビューフローを実行する
2. `Organization::WeeklyReview = true` の Organization を全てレビューし、週間タイムラインを作成する
3. `Organization::StrategicBlock = true` の戦略Organizationの週次目標を設定する
4. 締切タスクと `ScheduledDate` の週内配置を計画する
5. 異常（締切集中、過積載、戦略枠ゼロ）を検出し調整する
6. 週次レビュー結果を `WeeklyNote` エントリとして miloa に記録する

**Horizon Review（明示依頼時のみ）**：
1. ユーザーが「Horizon Review」「方向性の確認」「上位目標のレビュー」などと明示的に依頼したときのみ実行する
2. `references/horizon-review.md` を読み、レビューフローを実行する
3. `Purpose` / `Vision` / `Goal` エントリを取得し、整合性マトリクスを構築する
4. `Area` エントリの `Goals` リンクと、各 Area に紐づく Active Project の状態を確認する
5. 異常を検出し、最小の修正方針をユーザーに提示する。自動修正は行わない
6. 通常の週次レビュー・日次計画・GTD 健全性レビューでは Horizon に触れない

**Daily 計画のフロー**：
1. **Pre-flight Check（Stale Task Radar）**: 古い `Next` / `Await` / 期限超過 / 予定超過を検索し、処遇決定
2. **Google Calendar を参照**して今日の予定をタイトル付きで取得
3. **不足情報を確認**し、移動・生活時間・起床/就寝条件を埋める
4. **空き時間ブロックを特定**し、実質稼働可能時間を計算
5. **戦略Organization枠を先に検討**し、`StrategicBlock = true` の各Organizationから最低1件ずつ選定し時間枠を予約する
6. **`EstimatedMinutes` と `Context` を補助的に見ながら**、残り時間で締切タスクや通常タスクを選定し、具体的な時間枠を割り当てる
7. **時刻付きのスケジュールを DailyNote に記載**
8. **`ScheduledDate` / `DueDate` を変更した場合は理由を DailyNote に記録**

戦略プロジェクト枠の詳細な選定ルール、時間幅、見送り条件、DailyNote への書き方は `references/daily-plan.md` を正とする。週次レビューの詳細は `references/weekly-review.md` を正とする。

## 出力期待

miloa を変更した場合は、何を変更したか、なぜ変更したかをユーザーに伝える。チャット出力は簡潔に保つが、`Next` / `Await`、`ActivatedDate` / `WaitingSince` / `ScheduledDate`、Project リンクが保守的に処理されたことを検証できるだけの詳細は含める。

レビューだけを行う場合は、重大度順または Project ごとに、検出した問題・根拠・推奨アクションを短く列挙する。問題がなければ、その旨と未確認の残留リスクを伝える。

不確実な場合は、網羅性よりも `Next` の信頼性を守る。

## 出力前自己検証リスト

miloa を変更したり、日次計画・週次レビューを出力する前に、以下を機械的に確認する：

- [ ] 新しいフィールドやタグを勝手に追加していないか
- [ ] `ScheduledDate` / `DueDate` を持つタスクを無視して選定していないか
- [ ] Pre-flight Check（Stale Task Radar）をスキップしていないか
- [ ] 古い `Next` / `Await` をそのまま今日の候補に入れていないか
- [ ] 戦略Organization枠を締切タスクより後回しにしていないか
- [ ] `EstimatedMinutes = 240` のタスクを分割検討なしにそのままスケジュールに押し込んでいないか
- [ ] `ScheduledDate` / `DueDate` を変更した場合、理由を記録したか
- [ ] 同じタスクを繰り返し延期し、理由の特定と解消を行っていないか
- [ ] DailyNote のタイムスケジュール表が plain text だけでも読める形になっているか
- [ ] Horizon Review を依頼されていないのに、勝手に上位目標や Area の Goals リンクに触れていないか
