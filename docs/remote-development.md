# 自宅NixOSを開発ホストとして使う

## 構成と境界

- 自宅: niri + Alacrittyの別WindowからHerdr Terminalへdirect attach。
- Mac: `mosh home` → `herdr`。自宅と同じUnixユーザー `see2et` のデフォルトsessionを使う。
- Web: Tailscale Serveによるtailnet限定HTTPS。dev serverのupstreamはloopbackのみ。
- GUI: Moonlight → Tailscale → Sunshine → ログイン済みの同じniriセッション。
- WSLは変更せずZellijを維持。desktop/Macは宣言上Zellijを外すが、既存のsessionデータを削除しない。

Herdrのプロセス継続はdetach中の保証であり、ホスト再起動・server停止・更新に伴うserver再起動ではない。
serverの自動再起動や、更新時の強制停止は行わない。`herdr server stop` は全paneを終了させるため、通常の切替には使わない。
Herdrは公式flakeのv0.9.0を固定している。更新はflake inputで行い、`herdr update`は使わない。

## 初回反映

### 1. 非破壊検証

```bash
nix flake check --show-trace
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
```

### 2. NixOSの反映は実機ユーザーが実行

```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos#desktop
sudo nixos-rebuild test --flake /etc/nixos#desktop
sudo nixos-rebuild switch --flake /etc/nixos#desktop
```

`test`と`switch`はエージェントに実行させない。ログイン用パスワードが使えることを先に確認する。
ユーザーlingerを有効にし、自動suspend/hibernateを禁止する。DMSのロックは維持し、ロック後の自動画面消灯だけを無効化する。
物理モニターを接続し、必要な映像出力を維持する。自動ログイン・自動unlock・KMSのCAP_SYS_ADMIN付与は行わない。

### 3. Tailscaleと認証（管理者による初期設定）

1. 自宅とMacを同じtailnetに登録する。MagicDNSを有効にする。
2. TailnetのHTTPS証明書を有効にする。ホスト名とtailnet DNS名は証明書透明性ログに記録されるが、Preview自体は公開されない。
3. `docs/tailnet-remote-dev.json`を既存policyと照合する。このファイルは現在の自宅/MacのTailscaleアドレスを使った最小policy例で、他用途のpolicyを丸ごと置換するものではない。
4. 既存のallow-allや広いgrantが残っているとMac限定にならない。重複許可を整理し、同ファイルのpolicy testsを管理画面で実行する。端末再登録でIPが変わったら更新する。
5. 認証情報やAPI keyをNixファイル、Git、Nix storeへ保存しない。

Tailscale Serveはtailscaled内のlistenerなので、NixOSのinterface firewallだけでMac限定になったとは判断しない。
実際のtailnet policy適用と拒否テストが必須。Sunshineの自動firewall開放も使用しない。
自宅nodeのkey有効期限を管理画面で確認する。無期限化は紛失時の失効管理とのトレードオフなので自動変更しない。

### 4. Mac

Macの既存Darwin反映手順でbuild/switchする。Mosh、Moonlight、SSH alias `home`が配布される。
`home`は `nixos.taile209b8.ts.net`、ユーザーは `see2et`、鍵は `~/.ssh/id_ed25519`。
別の鍵を使う場合は`home/darwin/remote-dev.nix`を変更する。

Macの公開鍵を自宅の`~/.ssh/authorized_keys`へ安全に登録し、Macから鍵認証を確認する。

```bash
ssh -o BatchMode=yes -o PasswordAuthentication=no home true
mosh home
```

SSHはMoshの初回認証にも必要。公開鍵を確認できるまでは現在のパスワード認証を維持する。
確認後、`modules/nixos/desktop/remote-dev.nix`の`services.openssh.settings`へ
`PasswordAuthentication = false;`と`KbdInteractiveAuthentication = false;`を追加し、同じ安全な順序で反映する。
この手順はローカルのPAMパスワードやDMSロック認証を無効化するものではない。

## Terminalの日常操作

最初のprojectを登録する（PATHは実在する自宅側ディレクトリ）:

```bash
herdr-home project ~/Projects/my-project --label my-project
```

| 操作 | 導線 |
|---|---|
| 新しいTerminal Window | `Mod+Return` |
| Window移動 | 既存のniri `Mod+h/j/k/l` |
| 既存Terminalを開く | launcherの「Herdr: Restore Terminal」 |
| projectの全Terminalを開く | `herdr-home restore --workspace w1 --all` |
| Terminal一覧 | `herdr-home list` |
| MacのTUIへ引き継ぐ | 自宅またはMosh先で`herdr-home handoff`、続けて`herdr` |

`w1`は例。実際のIDは一覧から取得する。`restore`は新しいTabを作成せず、既存のmanaged Windowがあればfocusする。
`Mod+Return`はフォーカス元のmanaged Terminalのprojectと現在のforeground CWDを引き継ぐ。
別アプリから起動した場合はAlacritty内でprojectをfuzzy選択する。最初のproject登録は先に済ませる。
`herdr-home new --workspace ID --cwd PATH --label NAME`で明示指定もできる。

Windowを閉じると表示clientのみを終了する。`exit`、Herdrのclose pane/tab、server stopはプロセスを終了する操作なので区別する。
handoffは今回のhelperで作った表示clientだけにUnix socketで終了を依頼し、PID検索や`pkill`は行わない。
別sessionや手動の`herdr terminal attach`は対象外。通常運用はデフォルトsessionに統一する。
local/remoteで`HERDR_CONFIG_PATH`や`HERDR_SOCKET_PATH`を異なる値に設定しない。
Sunshine/Moonlightでは既存Windowをそのまま操作するのでhandoffは不要。

Herdr全体UIは`Ctrl+b`を押して離してから操作するone-shot prefix。通常キーはpaneへ送る。

| prefix後 | 動作 |
|---|---|
| `h/j/k/l` | Pane移動 |
| `H/L` | 前/次Tab |
| `w` | fzfによるWorkspace選択 |
| `N` | Workspace作成 |
| `c` | Tab作成 |
| `v` / `-` | 左右/上下分割 |
| `x` / `X` | Pane/Tabを終了 |
| `q` | detach |
| `[` | scrollback/copy mode |
| `?` | ヘルプ |

literal `Ctrl+b`は`Ctrl+b Ctrl+b`。Mosh固有の`Ctrl+^`予約は別に残る。
Moshは画像転送や高度なkeyboard protocolを通常のローカルTerminal同様には扱わないため、Yaziの画像preview等は保証しない。
設定変更後は`herdr config check`、`herdr server reload-config`。session snapshot/historyはHome Managerで上書きしない。

## Web Preview

管理は同じ自宅ユーザーで統一する。初期権限は管理者が選ぶ。

- ユーザーで運用する場合: 管理者が一度 `sudo tailscale set --operator=see2et` を実行する。これはServe専用ではなくTailscale操作権限を与えるので、その範囲を理解して設定する。
- operatorを与えない場合: `sudo home-preview ...`で統一する。rootのregistryと通常ユーザーのregistryを混在させない。

```bash
# projectのHerdr Terminalで、dev serverを127.0.0.1:5173で起動しておく
home-preview add my-project 5173
home-preview list
home-preview url my-project
home-preview remove my-project
home-preview apply
```

HTTPSポートは8443..8499から自動割当。`add NAME UPSTREAM_PORT HTTPS_PORT`で明示指定できる。
Macのブラウザで表示された`https://nixos.taile209b8.ts.net:8443/`等を開く。
URLにHTTPSポートを含める。Moshによるport forwardingは不要。

registryは`${XDG_STATE_HOME:-$HOME/.local/state}/home-preview/registry.json`、directoryは0700、fileは0600。
Serveの登録は`--bg`で残る。`apply`は登録済みで消失したproxyだけを復元し、他のServe設定やFunnelを上書きしない。
デバイス再起動後にServe設定が戻っても、dev serverのプロセスは別途起動が必要。

アプリ固有のHost/origin制約は対象hostnameを明示許可する。ViteなどのHMRは必要に応じて外向きの`wss`/hostname/clientPortを指定する。
アプリのリポジトリはこの設定から勝手に変更しない。HTTP表示だけでなく更新反映とWebSocket再接続を確認する。
同一hostnameの別ポートはCookieを分離しない。認証Cookieが衝突するアプリは個別設計が必要。
内部のdev serverを`0.0.0.0`で広く公開したり、Funnelで公開したりしない。

## Sunshine / Moonlight

反映後、ログイン済みniriで`systemctl --user status sunshine`を確認する。
自宅のブラウザで`https://localhost:47990`を開き、管理用資格情報を設定する。
MacのMoonlightに`nixos.taile209b8.ts.net`をAdd PCし、PINを自宅の管理UIへ入力してpairingする。
管理UIが必要なときだけ、Macから`ssh -N -L 47990:127.0.0.1:47990 home`でloopbackへ転送してもよい。
47990をtailnetへ開放しない。通常の映像・入力通信はTailscale経由で直接行う。

- Moonlightの開始設定: Desktop、1080p、60fps、SDR、H.264。
- captureは`wlr`、encoderは`nvenc`。KMS権限を自動追加しない。
- `tailscale ping homeの実ホスト名`でdirect/relayを確認する。relay時は画質・遅延が悪化し得る。
- 自宅の物理画面にも同じ内容が表示され得る。プライベートな独立デスクトップではない。
- 画面ロックを維持し、ロック状態からの表示・通常認証・入力を実機確認する。自動unlockはしない。
- 再起動直後のGDM操作、完全headless、物理モニター電源断からの復旧は保証しない。

黒画面の場合は`journalctl --user -u sunshine -b`を確認する。wlr/NVIDIAで成立しなければそこで止め、KMS権限や別capture方式の承認を求める。

## 受入チェック

- [ ] 自宅Windowを閉じてもAgent/dev serverが生存し、restoreで同じTerminalへ戻れる。
- [ ] niriの新規Windowがフォーカス元のproject/CWDを継承する。
- [ ] handoff後にMacのTerminalサイズへ追従し、fuzzy選択・Tab移動が使える。
- [ ] MacのWi-Fi切断/sleepを挟んでもプロセスが生存し、Moshへ復帰できる。
- [ ] MacのブラウザでHTTPS Preview、HMR、WebSocket再接続が動く。
- [ ] Preview削除後にアクセス不能になり、他のServe設定は保持される。
- [ ] Moonlightの画面・音声・マウス・日本語入力・niriキー・切断復帰が動く。
- [ ] ロック後の接続・通常認証が可能で、認証を迂回できない。
- [ ] tailnet policy testsが成功し、許可していない端末からSSH/Preview/streamに接続できない。

ローカルの自動チェックは `nix build .#checks.x86_64-linux.remote-development`。
このチェックのPreview部分はfake Tailscaleであり、MacからのTLS/HMR実測を代替しない。

QAではHOME、全XDGディレクトリ、TMPDIR、ZDOTDIR、Herdr socket/configを隔離し、
`terminal.default_shell`もテスト用shellに固定する。通常のzsh設定をQA環境から読み込まない。
Antidoteの生成bundleは実際のplugin cache配下へ保存する。
Home Manager既定の共有`/tmp/tmp_hm_zsh_plugins...`は、別環境の絶対パスを混入させるため使わない。

問題時は直前のNixOS generationへ手動rollbackするか、導入module/importと起動キーを戻してbuildする。
Herdr/Zellijの保存データを削除する必要はない。SunshineやPreviewの撤去とTerminal server停止は別々に判断する。
