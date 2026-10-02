# Agent Skills の宣言的管理

`agent-skills-nix` の Home Manager モジュールを `home/common` で読み込み、
desktop / WSL / Darwin に同じ Skills を配布する。
設定は `home/common/programs/agent-skills.nix`、取得元と revision は
`flake.nix` / `flake.lock` が管理する。

- `personal-skills` は `git+ssh://git@github.com/See2et/agent-skills.git` を
  `flake = false` で取得する。Skills 側に flake.nix は不要。
- リポジトリ直下の Skills を全て選択する。比較評価用の入れ子の Skills は
  カタログに別項目として登録しない。各 Skill 内の資料・evals はそのまま保持する。
- `~/.agents/skills` は読み取り専用の bundle への単一リンクになる。
  Codex / OpenCode はこの共通パスを読む。エージェント別の重複配布はしない。
- 既存のディレクトリを上書きしない。初回適用前に checkout を退避する。
- SSH 秘密鍵は従来どおり `~/.ssh/id_ed25519_personal` に手動配置する。
  鍵は Git / Nix Store に入れない。Private repository の取得内容自体は
  Nix Store に入るため、Skills に秘密情報を含めない（通常 Store は他ユーザーも読める）。

## SSH 鍵の準備（各端末の通常ユーザーで実行）

まだ鍵がない場合のみ作成する。既存鍵を上書きしない。

```sh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_personal
# 必要なら稼働中の SSH agent に追加（パスフレーズ付き鍵）
ssh-add ~/.ssh/id_ed25519_personal
```

`~/.ssh/id_ed25519_personal.pub` を GitHub の Settings → SSH and GPG keys
に登録する。リポジトリへの read 権限も必要。
未適用の端末でも確認できるよう、以下では鍵のパスを明示する。

```sh
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_personal -T git@github.com
git -c core.sshCommand='ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_personal' \
  ls-remote ssh://git@github.com/See2et/agent-skills.git HEAD
```

初回接続では GitHub 公開の host key fingerprint を確認する。
`ssh -T` は認証成功の挨拶を表示しても終了コード 1 になる。
`git ls-remote` の成功でリポジトリのアクセスも確認できる。

## 初回移行

現在の checkout は編集用として保持する。未コミット変更があればそこで保存する。
以下はユーザーが実行する手順。退避先が既に存在する場合は別の名前を選ぶ。

```sh
mkdir -p ~/src
test ! -e ~/src/agent-skills && mv ~/.agents/skills ~/src/agent-skills
```

初期 lock は既存 checkout のコミット
`1dffc661a819a438fcca93d5b90a403329bc9381`（当時の origin/HEAD と一致）を
Nix のローカル Git fetcher で取り込み、得た revision / NAR hash を使って
SSH URL を固定した。SSH 鍵未作成のためリモート SSH fetch は未検証。
各端末では上の SSH 確認を済ませてから使用する。

## 更新と NixOS 適用

Skills は `~/src/agent-skills` などの編集用 checkout で編集し、GitHub に push する。
配布先の `~/.agents/skills` は直接編集しない。

取得・更新・ビルドは **sudo を付けず**、対象ユーザーの SSH 設定と agent を使う。

```sh
cd /etc/nixos
# Skills を更新したい時だけ実行（初回 lock の SSH 再取得確認にも使える）
nix flake update personal-skills
nix flake check --show-trace
nix build .#nixosConfigurations.desktop.config.system.build.toplevel --out-link result-agent-skills
```

ビルド後、ユーザーが次の順で適用する。WSL は上の `desktop` を `wsl` に変える。
同じビルド成果物を使うので、root が Private repository を取得する必要はない。
`sudo -E` や root の鍵設定には依存しない。

```sh
system_path=$(readlink -f result-agent-skills)
sudo "$system_path/bin/switch-to-configuration" dry-activate
# dry-activate の結果を確認してから、ユーザーが実行
sudo "$system_path/bin/switch-to-configuration" test
# test の動作を確認してから、ユーザーが実行
# nixos-rebuild と同様に system profile も更新して世代を保存する
sudo nix-env --profile /nix/var/nix/profiles/system --set "$system_path"
sudo "$system_path/bin/switch-to-configuration" switch
```

`sudo nixos-rebuild ... --flake ...` を直接実行すると、キャッシュにない
SSH input の取得を root が試みて認証に失敗する場合がある。
上記のビルド済みパスからの適用を使う。
`dry-activate` は Home Manager のファイル配置まで検証するものではないため、
初回 checkout 退避の確認と `test` 後の Home Manager 結果確認も必要。

Darwin でも取得・ビルドを通常ユーザーで行う。実際の aarch64-darwin 端末で
`nix build .#darwinConfigurations.darwin.system` し、端末側の適用手順に従う。

## 別の Private Skills repository を追加する

`flake.nix` に `flake = false` の `git+ssh` input を追加し、同モジュールに
`sources.<name>.input = "<input名>";` を追加する。配置に応じて `subdir` と
`filter.maxDepth` を設定し、`skills.enableAll` の source 名リストに加える。
名前が衝突する場合は `sources.<name>.idPrefix` で namespace を付ける。
新規 `.nix` ファイルは評価前に `git add` する。

参照: [agent-skills-nix](https://github.com/Kyure-A/agent-skills-nix)、
[Nix Git flake inputs](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake.html#types)。
