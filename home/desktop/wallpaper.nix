{
  pkgs,
  lib,
  config,
  ...
}:
let
  stateDir = "${config.xdg.stateHome}/desktop";
  currentFile = "${stateDir}/wallpaper.current";
  indexFile = "${stateDir}/wallpaper.index";
  wallpaperDirs = [
    "/etc/nixos/assets/wallpapers"
    "${config.xdg.dataHome}/wallpapers"
  ];

  desktopWallpaperApply = pkgs.writeShellScriptBin "desktop-wallpaper-apply" ''
    set -euo pipefail

    mkdir -p "${stateDir}"

    startup=0
    if [ "''${1:-}" = "--startup" ]; then
      startup=1
      shift
    fi

    pick_wayland_display() {
      local runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      local sock

      if [ -n "''${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime/$WAYLAND_DISPLAY" ]; then
        return 0
      fi

      for sock in "$runtime"/wayland-*; do
        if [ -S "$sock" ]; then
          WAYLAND_DISPLAY="$(basename "$sock")"
          export WAYLAND_DISPLAY
          return 0
        fi
      done

      return 1
    }

    ensure_daemon() {
      local attempt

      for attempt in $(seq 1 30); do
        if pick_wayland_display; then
          break
        fi
        sleep 0.2
      done

      if ! pick_wayland_display; then
        printf '%s\n' "desktop-wallpaper-apply: Wayland socket not ready" >&2
        return 1
      fi

      if ! ${pkgs.swww}/bin/swww query >/dev/null 2>&1; then
        ${pkgs.swww}/bin/swww-daemon --no-cache >/dev/null 2>&1 &
      fi

      for attempt in $(seq 1 30); do
        if ${pkgs.swww}/bin/swww query >/dev/null 2>&1; then
          return 0
        fi
        sleep 0.2
      done

      printf '%s\n' "desktop-wallpaper-apply: swww-daemon not ready" >&2
      return 1
    }

    collect_wallpapers() {
      shopt -s nullglob nocaseglob
      local files=()
      for dir in ${lib.concatStringsSep " " wallpaperDirs}; do
        for f in "$dir"/*.{png,jpg,jpeg,webp,avif}; do
          files+=("$f")
        done
      done
      if [ "''${#files[@]}" -eq 0 ]; then
        return 1
      fi
      printf '%s\n' "''${files[@]}"
    }

    target="''${1:-}"
    if [ -z "$target" ] && [ -s "${currentFile}" ]; then
      candidate="$(<"${currentFile}")"
      if [ -f "$candidate" ]; then
        target="$candidate"
      fi
    fi

    if [ -z "$target" ]; then
      target="$(collect_wallpapers | head -n 1 || true)"
    fi

    [ -n "$target" ] || {
      printf '%s\n' "desktop-wallpaper-apply: no wallpaper candidates found" >&2
      exit 1
    }
    [ -f "$target" ] || {
      printf '%s\n' "desktop-wallpaper-apply: wallpaper not found: $target" >&2
      exit 1
    }

    ensure_daemon

    if [ "$startup" -eq 1 ]; then
      ${pkgs.swww}/bin/swww img "$target" --transition-type none
    else
      ${pkgs.swww}/bin/swww img "$target" \
        --transition-type fade \
        --transition-fps 60 \
        --transition-duration 1.0
    fi

    printf '%s\n' "$target" >"${currentFile}"
  '';

  desktopWallpaperCycle = pkgs.writeShellScriptBin "desktop-wallpaper-cycle" ''
    set -euo pipefail

    action="''${1:-next}"
    mkdir -p "${stateDir}"

    shopt -s nullglob nocaseglob
    wallpapers=()
    for dir in ${lib.concatStringsSep " " wallpaperDirs}; do
      for f in "$dir"/*.{png,jpg,jpeg,webp,avif}; do
        wallpapers+=("$f")
      done
    done

    count="''${#wallpapers[@]}"
    [ "$count" -gt 0 ] || exit 0

    idx=-1
    if [ -s "${indexFile}" ]; then
      idxRaw="$(<"${indexFile}")"
      if [[ "$idxRaw" =~ ^[0-9]+$ ]]; then
        idx="$idxRaw"
      fi
    fi

    case "$action" in
      next)
        idx=$(( (idx + 1) % count ))
        ;;
      prev)
        idx=$(( (idx - 1 + count) % count ))
        ;;
      random)
        idx=$(( RANDOM % count ))
        ;;
      *)
        exit 1
        ;;
    esac

    selected="''${wallpapers[$idx]}"
    printf '%s\n' "$idx" >"${indexFile}"

    exec ${desktopWallpaperApply}/bin/desktop-wallpaper-apply "$selected"
  '';

  desktopWallpaperAuto = pkgs.writeShellScriptBin "desktop-wallpaper-auto" ''
    set -euo pipefail

    cmd="''${1:-toggle}"
    timer="desktop-wallpaper-rotate.timer"

    case "$cmd" in
      on)
        systemctl --user start "$timer"
        ${pkgs.libnotify}/bin/notify-send "Wallpaper" "Auto rotation: ON"
        ;;
      off)
        systemctl --user stop "$timer"
        ${pkgs.libnotify}/bin/notify-send "Wallpaper" "Auto rotation: OFF"
        ;;
      toggle)
        if systemctl --user is-active --quiet "$timer"; then
          systemctl --user stop "$timer"
          ${pkgs.libnotify}/bin/notify-send "Wallpaper" "Auto rotation: OFF"
        else
          systemctl --user start "$timer"
          ${pkgs.libnotify}/bin/notify-send "Wallpaper" "Auto rotation: ON"
        fi
        ;;
      status)
        if systemctl --user is-active --quiet "$timer"; then
          printf '%s\n' "on"
        else
          printf '%s\n' "off"
        fi
        ;;
      *)
        exit 1
        ;;
    esac
  '';

  desktopWallpaperMenu = pkgs.writeShellScriptBin "desktop-wallpaper-menu" ''
    set -euo pipefail

    sleep 0.12

    autoState="$(${desktopWallpaperAuto}/bin/desktop-wallpaper-auto status 2>/dev/null || printf 'off')"
    if [ "$autoState" = "on" ]; then
      autoLabel="Auto rotation: ON"
    else
      autoLabel="Auto rotation: OFF"
    fi

    choice="$(${pkgs.rofi}/bin/rofi -dmenu -no-custom -i -p "Wallpaper" <<EOF
N Next wallpaper
P Previous wallpaper
R Random wallpaper
T Toggle auto rotation
O Turn auto rotation off
S Show auto rotation status
EOF
    )"
    rofiStatus=$?
    [ "$rofiStatus" -eq 0 ] || exit 0
    [ -n "$choice" ] || exit 0

    actionKey="''${choice%% *}"

    case "$actionKey" in
      N)
        exec ${desktopWallpaperCycle}/bin/desktop-wallpaper-cycle next
        ;;
      P)
        exec ${desktopWallpaperCycle}/bin/desktop-wallpaper-cycle prev
        ;;
      R)
        exec ${desktopWallpaperCycle}/bin/desktop-wallpaper-cycle random
        ;;
      T)
        exec ${desktopWallpaperAuto}/bin/desktop-wallpaper-auto toggle
        ;;
      O)
        exec ${desktopWallpaperAuto}/bin/desktop-wallpaper-auto off
        ;;
      S)
        ${pkgs.libnotify}/bin/notify-send "Wallpaper" "$autoLabel"
        ;;
      *)
        exit 0
        ;;
    esac
  '';
in
{
  config = lib.mkIf config.programs.niri.enable {
    home.packages = [
      pkgs.swww
      desktopWallpaperApply
      desktopWallpaperCycle
      desktopWallpaperAuto
      desktopWallpaperMenu
    ];

    systemd.user.services.desktop-wallpaper-rotate = {
      Unit = {
        Description = "Rotate desktop wallpaper";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${desktopWallpaperCycle}/bin/desktop-wallpaper-cycle next";
      };
    };

    systemd.user.timers.desktop-wallpaper-rotate = {
      Unit = {
        Description = "Rotate desktop wallpaper periodically";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnBootSec = "5m";
        OnUnitActiveSec = "20m";
        Unit = "desktop-wallpaper-rotate.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.desktop-wallpaper-startup = {
      Unit = {
        Description = "Apply wallpaper during graphical session startup";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        Before = [
          "waybar.service"
          "swaync.service"
        ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 1;
        ExecStart = "${desktopWallpaperApply}/bin/desktop-wallpaper-apply --startup";
        TimeoutStartSec = 10;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
