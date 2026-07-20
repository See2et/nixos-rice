# VR ownership policy

## 目的

この文書は、Steam, SteamVR, ALVR, OyasumiVR, WayVR 周辺の変更で、どこを Nix が持ち、どこを実行時に任せるかを固定する。対象は desktop の VR 系だけで、laptop ターゲットは存在しない。

## 参照すべき前提

- `programs.steam` の統合、パッケージ導入、immutable wrapper、読み取り専用の診断、子 runtime 環境の注入は Nix の責務。
- Steam, SteamVR の depot, `localconfig.vdf`, active runtime selector は、`steamvr-select-openxr` などの明示コマンドで切り替える user-owned mutable state であり、Nix が一般に所有するものではない。
- WayVR は WlxOverlay-S の後継であり、OVR Advanced Settings の代替ではあるが後継ではない。パッケージ名は `wayvr`。
- WayVR の安定設定は Nix が持つが、`conf.d/zz-saved-config.json5`, `conf.d/zz-saved-state.json5`, `pw_tokens.yaml`, `wayvr.vrmanifest`, `actions.json`, `actions_binding_*.json` は runtime 側の書き込み領域。
- `wayvr --install` を activation で実行してはいけない。

## ALVR と SteamVR の前提

- この節は現時点の検証結果に基づく運用規則であり、将来の SteamVR / ALVR 版に同じ症状や同じ回避策を保証しない。
- `home/desktop/vr/alvr.nix` は `early_hmd_initialization=true` をパッチし、`tests/repo-policy.sh` はその固定を守る。
- SteamVR の更新や branch 変更は `SteamVR/bin/linux64/vrcompositor` の wrapper symlink を上書きするので、変更後は ALVR Dashboard から SteamVR を起動して wrapper を再導入する。
- `vrcompositor` は使用中の ALVR package の `libexec/alvr/vrcompositor-wrapper` への symlink であることを確認し、`vrcompositor.real` は選択中の SteamVR branch の通常 binary であることを確認する。
- Steam updater が `vrcompositor` と stale な `vrcompositor.real` を通常 file として残すと、ALVR の wrapper 再導入は rename 衝突で失敗する。
- wrapper が復元されない場合は SteamVR と ALVR を停止し、branch 変更前の backup と hash を照合してから重複を解消する。通常 file を根拠なく削除または移動してはいけない。
- `previous` は移動する runtime workaround であり、Nix pin ではないので、branch 選択時と更新後の QA で build 番号を確認する。
- SteamVR branch は Steam の公式 UI で選択し、`appmanifest_250820.acf`, `localconfig.vdf`, depot を直接編集して branch を偽装しない。
- 手動で `vrcompositor` を触るのは、SteamVR と ALVR が停止していて、完全な backup があり、hash 照合で active branch の binary を特定できる場合だけにする。
- 今回の系では、起動順は ALVR Dashboard、そこから SteamVR を起動、`vrserver` と `vrcompositor` の起動確認、PICO client 起動、encoder 起動確認で固定する。
- shutdown 系の異常は HMD 初期化の遅延と chaperone 変化を先に疑い、stutter 系の異常は encoder / network / decode の健全さを見てから SteamVR の branch 差を切り分ける。
- live QA は ALVR WebSocket `ws://127.0.0.1:8082/api/events` に `X-ALVR: true` を付けて行い、`GraphStatistics` の `game_time_s`, `server_compositor_s`, `encoder_s`, `network_s`, `decoder_s`, `client_fps`, `server_fps` を見る。
- ALVR 20.14.1 の text logs は `STATS` と `GRAPH` の payload を意図的に省略するので、空の tag を「統計が無い」と解釈しない。
- 現時点の healthy reference は 180s、12,835 samples、desync/disconnect 0、`game_time` p50 11.65ms、p95 16.01ms、`client_fps` と `server_fps` はおおむね 72fps である。

## ALVR quality profile の再現と適用

- `home/desktop/vr/tools/alvr-quality-profile` は、Nix が持つ PICO 4 向け画質 profile を runtime-owned な ALVR session へ明示適用する唯一の導線。
- profile は HEVC、35Mbps、72Hz、view width 1856、foveation center `0.60x0.55`、edge ratio `2.0x2.5`、client-side post-processing 無効を固定する。
- `alvr-quality-profile status` は current session を読み取って profile と比較するだけで、session を変更しない。完全一致なら exit 0、drift があれば non-zero を返す。
- `alvr-quality-profile apply` は drift がある場合だけ、起動中の ALVR server の `/api/dashboard-request` へ `SetValues` を送り、session の read-back が完全一致するまで検証する。既に一致していれば API request を送らず成功し、session file は直接書き換えない。
- `apply` は activation、login hook、desktop entry、timer から自動実行してはいけない。必ずユーザーが明示的に実行する。
- `apply` 後は ALVR Dashboard の **Restart SteamVR** を使う。外部から `RestartSteamvr` API だけを送ると server 側の shutdown half だけが実行され、Dashboard が持つ relaunch worker が動かないため、SteamVR が停止したままになる。
- profile が再現するのは宣言した画質 field の desired state だけ。client trust、IP、接続状態、token、その他の session state は引き続き runtime 所有であり、Nix の再現対象ではない。

## 所有権マトリクス

| 領域 | 所有者 | 変更してよいもの | 触ってはいけないもの |
| --- | --- | --- | --- |
| Nix 管理 | Nix | `programs.steam` 統合, package, immutable wrapper, read-only diagnostics, explicit child runtime env, explicit selector command, stable WayVR config | depot 内容, `localconfig.vdf`, runtime state |
| Steam / SteamVR runtime | runtime | depot, `localconfig.vdf`, active runtime selector, ALVR session, Oyasumi state | activation からの上書き |
| ALVR quality profile | Nix が desired fields、runtime が session | `alvr-quality-profile status`, ユーザーによる明示的な `apply`, ALVR API 経由の field 更新 | session file の直接編集, activation/login/timer からの自動適用, client trust/IP/token の所有 |
| SteamVR 内の ALVR wrapper symlink と SteamVR branch | runtime | `SteamVR/bin/linux64/vrcompositor`, `vrcompositor.real`, ALVR Dashboard からの再導入, `previous` の実体確認 | Nix 管理 wrapper の改変, branch の Nix pin, activation からの再生成 |
| active runtime selector | user-owned mutable state | `steamvr-select-openxr --manifest`, `steamvr-select-openxr --restore` で切り替える現在値 | activation の自動上書き |
| WayVR 安定設定 | Nix | `home/desktop/vr/wayvr.nix` で配る `wayvr/config.yaml`, `wayvr/openxr_actions.json5`, `wayvr-openxr`, `wayvr-openvr` | runtime 生成物, token, 保存済みセッション |
| WayVR 実行時状態 | runtime | `conf.d/zz-saved-config.json5`, `conf.d/zz-saved-state.json5`, `pw_tokens.yaml`, `wayvr.vrmanifest`, `actions.json`, `actions_binding_*.json` | Git 管理下の設定ファイル |

## 禁止パターン

- activation で Steam, SteamVR, ALVR, WayVR の runtime state を書き換える。
- `localconfig.vdf` や depot を Nix で再現可能な資産として扱う。
- SteamVR branch を `appmanifest_250820.acf` や `localconfig.vdf` の直接編集だけで切り替える。
- `alvr-quality-profile apply` を activation、login hook、timer から実行する。
- ALVR session file を profile 適用のために直接編集する。
- 外部 API の `RestartSteamvr` だけで SteamVR restart が完結すると仮定する。
- `wayvr --install` を system activation に入れる。
- explicit user command 以外で active runtime selector を切り替える。
- 安定設定と generated state を同じディレクトリで混ぜる。
- 存在しない laptop ターゲットを前提に文書や設定を増やす。

## 許可するコマンドと流れ

1. 変更前に `nix flake check --show-trace` で評価を通す。
2. `nix build .#nixosConfigurations.desktop.config.system.build.toplevel` でビルドを確認する。
3. 必要なら `nix eval` で option の読み取りだけ行う。
4. 反映はユーザーが `sudo nixos-rebuild dry-activate --flake /etc/nixos#desktop`、次に `test`、最後に `switch` を手動で実行する。
5. VR 固有の Nix 管理コマンドは `steamvr-diagnose`, `steamvr-runtime-env`, `steamvr-select-openxr --manifest`, `steamvr-select-openxr --restore`, `alvr-quality-profile status`, `alvr-quality-profile apply`, `wayvr-openxr`, `wayvr-openvr` に限る。
6. SteamVR branch 選択と ALVR Dashboard からの SteamVR 起動は user-owned runtime 操作であり、前項の Nix 管理コマンドには含めない。
7. active runtime selector の切り替えは、`steamvr-select-openxr` の明示コマンドで行い、事前 backup か absent-state marker と失敗時 restore をセットで扱う。
8. ALVR quality profile は `status`、ALVR Dashboard と SteamVR の起動、`apply`、Dashboard の **Restart SteamVR**、PICO client 再接続、`status`、physical HMD QA の順で適用する。

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
- SteamVR の `buildid` と `BetaKey`、`vrcompositor` symlink の参照先、`vrcompositor.real` の file type と hash
- ALVR `GraphStatistics` の計測時間、sample 数、desync/disconnect 数、`game_time_s` と client/server FPS の分布
- `alvr-quality-profile status` の apply 前後の結果と、Dashboard-owned restart 後の negotiated codec/bitrate
- ALVR Dashboard、SteamVR、PICO client、encoder の起動順と、計測終了時の process 生存確認
- 物理 HMD の実機確認メモ

## update と reproducibility の限界

- 再現できるのは Nix が管理する設定と wrapper だけ。
- depot, selector state, localconfig, token, session は machine-local で揺れる。
- その場の HMD 接続状態や runtime の自動生成物は、ビルド成果物としては再現しない。
- ALVR wrapper binary は Nix が持つが、SteamVR 内の wrapper symlink、SteamVR branch、`previous` の指す build は runtime-local で揺れるので、Nix に固定した体で書かない。
- `alvr-quality-profile` により画質 field の desired state は再現できるが、session 全体は再現しない。`status` で drift を検出し、必要なときだけ明示的に `apply` する。
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
- ALVR issue #3244: https://github.com/alvr-org/ALVR/issues/3244
- ALVR issue #3297: https://github.com/alvr-org/ALVR/issues/3297
- ALVR issue #3326: https://github.com/alvr-org/ALVR/issues/3326
- WayVR repository and docs: https://github.com/wayvr-org/wayvr
- WayVR commit 786660a4d54b73714399c9433a68c8cc35eb55f4: https://github.com/wayvr-org/wayvr/commit/786660a4d54b73714399c9433a68c8cc35eb55f4
