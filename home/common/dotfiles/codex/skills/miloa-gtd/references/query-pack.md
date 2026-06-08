# miloa GTD 必須クエリ集

このファイルは、週次レビュー・日次計画・健全性レビューの**最低限の取得順**を固定するためのもの。迷ったらこの順に検索する。

## 共通ルール

1. まず `list_tags` を読む
2. 先に検索を終えてから計画や更新に入る
3. クエリ結果が空でも、その確認自体を完了扱いとして記録する
4. `WeeklyNote` / `DailyNote` / Task 更新を書き始める前に、必要クエリの未実行がないことを確認する

## 週次レビューの必須取得順

1. `WeeklyReviewTarget`
2. 当日レビュー対象の `Organization`
3. `DailyFloorCommitment`
4. `WeeklyQuotaCommitment`
5. `Project::Status = Active`
6. 今週内 `Project::DueDate` の `Active` Project
7. 今週内 `DueDate` の未完了 Task
8. 今週内 `ScheduledDate` の未完了 Task
9. 古い `Next`
10. 古い `Await`
11. 先週の `DailyNote`
12. 必要なら直近の `WeeklyNote`
13. Google Calendar の今週予定

## 日次計画の必須取得順

1. 今日の `DailyNote`
2. `Task::Bucket = Next` の未完了 Task
3. `Task::Bucket = Await` の未完了 Task
4. `DueDate <= today` の未完了 Task
5. `Project::DueDate <= today` または近接した `Active` Project
6. `ScheduledDate <= today` の未完了 Task
7. 古い `Next`
8. 古い `Await`
9. 今日に関係する `DailyFloorCommitment`
10. 直近 `WeeklyNote` の今日配分
11. 必要な Active Project
12. Google Calendar の今日予定

## GTD 健全性レビューの必須取得順

1. `Project::Status = Active`
2. 未完了 Task
3. 古い `Next`
4. 古い `Await`
5. `Project::DueDate < today` の `Active` Project
6. `DueDate < today` の未完了 Task
7. `ScheduledDate < today` の未完了 Task
8. `EstimatedMinutes = 240` の Task
9. `WeeklyReviewTarget`
10. `DailyFloorCommitment`
11. `WeeklyQuotaCommitment`

## 停止条件

以下に当てはまる場合は、検索追加またはユーザー確認に戻る：

- Google Calendar を見るべきモードなのに、まだ取得していない
- Active Project との関係が見えていない
- `Project::DueDate` が近いのに、支える Task 群や週内配置が見えていない
- `ScheduledDate` / `DueDate` を変更したいのに、理由の記録先が決まっていない
- `Project::DueDate` を変更したいのに、理由の記録先が決まっていない
- `WeeklyQuotaCommitment` があるのに、WeeklyNote 側の週内配分が見えていない
- `Bucket` を変更したくなったが、その変更自体が依頼されていない
