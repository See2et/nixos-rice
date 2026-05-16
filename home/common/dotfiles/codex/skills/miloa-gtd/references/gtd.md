
# miloa における GTD ルール

## 原則

`Task::Bucket = Next` は、未解決の前提条件なしに今すぐ着手できるアクションに限定する。将来の Project ステップは、それが実行可能になるまで Project 本文内に置き、通常は `# Plan` の下に記載する。

## GTD マッピング

| GTD 概念 | miloa での表現 |
|---|---|
| Inbox | `Bucket` と `Project` が未設定の `Task` |
| Next Action | `Task::Bucket = Next` |
| Someday/Maybe | `Task::Bucket = Someday` |
| Waiting For | `Task::Bucket = Await` に加えて `Bucket::Await::Reason` |
| Project | `Project::Status = Active` |
| Done | `Task::Status = Done` |
| 開始日／レビュー日 | `Task::ScheduledDate` |
| 厳格な締切 | `Task::DueDate` |
| 将来の Project ステップ | Project 本文の `# Plan` |

## タスクタイトル

タイトルは次の形を優先する：

`[動詞] + [対象] + [完了条件]`

良い例：

- `山田さんに確認メッセージを送る`
- `The Sybil Attackの要約メモを作る`
- `レポートの導入を400字で下書きする`

`レポート`、`miloa改善`、`発表準備`、`考える`、`対応する` のような曖昧なトピック名は避ける。

## Bucket ルール

### Next

以下すべてが真の場合のみ使用する：

- 未完了の前提条件がタスクをブロックしていない。
- タイトルに、明確な物理的または認知的なアクション動詞が含まれている。
- 今始めても大きな手戻りが発生しない。
- Project 計画内の単なる将来ステップではない。

直列型 Project では、原則として有効な `Next` は最大1件に保つ。作業が本当に並行して進められる場合のみ、2〜3件を許容する。

### Await

他者、システム、承認、返信、外部プロセスなど、外部依存がある場合のみ使用する。

設定するもの：

- `Task::Bucket = Await`
- `Task::Bucket::Await::Reason` に、誰／何を待っているのかを設定する。

「アウトラインを作ってから下書きする」のような内部的な順序関係には `Await` を使わない。それは Project 計画に置く。

### Someday

ユーザーが現時点でコミットしていない任意の候補に使用する。アクティブな Project に必要な将来ステップを `Someday` に入れない。

### Bucket 未設定

未処理の Inbox 項目、またはキャプチャだけが目的の軽量なバックログに使用する。

## 日付

- `DueDate`: その日までにタスクが完了していなければならない厳格な締切。
- `ScheduledDate`: ユーザーがそのタスクを開始またはレビューすると決めた日付。

`DueDate` をゆるい優先度マーカーとして使ってはならない。ユーザーが十分な情報を提供していない限り、`DueDate`、`ScheduledDate`、`Project` を推測して設定しない。

## Project ルール

望ましい成果が2ステップ以上を必要とする場合、Project を作成する。

トピック名ではなく、成果志向のタイトルを使う：

- `5/28 輪読発表：The Sybil Attack`
- `任意中間レポートを提出可能な状態にする`
- `miloaの限定公開画面をユーザーが試せる状態にする`

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

## 禁止事項

- `Next` を一般的な「やること」リストとして使う。
- Project 計画のすべてのステップを `Next` Task に変換する。
- 必須の Project フォローアップを `Someday` に入れる。
- 内部的な順序依存に `Await` を使う。
- `DueDate` を優先度として使う。
- 少しだけタイトルが違う重複 Task を作成する。
- `Priority`、`Energy`、`Blocked`、`Area`、`Goal`、`NextAction`、`WaitingFor` などのフィールドを気軽に追加する。
