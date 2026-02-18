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

    ensure_daemon() {
      if ! ${pkgs.swww}/bin/swww query >/dev/null 2>&1; then
        ${pkgs.swww}/bin/swww-daemon >/dev/null 2>&1 &
        sleep 0.25
      fi
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
    if [ -z "$target" ]; then
      if [ -s "${currentFile}" ]; then
        target="$(<"${currentFile}")"
      else
        target="$(collect_wallpapers | head -n 1)"
      fi
    fi

    [ -n "$target" ] || exit 0
    [ -f "$target" ] || exit 0

    ensure_daemon

    ${pkgs.swww}/bin/swww img "$target" \
      --transition-type fade \
      --transition-fps 60 \
      --transition-duration 1.0

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
in
{
  config = lib.mkIf config.programs.niri.enable {
    home.packages = [
      pkgs.swww
      desktopWallpaperApply
      desktopWallpaperCycle
      desktopWallpaperAuto
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
  };
}
