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

  oyasumiVersion = "25.6.12-linux-v0.6.1";
  oyasumiSrc = pkgs.fetchurl {
    url = "https://github.com/sofoxe1/OyasumiVR/releases/download/oyasumivr-v${oyasumiVersion}/oyasumi-linux.tar.zst";
    hash = "sha256-oF8+JIaDNrrn2Y9s57W6cD459xB7FRur+NBkVAIIEHI=";
  };

  oyasumiRuntimeLibs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    dbus
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libayatana-appindicator
    libxkbcommon
    libsoup_3
    nspr
    nss
    openssl
    pango
    webkitgtk_4_1
  ];

  oyasumiRuntimeLibraryPath = pkgs.lib.makeLibraryPath oyasumiRuntimeLibs;
  oyasumiRuntimeBinPath = pkgs.lib.makeBinPath [
    pkgs.desktop-file-utils
    pkgs.xdg-utils
  ];
  oyasumiGSettingsPath = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";

  oyasumiBin = pkgs.stdenvNoCC.mkDerivation {
    pname = "oyasumivr-bin";
    version = oyasumiVersion;
    src = oyasumiSrc;

    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.patchelf
      pkgs.zstd
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/oyasumi"
      tar --use-compress-program=unzstd -xvf "$src" -C "$out/share/oyasumi"

      if [ -f "$out/share/oyasumi/Oyasumi/OyasumiVR" ]; then
        chmod +x "$out/share/oyasumi/Oyasumi/OyasumiVR"
        patchelf --set-rpath "${oyasumiRuntimeLibraryPath}" "$out/share/oyasumi/Oyasumi/OyasumiVR"
      fi

      if [ -f "$out/share/oyasumi/Oyasumi/resources/sidecars/oyasumivr-overlay-sidecar" ]; then
        chmod +x "$out/share/oyasumi/Oyasumi/resources/sidecars/oyasumivr-overlay-sidecar"
        patchelf --set-rpath "${oyasumiRuntimeLibraryPath}:\$ORIGIN:\$ORIGIN/cef" "$out/share/oyasumi/Oyasumi/resources/sidecars/oyasumivr-overlay-sidecar"
      fi

      if [ -f "$out/share/oyasumi/Oyasumi/resources/sidecars/cef/libcef.so" ]; then
        patchelf --set-rpath "${oyasumiRuntimeLibraryPath}:\$ORIGIN" "$out/share/oyasumi/Oyasumi/resources/sidecars/cef/libcef.so"
      fi

      runHook postInstall
    '';
  };

  oyasumiLaunch = pkgs.writeShellScriptBin "oyasumivr" ''
    set -euo pipefail

    export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
    export __NV_DISABLE_EXPLICIT_SYNC="''${__NV_DISABLE_EXPLICIT_SYNC:-1}"
    export PATH="${oyasumiRuntimeBinPath}:''${PATH}"
    export LD_LIBRARY_PATH="${oyasumiRuntimeLibraryPath}:''${LD_LIBRARY_PATH:-}"
    export GIO_MODULE_DIR="${pkgs.glib-networking}/lib/gio/modules"
    export GSETTINGS_SCHEMA_DIR="${oyasumiGSettingsPath}"

    steamvr_openxr_manifest="$HOME/.local/share/Steam/steamapps/common/SteamVR/steamxr_linux64.json"
    openxr_config_dir="$XDG_CONFIG_HOME/openxr/1"
    openxr_active_runtime="$openxr_config_dir/active_runtime.json"

    if [ -z "''${XR_RUNTIME_JSON:-}" ] && [ -f "$steamvr_openxr_manifest" ]; then
      export XR_RUNTIME_JSON="$steamvr_openxr_manifest"
    fi

    if [ -z "''${OPENXR_RUNTIME_JSON:-}" ] && [ -n "''${XR_RUNTIME_JSON:-}" ]; then
      export OPENXR_RUNTIME_JSON="$XR_RUNTIME_JSON"
    fi

    if [ -n "''${XR_RUNTIME_JSON:-}" ] && [ ! -f "$openxr_active_runtime" ]; then
      mkdir -p "$openxr_config_dir"
      cat > "$openxr_active_runtime" <<EOF
{
  "file_format_version": "1.0.0",
  "runtime": {
    "name": "SteamVR",
    "library_path": "$XR_RUNTIME_JSON"
  }
}
EOF
    fi

    exec ${pkgs.steam-run}/bin/steam-run \
      "${oyasumiBin}/share/oyasumi/Oyasumi/OyasumiVR" "$@"
  '';

  rofiLauncher = pkgs.writeShellScriptBin "rofi-launcher" ''
    exec ${pkgs.rofi}/bin/rofi \
      -show drun \
      -modi "drun,run,window"
  '';

  typstPreviewCompat = pkgs.writeShellScriptBin "typst-preview" ''
    exec ${pkgs.tinymist}/bin/tinymist preview "$@"
  '';

  desktopSessionAction = pkgs.writeShellScriptBin "desktop-session-action" ''
    action="''${1:-}"

    case "$action" in
      lock)
        exec desktop-lock
        ;;
      logout)
        exec ${pkgs.niri}/bin/niri msg action quit
        ;;
      suspend)
        exec systemctl suspend
        ;;
      reboot)
        exec systemctl reboot
        ;;
      shutdown)
        exec systemctl poweroff
        ;;
      *)
        exit 1
        ;;
    esac
  '';

  desktopPowerMenu = pkgs.writeShellScriptBin "desktop-power-menu" ''
    choice="$(
      printf '%s\n' "L Lock" "E Logout" "U Suspend" "R Reboot" "S Shutdown" \
        | ${pkgs.rofi}/bin/rofi -dmenu -no-custom -i -p "Session"
    )"
    rofiStatus=$?
    [ "$rofiStatus" -eq 0 ] || exit 0
    [ -n "$choice" ] || exit 0

    actionKey="''${choice%% *}"

    case "$actionKey" in
      L)
        exec ${desktopSessionAction}/bin/desktop-session-action lock
        ;;
      E)
        exec ${desktopSessionAction}/bin/desktop-session-action logout
        ;;
      U)
        exec ${desktopSessionAction}/bin/desktop-session-action suspend
        ;;
      R)
        exec ${desktopSessionAction}/bin/desktop-session-action reboot
        ;;
      S)
        exec ${desktopSessionAction}/bin/desktop-session-action shutdown
        ;;
      *)
        exit 0
        ;;
    esac
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

  emojiPicker = pkgs.writeShellScriptBin "emoji-picker" ''
    sleep 0.12
    exec ${pkgs.rofimoji}/bin/rofimoji \
      --selector rofi \
      --clipboarder wl-copy \
      --action copy \
      --prompt "Emoji"
  '';

  screenshotInstant = pkgs.writeShellScriptBin "screenshot-instant" ''
    screenshotsDir="${config.xdg.userDirs.pictures}/Screenshots"
    mkdir -p "$screenshotsDir"

    timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
    target="$screenshotsDir/screenshot-$timestamp-full.png"

    ${pkgs.grim}/bin/grim "$target" || exit 0
    ${pkgs.wl-clipboard}/bin/wl-copy < "$target" || exit 0
    ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "Copied to clipboard: $target"
  '';

  screenshotPicker = pkgs.writeShellScriptBin "screenshot-picker" ''
    screenshotsDir="${config.xdg.userDirs.pictures}/Screenshots"
    mkdir -p "$screenshotsDir"
    timestamp="$(date +%Y-%m-%d_%H-%M-%S)"

    frozenFrame="$(${pkgs.coreutils}/bin/mktemp /tmp/screenshot-frozen-XXXXXX.png)"
    trap 'rm -f "$frozenFrame"' EXIT

    ${pkgs.grim}/bin/grim "$frozenFrame" || exit 0

    focused_geometry() {
      focusedWindowJson="$(${pkgs.niri}/bin/niri msg --json focused-window 2>/dev/null || true)"
      [ -n "$focusedWindowJson" ] || return 1
      [ "$focusedWindowJson" != "null" ] || return 1

      printf '%s' "$focusedWindowJson" | ${pkgs.jq}/bin/jq -r '
        (
          .Ok.FocusedWindow
          // .Ok.Window
          // .FocusedWindow
          // .Window
          // .
        ) as $window
        | $window.layout as $layout
        | ($layout.window_size // empty) as $size
        | if ($size | length) == 2 then
            ($layout.window_offset_in_tile // [0.0, 0.0]) as $offset
            | ($layout.tile_pos_in_workspace_view // null) as $tile
            | if $tile != null then
                ($tile[0] + $offset[0]) as $x
                | ($tile[1] + $offset[1]) as $y
              else
                $offset[0] as $x
                | $offset[1] as $y
              end
            | ($x | floor) as $xf
            | ($y | floor) as $yf
            | ($size[0] | floor) as $width
            | ($size[1] | floor) as $height
            | if $width > 0 and $height > 0 then
                ($xf | tostring) + "," + ($yf | tostring) + " " + ($width | tostring) + "x" + ($height | tostring)
              else empty end
          else empty end
      ' 2>/dev/null
    }

    layout_origin() {
      outputsJson="$(${pkgs.niri}/bin/niri msg -j outputs 2>/dev/null || true)"
      [ -n "$outputsJson" ] || {
        printf '0 0\n'
        return 0
      }

      printf '%s' "$outputsJson" | ${pkgs.jq}/bin/jq -r '
        def outputs:
          if type == "array" then .
          elif .Ok.Outputs? then .Ok.Outputs
          elif .Outputs? then .Outputs
          else [] end;

        def ox:
          .logical.x
          // .logical.position[0]
          // .position.x
          // .position[0]
          // .x
          // 0;

        def oy:
          .logical.y
          // .logical.position[1]
          // .position.y
          // .position[1]
          // .y
          // 0;

        [ outputs[]? | [ ((ox // 0) | tonumber? // 0), ((oy // 0) | tonumber? // 0) ] ] as $coords
        | if ($coords | length) == 0 then
            "0 0"
          else
            (([$coords[] | .[0]] | min | floor | tostring) + " " + ([$coords[] | .[1]] | min | floor | tostring))
          end
      ' 2>/dev/null || printf '0 0\n'
    }

    crop_frozen_geometry() {
      geometry="$1"
      destination="$2"
      [ -n "$geometry" ] || return 1
      [ -n "$destination" ] || return 1

      position="''${geometry%% *}"
      size="''${geometry#* }"
      [ "$position" != "$geometry" ] || return 1

      x="''${position%%,*}"
      y="''${position##*,}"
      width="''${size%%x*}"
      height="''${size##*x}"

      [[ "$x" =~ ^-?[0-9]+$ ]] || return 1
      [[ "$y" =~ ^-?[0-9]+$ ]] || return 1
      [[ "$width" =~ ^[0-9]+$ ]] || return 1
      [[ "$height" =~ ^[0-9]+$ ]] || return 1

      [ "$width" -gt 0 ] || return 1
      [ "$height" -gt 0 ] || return 1

      adjustedX=$((x - layoutOriginX))
      adjustedY=$((y - layoutOriginY))

      [ "$adjustedX" -ge 0 ] || return 1
      [ "$adjustedY" -ge 0 ] || return 1

      ${pkgs.imagemagick}/bin/magick "$frozenFrame" -crop "''${width}x''${height}+''${adjustedX}+''${adjustedY}" +repage "$destination"
    }

    origin="$(layout_origin)"
    layoutOriginX="''${origin%% *}"
    layoutOriginY="''${origin##* }"
    [[ "$layoutOriginX" =~ ^-?[0-9]+$ ]] || layoutOriginX=0
    [[ "$layoutOriginY" =~ ^-?[0-9]+$ ]] || layoutOriginY=0

    sleep 0.12

    mode="$(printf '%s\n' "Area (trim)" "Full screen" "Focused window" | ${pkgs.rofi}/bin/rofi -dmenu -no-custom -i -p "Screenshot")"
    rofiStatus=$?
    [ "$rofiStatus" -eq 0 ] || exit 0
    [ -n "$mode" ] || exit 0

    case "$mode" in
      "Full screen")
        target="$screenshotsDir/screenshot-$timestamp-full.png"
        ${pkgs.coreutils}/bin/cp "$frozenFrame" "$target" || exit 0
        ;;
      "Area (trim)")
        geometry="$(${pkgs.slurp}/bin/slurp)"
        [ -n "$geometry" ] || exit 0
        target="$screenshotsDir/screenshot-$timestamp-area.png"
        crop_frozen_geometry "$geometry" "$target" || exit 0
        ;;
      "Focused window")
        geometry="$(focused_geometry || true)"
        if [ -n "$geometry" ]; then
          target="$screenshotsDir/screenshot-$timestamp-window.png"
          crop_frozen_geometry "$geometry" "$target" || exit 0
        else
          ${pkgs.niri}/bin/niri msg action screenshot-window || exit 0
          ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "Focused window captured (live fallback)"
          exit 0
        fi
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

  xdg.desktopEntries.oyasumivr = {
    name = "OyasumiVR";
    genericName = "VR Sleep Utilities";
    comment = "Launch OyasumiVR via steam-run";
    exec = "oyasumivr";
    terminal = false;
    categories = [ "Utility" ];
  };

  home.packages = with pkgs; [
    alacritty
    alacrittyCwd
    kitty
    wezterm
    typst
    tinymist
    websocat
    typstPreviewCompat
    rofi
    rofimoji
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
    figma-linux
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
    oyasumiLaunch
    rofiLauncher
    desktopSessionAction
    desktopPowerMenu
    cliphistPicker
    emojiPicker
    screenshotInstant
    screenshotPicker
    desktopVolume
    desktopBrightness
  ];
}
