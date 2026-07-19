# VR ownership policy

## 目的

この文書は、Steam, SteamVR, ALVR, OyasumiVR, WayVR 周辺の変更で、どこを Nix が持ち、どこを実行時に任せるかを固定する。対象は desktop の VR 系だけで、laptop ターゲットは存在しない。

## 参照すべき前提

- `programs.steam` の統合、パッケージ導入、immutable wrapper、読み取り専用の診断、子 runtime 環境の注入は Nix の責務。
- Steam, SteamVR の depot, `localconfig.vdf`, active runtime selector は、`steamvr-select-openxr` などの明示コマンドで切り替える user-owned mutable state であり、Nix が一般に所有するものではない。
- WayVR は WlxOverlay-S の後継であり、OVR Advanced Settings の代替ではあるが後継ではない。パッケージ名は `wayvr`。
- WayVR の安定設定は Nix が持つが、`conf.d/zz-saved-config.json5`, `conf.d/zz-saved-state.json5`, `pw_tokens.yaml`, `wayvr.vrmanifest`, `actions.json`, `actions_binding_*.json` は runtime 側の書き込み領域。
- `wayvr --install` を activation で実行してはいけない。

## 所有権マトリクス

| 領域 | 所有者 | 変更してよいもの | 触ってはいけないもの |
| --- | --- | --- | --- |
| Nix 管理 | Nix | `programs.steam` 統合, package, immutable wrapper, read-only diagnostics, explicit child runtime env, explicit selector command, stable WayVR config | depot 内容, `localconfig.vdf`, runtime state |
| Steam / SteamVR runtime | runtime | depot, `localconfig.vdf`, active runtime selector, ALVR session, Oyasumi state | activation からの上書き |
| active runtime selector | user-owned mutable state | `steamvr-select-openxr --manifest`, `steamvr-select-openxr --restore` で切り替える現在値 | activation の自動上書き |
| WayVR 安定設定 | Nix | `home/desktop/vr/wayvr.nix` で配る `wayvr/config.yaml`, `wayvr/openxr_actions.json5`, `wayvr-openxr`, `wayvr-openvr` | runtime 生成物, token, 保存済みセッション |
| WayVR 実行時状態 | runtime | `conf.d/zz-saved-config.json5`, `conf.d/zz-saved-state.json5`, `pw_tokens.yaml`, `wayvr.vrmanifest`, `actions.json`, `actions_binding_*.json` | Git 管理下の設定ファイル |

## 禁止パターン

- activation で Steam, SteamVR, WayVR の runtime state を書き換える。
- `localconfig.vdf` や depot を Nix で再現可能な資産として扱う。
- `wayvr --install` を system activation に入れる。
- explicit user command 以外で active runtime selector を切り替える。
- 安定設定と generated state を同じディレクトリで混ぜる。
- 存在しない laptop ターゲットを前提に文書や設定を増やす。

## 許可するコマンドと流れ

1. 変更前に `nix flake check --show-trace` で評価を通す。
2. `nix build .#nixosConfigurations.desktop.config.system.build.toplevel` でビルドを確認する。
3. 必要なら `nix eval` で option の読み取りだけ行う。
4. 反映はユーザーが `sudo nixos-rebuild dry-activate --flake /etc/nixos#desktop`、次に `test`、最後に `switch` を手動で実行する。
5. VR 固有の許可コマンドは `steamvr-diagnose`, `steamvr-runtime-env`, `steamvr-select-openxr --manifest`, `steamvr-select-openxr --restore`, `wayvr-openxr`, `wayvr-openvr` に限る。
6. active runtime selector の切り替えは、`steamvr-select-openxr` の明示コマンドで行い、事前 backup か absent-state marker と失敗時 restore をセットで扱う。

## WayVR の config と generated state の境界

- Nix が持つもの
  - `home/desktop/vr/wayvr.nix` で配る固定設定
  - `wayvr/config.yaml`
  - `wayvr/openxr_actions.json5`
  - `wayvr-openxr`, `wayvr-openvr`
- runtime が持つもの
  - `conf.d/zz-saved-config.json5`
  - `conf.d/zz-saved-state.json5`
  - `pw_tokens.yaml`
  - `wayvr.vrmanifest`
  - `actions.json`
  - `actions_binding_*.json`
  - 起動後に WayVR が書き足すファイル群

この境界を越えて保存したら、その変更は壊れる前提で扱う。再現対象ではなく、runtime の副産物とみなす。

## runtime selection と rollback

1. 現在の selector 状態を退避する。
2. 明示コマンドで runtime を切り替える。
3. WayVR, SteamVR, ALVR の順に読み取り専用確認をする。
4. 失敗したら退避した状態に restore する。
5. 元に戻せない状態では selector を進めない。

- trusted manifest は OpenXR runtime manifest として最低でも `file_format_version == "1.0.0"` と非空の `runtime.library_path` を持ち、その解決先 shared library が存在するものに限る。
- arch-specific selector が元から無い状態で一時的に `active_runtime.x86_64.json` を作る場合は、backup の代わりに absent-state marker を残し、restore で作成した arch-specific selector だけを消して generic fallback か完全 absent を露出させる。
- stale backup と absent-state marker が同時に残っている状態は不正として扱い、restore/select を進めない。

selector の目的は「今どの runtime を使うか」を明示することだけで、永続 state を Nix 側へ吸い上げることではない。

## debugging evidence checklist

- `nix flake check --show-trace` の結果
- `nix build` の成功可否
- 変更したファイルのパス
- selector command の実行前後で退避した state の差分
- `wayvr/openxr_actions.json5` と generated state の境界が分かる証拠
- SteamVR, ALVR, Oyasumi の読み取り専用ログ
- 物理 HMD の実機確認メモ

## update と reproducibility の限界

- 再現できるのは Nix が管理する設定と wrapper だけ。
- depot, selector state, localconfig, token, session は machine-local で揺れる。
- その場の HMD 接続状態や runtime の自動生成物は、ビルド成果物としては再現しない。
- 仕様変更があれば、この文書を先に直してから実装する。

## validation と activation の gate

- 安全: `nix flake check`, `nix build`, `nix eval`
- 条件付き: agent が行う `dry-activate`
- ユーザーのみ: `test`, `switch`
- 反映後に必要: physical HMD QA

## authoritative URLs

- OpenXR loader spec: https://registry.khronos.org/OpenXR/specs/1.1/html/xrspec.html
- NixOS steam module: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/programs/steam.nix
- Valve steam-runtime: https://github.com/ValveSoftware/steam-runtime
- WayVR repository and docs: https://github.com/wayvr-org/wayvr
- WayVR commit 786660a4d54b73714399c9433a68c8cc35eb55f4: https://github.com/wayvr-org/wayvr/commit/786660a4d54b73714399c9433a68c8cc35eb55f4
