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

## ワークフロー

タスクとプロジェクトのキャプチャ、インボックス処理、Next/Await/Someday の判断、Project 計画については、`references/gtd.md` を読む。

「今日やること」、日次タスク選定、Deep Work/Shallow Work 分類、Eisenhower トリアージ、DailyNote 作成については、`references/gtd.md` の後に `references/daily-plan.md` を読む。

**Daily 計画のフロー**：
1. **Google Calendar を参照**して今日の予定を取得
2. **空き時間ブロックを特定**し、実質稼働可能時間を計算
3. **選定したタスクに具体的な時間枠を割り当て**（タイムスケジュール作成）
4. **時刻付きのスケジュールを DailyNote に記載**

## 出力期待

miloa を変更した場合は、何を変更したか、なぜ変更したかをユーザーに伝える。チャット出力は簡潔に保つが、`Next`、日付、Project リンクが保守的に処理されたことを検証できるだけの詳細は含める。

不確実な場合は、網羅性よりも `Next` の信頼性を守る。
