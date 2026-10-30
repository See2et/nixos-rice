# /etc/nixos での作業制約

この checkout は稼働中のシステム設定です。対象は Desktop / WSL / Darwin の3つで、laptop ターゲットはありません。導入・SSH・更新・ロールバックの手順は [README.md](README.md) を参照してください。

## 適用の安全境界

- `nix eval` / `nix build` / `nix flake check` で評価・ビルドまで検証できます。これらはシステムを activation しません。
- NixOS は必ず `dry-activate` → `test` → `switch` の順に進めます。`test` / `switch`（ロールバックを含む）は実機ユーザーだけが手動で実行します。エージェントやサブエージェントは実行しません。
- エージェントが実行できるのは `dry-activate` までです。dry モードでも activation logic を実行するため、サブエージェントには委任しません。
- Darwin の activation / `darwin-rebuild switch` も実機ユーザー専用です。
- `dry-activate` は Home Manager / Plugin の実適用を検証しません。ユーザーの `test` 後に Home Manager の成功も確認します。
- Desktop の `see2et` には宣言的なパスワードがありません。GDM 再起動でログイン不能にならないよう、適用前にローカルパスワードが設定済みであることをユーザーに確認します。秘密情報や `hashedPasswordFile` の保存先を勝手に作りません。

## 配置とホスト隔離

`hosts/*/default.nix` は imports とホストの identity を結ぶ場所です。設定は `modules/nixos/*`、`modules/darwin/*`、`home/*` の適切なモジュールへ置き、ルートにモノリスを再導入しません。

- `home/common/` は3ターゲット共通で platform-agnostic に保ちます。Linux 共通は `home/linux/`、Desktop / WSL / Darwin 固有は各 `home/<host>/` へ置きます。
- Desktop は `nixos-wsl`、`modules/nixos/wsl`、`home/wsl` を import しません。
- WSL は `modules/nixos/desktop`、`home/desktop`、`hardware-configuration.nix` を import しません。
- `hardware-configuration.nix` は `hosts/desktop` だけが import し、共通モジュールへ移しません。
- `/mnt/c` の PATH 設定は `home/wsl/session.nix` に限定し、`home/common/` や `modules/nixos/common/` に入れません。
- Darwin は `modules/nixos/*`、`home/linux`、`home/desktop`、`home/wsl` を import しません。

## 変更時の検証

Git flake は未追跡ファイルを評価対象に含めません。新しいモジュールは `git add path/to/module.nix` で追跡してから評価します。

```bash
nix flake check --show-trace
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
nix build .#nixosConfigurations.wsl.config.system.build.toplevel
# aarch64-darwin 実機で実行
nix build .#darwinConfigurations.darwin.system
```

変更した option の `nix eval` と対象ホストのビルドで確認し、適用は上記の安全境界に従います。

### VR / Desktop の実機 QA

Steam、SteamVR、ALVR、OyasumiVR、WayVR に触る前に [home/desktop/vr/AGENTS.md](home/desktop/vr/AGENTS.md) を必ず読みます。VR 変更はビルドとユーザーの適用に加え、実機 HMD QA を通すまで受け入れません。

Desktop の theme / token / wallpaper 変更では、次を確認します。

- DMS bar、launcher、通知、lock / power UI のフォント・スケール、余白・角丸が一貫していること。
- 通常・urgent 状態の文字とアイコンが、現在の壁紙や背景上で読めること。
- launcher、power menu、lock、OSD が遅延や目立つ stutter なく表示されること。
- GTK と Qt のアプリを少なくとも1つずつ開き、icon / cursor / theme の整合を確認すること。
- 同じ3場面（idle desktop、launcher open、notification + OSD）の変更前後を撮影し、並べて比較してから受け入れること。

## Skills / Plugins / Pi の変更

取得元・更新コマンド・失敗条件は [README.md の依存の更新](README.md#依存の更新) を参照してください。

- 配布先 `~/.agents/skills` や Nix Store を直接編集せず、編集用 checkout から push して pin を更新します。
- private GitHub input は `flake = false` の `git+ssh://git@github.com/<owner>/<repo>.git` を使います。取得内容は Store に入るため、秘密鍵・認証情報を含めません。秘密鍵は通常ユーザーの `~/.ssh/id_ed25519_personal` に置き、root のホームへコピーしません。
- revision はルートの `flake.lock` に固定し、`skills/`、`codex-plugins/`、`pi-extensions/` に子の `flake.lock` を作りません。
- Pi 拡張の登録は `pi-extensions/inventory.json` を編集し、生成される `pi-extensions/flake.nix` は直接編集しません。
- 更新中は他の編集を止め、成功後に diff を確認します。Plugins の更新前にはユーザーに Codex セッションの終了を依頼します（適用時に旧キャッシュを整理するため）。
- 無関係な Plugin・設定・認証・セッション・編集用 checkout を保持します。取得やビルドの成功を activation の成功とみなしません。
