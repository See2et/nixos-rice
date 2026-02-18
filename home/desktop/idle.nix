{
  pkgs,
  lib,
  config,
  ...
}:
let
  lockCmd = pkgs.writeShellScriptBin "desktop-lock" ''
    exec ${pkgs.swaylock}/bin/swaylock
  '';

  dimCmd = pkgs.writeShellScriptBin "desktop-idle-dim" ''
    ${pkgs.brightnessctl}/bin/brightnessctl -s set 20% >/dev/null 2>&1 || true
  '';

  wakeCmd = pkgs.writeShellScriptBin "desktop-idle-wake" ''
    ${pkgs.niri}/bin/niri msg action power-on-monitors >/dev/null 2>&1 || true
    ${pkgs.brightnessctl}/bin/brightnessctl -r >/dev/null 2>&1 || true
  '';

  powerOffCmd = pkgs.writeShellScriptBin "desktop-display-off" ''
    ${pkgs.niri}/bin/niri msg action power-off-monitors >/dev/null 2>&1 || true
  '';

  lockAndPowerOffCmd = pkgs.writeShellScriptBin "desktop-lock-and-display-off" ''
    ${lockCmd}/bin/desktop-lock >/dev/null 2>&1 || true
    ${powerOffCmd}/bin/desktop-display-off >/dev/null 2>&1 || true
  '';
in
{
  config = lib.mkIf config.programs.niri.enable {
    home.packages = [
      lockCmd
      dimCmd
      wakeCmd
      powerOffCmd
      lockAndPowerOffCmd
    ];

    services.swayidle = {
      enable = true;

      # idle flow: dim -> lock -> display off -> wake
      timeouts = [
        {
          timeout = 240;
          command = "${dimCmd}/bin/desktop-idle-dim";
          resumeCommand = "${wakeCmd}/bin/desktop-idle-wake";
        }
        {
          timeout = 300;
          command = "${lockCmd}/bin/desktop-lock";
        }
        {
          timeout = 330;
          command = "${powerOffCmd}/bin/desktop-display-off";
          resumeCommand = "${wakeCmd}/bin/desktop-idle-wake";
        }
      ];

      events = [
        {
          event = "before-sleep";
          command = "${lockAndPowerOffCmd}/bin/desktop-lock-and-display-off";
        }
        {
          event = "after-resume";
          command = "${wakeCmd}/bin/desktop-idle-wake";
        }
      ];
    };
  };
}
