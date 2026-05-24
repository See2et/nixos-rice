---
name: miloa-gtd
description: Manage GTD-style tasks, projects, inbox cleanup, Next actions, Waiting For, Someday items, review hygiene, and realistic daily plans in the user's miloa workspace. Use when Codex is asked to create, review, audit, organize, or update miloa Task/Project/DailyNote/Event entries; process an inbox; preserve a trustworthy Next list; detect stale or malformed Project/Task states; choose today's tasks; or write a DailyNote plan from miloa tasks.
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

- `Task`: `Status`, `Bucket`, `Context`, `DueDate`, `ScheduledDate`, `Project`.
  - `Task::Bucket = Next` のときは `Task::Bucket::Next::ActivatedDate` を使う。
  - `Task::Bucket = Await` のときは `Task::Bucket::Await::Reason` と `Task::Bucket::Await::WaitingSince` を使う。
- `Project`: `Status`.
- `DailyNote`: `Date`.
- `Event`: `StartDate`, `EndDate`, `参加者`.

**外部データソース**: Google Calendar（日次計画時に参照し、実質稼働可能時間を計算する）

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

ユーザー運用で `Status` の信頼度が `Bucket` より高い場合は、まず `Status` を正として読む。`Status = Done` かつ `Bucket = Next` / `Await` は即座に破損扱いせず、必要なら Bucket 整備候補として軽く触れる。

レビューでは「壊れている理由」と「最小の修正方針」をセットで返す。自動修正を依頼されていない限り、いきなり大量変更せず、まず検出結果を整理して伝える。

## 日次計画で必ず確認すること

1. Google Calendar の当日予定は、**開始時刻・終了時刻に加えてイベントタイトルも必ず取得する**。
2. 予定と予定の間の時間は機械的に「空き時間」とみなさず、**その場で実行可能な時間か**を判定する。
3. 日次計画では、**戦略プロジェクト枠を締切タスクより先に検討する**。このスキルにおける戦略プロジェクトは、**SuteraVR** と **miloa** に関連する `Project` のみとする。
4. 戦略プロジェクト枠を置ける日には、**SuteraVR または miloa のどちらかから最低1件**、その日に具体的な時間枠を確保する候補を選ぶ。候補があるのに枠を置かない場合は、その理由を明示する。
5. 平日は大学の登校日である可能性をまず考慮する。大学登校日では、授業間の休み時間は原則として**次の講義室への移動、授業準備、短い休憩**に使われるものとして扱い、タスク時間に自動変換しない。
6. Google Calendar に外出予定があり、前後の移動時間が明記されていない場合は、**移動時間の見積もりを必ずユーザーに確認する**。
7. ご飯・洗濯・お風呂の時間が予定に明記されていない場合は、それぞれについて**その日に確保が必要かどうか、必要ならどれくらい見込むかをユーザーに確認する**。
8. 大学登校日でない日次計画では、ユーザーの希望する**起床時刻と就寝時刻**を把握してから、計画可能時間帯を確定する。大学登校日は、起床後すぐ登校する前提として起床時刻の確認は省略してよい。
9. 上の確認が済んでいない場合は、見切り発車で DailyNote を確定しない。まず不足情報を短く確認する。
10. DailyNote のタイムスケジュール表は、**mention 展開に依存せず plain text だけでも読める形**で書く。`:entry{#...}` は参照情報として別セクションに分けるか、plain text の補助としてのみ使う。

## ワークフロー

タスクとプロジェクトのキャプチャ、インボックス処理、Next/Await/Someday の判断、`ActivatedDate` / `WaitingSince` を含む Bucket 更新ルール、Project 計画については、`references/gtd.md` を読む。

Project / Task の健全性レビュー、停滞検出、Plan と Task の整合性確認、重複候補の扱いについては、`references/gtd.md` のレビュー節を読む。

「今日やること」、日次タスク選定、Deep Work/Shallow Work 分類、Eisenhower トリアージ、古い `Next` / `Await` の扱い、DailyNote 作成については、`references/gtd.md` の後に `references/daily-plan.md` を読む。

**Daily 計画のフロー**：
1. **Google Calendar を参照**して今日の予定をタイトル付きで取得
2. **不足情報を確認**し、移動・生活時間・起床/就寝条件を埋める
3. **空き時間ブロックを特定**し、実質稼働可能時間を計算
4. **SuteraVR / miloa の戦略プロジェクト枠を先に検討**し、置けるなら先に時間枠を予約する
5. **残り時間で締切タスクや通常タスクを選定**し、具体的な時間枠を割り当てる
6. **時刻付きのスケジュールを DailyNote に記載**

戦略プロジェクト枠の詳細な選定ルール、時間幅、見送り条件、DailyNote への書き方は `references/daily-plan.md` を正とする。

## 出力期待

miloa を変更した場合は、何を変更したか、なぜ変更したかをユーザーに伝える。チャット出力は簡潔に保つが、`Next` / `Await`、`ActivatedDate` / `WaitingSince` / `ScheduledDate`、Project リンクが保守的に処理されたことを検証できるだけの詳細は含める。

レビューだけを行う場合は、重大度順または Project ごとに、検出した問題・根拠・推奨アクションを短く列挙する。問題がなければ、その旨と未確認の残留リスクを伝える。

不確実な場合は、網羅性よりも `Next` の信頼性を守る。
