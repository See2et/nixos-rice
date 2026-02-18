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
  ];
}
