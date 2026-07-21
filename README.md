# nixos-rice

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
- Linuxターゲットでは root/sudo 権限があること

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

4. 安全な順序で検証・反映します。`dry-activate` から開始し、`test` と `switch` は必ず実機ユーザーが手動で実行してください。

```bash
nix flake check --show-trace
sudo nixos-rebuild dry-activate --flake /etc/nixos#desktop
sudo nixos-rebuild test --flake /etc/nixos#desktop
sudo nixos-rebuild switch --flake /etc/nixos#desktop
```

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

3. 安全な順序で検証・反映します。

```bash
cd /etc/nixos
nix flake check --show-trace
darwin-rebuild build --flake .#darwin
darwin-rebuild switch --flake .#darwin
```

`darwin-rebuild` コマンドが未導入の場合:

```bash
nix run github:LnL7/nix-darwin/nix-darwin-26.05#darwin-rebuild -- build --flake .#darwin
nix run github:LnL7/nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake .#darwin
```

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
sudo nixos-rebuild dry-activate --flake /etc/nixos#desktop   # または #wsl
sudo nixos-rebuild test --flake /etc/nixos#desktop           # 実機ユーザーが手動実行
sudo nixos-rebuild switch --flake /etc/nixos#desktop         # 実機ユーザーが最後に手動実行
```

## 6) ロールバック（NixOS）

```bash
sudo nixos-rebuild switch --profile /nix/var/nix/profiles/system --rollback
```
