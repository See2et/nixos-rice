# nixos-rice

1つのリポジトリで、以下3ターゲットを管理する統合Nix flakeです。

- `nixosConfigurations.desktop`（NixOSデスクトップ）
- `nixosConfigurations.wsl`（NixOS-WSL）
- `homeConfigurations.darwin`（macOS向けHome Manager）

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

1. 別マシンへ導入する場合は、ハードウェア設定を更新します。

```bash
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
```

2. 必要に応じて `hosts/desktop/default.nix` のユーザー情報を変更します。
   - `home-manager.users.see2et`
   - `home.username`
   - `home.homeDirectory`

3. 安全な順序で検証・反映します。

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

3. 検証・反映を実行します。

```bash
nix flake check --show-trace
sudo nixos-rebuild dry-activate --flake /etc/nixos#wsl
sudo nixos-rebuild test --flake /etc/nixos#wsl
sudo nixos-rebuild switch --flake /etc/nixos#wsl
```

### Darwin（macOS, Home Managerのみ）

1. `flake.nix` の `homeConfigurations.darwin` でユーザー情報を変更します。
   - `home.username`
   - `home.homeDirectory`

2. Home Manager を適用します。

```bash
cd /etc/nixos
nix flake check --show-trace
home-manager switch --flake .#darwin
```

`home-manager` コマンドが未導入の場合:

```bash
nix run github:nix-community/home-manager -- switch --flake .#darwin
```

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
sudo nixos-rebuild switch --flake /etc/nixos#desktop   # または #wsl
```

## 6) ロールバック（NixOS）

```bash
sudo nixos-rebuild switch --profile /nix/var/nix/profiles/system --rollback
```
