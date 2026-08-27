---
name: executable-specification
description: 日本語で、最も維持しやすい実行可能仕様を先に選び、必要なときだけ短い RED/GREEN/refactor を回す Skill。例・schema・型・newtype・smart constructor・typestate・API・visibility・static analysis・runtime contract・integration・benchmark・PBT のどれを使うべきか迷う場面、または universal property を本当に扱う場面で使う。実装の都合ではなく、保守しやすい仕様表現を選びたいときに使う。
---

# 実行可能仕様の選択

この Skill は、「何をテストするか」ではなく「どの形で仕様を表すと最も長持ちするか」を先に決めるためのものです。

## 基本方針

最初にやることはテストを書くことではありません。まず、対象の振る舞いを一文で言い切り、その振る舞いを最小の保守コストで表せる実行可能な仕様を選びます。

同じ WHAT を複数の層で重ねて書かないでください。型でも schema でも runtime でも同じ主張を繰り返すと、変更時に全部ずれて壊れます。重複する WHAT は、最も上流で最も安定な表現 1 つに寄せます。

## 選択の優先順位

迷ったら、次の順で検討します。

1. **型 / newtype / smart constructor / typestate**
   - そもそも不正状態を作れないか。
   - コンパイル時に防げるなら、最強で最も安い。

2. **API / visibility**
   - 公開範囲を狭めるだけで事故を防げないか。
   - 触れられる面を減らすのは、最も壊れにくい仕様です。

3. **schema / static analysis**
   - 形、必須項目、制約、禁止パターンを機械的に読めるか。
   - 入出力の契約が主題なら、ここが先です。

4. **runtime contract**
   - 実行時にしか確認できない不変条件があるか。
   - 失敗時に何を保証するかが重要なら、契約テストが有効です。

5. **example tests**
   - 具体的な分岐、バグ再現、境界値、ユーザーに見えるふるまいを示す。
   - 一番読みやすく、最初に選ぶことが多いです。

6. **integration tests**
   - 複数コンポーネントの接続面、I/O、設定、配線を確認する。
   - 単体で見えない結合不具合に使います。

7. **benchmark / performance guard**
   - 正しさよりも、退化が問題になる箇所に限って使う。
   - 仕様そのものというより、退行監視です。

8. **property-based testing (PBT)**
   - universal property を本当に言えるときだけ使う。
   - 使いどころは強いが、常用ではありません。

最終判断は「読みやすいか」ではなく、「変更時にどれが一番長生きするか」です。

## 強い仕様表現を選ぶ基準

次の問いで選びます。

- 不正状態は型で消せるか。
- 生成時点で不正値を作れないか。
- 公開 API を絞るだけで守れるか。
- schema で十分か。
- static analysis で落とせるか。
- runtime contract が必要か。
- 少数の example で十分か。
- 連携や I/O をまたぐか。
- 退化監視として benchmark が必要か。
- universal property を本当に言えるか。

## 短い TDD ループ

TDD は、行動を増やすための儀式ではなく、変更のリスクを最小化するために使います。

### 使う場面

- 振る舞いが変わるとき。
- 既存の保証を壊さずに実装を変えるとき。
- 仕様選択がまだ不安で、最小の失敗を確認したいとき。

### 使わない場面

- ただの整形。
- 名前変更。
- 実装の見通し改善だけ。
- 行動が変わっていないのに TDD の形だけをなぞるとき。

### 進め方

1. 振る舞いを一文で書く。
2. その振る舞いに最も合う executable spec を 1 つ選ぶ。
3. 最小の RED を作る。
4. 最小の変更で GREEN にする。
5. 仕様が固定されたら refactor する。

### Proportional TDD

TDD の大きさは課題の大きさに比例させます。

- 小さな修正なら、小さな example だけでよい。
- schema で済むなら、PBT を持ち出さない。
- 1 個のバグなら、1 個の再現例で足りることが多い。
- 連続した状態遷移なら、stateful / model-based を選ぶ。
- 広い入力空間だけが本質なら、PBT を検討する。

## 何を RED とみなすか

次は有効な RED です。

- assertion failure
- compile failure
- schema / contract failure
- property violation

次は仕様の RED ではありません。先に潰します。

- environment failure
- dependency failure
- import resolution failure
- syntax error
- test harness 自体の起動失敗

理由は単純です。これは振る舞いの失敗ではなく、実行環境の失敗だからです。仕様の強さを判断したいのに、土台の壊れでノイズを見てはいけません。

## Example と PBT の選び方

Example は「この 1 つの振る舞いを明確に見せる」ために使います。PBT は「すべての入力に対して成り立つ主張」を示すために使います。

次なら Example を優先します。

- 変更点が局所的。
- 再現したい bug が 1 つある。
- 読み手に手順を見せたい。
- 期待結果が具体的で短い。

次なら PBT を検討します。

- universal property を一文で言える。
- 入力空間が広く、例を増やしても本質が伝わらない。
- 反例が縮むほど価値がある。
- model と照合した方が強い。

## 生成を重ねるときの注意

同じ WHAT を別の層で重ねないでください。

悪い例:

- type で禁止したのに、同じ禁止を runtime contract と example でも重ねる。
- schema で十分なのに PBT でも同じ形を確認する。
- visibility を絞れば足りるのに、実装詳細にテストを増やす。

これは「守りが厚い」のではなく、「保守点が増えている」だけです。

## 削除中心の見直し

レビューでは、追加できるかより、**削除しても壊れないか** を先に見ます。

確認すること:

- この example は 1 つ減らせるか。
- この contract は schema に寄せられるか。
- この runtime assertion は型に移せるか。
- この integration test は本当に必要か。
- この PBT は local example で置き換えられないか。

削れるなら削ります。守りたいのはテスト数ではなく、仕様の説明力です。

## PBT 参照を読む条件

`references/property-based-testing.md` を開くのは、次の条件を満たしたときだけです。

- universal property を言える。
- 例では足りない。
- generator が必要。
- shrinking が価値を持つ。
- stateful / model-based の必要性がある。

それ以外では開かないでください。PBT は強い道具ですが、最初の道具ではありません。

## 避けるべきこと

- PBT をデフォルトにする。
- 失敗の原因が setup なのに red と誤認する。
- 実装の WHAT をそのまま test に写す。
- 同じ WHAT を複数層で重ねる。
- example で十分なのに property を採る。
- 何も変わっていないのに TDD を続ける。
- benchmark を正しさの代わりにする。

## 使い分けの要点

- 不正状態を消すなら type / newtype / smart constructor / typestate。
- 触れる面を減らすなら API / visibility。
- 形と契約なら schema / static analysis。
- 実行時の不変条件なら runtime contract。
- 具体的な振る舞いなら example。
- 接続や配線なら integration。
- 退行監視なら benchmark。
- universal property なら PBT。

この順番を外さないでください。順番を崩すと、強いはずの仕様が弱い説明になります。
