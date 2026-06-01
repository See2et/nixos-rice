# miloa における Horizon Review

## 発動条件（絶対）

以下の場合のみ実行する。通常の週次レビュー、日次計画、GTD 健全性レビューでは Horizon に触れない。

- ユーザーが「Horizon Review」「方向性の確認」「上位目標のレビュー」などと明示的に依頼した
- ユーザーが「この Area の活動は本当に正しい方向か？」「上位目標とズレていないか？」と問うた

## Horizon 定義

GTD の Horizons of Focus を miloa に落とし込んだもの。

| 階層 | miloa Tag | 役割 | 接続 |
|---|---|---|---|
| H5 Purpose | `Purpose` | 原理・価値観。「なぜやるのか」 | — |
| H4 Vision | `Vision` | 3〜5年先の成功像。「どうなっているか」 | `Vision::ParentPurposes` → `Purpose` |
| H3 Goal | `Goal` | 12〜24ヶ月での達成目標。「何を達成するか」 | `Goal::ParentVisions` → `Vision` |
| H2 Area | `Area` | 継続的な責務領域 | `Area::Goals` → `Goal` |
| H1 Project | `Project` | 完了可能な成果 | `Project::Area` → `Area` |

## 接続構造

```
Purpose (H5)
    ↓ Array of EntryRef
Vision (H4)
    ↓ Array of EntryRef
Goal (H3)
    ↓ Array of EntryRef
Area (H2)
    ↓ EntryRef
Project (H1)
    ↓
Task (Ground)
```

- `Vision::ParentPurposes` は Array。1つの Vision が複数の Purpose に導かれるケースを許容する。
- `Goal::ParentVisions` は Array。1つの Goal が複数の Vision に導かれるケースを許容する。
- `Area::Goals` は Array。1つの Area が複数の Goal に貢献する。

## Horizon Review フロー

### ステップ1: データ収集

1. `list_tags` でスキーマ確認
2. `Purpose` エントリを取得（`Status` すべて）
3. `Vision` エントリを取得（`ParentPurposes` 付き）
4. `Goal` エントリを取得（`ParentVisions`, `TargetDate` 付き）
5. `Area` エントリを取得（`Goals` 付き）
6. `Project` エントリを取得（`Status = Active`, `Area`, `Organization` 付き）

### ステップ2: 整合性マトリクス構築

以下の因果リンクを確認する：

```
Purpose → Vision → Goal → Area → Project
```

確認観点：
- `Vision::ParentPurposes` が設定されているか（未設定は Orphan Vision）
- `Goal::ParentVisions` が設定されているか（未設定は Orphan Goal）
- `Area::Goals` が設定されているか（未設定は Orphan Area）
- 各 Goal に紐づく Area に、Active Project が存在するか
- `Vision::ParentPurposes` の各 Purpose の `Status` が `Dropped` になっていないか
- `Goal::ParentVisions` の各 Vision の `Status` が `Dropped` になっていないか

### ステップ3: 異常検出

以下を検出し、重大度順に列挙する。

#### Orphan Vision（浮遊 Vision）
- `Vision::ParentPurposes` が未設定、または存在しない Purpose を指している
- 判定: 上位原理との接続が断絶している

#### Orphan Goal（浮遊 Goal）
- `Goal::ParentVisions` が未設定、または存在しない Vision を指している
- 判定: 上位ビジョンとの接続が断絶している

#### Orphan Area（浮遊 Area）
- `Area::Goals` が未設定の Area
- 判定: 純粋な維持領域（健康・生活など）か、Goal リンクの漏れか。前者は正常、後者は要対応

#### Empty Goal（空っぽ Goal）
- `Goal::Status = Active` だが、紐づく Area がない、または紐づく Area に Active Project がない
- これは「目標だけ立てて、実行が繋がっていない」状態

#### Stale Goal（古びた Goal）
- `Goal::TargetDate` を過ぎたのに `Goal::Status = Active` のまま
- これは「目標の達成・見直しが行われていない」状態

#### Stale Parent Purpose（枯れた上位原理）
- `Vision::ParentPurposes` に含まれる Purpose の `Status = Dropped`
- これは「導かれる原理が放棄されているのに、Vision がまだ Active」状態

#### Stale Parent Vision（枯れた上位ビジョン）
- `Goal::ParentVisions` に含まれる Vision の `Status = Dropped`
- これは「導かれるビジョンが放棄されているのに、Goal がまだ Active」状態

#### Goal-less Projects（戦術的散乱）
- Active Project の中で、`Area::Goals` が未設定の Area に紐づく Project が多い
- これは「やっていることに上位方向性がない」状態

#### Goal 間の矛盾
- 同じ Area に紐づく Goal が互いに矛盾していないか
- 例: 同じ Area が「国内就職を目指す」と「海外留学を目指す」両方に紐づいている

### ステップ4: 議論ベースで提示

自動修正は行わない。以下をユーザーに提示する：

1. 検出した異常のリスト（重大度順）
2. 各異常について「なぜ問題か」の簡潔な説明
3. 最小の修正方針の候補（複数提示してもよい）
4. ユーザーの判断を仰ぎ、承認後にのみ変更を実行する

### ステップ5: 変更実行（ユーザー承認後のみ）

承認された変更を実行する：

- `Purpose` / `Vision` / `Goal` の `Status` 更新（`Active` → `Achieved` / `Dropped`）
- `Vision::ParentPurposes` の追加・削除
- `Goal::ParentVisions` の追加・削除
- `Area::Goals` の追加・削除
- 新規 `Purpose` / `Vision` / `Goal` エントリの作成
- `Project::Area` / `Project::Organization` の修正（Horizon Review で通常は不要）

**実行後は必ず「何を変更したか」をユーザーに報告する。**

### ステップ6: レビュー記録（任意）

ユーザーが求めた場合、レビュー結果を `DailyNote` または `WeeklyNote` に追記する。通常はチャット対話ログのみで十分。

## 頻度とタイミング

- `Goal` (H3): 月次〜四半期
- `Vision` (H4): 四半期〜年次
- `Purpose` (H5): 年次、または人生の節目
- ただし、ユーザーが依頼した場合はいつでも実行可能
- 通常の週次レビューと混同しない

## 禁止事項

- Horizon Review を依頼されていないのに、勝手に上位目標や Area の Goals リンクに触れる
- `Purpose` / `Vision` / `Goal` を大量に作成して構造を複雑化する。必要最小限を維持する
- H3〜H5 を「やることリスト」として扱う。Horizon は方向性の文書であり、Next Action ではない
- `Area::Goals` を週次レビューで毎回見直す。Horizon Review 専用とし、週次レビューでは軽く触れるに留める
- `ParentPurposes` / `ParentVisions` を Array であることを理由に、無関係な Purpose/Vision を無理に接続する
