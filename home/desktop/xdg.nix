{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.file.".local/bin/steam" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      steam_bin="/run/current-system/sw/bin/steam"
      steamvr_launch=0
      for arg in "$@"; do
        case "$arg" in
          *250820*|*SteamVR*|*steamvr*)
            steamvr_launch=1
            break
            ;;
        esac
      done

      if [ "$steamvr_launch" -eq 1 ]; then
        steamvr_qt_root="${config.home.homeDirectory}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/qt"
        steamvr_qt_lib="$steamvr_qt_root/lib"
        steamvr_qt_plugins="$steamvr_qt_root/plugins"
        nvidia_icd="/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json:/run/opengl-driver-32/share/vulkan/icd.d/nvidia_icd.i686.json"
        export VK_DRIVER_FILES="$nvidia_icd"
        export VK_ICD_FILENAMES="$nvidia_icd"
        export QT_QPA_PLATFORM=xcb
        export QT_PLUGIN_PATH="$steamvr_qt_plugins"
        export LD_LIBRARY_PATH="$steamvr_qt_lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __VK_LAYER_NV_optimus=NVIDIA_only
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export DRI_PRIME=1
      else
        unset VK_DRIVER_FILES VK_ICD_FILENAMES
        unset QT_QPA_PLATFORM QT_PLUGIN_PATH
        unset __NV_PRIME_RENDER_OFFLOAD __VK_LAYER_NV_optimus __GLX_VENDOR_LIBRARY_NAME DRI_PRIME
      fi

      unset VK_LAYER_PATH VK_INSTANCE_LAYERS
      exec "$steam_bin" "$@"
    '';
  };

  home.file.".local/bin/wlx-overlay-s" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      force_openxr=1
      for arg in "$@"; do
        case "$arg" in
          --openxr|--openvr)
            force_openxr=0
            break
            ;;
        esac
      done

      if [ "$force_openxr" -eq 1 ]; then
        exec "${config.home.homeDirectory}/.nix-profile/bin/wlx-overlay-s" --openxr "$@"
      fi

      exec "${config.home.homeDirectory}/.nix-profile/bin/wlx-overlay-s" "$@"
    '';
  };

  home.activation.steamVrLaunchOptions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    steamvr_launch_options="QT_QPA_PLATFORM=xcb %command%"
    userdata_root="${config.home.homeDirectory}/.local/share/Steam/userdata"

    if [ -d "$userdata_root" ]; then
      for localconfig in "$userdata_root"/*/config/localconfig.vdf; do
        [ -f "$localconfig" ] || continue
        tmp_file="$(${pkgs.coreutils}/bin/mktemp)"

        if ${pkgs.python3}/bin/python - "$localconfig" "$tmp_file" "$steamvr_launch_options" <<'PY'
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
desired = sys.argv[3]

text = source.read_text(encoding="utf-8", errors="ignore")
pattern = re.compile(r'("250820"\s*\{)(.*?)(\n([ \t]*)\})', re.S)
match = pattern.search(text)

if not match:
    target.write_text(text, encoding="utf-8")
    raise SystemExit(0)

block_start, block_body, block_end, close_indent = match.groups()

launch_re = re.compile(r'(\n[ \t]*"LaunchOptions"[ \t]*"[^"]*")')
new_launch_line = f'\n{close_indent}\t"LaunchOptions"\t\t"{desired}"'

launch_matches = list(launch_re.finditer(block_body))
if launch_matches:
    target_match = launch_matches[-1]
    new_block_body = (
        f"{block_body[:target_match.start()]}"
        f"{new_launch_line}"
        f"{block_body[target_match.end():]}"
    )
else:
    new_block_body = f"{block_body}{new_launch_line}"

updated = f"{text[:match.start()]}{block_start}{new_block_body}{block_end}{text[match.end():]}"
target.write_text(updated, encoding="utf-8")
PY
        then
          ${pkgs.coreutils}/bin/mv "$tmp_file" "$localconfig"
        else
          ${pkgs.coreutils}/bin/rm -f "$tmp_file"
        fi
      done
    fi
  '';

  home.activation.oyasumiOverlayDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    overlay_config="${config.home.homeDirectory}/.config/oyasumi/overlay_config.toml"

    if [ -f "$overlay_config" ]; then
      tmp_file="$(${pkgs.coreutils}/bin/mktemp)"

      if ${pkgs.python3}/bin/python - "$overlay_config" "$tmp_file" <<'PY'
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
text = source.read_text(encoding="utf-8", errors="ignore")

text = re.sub(
    r"^\s*draw_only_when_on_overlay\s*=\s*true\s*$",
    "draw_only_when_on_overlay = false",
    text,
    flags=re.M,
)
text = re.sub(
    r'^\s*show_mode\s*=\s*"last_controller"\s*$',
    'show_mode="hmd"',
    text,
    flags=re.M,
)

target.write_text(text, encoding="utf-8")
PY
      then
        ${pkgs.coreutils}/bin/mv "$tmp_file" "$overlay_config"
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp_file"
      fi
    fi
  '';

  xdg = {
    mimeApps = {
      enable = true;
      associations.added = {
        "application/xhtml+xml" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "text/html" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "x-scheme-handler/about" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "x-scheme-handler/http" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "x-scheme-handler/https" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "x-scheme-handler/unknown" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
      };
      defaultApplications = {
        "application/xhtml+xml" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "text/html" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "x-scheme-handler/about" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "x-scheme-handler/http" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "x-scheme-handler/https" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
        "x-scheme-handler/unknown" = [
          "zen-url.desktop"
          "zen-beta.desktop"
        ];
      };
    };

    desktopEntries = {
      zen-url = {
        name = "Zen Browser URL Handler";
        genericName = "Web Browser";
        exec = "/etc/profiles/per-user/${config.home.username}/bin/zen-beta --name zen-beta %U";
        terminal = false;
        type = "Application";
        icon = "zen-browser";
        categories = [
          "Network"
          "WebBrowser"
        ];
        mimeType = [
          "application/xhtml+xml"
          "text/html"
          "x-scheme-handler/about"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/unknown"
        ];
        startupNotify = true;
      };

      steam = {
        name = "Steam";
        genericName = "Game platform";
        exec = "${config.home.homeDirectory}/.local/bin/steam %U";
        settings = {
          Path = "${config.home.homeDirectory}/.local/share/Steam/ubuntu12_32";
        };
        terminal = false;
        type = "Application";
        icon = "steam";
        categories = [
          "Network"
          "FileTransfer"
          "Game"
        ];
        mimeType = [
          "x-scheme-handler/steam"
          "x-scheme-handler/steamlink"
        ];
        startupNotify = true;
      };
    };

    configFile = {
      "wayvr/openxr_actions.json5".source = ./wayvr/openxr_actions.json5;
      "wlxoverlay/openxr_actions.json5".source = ./wayvr/openxr_actions.json5;
    };

  };
}
