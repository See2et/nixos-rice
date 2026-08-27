# Property-based testing reference

これは、`executable-specification` Skill で universal property を選んだ後にだけ読む補助資料です。PBT は強力ですが、最初の選択肢ではありません。

## 0. 使う条件

次のどれかを一文で言えるときだけ PBT を使います。

- すべての valid input で invariant が成り立つ。
- 入出力が round-trip する。
- 変換しても意味が保たれる。
- 何回繰り返しても結果が変わらない。
- command sequence が model と一致する。

この一文が言えないなら、まだ PBT の段階ではありません。

## 1. Domain rule → Property → Generator

順番を逆にしないでください。まず domain rule、次に property、最後に generator です。

### 1-1. Domain rule

まず、業務や仕様の言葉でルールを言います。

例:

- 残高は負にならない。
- 既に正規化済みの値は再正規化しても同じ意味を持つ。
- 同じ command を 2 回続けても結果は壊れない。
- 保存前の state は常に整合している。

### 1-2. Property

そのルールを、検証可能な主張に変えます。

良い property は、短く、普遍的で、何が壊れたかが読めます。

良い例:

- `encode(decode(x)) == x`
- `sort(sort(xs)) == sort(xs)`
- `balance >= 0`
- `apply(cmds, model) == apply(cmds, system)`

悪い例:

- 実装の手順をそのまま書く。
- 入力の一部だけを見て、普遍性を装う。
- 何を守る主張なのか読めない。

### 1-3. Generator

property を支える入力生成を作ります。

generator は「たくさん出せばよい」ではありません。**壊れやすいところを出せるか** が重要です。

## 2. generator の作り方

generator は boundary と structure に寄せます。

### 基本的に厚くする領域

- empty
- minimal
- maximal
- boundary

valid Domain state の探索を既定にします。型や smart constructor が禁止済みの状態を大量生成し、毎回 reject されることだけを確認しても、通常は価値がありません。

### 状況別の作り分け

- **valid generator**: contract を満たす入力を主に出す。
- **invalid generator**: boundary rejection 自体が意味のある contract のときだけ使う。
- **boundary-aware generator**: 0, 1, 空, 最大長, 桁境界などを厚めに入れる。
- **operation sequence generator**: lifecycle や protocol の操作列を作る。
- **state-aware generator**: 現在の model state で許される次の操作だけを作る。

### 避けるもの

- 何でもランダムに出すだけの generator。
- happy path しか出さない generator。
- validity を generator に隠して、何を守っているか見えなくする作り方。
- private field や内部データ構造へ依存し、refactor で壊れる generator。
- custom generator に寄せすぎて、framework 標準の shrink 能力を失う作り方。

generator は仕様の一部です。雑に作ると、テストが強く見えて弱くなります。

## 3. shrinking

shrink は「失敗を小さくする」ためではなく、「原因を読める形にする」ためにあります。

### 良い shrink の条件

- 最小例がまだ意味を持つ。
- 失敗の本質が消えない。
- data shape と矛盾しない。
- 再現しやすい。

### 悪い shrink の兆候

- 最小例が壊れすぎて読めない。
- 重要な構造が消える。
- どこが悪いか分からない。

### 実務上の判断

framework 標準の combinator と shrinker を優先します。primitive を縮めてから public constructor で Domain object を組み立てると、validity と shrinking を両立しやすくなります。

shrunk した後も同じ contract 違反で落ちることを確認します。落ちないなら、property、generator、shrinker のどれかが不適切です。seed と最小反例は再現可能にします。

## 4. stateful / model-based testing

順序や履歴が本質なら、単発の example より model が強いです。

### 使う条件

- command の順番が重要。
- 状態が蓄積する。
- 単発の入出力では bug を落としきれない。
- API 呼び出しの流れで壊れる。

### 基本形

1. model state を定義する。
2. command を定義する。
3. command sequence を生成する。
4. system と model の両方に適用する。
5. observable な結果を比較する。

### 見るポイント

- step ごとの状態。
- 最終状態。
- 例外やエラーの出方。
- 不変条件の維持。

## 5. 独立した oracle

PBT が弱くなる最大原因は、system が自分自身を採点していることです。

### 強い oracle

- simpler reference implementation
- 数学的な law
- 別データソース
- 簡潔な model
- 仕様書から直接導ける invariant

### 弱い oracle

- 同じ実装パスを辿る比較
- 実装の内部状態をそのまま正解にする比較
- たまたま一致しているだけの出力比較

oracle は subject より単純でなければいけません。単純でない oracle は、バグを見逃しても気づけません。

## 6. PBT の禁止事項

次は使ってはいけません。

- weak property: `panic しない`、`戻り値が存在する`、`length >= 0`のように、ほとんど何も保証しない。
- random property: ただの fuzz で、主張がない。
- trivial property: 戻り値の型や `x == x` だけを見る。
- implementation-repeating property: 実装を言い換えただけ。
- production logic を test 側でもう一度実装して一致を確認する。
- invalid-generator domination: 意味のない invalid input の reject だけを大量確認する。
- overfit property: 1 つのバグにだけ効く形に偏る。
- hidden setup property: setup failure を property failure に見せる。
- same-path oracle: subject と oracle が同じ欠陥を共有する。
- boundary-blind property: 境界で壊れるのに境界を作らない。
- clock/network uncontrolled property: 外部揺らぎを制御しない。

## 7. 説明価値のある例を残す

PBT は広さに強く、example は説明力に強いので、具体例自体に意味があるものは残します。一方、独立した説明責任も regression value もない重複exampleは削除します。

### 残すべき example

- user-facing の代表例。
- 失敗時に一目で理解できる例。
- 境界の意味を説明する例。
- regression として残すべき例。

### 消してよいことが多い example

- property と完全に同じことを重複している。
- どの主張にも寄与していない。
- 説明なしでは意味が分からない。

## 8. mutation testing

mutation testing は任意の診断手段です。mutation score 100%を目標にせず、survivor が意味のある未保証動作を示すかを判断します。

### 見るべき survivor

- off-by-one が生き残る。
- comparison 反転が生き残る。
- branch 削除が生き残る。
- update 抜けが生き残る。
- default 変更が生き残る。

### survivor の分類

- meaningful behavior difference
- equivalent mutation
- implementation detail
- static guarantee へ移すべきもの
- property が弱い
- generator の探索領域が弱い
- 新しい contract が本当に存在する

survivor を見て、すぐ example を1件追加しません。まず既存property、generator、static guaranteeのどれを改善すべきか判断します。

## 9. dependency policy

PBT は依存を増やしやすいので、使う条件を絞ります。

### 導入判断

- project に既存の PBT framework や generator があれば、それを優先する。
- 言語や ecosystem を調査してから候補を選ぶ。
- 新規dependencyが必要なら、探索力、shrinking、再現性に対する価値と保守コストを説明し、勝手に導入しない。
- model との比較用helperは、production logicより十分単純な場合だけ作る。

### 増やしすぎない

- 本番実装と同じロジックを test 側に複製しない。
- 仕様のための仕様を追加しない。
- framework の流儀に合わせるためだけの helper を積まない。

依存が増えるほど、壊れたときの原因特定が遅くなります。

## 10. overuse prevention

PBT の使いすぎを止めるためのチェックです。

採用するには、次をすべて説明できる必要があります。

- どの Domain invariant または普遍的Contractを表すか。
- なぜ少数の意味あるexampleでは不足するか。
- production実装から独立したoracleは何か。
- valid Domain stateと重要なboundaryをどう生成するか。
- 最小反例へshrinkingしても意味が残るか。
- 実行時間と保守コストがriskに見合うか。

一つでも説明できなければ、より単純な executable specification へ戻ります。

## 11. 使う順番

1. domain rule を書く。
2. property に変える。
3. generator を作る。
4. valid state と重要な boundary を探索する。invalid は拒否Contractに意味がある場合だけ足す。
5. shrink を確認する。
6. stateful / model-based が必要なら足す。
7. strong oracle と比較する。
8. 必要なら mutation survivor を分類する。
9. example を残すか削るか判断する。

この順番を飛ばさないでください。飛ばすと、PBT は強い道具ではなく、派手な雑音になります。
