---
name: miloa-gtd
description: Manage GTD-style tasks, projects, inbox cleanup, Next actions, Waiting For, Someday items, and realistic daily plans in the user's miloa workspace. Use when Codex is asked to create, review, organize, or update miloa Task/Project/DailyNote/Event entries; process an inbox; preserve a trustworthy Next list; choose today's tasks; or write a DailyNote plan from miloa tasks.
---

# miloa GTD

ユーザーの miloa タスクシステムを扱うときは、このスキルを使用する。目的は構造を増やすことではない。目的は `Next` の信頼性を保ち、現実的に完了できる日次計画を作ることである。

## 必須コンテキスト

miloa のエントリを書き込む、または更新する前に：

1. `list_tags` で最新の miloa タグスキーマを読み込む。
2. 新規作成する前に、既存の `Task` と `Project` エントリを検索する。
3. 重複を作成するよりも、既存エントリの更新・リンク・言及を優先する。
4. ユーザーが明示的に依頼した場合、または持続的なワークフロー上の問題に必要な場合を除き、新しいタグやフィールドを作成しない。

## コアスキーマ

miloa の現在のスキーマを唯一の正として使用する。このスキル作成時点で、関連するタグは以下の通り：

- `Task`: `Status`, `Bucket`, `Context`, `DueDate`, `ScheduledDate`, `Project`.
- `Project`: `Status`.
- `DailyNote`: `Date`.
- `Event`: `StartDate`, `EndDate`, `参加者`.

**外部データソース**: Google Calendar（日次計画時に参照し、実質稼働可能時間を計算する）

## 日次計画で必ず確認すること

1. Google Calendar の当日予定は、**開始時刻・終了時刻に加えてイベントタイトルも必ず取得する**。
2. 予定と予定の間の時間は機械的に「空き時間」とみなさず、**その場で実行可能な時間か**を判定する。
3. 平日は大学の登校日である可能性をまず考慮する。大学登校日では、授業間の休み時間は原則として**次の講義室への移動、授業準備、短い休憩**に使われるものとして扱い、タスク時間に自動変換しない。
4. Google Calendar に外出予定があり、前後の移動時間が明記されていない場合は、**移動時間の見積もりを必ずユーザーに確認する**。
5. ご飯・洗濯・お風呂の時間が予定に明記されていない場合は、それぞれについて**その日に確保が必要かどうか、必要ならどれくらい見込むかをユーザーに確認する**。
6. 大学登校日でない日次計画では、ユーザーの希望する**起床時刻と就寝時刻**を把握してから、計画可能時間帯を確定する。大学登校日は、起床後すぐ登校する前提として起床時刻の確認は省略してよい。
7. 上の確認が済んでいない場合は、見切り発車で DailyNote を確定しない。まず不足情報を短く確認する。
8. DailyNote のタイムスケジュール表は、**mention 展開に依存せず plain text だけでも読める形**で書く。`:entry{#...}` は参照情報として別セクションに分けるか、plain text の補助としてのみ使う。

## ワークフロー

タスクとプロジェクトのキャプチャ、インボックス処理、Next/Await/Someday の判断、Project 計画については、`references/gtd.md` を読む。

「今日やること」、日次タスク選定、Deep Work/Shallow Work 分類、Eisenhower トリアージ、DailyNote 作成については、`references/gtd.md` の後に `references/daily-plan.md` を読む。

**Daily 計画のフロー**：
1. **Google Calendar を参照**して今日の予定をタイトル付きで取得
2. **不足情報を確認**し、移動・生活時間・起床/就寝条件を埋める
3. **空き時間ブロックを特定**し、実質稼働可能時間を計算
4. **選定したタスクに具体的な時間枠を割り当て**（タイムスケジュール作成）
5. **時刻付きのスケジュールを DailyNote に記載**

## 出力期待

miloa を変更した場合は、何を変更したか、なぜ変更したかをユーザーに伝える。チャット出力は簡潔に保つが、`Next`、日付、Project リンクが保守的に処理されたことを検証できるだけの詳細は含める。

不確実な場合は、網羅性よりも `Next` の信頼性を守る。
