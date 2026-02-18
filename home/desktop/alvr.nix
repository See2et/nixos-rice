{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.file.".local/bin/alvr-env" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        export WINIT_UNIX_BACKEND=wayland
        if [ -n "''${DISPLAY:-}" ]; then
          display_num="''${DISPLAY#*:}"
          display_num="''${display_num%%.*}"
          if [ -z "$display_num" ] || [ ! -S "/tmp/.X11-unix/X$display_num" ]; then
            if [ -S "/tmp/.X11-unix/X0" ]; then
              export DISPLAY=":0"
            else
              unset DISPLAY
              unset XAUTHORITY
            fi
          fi
        elif [ -S "/tmp/.X11-unix/X0" ]; then
          export DISPLAY=":0"
        fi
      elif [ -n "''${DISPLAY:-}" ]; then
        display_num="''${DISPLAY#*:}"
        display_num="''${display_num%%.*}"

        if [ -n "$display_num" ] && [ ! -S "/tmp/.X11-unix/X$display_num" ]; then
          unset DISPLAY
          unset XAUTHORITY
        fi
      fi
    '';
  };

  home.file.".local/bin/alvr_dashboard" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      . "${config.home.homeDirectory}/.local/bin/alvr-env"

      exec "${pkgs.alvr}/bin/alvr_dashboard" "$@"
    '';
  };

  home.file.".local/bin/alvr_launcher" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      . "${config.home.homeDirectory}/.local/bin/alvr-env"

      exec "${pkgs.alvr}/bin/alvr_launcher" "$@"
    '';
  };

  xdg.desktopEntries.alvr = {
    name = "ALVR";
    genericName = "Game";
    comment = "ALVR is an open source remote VR display which allows playing SteamVR games on a standalone headset such as Gear VR or Oculus Go/Quest.";
    exec = "${config.home.homeDirectory}/.local/bin/alvr_dashboard";
    terminal = false;
    type = "Application";
    icon = "alvr";
    categories = [ "Game" ];
    startupNotify = true;
    settings = {
      StartupWMClass = "alvr.dashboard";
    };
  };

  xdg.desktopEntries.alvr-dashboard = {
    name = "ALVR Dashboard";
    genericName = "VR streaming dashboard";
    exec = "${config.home.homeDirectory}/.local/bin/alvr_dashboard";
    terminal = false;
    type = "Application";
    icon = "alvr";
    categories = [
      "Game"
      "Network"
    ];
    startupNotify = true;
  };

  home.activation.alvrForceSoftwareEncoding = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    session_file="${config.home.homeDirectory}/.config/alvr/session.json"

    if [ -f "$session_file" ]; then
      tmp_file="$(${pkgs.coreutils}/bin/mktemp)"

      if ${pkgs.jq}/bin/jq '
        .openvr_config.force_sw_encoding = true
        | .session_settings.video.encoder_config.software.force_software_encoding = true
      ' "$session_file" > "$tmp_file"; then
        ${pkgs.coreutils}/bin/mv "$tmp_file" "$session_file"
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp_file"
      fi
    fi
  '';
}
