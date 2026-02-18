{
  pkgs,
  inputs,
  config,
  ...
}:
let
  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  rofiLauncher = pkgs.writeShellScriptBin "rofi-launcher" ''
    exec ${pkgs.rofi}/bin/rofi -show drun
  '';

  alacrittyCwd = pkgs.writeShellScriptBin "alacritty-cwd" ''
    focusedWindowJson="$(${pkgs.niri}/bin/niri msg --json focused-window 2>/dev/null || true)"
    focusedAppId="$(printf '%s' "$focusedWindowJson" | ${pkgs.jq}/bin/jq -r '
      .Ok.FocusedWindow.app_id
      // .Ok.Window.app_id
      // .FocusedWindow.app_id
      // .Window.app_id
      // .app_id
      // .["app-id"]
      // empty
    ' 2>/dev/null || true)"
    focusedPid="$(printf '%s' "$focusedWindowJson" | ${pkgs.jq}/bin/jq -r '
      .Ok.FocusedWindow.pid
      // .Ok.Window.pid
      // .FocusedWindow.pid
      // .Window.pid
      // .pid
      // empty
    ' 2>/dev/null || true)"

    if ! [[ "$focusedPid" =~ ^[0-9]+$ ]]; then
      windowsJson="$(${pkgs.niri}/bin/niri msg -j windows 2>/dev/null || true)"
      focusedAppId="$(printf '%s' "$windowsJson" | ${pkgs.jq}/bin/jq -r '
        first(
          (if type == "array" then .[] else .Ok.Windows[]? end)
          | select((.is_focused // .["is-focused"] // false) == true)
        )
        | (.app_id // .["app-id"] // empty)
      ' 2>/dev/null || true)"
      focusedPid="$(printf '%s' "$windowsJson" | ${pkgs.jq}/bin/jq -r '
        first(
          (if type == "array" then .[] else .Ok.Windows[]? end)
          | select((.is_focused // .["is-focused"] // false) == true)
        )
        | (.pid // empty)
      ' 2>/dev/null || true)"
    fi

    focusedAppIdLower="$(printf '%s' "$focusedAppId" | ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]')"

    if [ "$focusedAppIdLower" = "alacritty" ] && [[ "$focusedPid" =~ ^[0-9]+$ ]]; then
      shellPid=""
      if [ -r "/proc/$focusedPid/task/$focusedPid/children" ]; then
        IFS=' ' read -r shellPid _ < "/proc/$focusedPid/task/$focusedPid/children"
      fi

      for candidatePid in "$shellPid" "$focusedPid"; do
        if [[ "$candidatePid" =~ ^[0-9]+$ ]]; then
          focusedCwd="$(${pkgs.coreutils}/bin/readlink -f "/proc/$candidatePid/cwd" 2>/dev/null || true)"
          if [ -n "$focusedCwd" ] && [ -d "$focusedCwd" ]; then
            exec ${pkgs.alacritty}/bin/alacritty --working-directory "$focusedCwd"
          fi
        fi
      done
    fi

    exec ${pkgs.alacritty}/bin/alacritty --working-directory "$HOME"
  '';

  cliphistPicker = pkgs.writeShellScriptBin "cliphist-picker" ''
    sleep 0.12
    selection="$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -no-custom -i -p "Clipboard")"
    rofiStatus=$?
    [ "$rofiStatus" -eq 0 ] || exit 0
    [ -n "$selection" ] || exit 0
    itemId="''${selection%%$'\t'*}"
    [[ "$itemId" =~ ^[0-9]+$ ]] || exit 0
    ${pkgs.cliphist}/bin/cliphist decode <<<"$selection" | ${pkgs.wl-clipboard}/bin/wl-copy || exit 0
  '';

  screenshotPicker = pkgs.writeShellScriptBin "screenshot-picker" ''
    sleep 0.12

    mode="$(printf '%s\n' "Area (trim)" "Full screen" "Focused window" | ${pkgs.rofi}/bin/rofi -dmenu -no-custom -i -p "Screenshot")"
    rofiStatus=$?
    [ "$rofiStatus" -eq 0 ] || exit 0
    [ -n "$mode" ] || exit 0

    screenshotsDir="${config.xdg.userDirs.pictures}/Screenshots"
    mkdir -p "$screenshotsDir"
    timestamp="$(date +%Y-%m-%d_%H-%M-%S)"

    case "$mode" in
      "Full screen")
        target="$screenshotsDir/screenshot-$timestamp-full.png"
        ${pkgs.grim}/bin/grim "$target" || exit 0
        ;;
      "Area (trim)")
        geometry="$(${pkgs.slurp}/bin/slurp)"
        [ -n "$geometry" ] || exit 0
        target="$screenshotsDir/screenshot-$timestamp-area.png"
        ${pkgs.grim}/bin/grim -g "$geometry" "$target" || exit 0
        ;;
      "Focused window")
        ${pkgs.niri}/bin/niri msg action screenshot-window || exit 0
        ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "Focused window captured"
        exit 0
        ;;
      *)
        exit 0
        ;;
    esac

    ${pkgs.wl-clipboard}/bin/wl-copy < "$target" || exit 0
    ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "Copied to clipboard: $target"
  '';

  desktopVolume = pkgs.writeShellScriptBin "desktop-volume" ''
    action="''${1:-up}"

    case "$action" in
      up)
        ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
        ;;
      down)
        ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ;;
      mute)
        ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
      *)
        exit 1
        ;;
    esac

    volumeLine="$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
    [ -n "$volumeLine" ] || exit 0

    set -- $volumeLine
    volumeFloat="''${2:-0.0}"

    muted=false
    case "$volumeLine" in
      *"[MUTED]"*) muted=true ;;
    esac

    intPart="''${volumeFloat%%.*}"
    fracPart="''${volumeFloat#*.}"
    if [ "$fracPart" = "$volumeFloat" ]; then
      fracPart="0"
    fi

    fracPart="''${fracPart}00"
    fracPart="''${fracPart%''${fracPart#??}}"
    percent=$((10#$intPart * 100 + 10#$fracPart))

    if [ "$percent" -lt 0 ]; then
      percent=0
    fi

    if [ "$percent" -gt 150 ]; then
      percent=150
    fi

    if [ "$muted" = true ] || [ "$percent" -eq 0 ]; then
      icon="audio-volume-muted-symbolic"
      label="Muted"
    elif [ "$percent" -lt 35 ]; then
      icon="audio-volume-low-symbolic"
      label="$percent%"
    elif [ "$percent" -lt 70 ]; then
      icon="audio-volume-medium-symbolic"
      label="$percent%"
    else
      icon="audio-volume-high-symbolic"
      label="$percent%"
    fi

    ${pkgs.libnotify}/bin/notify-send \
      -a "desktop-osd" \
      -u low \
      -t 1200 \
      -h string:x-canonical-private-synchronous:desktop-volume \
      -h int:value:"$percent" \
      -i "$icon" \
      "Volume" "$label"
  '';

  desktopBrightness = pkgs.writeShellScriptBin "desktop-brightness" ''
    action="''${1:-up}"

    case "$action" in
      up)
        ${pkgs.brightnessctl}/bin/brightnessctl -q set +5%
        ;;
      down)
        ${pkgs.brightnessctl}/bin/brightnessctl -q set 5%-
        ;;
      *)
        exit 1
        ;;
    esac

    brightnessLine="$(${pkgs.brightnessctl}/bin/brightnessctl -m 2>/dev/null || true)"
    [ -n "$brightnessLine" ] || exit 0

    IFS=',' read -r _ _ _ _ brightnessRaw <<EOF
$brightnessLine
EOF

    percent="''${brightnessRaw%%%}"
    case "$percent" in
      ""|*[!0-9]*) exit 0 ;;
    esac

    if [ "$percent" -lt 25 ]; then
      icon="display-brightness-low-symbolic"
    elif [ "$percent" -lt 65 ]; then
      icon="display-brightness-medium-symbolic"
    else
      icon="display-brightness-high-symbolic"
    fi

    ${pkgs.libnotify}/bin/notify-send \
      -a "desktop-osd" \
      -u low \
      -t 1200 \
      -h string:x-canonical-private-synchronous:desktop-brightness \
      -h int:value:"$percent" \
      -i "$icon" \
      "Brightness" "$percent%"
  '';
in
{
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  home.packages = with pkgs; [
    alacritty
    alacrittyCwd
    kitty
    wezterm
    rofi
    cliphist
    grim
    slurp
    xwayland-satellite
    wl-clipboard
    waybar
    playerctl
    wlogout
    swaylock
    pavucontrol
    pulseaudio
    brightnessctl
    gcolor3
    pkgsUnstable.godot_4_6
    discord
    discord-canary
    slack
    youtube-music
    yubioath-flutter
    obsidian
    obs-studio
    xfce.thunar
    xfce.thunar-archive-plugin
    xfce.thunar-volman
    alvr
    vrcx
    sidequest
    wlx-overlay-s
    rofiLauncher
    cliphistPicker
    screenshotPicker
    desktopVolume
    desktopBrightness
  ];
}
