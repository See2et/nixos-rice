---
name: miloa-gtd
description: Manage GTD-style tasks, projects, areas, inbox cleanup, Next actions, Waiting For, Someday items, review hygiene, weekly reviews, project due-date integrity, and realistic daily plans in the user's miloa workspace. Use when Codex is asked to create, review, audit, organize, or update miloa Task/Project/Area/DailyNote/WeeklyNote/Event entries; process an inbox; preserve a trustworthy Next list; detect stale or malformed Project/Task/Area states; check parent-project and child-task deadline consistency; choose today's tasks; run weekly reviews; design or migrate Organization review policies or time-allocation commitments on Organizations/Areas/Projects/Goals; or write a DailyNote plan from miloa tasks.
---

# miloa GTD

ユーザーの miloa タスクシステムを扱うときは、このスキルを使用する。目的は構造を増やすことではない。目的は `Next` の信頼性を保ち、`Await` を放置されない待ちリストとして保ち、現実的に完了できる日次計画と週次レビューを作ることである。また、miloa には MCP 経由でアクセスできる。

## 実行モード

まず依頼が次のどれかを判定する：

- GTD 健全性レビュー
- 週次レビュー
- 日次計画
- Inbox / Task / Project 更新
- Project / Task 明確化インタビュー
- Organization / commitment anchor ポリシー設計 / 移行

判定したモードに必要な reference だけを読む。迷ったら書き込み前に `references/gtd.md` を読み、必要なら追加で `references/weekly-review.md` または `references/daily-plan.md` を読む。

どのモードでも、最初のユーザー向け返答では必ず `○○モードを検知しました` と明示する。ここでの `○○` は判定した実行モード名そのものを使う。モード宣言を省略して作業を始めない。

## No-Write Gates

以下が揃うまで、`_create_entry` / `_update_entry` / `_delete_entry` / `_create_tag` / `_update_tag` を実行しない。

1. `list_tags` を読み、**現在の実スキーマ**を確認した
2. 関連する既存 `Task` / `Project` / `Organization` / 必要なら既存 `DailyNote` / `WeeklyNote` を検索した
3. いま実行しているモードに必要な reference を読んだ
4. 変更対象と変更理由を短く言語化できる

追加ゲート：

- 週次レビューでは、Google Calendar の週予定取得と、**当日レビュー対象の Organization** の全件確認が終わるまで書き込まない
- 日次計画では、Pre-flight Check 完了と Google Calendar の当日予定取得が終わるまで書き込まない
- `ScheduledDate` / `DueDate` / `Project::DueDate` を変更する場合、記録先（通常は DailyNote または WeeklyNote）の理由文を先に決めるまで書き込まない
- `Project::Status` を `Active` にする、または `Active` の `Project` 本文を実質更新する場合、Natural Planning Model の最低骨格（`# Purpose` / `# Principles` / `# Outcome` / `# Plan`）を確認するまで書き込まない
- API 都合だけを理由に `Bucket` を変更しない。`Bucket` を触るのは、GTD 上その変更自体が意図されているときだけ
- Organization または commitment anchor のポリシーを変更する場合、**無効状態をどう避けるか**を先に説明できるまで書き込まない

## 必須コンテキスト

miloa のエントリを書き込む、または更新する前に：

1. `list_tags` で最新の miloa タグスキーマを読み込む。
2. 新規作成する前に、既存の `Task` / `Project` / `Organization` と既存ポリシータグの利用状況を検索する。
3. 重複を作成するよりも、既存エントリの更新・リンク・言及を優先する。
4. ユーザーが明示的に依頼した場合、または持続的なワークフロー上の問題に必要な場合を除き、新しいタグやフィールドを作成しない。

スキーマの具体例と reference 内の例が食い違う場合は、**必ず `list_tags` で見えた現在の実スキーマを正とする**。SKILL.md や reference のフィールド名は概念説明であり、古くなっている可能性がある。

## コアスキーマ

miloa の現在のスキーマを唯一の正として使用する。このスキルでは、次の概念を区別して扱う：

- `Area`: 機能的な責務領域。継続的に維持・改善する分類タグ。
- `Organization`: 組織・チーム・ブランドの文脈。Project に紐付けるハブ。
- `Project`: `Status`, `Area`, `Organization`, `DueDate` を持つ成果単位。
- `Task`: `Status`, `Bucket`, `Context`, `DueDate`, `ScheduledDate`, `Project`, `Area`, `EstimatedMinutes` を持つ実行単位。`Project::DueDate` は成果レベル、`Task::DueDate` は作業レベルの締切として区別する。
- `DailyNote`: 日次計画の記録。
- `WeeklyNote`: 週次レビューと週内配分の記録。
- `Event`: 議事録などそのEntryが対応する日時を示すタグ
- `Goal`: 12〜24ヶ月程度の到達目標。
- `Vision`: 3〜5年スパンの中長期像。
- `Purpose`: より上位の原理・価値観。

通常の GTD 整理では `Purpose` / `Vision` / `Goal` を更新対象にしないが、`Area` や Active Project の向き先を読む文脈として存在を把握しておく。Horizon Review では `Purpose -> Vision -> Goal -> Area -> Project` の因果チェーンを確認する。

### Active Project の最低本文

`Project::Status = Active` の Project は、GTD の Natural Planning Model に沿って、少なくとも次を本文に持つことを期待する：

- `# Purpose`
  - なぜこの Project をやるのか。誰にとって何が重要か。
- `# Principles`
  - 守る制約、判断基準、今回はやらないこと。
- `# Outcome`
  - 成功状態の像、または観測可能な完了条件。
- `# Plan`
  - 整理済みの塊、順序、既存 Task 参照。

加えて、日程感がある Project では `# Schedule` セクションを強く推奨する。ここには、外部イベント、本番日、提出日、中間マイルストーン、逆算上の節目を自由記述で残してよい。これは必ずしも structured な `Project::DueDate` や `Task::DueDate` に落とし切れない日程上の約束を WeeklyNote / DailyNote に接続するための一次情報として扱う。

`Brainstorming` の生メモや本文中の `Next Actions` 列挙は必須ではない。`Next Actions` は通常どおり `Task` + `Bucket = Next` で管理する。

### Project / Task 明確化インタビュー

このモードの目的は、完全な要件定義ではなく、Project や Task に取り組むとっかかりを作ることにある。完全性よりも着手可能性を優先する。

- 1ラウンドにつき 1 論点だけを聞く
- 十分な材料が揃ったら、追加質問より先に要約して本文更新または Task 化を提案する
- ユーザーが不確実だと言っていない論点を、網羅性のためだけに深掘りしない
- Task 名が `考える` `検討する` `確認する` `対応する` `進める` `整理する` のような抽象動詞で止まりそうなら、そのまま Task 化せず、まず具体化質問を1つだけ返す

Project では、次が揃ったら追加深掘りより先に本文更新案を作ってよい：

- `Purpose`: なぜやるかが 1〜2 文で言える
- `Outcome`: 完了状態が少なくとも 1 つ言える
- `Plan` または最初の一手: 着手点が 1 つ決まっている

日程感が重要な Project では、加えて次を早い段階で確認する：

- 外部イベント基準の節目。例: 面接日、発表日、提出日、レビュー日
- その前に終わっていたい中間マイルストーン
- 週内で強く意識したい順序や日程感

`Project::DueDate` を置くほどではなくても、これらは可能な限り `# Schedule` または `# Plan` に残す。

`Principles` は、制約や判断基準が実際に重要なときだけ聞く。未確定でも、着手可能性が十分ならインタビューを止めてよい。

Task では、次が揃ったら追加深掘りより先に Task 化してよい：

- 何をするかが、実際に手を動かし始められる具体動詞で言える
- 何をもって終わりかが短く言える
- 今すぐ着手できるか、できないなら何が前提かが分かる

Task の具体動詞テスト：

- タイトルを見た瞬間に、最初の5分でやる操作を説明できる
- 完了後に「何が残るか」を言える。例: 送信済みメッセージ、下書き400字、比較表3項目、予約完了
- `確認する` を使う場合は、何を確認して、確認後にどう判断するかまでタイトルか本文で示す
- `考える` `検討する` `進める` `対応する` `整理する` のように、操作も完了条件も曖昧な語で止めない
- 抽象名詞だけのタイトルを作らない。`発表準備` ではなく `発表スライドの構成を3章で下書きする` のように書く

このモードでのアンチパターン：

- 本文や Task を書けるだけの材料があるのに、網羅性のためだけに質問を続ける
- 毎回 `Purpose` / `Principles` / `Outcome` / `Plan` を同じ深さで埋めようとする
- 1回の返答で複数論点をまとめて大量に質問する
- `Next` にできる着手点が見えているのに、曖昧さゼロを目指して停止しない
- 抽象動詞のまま Task を作り、ユーザーに「次に何をすればいいか」の再解釈を委ねる

### 推奨 TO-BE のレビュー / 時間コミットメント構造

レビュー対象かどうかと、毎日 / 毎週の時間コミットメントは、**boolean を増やさず追加タグで表す**のを推奨する。想定は次の通り：

- `Organization`
  - 文脈のハブ。Project はこれを参照する。
- `commitment anchor`
  - `Organization` / `Area` / `Project` / `Goal` のうち、継続的に時間を配分したい対象。
  - 例: `SuteraVR` のような組織、`学業` のような責務領域、`数学演習` のような継続テーマ。
- `WeeklyReviewTarget`
  - `Day` を持つ。これが付いている Organization だけが週次レビュー対象。
- `DailyFloorCommitment`
  - `MinimumMinutes` を持つ。commitment anchor に毎日最低限確保したい対象。
  - 任意で `StretchPolicy` を持つ。`MaximizeWhenPossible` なら、約束済みタスクの後で余剰時間を寄せる。
- `WeeklyQuotaCommitment`
  - `TargetHours` を持つ。commitment anchor に対して、週次レビュー時点で週内の粗配分を決める対象。

### 無効状態を避ける原則

- `ReviewEnabled` と `ReviewDay` を別フィールドで持たない。レビュー対象は `WeeklyReviewTarget` タグの有無で表す。
- 同じ commitment anchor に `DailyFloorCommitment` と `WeeklyQuotaCommitment` を**同時に付けない**。
- `WeeklyQuotaCommitment` の時間配分は、日次で気分次第に決めず、**WeeklyNote 作成時点で週内の粗配分を先に決める**。
- `DailyFloorCommitment` は「最低限触る」を意味するだけではない。`StretchPolicy = MaximizeWhenPossible` の場合は、余剰時間を優先的に寄せる対象でもある。
- `WeeklyReviewTarget` は引き続き `Organization` 専用に保つ。レビュー曜日まで `Area` / `Project` / `Goal` に広げない。
- 実スキーマがまだ旧式 (`Organization::StrategicBlock`, `Organization::WeeklyReview`) の場合、**旧式のまま新しい運用を捏造しない**。必要ならユーザー合意のもとでスキーマ移行を行う。

**外部データソース**: Google Calendar（日次計画・週次レビュー時に参照し、実質稼働可能時間を計算する）

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
5. `DueDate` / `ScheduledDate` が今日より前なのに未完了の Task、または `Project::DueDate` が今日より前なのに `Status = Active` の Project。
6. 1 Project に `Next` が多すぎる状態。
7. Project 本文の `# Plan` と実際の Task 状態のズレ。
8. 重複していそうな Task / Project。
9. `Status` と `Bucket` の差分が実務上問題を起こしていそうな Task。
10. Active でない Project に、未完了の実行タスクがぶら下がっていないか。
11. `EstimatedMinutes = 240` の Task や、明らかに粒度が粗く日次計画に載せにくい Task。
12. `Project::DueDate` と子 Task の整合性が壊れていないか。特に、子 Task の `DueDate` が親 Project の `DueDate` を後ろ倒ししていないか、締切が近いのに有効な `Next` や週内配置が欠けていないか。
13. Organization / commitment anchor ポリシーに無効状態がないか。特に、レビュータグなのに曜日が欠ける、同じ anchor に時間コミットメントタグが複数付く、など。
14. `Project::Status = Active` なのに、Natural Planning Model の最低骨格（`# Purpose` / `# Principles` / `# Outcome` / `# Plan`）が欠けていないか。
15. `Next` や期限付き Task が、`考える` `確認する` `対応する` `進める` のような抽象動詞、またはトピック名だけで止まっていないか。
16. `Project` 本文の `# Schedule` や `# Plan` に近接した日程感・マイルストーンがあるのに、それを支える `Next` や週内配置が見えていない Project がないか。

ユーザー運用で `Status` の信頼度が `Bucket` より高い場合は、まず `Status` を正として読む。`Status = Done` かつ `Bucket = Next` / `Await` は即座に破損扱いせず、必要なら Bucket 整備候補として軽く触れる。

レビューでは「壊れている理由」と「最小の修正方針」をセットで返す。抽象 Task 名を指摘するときは、可能なら `どの動詞に言い換えるか` `何が終われば完了か` まで添える。自動修正を依頼されていない限り、いきなり大量変更せず、まず検出結果を整理して伝える。

## 日次計画で必ず確認すること

1. **Pre-flight Check（Stale Task Radar）を実行する**。`ActivatedDate` から3日以上経った `Next`、`WaitingSince` から3日以上経った `Await`、`DueDate < today` の未完了タスク、`ScheduledDate <= today` の未完了タスク、`Project::DueDate <= today` または近接している `Active` Project を検索し、**全てに処遇（実行/分割/再設定/Bucket変更）を決定してから**新規タスク選定に進む。
2. Google Calendar の当日予定は、**開始時刻・終了時刻に加えてイベントタイトルも必ず取得する**。
3. 予定と予定の間の時間は機械的に「空き時間」とみなさず、**その場で実行可能な時間か**を判定する。
4. 日次計画では、**週次で決めた約束を先に守る**。`Task::DueDate` / `ScheduledDate` / `Project::DueDate` と WeeklyNote 上の週内配分を無視しない。
5. 日次計画では、`Project::DueDate` が近いものだけでなく、**すべての `Active` Project を確認し**、本文の `# Schedule` / `# Plan` に今日〜数日以内の強い日程感が書かれていないかを見る。
6. `DailyFloorCommitment` は、締切タスクを守ったうえで**最低枠を置く**。対応する `Next` Task がなくても、commitment anchor 自体に対する作業枠として置いてよい。`StretchPolicy = MaximizeWhenPossible` なら、余剰時間を優先的に寄せる。
7. `WeeklyQuotaCommitment` は、**WeeklyNote でその日に割り当てられた分**を尊重して置く。
8. 平日は大学の登校日である可能性をまず考慮する。大学登校日では、授業間の休み時間は原則として**次の講義室への移動、授業準備、短い休憩**に使われるものとして扱い、タスク時間に自動変換しない。
9. Google Calendar に外出予定があり、前後の移動時間が明記されていない場合は、**移動時間の見積もりを必ずユーザーに確認する**。
10. ご飯・洗濯・お風呂の時間が予定に明記されていない場合は、それぞれについて**その日に確保が必要かどうか、必要ならどれくらい見込むかをユーザーに確認する**。
11. 大学登校日でない日次計画では、ユーザーの希望する**起床時刻と就寝時刻**を把握してから、計画可能時間帯を確定する。大学登校日は、起床後すぐ登校する前提として起床時刻の確認は省略してよい。
12. 上の確認が済んでいない場合は、見切り発車で DailyNote を確定しない。まず不足情報を短く確認する。
13. DailyNote のタイムスケジュールは、**mention 展開に依存せず plain text だけでも読める形**で、`## 今日のスケジュール` 配下に `### HH:MM-HH:MM` 見出しを並べる。対象となる Entry がある時間枠は `:entry{#...}` を単独で書けばよく、タイトルを別途繰り返さない。Google Calendar の予定など対応する Entry がない時間枠は平文で書く。別立ての「参照」セクションは作らない。
14. `EstimatedMinutes` がある Task は参考にしてよいが、**見込み時間をそのまま一日で消化しようとしない**。必要なら、その日の枠では一部だけ進める前提で計画する。
15. **`ScheduledDate` や `DueDate` や `Project::DueDate` を変更した場合は、理由を DailyNote の「日次振り返り」セクションに必ず記録する**。
16. その日の**作業終了時刻**を確認する。原則として月〜木は27〜28時まで許容し、金〜日は23時頃までを目安とする。夜遅くまで外出がある日は、帰宅後の作業時間は確保できない前提とする。
17. 時間枠に載せる前に、候補 Task のタイトルが具体動詞になっているか確認する。抽象動詞のままなら、スケジュールに入れる前に言い換えるか分割する。

## ワークフロー

Area の定義、スキーマ、Area と Project / Task / Organization / Goal の関係については、`references/area.md` を読む。

Organization の定義、スキーマ、レビュータグ、時間コミットメントタグ、Organization と Project の関係、および commitment anchor の扱いについては、`references/gtd.md` を読む。

タスクとプロジェクトのキャプチャ、インボックス処理、Next / Await / Someday の判断、`ActivatedDate` / `WaitingSince` を含む Bucket 更新ルール、Project 計画、Organization / commitment anchor ポリシー運用については、`references/gtd.md` を読む。

Project / Task の健全性レビュー、停滞検出、Plan と Task の整合性確認、重複候補の扱いについては、`references/gtd.md` のレビュー節を読む。

「今日やること」、日次タスク選定、Deep Work / Shallow Work 分類、古い `Next` / `Await` の扱い、DailyNote 作成については、`references/gtd.md` の後に `references/daily-plan.md` を読む。

**週次レビュー**：
1. `references/weekly-review.md` と `references/query-pack.md` を読む
2. Google Calendar で今週の予定を取得する。取得前に週次計画を書き始めない
3. **当日レビュー対象**の Organization だけをレビューする。全件総ざらいは、ユーザーが明示したときだけ行う
4. ただし、`Organization` のレビュー対象にかかわらず、**すべての `Active` Project は確認する**。特に本文の `# Schedule` / `# Plan` に週内の強い日程感や外部イベント基準の節目があるものを見落とさない
5. 各レビュー対象 Organization について、**今週必ず解くべき課題を1つ**決める。AI は候補提案まで行ってよいが、**最終決定は必ずユーザーから引き出す**
6. `WeeklyQuotaCommitment` を持つ commitment anchor については、**WeeklyNote 作成時点で週内の粗配分を決める**
7. `DailyFloorCommitment` を持つ commitment anchor については、日次で最低限確保する方針と、必要なら余剰時間の寄せ先を確認する
8. 締切タスクと締切 Project、および `ScheduledDate` と `Project` 本文上の週内マイルストーンの配置を計画する
9. 週内に載せる Task 名が抽象動詞で止まっていれば、具体動詞に言い換えるか、1回の作業で終わる単位へ分割する
10. 異常（締切集中、Project 締切に対する作業不足、過積載、週内 quota 未配置、レビュー対象なのに課題未決定、ポリシー競合、抽象 Task 名、本文日程感の未反映）を検出し調整する
11. 週次レビュー結果を `WeeklyNote` エントリとして miloa に記録する

**Horizon Review（明示依頼時のみ）**：
1. ユーザーが「Horizon Review」「方向性の確認」「上位目標のレビュー」などと明示的に依頼したときのみ実行する
2. `references/horizon-review.md` を読み、レビューフローを実行する
3. `Purpose` / `Vision` / `Goal` エントリを取得し、整合性マトリクスを構築する
4. `Area` エントリの `Goals` リンクと、各 Area に紐づく Active Project の状態を確認する
5. 異常を検出し、最小の修正方針をユーザーに提示する。自動修正は行わない
6. 通常の週次レビュー・日次計画・GTD 健全性レビューでは Horizon に触れない

**Daily 計画のフロー**：
1. `references/daily-plan.md` と `references/query-pack.md` を読む
2. **Pre-flight Check（Stale Task Radar）**: 古い `Next` / `Await` / 期限超過 / 予定超過を検索し、処遇決定
3. **Google Calendar を参照**して今日の予定をタイトル付きで取得
4. **不足情報を確認**し、移動・生活時間・起床 / 就寝条件を埋める
5. **約束済みタスクを先に扱う**。`Task::DueDate` / `ScheduledDate` / `Project::DueDate` と WeeklyNote 上の週内配分を確認する
6. **`DailyFloorCommitment` を置く**
7. **今日に割り当て済みの `WeeklyQuotaCommitment` を置く**
8. **余剰時間があれば `StretchPolicy = MaximizeWhenPossible` 対象へ寄せる**
9. **空き時間ブロックを特定**し、実質稼働可能時間を計算
10. **抽象 Task 名を具体動詞に直すか分割する**
11. **時刻付きのスケジュールを DailyNote に記載**
12. **`ScheduledDate` / `DueDate` / `Project::DueDate` を変更した場合は理由を DailyNote に記録**

## 出力期待

miloa を変更した場合は、何を変更したか、なぜ変更したかをユーザーに伝える。チャット出力は簡潔に保つが、`Next` / `Await`、`ActivatedDate` / `WaitingSince` / `ScheduledDate` / `Project::DueDate`、Project リンク、Organization / commitment anchor ポリシーが保守的に処理されたことを検証できるだけの詳細は含める。

レビューだけを行う場合は、重大度順または Project ごとに、検出した問題・根拠・推奨アクションを短く列挙する。問題がなければ、その旨と未確認の残留リスクを伝える。

Miloa の本文中で Entry を参照するときは、原則としてプレーンテキスト名だけで済ませず、`:entry{#...}` 形式を使う。特に Task / Project / DailyNote / WeeklyNote / Organization を挙げるときは、可能な限り entry reference を添える。`:entry{#...}` で対象が一意に分かる場面では、タイトルや名称を別途繰り返さなくてよい。対応する Entry が存在しない予定やメモだけを平文で書く。

一方で、**チャット上では `:entry{#...}` は展開されない**前提で扱う。ユーザーへのチャット返答で Entry に触れるときは、まずタイトルをそのまま表示する。必要なら補助的に `:entry{#...}` を併記してよいが、` :entry{#...}` だけを単独で見せて説明を済ませない。

DailyNote / WeeklyNote の本文は、表中心ではなく**ヘッダー中心**で書く。DailyNote は時間枠ごとの見出し、WeeklyNote は Organization ごとの見出しと日ごとの見出しを基本にし、必要な箇所だけ箇条書きを併用する。

週次レビューまたは日次計画で書き込みを行う前に、短い監査サマリを自分の中で確認する：

- `Schema loaded`
- `Calendar fetched`
- `Reference read`
- `Review complete` または `Pre-flight complete`
- `Write target decided`

不確実な場合は、網羅性よりも `Next` の信頼性を守る。

## 出力前自己検証リスト

miloa を変更したり、日次計画・週次レビューを出力する前に、以下を機械的に確認する：

- [ ] 新しいフィールドやタグを勝手に追加していないか
- [ ] `ScheduledDate` / `DueDate` を持つタスクや `Project::DueDate` を持つ Active Project を無視して選定していないか
- [ ] `Project::Status = Active` の Project に必要な Natural Planning Model の最低骨格を欠いたまま維持・更新していないか
- [ ] Pre-flight Check（Stale Task Radar）をスキップしていないか
- [ ] 古い `Next` / `Await` をそのまま今日の候補に入れていないか
- [ ] 当日の `DailyFloorCommitment` と WeeklyNote 上の quota 配分を見落としていないか
- [ ] `EstimatedMinutes = 240` のタスクを分割検討なしにそのままスケジュールに押し込んでいないか
- [ ] `ScheduledDate` / `DueDate` / `Project::DueDate` を変更した場合、理由を記録したか
- [ ] 同じタスクを繰り返し延期し、理由の特定と解消を行っていないか
- [ ] DailyNote のタイムスケジュール表が plain text だけでも読める形になっているか
- [ ] `Next` や今日/今週扱う Task が、抽象動詞やトピック名のまま残っていないか
- [ ] 週次レビューでは、当日レビュー対象の各 Organization に今週解くべき課題をちょうど1つ設定したか
- [ ] 同じ commitment anchor に時間コミットメント系タグを複数付けていないか
- [ ] Horizon Review を依頼されていないのに、勝手に上位目標や Area の Goals リンクに触れていないか
