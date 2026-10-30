# nixos-rice

Desktop（NixOS x86_64-linux）、WSL（NixOS-WSL）、Darwin（nix-darwin + Home Manager + nix-homebrew, aarch64-darwin）を管理する Nix flake です。

- [導入](#導入) / [日常の更新](#日常の更新) / [依存の更新](#依存の更新) / [ロールバック](#ロールバックnixos)
- 常時稼働開発ホスト（Herdr / Mosh / Web Preview / Sunshine）: [remote-development.md](docs/remote-development.md)
- Skills 更新時の Codex 自動監査・再実行: [skills-audit.md](docs/skills-audit.md)
- エージェントの作業制約: [AGENTS.md](AGENTS.md)

## Screenshots

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/5816cec8-05b5-4df4-ad27-e9ba25aa8df1" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/f714e29a-9027-4477-9cdc-c30007c91637" />

## 導入

Git と Nix（`nix-command` / `flakes` 有効）、root/sudo 権限が必要です。以下は `/etc/nixos` に checkout する場合の手順です。既存設定を退避してから配置してください。

```bash
sudo mv /etc/nixos "/etc/nixos.backup.$(date +%Y%m%d-%H%M%S)"
sudo git clone https://github.com/See2et/nixos-rice.git /etc/nixos
cd /etc/nixos
```

**NixOS の適用順序は `dry-activate` → `test` → `switch` です。`test` / `switch` と Darwin の activation は実機ユーザーが結果を確認しながら手動で実行してください。** `dry-activate` は Home Manager / Plugin の実適用を検証しないため、`test` 後に Home Manager の成功も確認します。

### Private GitHub の SSH 準備（Desktop / Darwin）

秘密鍵は通常ユーザーの `~/.ssh/id_ed25519_personal` に置き、Git / Nix Store / root のホームへコピーしません。取得した private repository の内容は Nix Store に入ります。既存の鍵があればそのまま使います。新規作成は通常ユーザーで行います（同名ファイルがあれば中止）。

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

初回適用前は鍵指定がまだ有効でない場合があります。通常ユーザーで鍵を明示して接続を確認してください。host key の確認を求められたら、[GitHub 公式の SSH fingerprint](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints) と一致することを確認してから承認します。

```bash
ssh -i ~/.ssh/id_ed25519_personal -T git@github.com
```

初回の通常ユーザービルドだけ、一時的に `GIT_SSH_COMMAND` で鍵を指定します。適用後はシステム SSH 設定が GitHub の公式 Ed25519 host key を固定し、root の GitHub 接続だけに通常ユーザーの鍵パスを指定します。sudo は `SSH_AUTH_SOCK` を保持するため、ロード済み agent を利用できます。通常の sudo rebuild に `GIT_SSH_COMMAND` の保持は不要です。WSL はこの sudo SSH 設定の対象外です。

適用後、通常ユーザーから root の認証と repository の read 権限を確認してください。

```bash
sudo ssh -G git@github.com | rg '^(identityfile|identitiesonly|stricthostkeychecking|hostkeyalgorithms) '
sudo ssh -T git@github.com
sudo git ls-remote git@github.com:See2et/agent-skills.git HEAD
```

`ssh -T` は認証成功メッセージが出ても終了コード 1 になります。ユーザー名・ホームを変更する場合は、ホストのユーザー設定と鍵の配置を合わせてください。

### Desktop（NixOS）

1. `hardware-configuration.nix` を実機に合わせて更新します。

   ```bash
   sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix > /dev/null
   ```

2. 必要に応じて `hosts/desktop/default.nix` のユーザー情報を変更します。
3. `see2et` には宣言的なパスワードがありません。GDM 再起動後にログインできなくなるのを防ぐため、事前に `sudo passwd see2et` でローカルパスワードを設定します。
4. 初回は通常ユーザーでビルドし、実機ユーザーが各段階を確認して手動適用します。

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

### WSL（NixOS-WSL）

先に NixOS-WSL のベースイメージを導入します。必要に応じて `hosts/wsl/default.nix` のユーザー情報を変更し、sudo・ログイン復旧用に `sudo passwd nixos` でパスワードを設定します。

```bash
nix flake check --show-trace
sudo nixos-rebuild dry-activate --flake /etc/nixos#wsl
sudo nixos-rebuild test --flake /etc/nixos#wsl
sudo nixos-rebuild switch --flake /etc/nixos#wsl
```

### Darwin（macOS）

`flake.nix` の `darwinUser.name` / `darwinUser.home` を実機に合わせます。通常運用は `darwinConfigurations.darwin` を使います（`homeConfigurations.darwin` は評価互換用）。ビルドは実機の `aarch64-darwin` 環境で確認してください。

初回は通常ユーザーでビルドし、実機ユーザーが手動適用します。`darwin-rebuild` が未導入でもこの手順を使えます。

```bash
export GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519_personal -o IdentitiesOnly=yes'
nix flake check --show-trace
nix build .#darwinConfigurations.darwin.system --out-link result
sudo nix-env --profile /nix/var/nix/profiles/system --set "$(readlink -f result)"
sudo ./result/activate
unset GIT_SSH_COMMAND
```

## 日常の更新

```bash
cd /etc/nixos
git pull --rebase
nix flake check --show-trace
```

Desktop は各段階の結果を確認します。WSL は `#desktop` を `#wsl` に置き換えます。`test` / `switch` は実機ユーザー専用です。

```bash
sudo nixos-rebuild dry-activate --flake path:/etc/nixos#desktop
sudo nixos-rebuild test --flake path:/etc/nixos#desktop
sudo nixos-rebuild switch --flake path:/etc/nixos#desktop
```

Darwin はビルド後、実機ユーザーが手動適用します。

```bash
sudo darwin-rebuild build --flake path:/etc/nixos#darwin
sudo darwin-rebuild switch --flake path:/etc/nixos#darwin
```

## 依存の更新

### Skills / Codex Plugins

Skills の取得元は `skills/flake.nix`、選択は `home/common/programs/agent-skills.nix` で管理します。配布先 `~/.agents/skills` は直接編集せず、編集用 checkout から push してください。Plugins は `codex-plugins/flake.nix` の取得元と `marketplaces.<name>.plugins` で管理します。

`/etc/nixos` から対象を指定して更新し、diff 確認・ビルド後に上記の適用手順を使います。revision はルートの `flake.lock` に固定し、子ディレクトリに lock を作りません。

```bash
nix flake update skills
nix flake update codex-plugins
# 個別更新
nix flake update skills/yomiyasu
nix flake update codex-plugins/astraeus
```

Plugins は Home Manager 適用時に Codex CLI で自動登録・更新され、リストから外すと以前管理した Plugin を削除します。旧キャッシュを整理するため、**更新前に利用中の Codex セッションを終了し、適用後に新しいセッションを開始**してください。無関係な Plugin・設定・認証と編集用 checkout は保持します。

### Pi 本体・拡張

Pi は Desktop / WSL / Darwin 共通です。本体は `nix flake update pi-nix` で更新します。拡張は checkout から次を使います（本体は更新しません）。private な Git 拡張には上記の SSH 準備が必要です。

```bash
nix run .#update-pi-extensions -- --list
nix run .#update-pi-extensions                          # 全拡張
nix run .#update-pi-extensions -- pi-interview          # 指定した拡張だけ
nix run .#update-pi-extensions -- pi-astraeus pi-interview
```

登録は `pi-extensions/inventory.json` に統一し、配列順に読み込みます。新規登録も inventory を編集して対象名を指定します。生成される `pi-extensions/flake.nix` は直接編集しません。手動編集を検出すると更新前に停止しますが、これは悪意ある改変への整合性保証ではありません。Git 登録名は `[a-z][a-z0-9_-]*`（Nix 予約語不可）、npm は scoped 名も使えます。

更新時の注意:

- 名前を全件検証してから、対象 Git input または npm の latest を exact version に固定します。未選択の直接依存・無関係な input は保持しますが、選択した npm 拡張の推移的依存は変わり得ます。npm install script は実行しません。
- stage 済み・未 stage の変更と非 ignored の新規ファイルを含む一時コピーで hash 計算と `nix build .#pi --no-link` を行い、成功後に対象の宣言・pin・hash だけを戻します。元の Git index は変更しません。Git revision はルートの `flake.lock` に固定し、`pi-extensions/flake.lock` は作りません。
- network・認証・hash 計算・ビルド（既存 patch の適用失敗を含む）の失敗、コピー後のソース編集を検出した場合は元の checkout へ反映しません。通常の書き込みエラーでは復元しますが、process/host crash に対して atomic ではありません。**更新中は他の編集を止め、成功後に diff を確認**してください。
- inventory から削除すると読み込まれなくなりますが、依存成果物の削除は別途レビューします。更新処理は未選択の依存を勝手に削除しません。
- `packages/pi-extensions/package.json` の sharp override は [GHSA-wq5f-xc86-pv6w](https://github.com/advisories/GHSA-wq5f-xc86-pv6w) 対策です。上流の修正版採用を確認するまで保持し、解除時は lock・ビルド・画像処理を確認します。
- activation や Pi の writable 設定は更新コマンドでは変更しません。常用環境への反映は上記の適用手順と、新しい wrapper からの Pi 再起動が必要です。checkout の編集や起動中の `/reload` だけでは新しい Store の拡張に切り替わりません。

システム適用前に試す場合:

```bash
nix build .#pi --out-link result-pi
./result-pi/bin/pi
```

Pi の認証・セッションは Pi が保存し、Nix に認証情報を書きません。Home Manager は必要な設定だけを writable ファイルへマージします。利用時に必要な設定・制約は次のとおりです。

- miloa: 各ホストで `pi mcp login miloa` を実行して承認し、`pi mcp list` で確認します。OAuth 認証情報は配布しません。起動中の Pi には `/reload` で反映します。
- Browser: Linux は Nix の Chromium が既定で、`PLAYWRIGHT_MCP_EXECUTABLE_PATH` のユーザー指定を優先します。Darwin は利用できるブラウザーを別途指定します。
- Recap: アイドル・再開時にも追加のモデル呼び出しが発生します。Home Manager は `~/.pi/agent/extensions/pi-recap.json` の model を `openai-codex/gpt-6.1-sol` に戻します。既存の `openai-codex` 認証を使い、利用不可・未認証時に別モデルへフォールバックしません。独自の `PI_CODING_AGENT_DIR` には同じ設定を別途用意してください。
- Usage: Codex 利用枠取得には native `/login openai` とは別に、同じアカウント・workspace で `/login openai-codex` が必要です。`Codex:✓` だけでは数値取得の成功を示しません。返されない枠は 0% として扱いません。
- 通知: 適用後は Pi を再起動して `/notify-test` で確認します。`Idle` は応答終了であり、非同期質問の回答や依頼全体の完了を意味しません。

SubAgent の完了通知・記録の期限切れ・元セッションの復旧は [pi-subagent-recovery.md](docs/pi-subagent-recovery.md) を参照してください。

## ロールバック（NixOS）

実機ユーザーが前の generation へ戻します。

```bash
sudo nixos-rebuild switch --profile /nix/var/nix/profiles/system --rollback
```

checkout の退避コピーは設定ファイルの復旧用です。復旧後の再ビルド・適用にも同じ確認手順を使ってください。
