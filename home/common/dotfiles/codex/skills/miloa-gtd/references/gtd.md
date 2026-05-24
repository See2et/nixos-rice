
# miloa における GTD ルール

## 原則

`Task::Bucket = Next` は、未解決の前提条件なしに今すぐ着手できるアクションに限定する。将来の Project ステップは、それが実行可能になるまで Project 本文内に置き、通常は `# Plan` の下に記載する。

## GTD マッピング

| GTD 概念 | miloa での表現 |
|---|---|
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

## Bucket 変更時の日付ルール

- `Next` にする場合: `ActivatedDate = today`。`WaitingSince` は持たせない。
- `Await` にする場合: `WaitingSince = today`。`Reason` を必ず書く。`ActivatedDate` は持たせない。
- `Someday` にする場合: `ActivatedDate` と `WaitingSince` は原則不要。
- `Done` にする場合: 完了状態が分かればよく、鮮度日付を更新しない。
- Bucket を変えずにレビューで見送るだけの場合: `ActivatedDate` / `WaitingSince` を更新しない。

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
- `Priority`、`Energy`、`Blocked`、`Area`、`Goal`、`NextAction`、`WaitingFor` などのフィールドを気軽に追加する。
