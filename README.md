# nixos-rice

常時稼働開発ホスト（Herdr / Mosh / Web Preview / Sunshine）の導入・運用は [remote-development.md](docs/remote-development.md) を参照。

Skills更新時のCodex自動監査と再実行方法は [skills-audit.md](docs/skills-audit.md) を参照。

Pi Coding Agent は Desktop / WSL / Darwin 共通で導入する。本体は `pi-nix`
input に固定し、`nix flake update pi-nix` で更新する。Home Manager / NixOS の
リリース更新とは独立している。適用は後述の通常の rollout gate に従う。

拡張の登録場所は `pi-extensions/inventory.json` に統一している。
配列の順番が読み込み順で、名前・取得元・必要なpackaging・agent定義を記載する。
`home/common/programs/pi.nix` はこの一覧から `piPackages` を生成し、
起動wrapperが `-e` で読み込む。`pi-subagents` のnpm依存込みpackagingと、
Astraeusの拡張・4つのagent定義の同一ソース参照もこの登録から決まる。
外部CLIは引き続き `runtimePackages` に追加する。共有Skillsは既存の
`~/.agents/skills` をPiが直接探索する。

リポジトリのcheckoutで、Git/npmの区別なく更新する。

```sh
nix run .#update-pi-extensions                          # 全拡張
nix run .#update-pi-extensions -- pi-interview          # 1つだけ
nix run .#update-pi-extensions -- pi-astraeus pi-interview # 複数
nix run .#update-pi-extensions -- --list                # 使用可能な名前
nix run .#update-pi-extensions -- --help
```

現在の名前は `pi-subagents`、`pi-astraeus`、`pi-understanding`、
`pi-web-access`、`pi-browser-actions`、`pi-interview`、`@raidou/pi-notify`、
`pi-lsp-extension`、`@mtrojnar/pi-usage`。名前は更新前に全件検証する。
Git拡張は対象のinputだけ、npm拡張はregistryのlatestを取得してexact versionに更新する。
未選択の直接依存・無関係なflake inputは保持するが、選択したnpm拡張の推移的依存は変わり得る。
Pi本体の `pi-nix` は別途更新する。

Gitのstatic input宣言 `pi-extensions/flake.nix` はinventoryから生成する成果物で、
手で登録を追加しない。生成時の本文checksumをコメントに保存し、宣言の名前・URLを含め、
本文の手動編集を検出した場合は更新処理の前に停止する。これは誤編集の検出用で、
悪意ある改変への整合性保証ではない。inventoryだけの変更なら、以前の生成物を検証してから同期する。
新しい拡張はinventoryだけに登録し、その名前を指定して更新する。
Gitの登録名はunquoted Nix identifierとして使える `[a-z][a-z0-9_-]*` に限り、
`if` などのNix予約語も使えない。
npmの名前は従来どおりscoped名も使える。
更新時にstatic宣言を同期し、npmの `package.json`・`package-lock.json` と
`default.nix` の `npmDepsHash` も必要に応じて生成する。これらはversion pinの成果物であり、
別の登録場所ではない。宣言の同期チェックは `python3 tests/pi-extensions.py` で実行できる。
inventoryから外した拡張は読み込まれなくなるが、依存成果物の削除はレビューして別途行う。
未選択・無関係な依存を更新処理が勝手に削除することはない。
Git revisionはルートの `flake.lock` だけで固定し、`pi-extensions/flake.lock` は作成しない。

更新はstage済み・未stageの変更と新しい非ignoredファイルを含む一時コピーで行う。
コピー内で `prefetch-npm-deps` によるhash計算と `nix build .#pi --no-link` が成功してから、
対象の宣言・pin・hashファイルだけを元のcheckoutへ戻す。元のGit indexは変更しない。
network・認証・hash計算・ビルドの失敗、またはコピー後のソース編集を検出した場合は公開しない。
既存の `--replace-fail` patchが新版に適用できない場合もビルド失敗として扱う。
複数ファイルの書き込みは通常の書き込みエラー時に復元するが、process/host crashに対する
atomic transactionではない。更新中は他の編集を止め、成功後にdiffを確認する。
更新コマンドはactivationやPiのwritable設定を変更しない。適用はユーザーが
通常の `dry-activate` → `test` → `switch` のrollout gateを手動で実行する。
Darwinも実機ユーザーが適用する。エージェントはactivationを実行しない。

`pi-astraeus` と `pi-understanding` は
`git+ssh` で取得するため、後述の private GitHub 用 SSH 設定を使う。
validator 用の Python / jsonschema は wrapper の PATH に含まれる。
Home Manager は `~/.pi/agent/agents/astraeus-{worker,designer,reviewer,adjudicator}.md`
を管理し、その他の agent 定義は引き続き Pi 側で管理できる。

`pi-astraeus` の generated-output recoveryと厳密なpreparation-failure settlementは、
公開済みcommit `8b192b4146e518c151565506569cc3c2aad4f096` を `flake.lock` に固定して配布する。
拡張と4つのagent定義は同じ不変のinputを使い、編集用checkoutや一時パッチは参照しない。
認証・設定・セッションは変更しない。ビルドとレビュー後、ユーザーが通常のrollout gateに従って
手動で `nixos-rebuild switch` を実行すると常用Piに反映される。起動中のPiには自動反映されないため、
新しいwrapperからPiを再起動してから `reconcile_generated` を使う。
`/reload` は新しいinputのStoreパスをすでに読み込んでいる場合に限る。
エージェントはactivationを実行しない。

理解支援の TUI SidePane は private repo
[`See2et/pi-understanding`](https://github.com/See2et/pi-understanding) から
`pi-extensions/pi-understanding` input として取得し、同じ wrapper で読み込む。
`/understand` で開く。未commit分 / ローカルbranch / コード全体 / Module / Commit / PRと
参照する版を区別し、実装側とは別の会話で Pi の現在のモデルと認証を使う。
`/understand scope` では候補を一覧から選べる。学習ペインのCtrl+Tでも対象を変更できる。
実装側のAIへ自然文で相談すると、候補を調べ、ユーザーの確認後に理解対象を選択できる。
Ctrl+Alt+Uで実装入力と学習入力を切り替える。fullscreenでは両方の入力欄を
クリックして移動でき、下書きは保持する。regularではキーボードで切り替える。
更新は編集用 ghq checkout から push した後、`nix run .#update-pi-extensions -- pi-understanding`、
ビルド、後述の rollout gate の順に行う。checkout の編集だけでは Store 側に反映されない。
詳しい操作と制限は拡張の README を参照。Git / gh は wrapper の PATH に含めるが、
GitHub 認証はユーザーの既存設定を使い、Nix には保存しない。
システム適用前でも `nix build .#pi --out-link result-pi`、`./result-pi/bin/pi` で
Nix に固定した拡張込みの Pi を起動できる。これは既存の `pi` コマンドの置換や
システムの activation は行わない。常用コマンドへの反映には rollout gate が必要。

CodeMode は既存のツール選択を保持して有効化する。設定は writable な
`settings.json` に必要なキーだけマージし、`codemode.mode` の既存値は保持する。
`pi-lsp-extension` 1.4.0 と `@mtrojnar/pi-usage` 0.2.0 も Nix で固定して読み込む。
LSP 用の TypeScript/JavaScript・Python・Rust サーバーを wrapper の PATH に含める。
`/lsp` で状態、`/usage` で利用枠を確認できる。LSP の追加言語・サーバーは
各プロジェクトの `.pi-lsp.json` または `/lsp-config` で設定する。

`pi-usage` の Codex 利用枠取得には、native `/login openai` とは別に
`/login openai-codex` で同じ ChatGPT アカウント・workspaceへ補助ログインする。
推論モデルは `openai/gpt-6.1-sol` のまま維持できる。`Codex:✓` は使用率の
取得成功ではなく、数値がない状態でも表示される。週だけを返すプランでは
週の割合とリセットまでの時間だけを表示し、返されない5時間枠を0%にしない。

npm版のversion・推移的依存は `packages/pi-extensions/package.json` と
`package-lock.json` に固定する。現在は `pi-web-access` 0.37.0、
`pi-browser-actions` 1.1.1、`pi-interview` 0.13.0、`@raidou/pi-notify` 0.8.0、
`pi-lsp-extension` 1.4.0、`@mtrojnar/pi-usage` 0.2.0。
更新コマンドは `npm install --save-exact --package-lock-only --ignore-scripts
--legacy-peer-deps` を使い、npmのinstall scriptは実行しない。

browser-actionsの`browser_session`で起動・接続し、`browser`で操作する。
LinuxではNixのChromiumを既定にする。`PLAYWRIGHT_MCP_EXECUTABLE_PATH`の
ユーザー指定は優先される。Darwinでは利用できるブラウザーを別途指定する。
既存のweb-accessの`web_search`を残すため、browser-actions側の検索名は
`browser_web_search`に変更している。Playwright CLIと画像の縮小処理はwrapperの
Nodeで実行し、Pi本体のBunとは分離する。Linuxの画像ライブラリに必要な
libstdc++はwrapperから供給する。検証は
`python3 packages/pi-extensions/smoke-browser.py ./result-pi/bin/pi`で行える。

miloaはPiのwritableな`~/.pi/agent/mcp.json`に登録する。OpenCodeの認証情報は
コピーせず、Pi側で独立してOAuth認証する。このホストでは登録済みだが、
認証は未完了。ユーザーが`./result-pi/bin/pi mcp login miloa`を実行して
ブラウザーで承認し、`./result-pi/bin/pi mcp list --json`で接続を確認する。
miloaのURLや認証情報はNixで配布しない。他のホストでは各自のPiに登録する。

SubAgentの完了通知・記録の期限切れ・元セッションの復旧は別の問題として扱う。
検証結果と改修案は[pi-subagent-recovery.md](docs/pi-subagent-recovery.md)を参照。
この変更ではSubAgent本体を改修せず、以前の未回収ownerによる受理ブロックも回避しない。

Home Manager 適用時に `piNotify` の有効化・入力待ち通知と `interview` の
呼び出し通知を設定する。他の Pi 設定と通知イベント・通知対象ツールは保持する。
Linux の `notify-send` とブラウザー起動用 `xdg-open` は wrapper の PATH に含める。
適用後は Pi を再起動して `/notify-test` で通知を確認する。
`Idle` は応答終了の通知であり、非同期質問の未回答や依頼全体の完了を判定しない。

非同期質問を使う場合は Pi に「`interview` を `async: true` で呼び、
回答待ちの間は回答に依存しない作業を続ける」と指示する。

`~/.pi/agent/settings.json`、認証、セッションは Pi が保存する。試す Package は
`pi -e npm:<package>@<version>` で一時的に読み込み、常用が決まったら Nix 管理へ
移す。Nix 管理の本体・Package は Nix 側で更新し、認証情報は Nix 式に書かない。

1つのリポジトリで、以下3ターゲットを管理する統合Nix flakeです。

- `nixosConfigurations.desktop`（NixOSデスクトップ）
- `nixosConfigurations.wsl`（NixOS-WSL）
- `darwinConfigurations.darwin`（macOS向けnix-darwin + Home Manager + nix-homebrew）

## Screenshots
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/5816cec8-05b5-4df4-ad27-e9ba25aa8df1" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/f714e29a-9027-4477-9cdc-c30007c91637" />


## 1) 事前準備

- Git と Nix がインストール済みであること
- Flakes が有効であること（`nix-command` と `flakes`）
- root/sudo 権限があること

### Private GitHub の SSH 準備（Desktop / Darwin）

秘密鍵は通常ユーザーの `~/.ssh/id_ed25519_personal` に置き、Git / Nix Store / root のホームへコピーしません。既存の鍵があればそのまま使います。新規作成する場合は、通常ユーザーで次を実行してください（同名ファイルがあれば作成を中止します）。

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
test ! -e ~/.ssh/id_ed25519_personal && test ! -e ~/.ssh/id_ed25519_personal.pub && ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_personal
cat ~/.ssh/id_ed25519_personal.pub
```

表示した**公開鍵だけ**を GitHub の Settings → SSH and GPG keys に登録し、private repository の read 権限を確認します。パスフレーズ付きの鍵は通常ユーザーの SSH agent にロードします。

```bash
# Desktop
ssh-add ~/.ssh/id_ed25519_personal
# Darwin（Apple の ssh-add を使用）
/usr/bin/ssh-add --apple-use-keychain ~/.ssh/id_ed25519_personal
```

初回適用前は Home Manager の鍵指定もまだ有効でない場合があります。通常ユーザーで鍵を明示して接続を確認してください。初回接続で host key の確認を求められたら、[GitHub 公式の SSH fingerprint](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints) と一致することを確認してから承認します。

```bash
ssh -i ~/.ssh/id_ed25519_personal -T git@github.com
```

bootstrap の通常ユーザービルドでは一時的に `GIT_SSH_COMMAND` で鍵を指定します。適用後はシステム SSH 設定が GitHub の公式 Ed25519 host key を固定し、root の GitHub 接続だけに通常ユーザーの鍵パスを指定します。sudo は `SSH_AUTH_SOCK` を保持するため、パスフレーズ付きの鍵もロード済み agent を利用できます。通常の sudo rebuild は `GIT_SSH_COMMAND` の保持を必要としません。WSL はこの sudo SSH 設定の対象外です。

適用後、通常ユーザーから次を実行して root の認証と repository の read 権限を確認してください。

```bash
sudo ssh -G git@github.com | rg '^(identityfile|identitiesonly|stricthostkeychecking|hostkeyalgorithms) '
sudo ssh -T git@github.com
sudo git ls-remote git@github.com:See2et/agent-skills.git HEAD
```

`ssh -T` は GitHub の認証成功メッセージが出ても終了コード 1 になります。ユーザー名・ホームを変更する場合は、ホストのユーザー設定と鍵の配置を合わせてください。

## 2) `/etc/nixos` にクローン

```bash
sudo mv /etc/nixos "/etc/nixos.backup.$(date +%Y%m%d-%H%M%S)"
sudo git clone https://github.com/See2et/nixos-rice.git /etc/nixos
cd /etc/nixos
```

## 3) ターゲット別の導入手順

### Desktop（NixOS）

1. ハードウェア設定を更新します。

```bash
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
```

2. 必要に応じて `hosts/desktop/default.nix` のユーザー情報を変更します。
   - `home-manager.users.see2et`
   - `home.username`
   - `home.homeDirectory`

3. 対象ユーザーのローカルパスワードを事前に設定します（未設定のままGDM再起動が発生するとログイン不能になる可能性があります）。

```bash
sudo passwd see2et
```

4. 初回は新しい root 用 SSH 設定がまだ有効でないため、通常ユーザーでビルドします。以下の適用コマンドは、実機ユーザーが各段階の結果を確認しながら手動で実行してください。

```bash
export GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes'
nix flake check --show-trace
nix build .#nixosConfigurations.desktop.config.system.build.toplevel --out-link result
system_path=$(readlink -f result)
sudo "$system_path/bin/switch-to-configuration" dry-activate
sudo "$system_path/bin/switch-to-configuration" test
sudo nix-env --profile /nix/var/nix/profiles/system --set "$system_path"
sudo "$system_path/bin/switch-to-configuration" switch
unset GIT_SSH_COMMAND
```

`test` 後は Home Manager の成功も確認します。以降は日常の sudo rebuild 手順を使えます。

### WSL（NixOS-WSL）

1. 先に NixOS-WSL のベースイメージを導入します。
2. 必要に応じて `hosts/wsl/default.nix` のユーザー情報を変更します。
   - `home-manager.users.nixos`
   - `home.username`
   - `home.homeDirectory`

3. 対象ユーザーのローカルパスワードを事前に設定します（sudoやログイン復旧のため）。

```bash
sudo passwd nixos
```

4. 検証・反映を実行します。必ず `dry-activate` から始め、`test` と `switch` は実機ユーザーが手動で進めてください。

```bash
nix flake check --show-trace
sudo nixos-rebuild dry-activate --flake /etc/nixos#wsl
sudo nixos-rebuild test --flake /etc/nixos#wsl
sudo nixos-rebuild switch --flake /etc/nixos#wsl
```

### Darwin（macOS, nix-darwin + Home Manager + nix-homebrew）

1. `flake.nix` の `darwinUser` を実機に合わせて変更します。
    - `name`
    - `home`

   これが Darwin 側の single source of truth で、以下に反映されます。
    - `users.users.<name>.home`
    - `system.primaryUser`
    - `home.username`
    - `home.homeDirectory`
    - `nix-homebrew.user`
    - OmniWM LaunchAgent の app path

2. Home Manager の共通化方針:
   - `home/common/` には platform-agnostic な設定のみを置きます。
   - Linux固有の session/path は `home/linux/`、WSL固有は `home/wsl/`、Darwin固有は `home/darwin/` に置きます。
   - Darwin の正規導線は `darwinConfigurations.darwin` です。

3. 初回は通常ユーザーでビルドし、新しい root 用 SSH 設定を含む成果物を実機ユーザーが手動で適用します。`darwin-rebuild` が未導入でも同じ手順を使えます。

```bash
cd /etc/nixos
export GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes'
nix flake check --show-trace
nix build .#darwinConfigurations.darwin.system --out-link result
sudo nix-env --profile /nix/var/nix/profiles/system --set "$(readlink -f result)"
sudo ./result/activate
unset GIT_SSH_COMMAND
```

以降は `sudo darwin-rebuild build --flake path:/etc/nixos#darwin` でビルドし、結果を確認してから実機ユーザーが `sudo darwin-rebuild switch --flake path:/etc/nixos#darwin` を手動で実行します。

注: `homeConfigurations.darwin` は評価互換のため残していますが、通常運用は `darwinConfigurations.darwin` を使用してください。

## 4) ビルド確認（任意だが推奨）

```bash
cd /etc/nixos
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
nix build .#nixosConfigurations.wsl.config.system.build.toplevel
```

注: Darwin のビルド確認は実機の `aarch64-darwin` 環境で実施してください。

## 5) 日常の更新フロー

```bash
cd /etc/nixos
git pull --rebase
nix flake check --show-trace
```

Desktop は次の各段階を確認します。`test` と `switch` は実機ユーザーが手動で実行してください。

```bash
sudo nixos-rebuild dry-activate --flake path:/etc/nixos#desktop
sudo nixos-rebuild test --flake path:/etc/nixos#desktop
sudo nixos-rebuild switch --flake path:/etc/nixos#desktop
```

Darwin では、ビルド後に実機ユーザーが手動で適用します。

```bash
sudo darwin-rebuild build --flake path:/etc/nixos#darwin
sudo darwin-rebuild switch --flake path:/etc/nixos#darwin
```

WSL は既存の `dry-activate` → `test` → `switch` 手順を使用します。

## 6) ロールバック（NixOS）

```bash
sudo nixos-rebuild switch --profile /nix/var/nix/profiles/system --rollback
```
