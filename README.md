# nixos-rice

常時稼働開発ホスト（Herdr / Mosh / Web Preview / Sunshine）の導入・運用は [remote-development.md](docs/remote-development.md) を参照。

Skills更新時のCodex自動監査と再実行方法は [skills-audit.md](docs/skills-audit.md) を参照。

Pi Coding Agent は Desktop / WSL / Darwin 共通で導入する。本体は `pi-nix`
input に固定し、`nix flake update pi-nix` で更新する。Home Manager / NixOS の
リリース更新とは独立している。適用は後述の通常の rollout gate に従う。

`home/common/programs/pi.nix` の `piPackages` に、npm 依存込みでビルドした
ローカル Package のルートを追加すると、起動 wrapper が `-e` で読み込む。
外部 CLI は `runtimePackages` に追加する。共有 Skills は既存の
`~/.agents/skills` を Pi が直接探索する。

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
