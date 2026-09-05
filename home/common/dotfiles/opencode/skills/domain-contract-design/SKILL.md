---
name: domain-contract-design
description: DDD、Domain-Driven Design、ドメイン設計、Design by Contract、DbC、invariant、Bounded Context、Aggregate boundary、Ubiquitous Language、contract ownerに関わり、Domainの意味・規則・所有権・境界・失敗の扱いが変わるか曖昧なときに使う。通常変更と大規模Domain変更を区別して契約を抽出する。意味や公開契約を変えないrename、helper抽出、format、dependency更新、trivial fix、純粋な見た目変更には使わない。
---

# ドメイン契約設計

この skill は、システムが「何を意味するか」「何を約束するか」「誰がその規則を持つか」が揺れる変更で使う。

ここでの DDD は、パターン集めではない。意味の境界を見つけ、言葉を揃えるための道具である。DbC は、precondition / postcondition / invariant を抜き出し、contract owner を一つに定めるための道具である。

## 使う場面

次のどれかが変わる、または曖昧になるときに使う。

- domain terms / ubiquitous language
- 規則や state の所有者
- 入力、出力、遷移の contract
- expected Result-like failures
- impossible states
- bounded context / aggregate boundary
- module、service、process をまたぐ境界
- persistence、public API、workflow の形

normal change でも、domain meaning が動くなら使う。大げさな再設計を待つ必要はない。

## 使わない場面

次のような変更に、戦略的な DDD を持ち込まない。

- copy edit
- formatting
- 意味が変わらない機械的な rename
- contract を保ったままの plumbing
- local で完結し、規則・所有権・failure の意味を変えない小さな修正
- 規則、所有権、failure の意味に触れない実装詳細

やり方だけが変わるなら、その場で閉じる。何を意味するかが変わらないなら、設計論を拡張しない。

## 基本姿勢

1. expected Result-like failures と impossible states を分ける。
   前者は contract の一部、後者は defect である。

2. 各規則には one canonical owner を置く。
   2 つの場所が同じ規則を主張しているなら、すでに contract が壊れている。

3. major change でない限り、DDD を重くしない。
   normal change は、明確な contract があれば十分で、全面的な domain program は不要である。

4. feature ごとの永続 Markdown を残さない。
   必要なときだけ transient handoff を使い、変更が落ち着いたら捨てる。

## 流れ

### 1. 変更を domain statement に言い換える

依頼を、plain な domain language に言い換える。

- 何が変わるか
- 何が true のままか
- 誰が rule を持つか
- どの failure が expected か
- どの state が存在してはならないか

### 2. 変更のクラスを決める

次のどちらかに振る。

- normal change: 同じ domain・ownership 内で閉じ、既存データや利用者の契約、他の境界の保証を壊さない contract 更新
- major change: boundary・ownership が動く、または既存の意味・互換性・整合性への影響から明示的な domain design が必要な変更。下記のトリガーで判定する

判定には変更対象の利用箇所・公開契約・保存データの制約など、関係する根拠を使う。影響が不明なら、その不明点に絞って確認する。未確認を「影響なし」と扱わず、不明という理由だけで major にもしない。

### 3. contract を抜き出す

変更に関係するものだけを書き出す。

- preconditions
- postconditions
- invariants
- canonical owner
- expected Result-like failures
- impossible states
- scope boundary

contract は最小に保つ。挙動、所有権、failure の意味に触れない rule は外す。

### 4. ownership と scope を確認する

次を確認する。

- single source of truth はあるか
- rule は適切な boundary で enforced されているか
- contract が変更に対して広すぎないか
- domain をまたぐ hidden coupling を生んでいないか

ownership が割れているなら、logic を足す前に split を直す。

### 5. 変更の形を決める

normal change では、

- 最小の contract surface だけを更新する
- 言葉を揃える
- contract が要らない新しい abstraction は足さない

major change では、

- boundary を明示する
- 各 rule の owner を特定する
- expected failures と invalid / impossible states を分ける
- 他者が続けられるよう transient handoff を残す

## major change のトリガー

次のどれかに当てはまるなら major change とみなす。

- Subdomain または Bounded Context を追加、分割、統合する
- Aggregate boundary、data owner、identity model を移動または変更する
- invariant 変更により、既存の保存データ・進行中の処理の有効性、利用者に約束した入力・結果・失敗の意味、または他の境界が依存する保証が変わる
- public API、command、query、event の Domain 上の意味や互換性を変える
- Context 間 integration を追加または変更する
- Aggregate をまたぐ transaction、整合性、並行性 policy を変える
- Domain 上の意味を伴う persistence migration を行う

major はコード量や「invariant を変更した」というラベルではなく、Domain の構造と既存の約束への影響で判断する。

局所的な制約変更は、同じ owner の内部に閉じ、既存データの再解釈・移行も、利用者の契約変更も、他の境界との調整も不要と確認できれば normal とする。たとえば、既存データや外部への契約を持たない内部の一時値に範囲制約を追加する変更が該当する。既存 API が受理していた入力を拒否したり、保存済み状態を無効にしたりする変更は、一行でも major になり得る。

既存契約どおりに不正入力を拒否するバグ修正と、契約自体を厳しくする変更は区別する。ただし、バグで生じた保存データの移行や利用者への互換性対応が必要なら、その影響も分類に含める。normal でも変更した contract と failure は明示し、必要な実行可能仕様で保証する。

contract の曖昧さ、rule の複数所有、expected failure と impossible state の混同は設計リスクだが、それだけでは major としない。owner と contract を明確にし、その解消が上記トリガーに該当する場合に major へ上げる。

## transient handoff の形式

共有 context が必要なときだけ、短い handoff を残す。恒久化しない。

```text
Domain statement:

Change class:

Canonical owner:

Preconditions:

Postconditions:

Invariants:

Expected domain failures:

Impossible states:

Boundary:

Open questions:

Decision:
```

これを feature ごとの permanent spec に変えない。

## anti-pattern review

次を見つけたら、止めて contract を引き直す。

- domain が見える前に DDD の pattern を集める
- すべての変更を strategic redesign にする
- expected failures を bug 扱いする
- impossible states を許容すべき edge case にする
- 2 つの module に同じ rule を持たせる
- 変更後も残る feature-specific Markdown を書く
- contract が見える前に abstraction を足す
- framework の都合で domain を曲げる framework-driven domain にする
- 実体のないモデルを増やす anemic model にする
- cross-context で false DRY をやる

特に、cross-context での false DRY、anemic models、framework-driven domains は危険信号である。再利用したくなったら、まず境界と所有権を疑う。

## 出力の型

この skill を使った出力は、次の順で短く返す。

- domain statement
- change class
- canonical owner
- 抜き出した contract
- ownership / boundary risk
- 最小の安全な next step

major でない限り、短く保つ。

## 削除志向の確認

この skill の最後に、自分にこう問う。

- この contract は 1 段階削れるか
- この rule は 1 箇所に寄せられるか
- この境界は消せるか、または狭められるか
- この説明は残すべきか、それとも transient で十分か

削れるなら削る。残すのは、意味・所有権・失敗の理解に本当に必要なものだけである。
