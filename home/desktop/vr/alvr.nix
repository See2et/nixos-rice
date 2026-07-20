{
  lib,
  pkgs,
  ...
}:
let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
  patchedFfmpeg = pkgs.ffmpeg.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ./patches/ffmpeg-8.0-vulkan-cuda-packed-format.patch
    ];
  });
  alvr = pkgs.alvr.override {
    ffmpeg = patchedFfmpeg;
  };

  alvrEnvText = ''
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

  alvrDashboard = pkgs.writeShellApplication {
    name = "alvr_dashboard";
    runtimeInputs = [ alvr ];
    text = ''
      ${alvrEnvText}
      exec "${alvr}/bin/alvr_dashboard" "$@"
    '';
  };

  alvrLauncher = pkgs.writeShellApplication {
    name = "alvr_launcher";
    runtimeInputs = [ alvr ];
    text = ''
      ${alvrEnvText}
      exec "${alvr}/bin/alvr_launcher" "$@"
    '';
  };
in
{
  home.packages = lib.optionals isX86_64 [
    alvrDashboard
    alvrLauncher
  ];

  xdg.desktopEntries.alvr = lib.mkIf isX86_64 {
    name = "ALVR";
    genericName = "Game";
    comment = "ALVR is an open source remote VR display which allows playing SteamVR games on a standalone headset such as Gear VR or Oculus Go/Quest.";
    exec = "alvr_dashboard";
    terminal = false;
    type = "Application";
    icon = "alvr";
    categories = [ "Game" ];
    startupNotify = true;
    settings = {
      StartupWMClass = "alvr.dashboard";
    };
  };

  xdg.desktopEntries.alvr-dashboard = lib.mkIf isX86_64 {
    name = "ALVR Dashboard";
    genericName = "VR streaming dashboard";
    exec = "alvr_dashboard";
    terminal = false;
    type = "Application";
    icon = "alvr";
    categories = [
      "Game"
      "Network"
    ];
    startupNotify = true;
  };
}
