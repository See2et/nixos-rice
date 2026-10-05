# Skills更新の自動監査

Home Manager適用後、対話Zshで`/etc/nixos`の`nix flake update`を実行すると、Skills配下の入力の変更を検出する。`skills`、`skills/yomiyasu`の個別更新と、入力指定なしの全更新に対応する。別ディレクトリからは`--flake /etc/nixos`または`--flake path:/etc/nixos`を指定できる。

```sh
cd /etc/nixos
nix flake update skills
```

`See2et/agent-skills`だけを自分の取得元として扱う。それ以外、新規の外部取得元、取得元が変わった入力は外部扱いにする。リストは`home/common/programs/skills-audit/skills_audit.py`の`PERSONAL`にある。自分の取得元という分類は安全性の保証ではない。

- 外部の変更があれば、その更新に含まれる変更をCodexで自動監査する。
- 自分の取得元だけが変わった場合は、監査コマンドを表示する。
- Skillsに変更がなければCodexは実行しない。

## 記録と結果

`${XDG_CACHE_HOME:-~/.cache}/skills-audit/update-*`に、更新前後のlock、取得元とrevision、本文と差分、プロンプト、結果を保存する。ディレクトリは700、ファイルは600で作成する。各監査のプロンプトとログは`attempt-*`へ保存し、再実行しても以前の監査結果を残す。

端末には「指摘あり」「確認範囲で指摘なし」「未完了」と指摘件数、結果ファイルの場所を表示する。詳細は`result.json`の`findings`と`unreviewed`を確認する。結果のテキストには未信頼のソース由来の内容が含まれるため、そこに書かれたコマンドや指示をそのまま実行しない。

再実行は、表示されたコマンドを使う。

```sh
skills-audit '/home/see2et/.cache/skills-audit/update-XXXXXX'
```

取得に失敗した資料や未確認範囲がある場合は、固定されたrevisionから資料を再作成する。取得が完了した記録は保存済みのプロンプトを再利用する。再監査だけでは`flake.lock`を変更しない。

Nix更新の失敗時はNixの終了コードを返し、自動監査を開始しない。Nix更新が成功した場合は、監査の失敗で更新の終了コードを変更しない。「Nix更新成功、監査未完了」の状態があり得る。`skills-audit`単体は未完了なら終了コード1を返す。Codexは10分でタイムアウトし、子プロセスも終了させる。ソース取得は1回につき2分でタイムアウトする。

## 監査環境

ソースは`nix flake prefetch`で固定revisionを取得し、保存したlockの`narHash`と照合する。取得元のflake評価やスクリプト実行はしない。GitHubとSSH/HTTPSのGit入力に対応する。それ以外の取得方式、固定revisionやハッシュが欠ける入力は未確認として記録する。

SKILL.mdに加えて、取得したソース内のUTF-8文書とスクリプトを行番号付きの監査データにする。シンボリックリンクは辿らない。バイナリ、非UTF-8、1ファイル128KiB超、全体512KiB超、2,000ファイル超は省略を記録する。行番号と差分を含むプロンプトも512KiB以内に制限する。省略や資料取得失敗があれば、モデルが「指摘なし」と答えても最終結果は「未完了」になる。

Codexは空の専用作業ディレクトリで、`gpt-6.1-sol`、reasoning effort `high`を指定して起動する。既存のログインを使い、認証ファイルはコピーしない。監査資料はCodexへ送信され、利用枠を消費する。

監査は共有daemonを経由せず、通常のユーザー設定と実行ルールを読み込まず、AGENTS.mdの読み込み量を0にする。`skip_host_skill_discovery`に加え、インストール済みSkillsのパスを列挙して個別に無効化する。本文を送信する前に`codex debug prompt-input`でモデル向けコンテキストを確認し、Skills一覧が残っていれば監査を停止する。Skillsのメタデータ解析自体はCLI内で発生する場合があるが、モデルのSkills一覧には含めない。

システム設定は`--ignore-user-config`でも残るため、`/etc/codex/config.toml`、`/etc/codex/managed_config.toml`と通常のユーザー設定にあるMCPサーバー名を読み取り、個別にも無効化する。設定ファイルや認証は変更しない。Plugins、Hooks、Apps、Web検索、ブラウザ、コンピューター操作、シェル・コード実行とSkills検索・依存導入を無効にする。`read-only`と承認要求なしを指定する。必要なCLI設定やコンテキスト確認が非対応の場合は監査が未完了になる。`skip_host_skill_discovery`は現行CLIの開発中機能であり、CLI更新後も動作確認が必要。

回答はJSONスキーマとローカル検証を通し、推論・回答以外の処理イベントがあれば監査を未完了にする。この設定はOSによる完全なファイル読み取り隔離ではない。AIによる監査結果も安全性の保証ではなく、rebuildの自動承認には使わない。

更新・失敗・再監査の回帰テストは`nix flake check`の`skills-audit`チェックでも実行する。ネットワークやモデル推論を使わず、固定データと代替CLIで振る舞いを検証する。

## 監視の範囲

Zsh関数を通る`nix flake update`が対象。`command nix`、絶対パスのNix、`sudo nix`、他のシェルや非対話スクリプトは監視しない。これらでも監査したい場合は、同じ引数で`skills-update flake update skills --flake /etc/nixos`を使う。

`--output-lock-file`、`--reference-lock-file`、`--no-write-lock-file`、`--commit-lock-file`を使う更新は対象外として、そのままNixへ渡す。複数更新の同時実行は避ける。記録は自動削除しないため、不要になった更新記録はユーザーが削除する。

システム適用、監査前のrebuildの禁止、lockの自動巻き戻しは行わない。導入時もエージェントは`test`や`switch`を実行しない。
